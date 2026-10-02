// Pomodoro/Timer/FloatingTimerController.swift
import AVFoundation
import AVKit
import CoreMedia
import SwiftUI
import UIKit
import os

private let floatingLogger = Logger(subsystem: "com.aarontilley.pomodoro", category: "FloatingTimer")

/// The floating timer: a Picture in Picture window showing the countdown
/// over other apps (iPad's stand-in for the iPhone's Live Activity).
///
/// iOS only does Picture in Picture for video, so this is a tiny "video":
/// once a second it draws a frame (phase, countdown, progress bar) and hands
/// it to an AVSampleBufferDisplayLayer. The window's play/pause button
/// pauses and resumes the timer. While it's showing, the app keeps running
/// in the background, so each frame also gives the view model a tick, which
/// keeps phases advancing (and Stats, alerts, and widgets up to date) just
/// as if the app were open. Needs the "audio" background mode (Xcode's
/// "Audio, AirPlay, and Picture in Picture").
@MainActor
final class FloatingTimerController: NSObject, ObservableObject {
    static var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    @Published private(set) var isActive = false

    /// Read by the timer each frame. Set once by TimerView.
    weak var viewModel: TimerViewModel? {
        didSet { renderFrame() }
    }

    /// Must be in the window for Picture in Picture to be possible (see
    /// FloatingTimerLayerHost); it never needs to be visible.
    let displayLayer = AVSampleBufferDisplayLayer()

    private var pipController: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var frameTimer: Timer?
    private var startWhenPossible = false
    private var lastReportedPaused: Bool?
    /// The system asks "is it paused?" synchronously on its own terms; this
    /// keeps the answer readable from any thread without touching the
    /// main actor.
    private let pausedForSystem = OSAllocatedUnfairLock(initialState: true)

    private static let frameSize = CGSize(width: 640, height: 360)

