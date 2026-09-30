// Shared/WatchConnectivityRelay.swift
import Foundation
import WatchConnectivity
import os

private let watchLogger = Logger(subsystem: "com.aarontilley.pomodoro", category: "WatchConnectivity")

/// What the iPhone and Apple Watch tell each other. The phone owns the
/// accent color and timer profiles, so it always sends them; the watch only
/// sends the timer state (those fields stay nil).
struct WatchSyncPayload: Codable, Equatable {
    var state: PomodoroState
    var accentColor: AccentColorOption? = nil
    var profile: TimerProfile? = nil
    var profileLabel: String? = nil
}

/// Thin WCSession wrapper, compiled into the iPhone app and the watch app
/// (it's inert in the widget extension, which never creates one). A paired
/// Watch can't read the phone's App Group, so this is the only channel.
///
/// Two kinds of traffic, each on the WatchConnectivity call built for it:
/// - Timer state → updateApplicationContext: only the *latest* value
///   matters, and it's delivered when the other side next runs even if it
///   isn't reachable now.
/// - Finished Focus sessions (watch → phone) → transferUserInfo: every one
///   must arrive, in order, even hours later, so they're queued rather than
///   replaced.
final class WatchConnectivityRelay: NSObject {
    /// Called on the main queue.
    var onReceivePayload: ((WatchSyncPayload) -> Void)?
    /// Called on the main queue (iPhone side).
    var onReceiveCompletedSession: ((PendingCompletedSession) -> Void)?

    private let session: WCSession?
    /// Anything sent before activation finishes is held and sent right after.
    private var pendingPayload: WatchSyncPayload?
    private var pendingSessions: [PendingCompletedSession] = []
    private let lock = NSLock()

    override init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func send(_ payload: WatchSyncPayload) {
        guard let session, session.activationState == .activated else {
            lock.withLock { pendingPayload = payload }
            return
        }
        #if os(iOS)
        // No watch app to talk to — nothing to do (and nothing to log).
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        guard let data = try? JSONEncoder().encode(payload) else { return }
        do {
            try session.updateApplicationContext(["payload": data])
        } catch {
            watchLogger.error("updateApplicationContext threw: \(String(describing: error), privacy: .public)")
        }
    }

    func sendCompletedSession(_ completed: PendingCompletedSession) {
        guard let session, session.activationState == .activated else {
            lock.withLock { pendingSessions.append(completed) }
            return
        }
        guard let data = try? JSONEncoder().encode(completed) else { return }
        session.transferUserInfo(["completedSession": data])
    }

    private func flushPending() {
        let (payload, sessions) = lock.withLock { () -> (WatchSyncPayload?, [PendingCompletedSession]) in
            defer { pendingPayload = nil; pendingSessions = [] }
            return (pendingPayload, pendingSessions)
        }
        if let payload { send(payload) }
        sessions.forEach(sendCompletedSession)
    }
}

extension WatchConnectivityRelay: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            watchLogger.error("activation failed: \(String(describing: error), privacy: .public)")
            return
        }
        watchLogger.log("activation completed, state=\(activationState.rawValue, privacy: .public)")
        flushPending()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["payload"] as? Data,
              let payload = try? JSONDecoder().decode(WatchSyncPayload.self, from: data)
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onReceivePayload?(payload)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["completedSession"] as? Data,
              let completed = try? JSONDecoder().decode(PendingCompletedSession.self, from: data)
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onReceiveCompletedSession?(completed)
        }
    }

    // iOS-only requirements (watchOS's WCSessionDelegate doesn't declare them).
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Switching to a different paired watch: reactivate for the new one.
        session.activate()
    }
    #endif
}
