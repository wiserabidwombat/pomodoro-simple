// Shared/WatchConnectivityRelay.swift
import Foundation
import WatchConnectivity

/// Thin WCSessionDelegate wrapper shared by both the phone app and the
/// watch app — WatchConnectivity is the only way for them to exchange
/// state, since a paired Watch can't reach the phone's App Group
/// container the way the widget extension does on the same device.
///
/// Uses updateApplicationContext rather than sendMessage/transferUserInfo:
/// only the *latest* state ever matters for a live countdown, and context
/// is still delivered next time the counterpart launches even if it isn't
/// currently reachable, unlike sendMessage.
final class WatchConnectivityRelay: NSObject {
    struct Payload: Codable {
        let state: PomodoroState
        let accentColor: AccentColorOption
        let durations: PomodoroDurations
    }

    var onReceive: ((PomodoroState, AccentColorOption, PomodoroDurations) -> Void)?

    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func send(state: PomodoroState, accentColor: AccentColorOption, durations: PomodoroDurations) {
        guard let session, session.activationState == .activated else { return }
        let payload = Payload(state: state, accentColor: accentColor, durations: durations)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? session.updateApplicationContext(["payload": data])
    }
}

extension WatchConnectivityRelay: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["payload"] as? Data,
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onReceive?(payload.state, payload.accentColor, payload.durations)
        }
    }

    // Required by WCSessionDelegate on iOS only — watchOS's WCSessionDelegate
    // doesn't declare these.
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