    override init() {
        super.init()
        displayLayer.videoGravity = .resizeAspect
        guard Self.isSupported else { return }
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        // A countdown has no timeline to scrub or skip through.
        controller.requiresLinearPlayback = true
        // Only when asked, never automatically on leaving the app.
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] controller, _ in
            let possible = controller.isPictureInPicturePossible
            Task { @MainActor in self?.possibleDidChange(possible) }
        }
        pipController = controller
    }

    // MARK: - Starting and stopping

    func toggle() {
        if isActive {
            pipController?.stopPictureInPicture()
        } else {
            start()
        }
    }

    private func start() {
        guard let pipController else { return }
        // An active playback session is what lets the window keep running
        // with the app in the background. mixWithOthers: never interrupts
        // music or podcasts (this "video" has no sound).
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            floatingLogger.error("Audio session setup failed: \(String(describing: error), privacy: .public)")
        }
        renderFrame()
        startFrameTimer()
        if pipController.isPictureInPicturePossible {
            pipController.startPictureInPicture()
        } else {
            // Possible once the layer has a frame and is on screen; the
            // observer above starts it then.
            startWhenPossible = true
        }
    }

    private func possibleDidChange(_ possible: Bool) {
        guard possible, startWhenPossible else { return }
        startWhenPossible = false
        pipController?.startPictureInPicture()
    }

    private func didStop() {
        isActive = false
        startWhenPossible = false
        frameTimer?.invalidate()
        frameTimer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startFrameTimer() {
        frameTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.renderFrame() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    /// The window's play/pause button.
    private func setPlaying(_ playing: Bool) {
        guard let viewModel else { return }
        let state = viewModel.state
        if playing {
            if !state.sessionActive {
                viewModel.start()
            } else if state.pausedAt != nil {
                viewModel.resume()
            }
        } else if state.sessionActive && state.pausedAt == nil {
            viewModel.pause()
        }
        renderFrame()
    }

    // MARK: - Frames

    private func renderFrame() {
        guard let viewModel else { return }
        if isActive {
            // With the app in the background its own ticker is stopped;
            // this keeps phases advancing while the window is showing.
            viewModel.tick()
        }
        let state = viewModel.state
        let profile = viewModel.activeProfile
        let paused = !state.sessionActive || state.pausedAt != nil
        let title: String
        let countdown: String
        if !state.sessionActive {
            title = "Ready"
            countdown = "\(profile.durations.workMinutes):00"
        } else {
            let phaseTitle = state.phase.title(profileLabel: viewModel.profiles.count > 1 ? profile.name : nil)
            title = state.pausedAt != nil ? "Paused · \(phaseTitle)" : phaseTitle
            countdown = state.pausedAt != nil
                ? state.formattedRemainingWhilePaused
                : PomodoroState.formattedRemaining(endDate: state.endDate, asOf: Date())
        }
        let length = profile.durations.duration(for: state.phase)
        let progress = state.sessionActive && length > 0 ? min(1, state.remainingSeconds() / length) : 1

        if let image = Self.drawFrame(title: title, countdown: countdown, progress: progress, accent: UIColor(viewModel.displayAccent.color)),
           let sampleBuffer = Self.makeSampleBuffer(from: image) {
            if displayLayer.status == .failed {
                displayLayer.flush()
            }
            displayLayer.enqueue(sampleBuffer)
        }

        pausedForSystem.withLock { $0 = paused }
        if paused != lastReportedPaused {
            lastReportedPaused = paused
            pipController?.invalidatePlaybackState()
        }
    }

    private static func drawFrame(title: String, countdown: String, progress: Double, accent: UIColor) -> CGImage? {
        let size = frameSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            centered.lineBreakMode = .byTruncatingTail

            title.draw(in: CGRect(x: 24, y: 34, width: size.width - 48, height: 46), withAttributes: [
                .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
                .foregroundColor: accent.withAlphaComponent(0.85),
                .paragraphStyle: centered,
            ])
            countdown.draw(in: CGRect(x: 0, y: 92, width: size.width, height: 180), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 150, weight: .bold),
                .foregroundColor: accent,
                .paragraphStyle: centered,
            ])

            let track = CGRect(x: 64, y: 300, width: size.width - 128, height: 10)
            UIColor(white: 1, alpha: 0.15).setFill()
            UIBezierPath(roundedRect: track, cornerRadius: 5).fill()
            accent.setFill()
            UIBezierPath(
                roundedRect: CGRect(x: track.minX, y: track.minY, width: track.width * max(0, min(1, progress)), height: track.height),
                cornerRadius: 5
            ).fill()
        }
        return image.cgImage
    }

    /// A one-frame "video" sample for the display layer, shown immediately.
    private static func makeSampleBuffer(from image: CGImage) -> CMSampleBuffer? {
        let width = image.width
        let height = image.height
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ] as CFDictionary
        var pixelBufferOut: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes, &pixelBufferOut) == kCVReturnSuccess,
              let pixelBuffer = pixelBufferOut
        else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let drawn: Bool = {
            guard let context = CGContext(
                data: CVPixelBufferGetBaseAddress(pixelBuffer),
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }()
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        guard drawn else { return nil }

        var formatOut: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatOut
        ) == noErr, let format = formatOut else { return nil }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sampleOut: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sampleOut
        ) == noErr, let sampleBuffer = sampleOut else { return nil }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        return sampleBuffer
    }
}

// MARK: - System callbacks
// AVKit may call these on any thread. None of them touch main-actor state
// directly: work hops to the main actor, and the paused question is
// answered from a lock. (Assuming the main thread here is the same kind of
// mistake as the notification-dismiss crash.)

extension FloatingTimerController: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        Task { @MainActor in self.setPlaying(playing) }
    }

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // "Live": no scrubber, no time display.
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        pausedForSystem.withLock { $0 }
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

extension FloatingTimerController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in self.isActive = true }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in self.didStop() }
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        floatingLogger.error("Picture in Picture failed to start: \(String(describing: error), privacy: .public)")
        Task { @MainActor in self.didStop() }
    }
}

/// Puts the floating timer's display layer in the window, where Picture in
/// Picture requires it to be. A couple of points square and black: never
/// noticeable.
struct FloatingTimerLayerHost: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .black
        view.displayLayer = displayLayer
        return view
    }

    func updateUIView(_ uiView: HostView, context: Context) {}

    final class HostView: UIView {
        var displayLayer: CALayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let displayLayer { layer.addSublayer(displayLayer) }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            displayLayer?.frame = bounds
        }
    }
}
