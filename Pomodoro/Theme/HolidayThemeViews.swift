import SwiftUI

/// The screen background: plain black normally; with a holiday theme, the
/// theme's tint fading into black from the top, plus (on the Timer screen)
/// slowly drifting particles.
struct ThemedBackground: View {
    let theme: HolidayTheme?
    var showsParticles = false
    /// Pass false while the screen is off-screen so the animation stops.
    var isAnimating = true

    var body: some View {
        ZStack {
            Color.black
            if let theme {
                LinearGradient(
                    colors: [theme.backgroundTint, .black],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.65)
                )
                if showsParticles {
                    HolidayParticlesView(theme: theme, isAnimating: isAnimating)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// A dozen emoji drifting across the screen, faint enough to stay behind
/// the countdown. Drawn in one Canvas at up to 30 fps; holds still with
/// Reduce Motion or Low Power Mode on, and pauses when not on screen.
struct HolidayParticlesView: View {
    let theme: HolidayTheme
    var isAnimating = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particles: [DriftParticle]

    init(theme: HolidayTheme, isAnimating: Bool = true) {
        self.theme = theme
        self.isAnimating = isAnimating
        var random = SeededRandom(seed: UInt64(theme.rawValue.unicodeScalars.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1.value) }))
        particles = (0..<12).map { _ in DriftParticle(random: &random, symbolCount: theme.ambientParticles.count) }
    }

    var body: some View {
        let holdStill = reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: holdStill || !isAnimating)) { timeline in
            // Holding still freezes the particles in a scattered layout.
            let time = holdStill ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.opacity = 0.4
                for particle in particles {
                    let symbol = theme.ambientParticles[particle.symbolIndex]
                    let text = context.resolve(Text(symbol).font(.system(size: particle.size)))
                    let position = particle.position(at: time, in: size, rises: theme.particlesRise)
                    context.drawLayer { layer in
                        layer.translateBy(x: position.x, y: position.y)
                        layer.rotate(by: .degrees(particle.rotation(at: time)))
                        layer.draw(text, at: .zero)
                    }
                }
            }
        }
    }
}

/// A burst of the theme's celebration emoji from the middle of the screen,
/// played each time `trigger` changes. Skipped with Reduce Motion on.
struct CelebrationBurstView: View {
    let theme: HolidayTheme
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    private static let duration: TimeInterval = 2.2
    private static let pieces = 26

    var body: some View {
        ZStack {
            if let startedAt {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startedAt)
                    Canvas { context, size in
                        draw(in: &context, size: size, elapsed: elapsed)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            let start = Date()
            startedAt = start
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.duration + 0.1))
                if startedAt == start { startedAt = nil }
            }
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        guard elapsed >= 0, elapsed < Self.duration else { return }
        let symbols = theme.celebrationParticles
        let origin = CGPoint(x: size.width / 2, y: size.height * 0.42)
        let gravity = 520.0
        // Fade out over the last 40%.
        context.opacity = min(1, (Self.duration - elapsed) / (Self.duration * 0.4))
        for index in 0..<Self.pieces {
            // Evenly spread angles with a fixed wobble, so every burst looks
            // the same and nothing random runs per frame.
            let angle = Double(index) / Double(Self.pieces) * 2 * .pi + sin(Double(index) * 12.9898) * 0.25
            let speed = 260 + 160 * abs(sin(Double(index) * 78.233))
            let x = origin.x + cos(angle) * speed * elapsed
            let y = origin.y + sin(angle) * speed * elapsed + 0.5 * gravity * elapsed * elapsed
            let size = 22 + 10 * abs(cos(Double(index) * 3.7))
            let text = context.resolve(Text(symbols[index % symbols.count]).font(.system(size: size)))
            context.drawLayer { layer in
                layer.translateBy(x: x, y: y)
                layer.rotate(by: .degrees(Double(index % 2 == 0 ? 1 : -1) * 140 * elapsed))
                layer.draw(text, at: .zero)
            }
        }
    }
}

// MARK: - Particle motion

/// One drifting emoji. Everything is fixed when created, and its position
/// is a pure function of time, so the Canvas keeps no per-frame state.
private struct DriftParticle {
    let symbolIndex: Int
    /// Horizontal lane, 0...1 of the width.
    let lane: Double
    /// Screen heights per second.
    let speed: Double
    /// Where in its loop it starts, 0...1.
    let phase: Double
    let size: CGFloat
    let swayAmplitude: Double
    let swaySpeed: Double
    let spinSpeed: Double

    init(random: inout SeededRandom, symbolCount: Int) {
        symbolIndex = Int.random(in: 0..<max(symbolCount, 1), using: &random)
        lane = Double.random(in: 0.05...0.95, using: &random)
        speed = Double.random(in: 0.025...0.06, using: &random)
        phase = Double.random(in: 0...1, using: &random)
        size = CGFloat.random(in: 16...28, using: &random)
        swayAmplitude = Double.random(in: 8...28, using: &random)
        swaySpeed = Double.random(in: 0.4...1.1, using: &random)
        spinSpeed = Double.random(in: -25...25, using: &random)
    }

    func position(at time: TimeInterval, in size: CGSize, rises: Bool) -> CGPoint {
        let margin = Double(self.size) * 2
        let travel = Double(size.height) + margin * 2
        let progress = (phase + time * speed).truncatingRemainder(dividingBy: 1)
        let y = rises ? Double(size.height) + margin - progress * travel : -margin + progress * travel
        let x = lane * Double(size.width) + sin(time * swaySpeed + phase * 2 * .pi) * swayAmplitude
        return CGPoint(x: x, y: y)
    }

    func rotation(at time: TimeInterval) -> Double {
        phase * 360 + time * spinSpeed
    }
}

/// SplitMix64: the same seed gives the same particle layout every launch.
private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
