// PomodoroWatch/WatchTimerViewModel.swift
import Foundation
import WatchKit

/// The watch runs its own TimerEngine against its own local storage
/// (UserDefaults.standard) — a paired Watch can't read the iPhone's App
/// Group — so every button works instantly, even with the phone out of
/// range. WatchConnectivityRelay keeps the two in step afterwards: the
/// phone sends its state, active profile, and accent color; the watch sends
/// back its own timer changes and any Focus sessions it finished, which the
/// phone records in Stats.
@MainActor
final class WatchTimerViewModel: ObservableObject {
    @Published private(set) var state: PomodoroState
    @Published private(set) var accentColor: AccentColorOption
    @Published private(set) var profile: TimerProfile
    /// The profile's name, or nil when the phone has only one profile.
    @Published private(set) var profileLabel: String?

    private let engine: TimerEngine
    private let store: PomodoroStateStore
    private let relay: WatchConnectivityRelay
    private var ticker: Timer?

    init(relay: WatchConnectivityRelay) {
        self.relay = relay
        let store = PomodoroStateStore(defaults: .standard)
        self.store = store
        let loadedState = store.loadState()
        let loadedProfile = store.loadActiveProfile()
        self.engine = TimerEngine(state: loadedState, profile: loadedProfile)
        self.state = loadedState
        self.accentColor = store.loadAccentColor()
        self.profile = loadedProfile
        self.profileLabel = UserDefaults.standard.string(forKey: Self.profileLabelKey)

        relay.onReceivePayload = { [weak self] payload in
            Task { @MainActor in self?.adopt(payload) }
        }
        startTicker()
    }

    private static let profileLabelKey = "watch.profileLabel"

    // MARK: - Actions

    func start() {
        engine.start()
        persistAndSync()
    }

    func pause() {
        catchUpIfNeeded()
        engine.pause()
        persistAndSync()
    }

    func resume() {
        catchUpIfNeeded()
        engine.resume()
        persistAndSync()
    }

    func skip() {
        catchUpIfNeeded()
        engine.skip()
        persistAndSync()
    }

    func restart() {
        engine.reset()
        persistAndSync()
    }

    func focusElapsed() -> TimeInterval? {
        engine.focusElapsed()
    }

    var minimumFocusToCount: TimeInterval {
        engine.minimumFocusToCount
    }

    /// Same rule as the iPhone: past the halfway mark, a Focus session can
    /// end early and still count.
    func finishEarly() {
        catchUpIfNeeded()
        guard let completed = engine.finishEarly() else { return }
        report(completed)
        persistAndSync()
    }

    // MARK: - Sync

    /// A state (plus profile and color) from the phone. Last write wins —
    /// the same rule the phone uses between the app, widget, and Lock Screen.
    /// Not sent back, so it can't bounce between the devices.
    private func adopt(_ payload: WatchSyncPayload) {
        engine.reload(payload.state)
        state = payload.state
        store.save(payload.state)
        if let accentColor = payload.accentColor {
            self.accentColor = accentColor
            store.save(accentColor)
        }
        if let profile = payload.profile {
            self.profile = profile
            engine.updateProfile(profile)
            store.save(profiles: [profile])
            store.saveActiveProfileID(profile.id)
        }
        profileLabel = payload.profileLabel
        UserDefaults.standard.set(payload.profileLabel, forKey: Self.profileLabelKey)
    }

    private func persistAndSync() {
        state = engine.state
        store.save(state)
        relay.send(WatchSyncPayload(state: state))
    }

    /// A Focus session finished on the watch: tell the phone so it lands in
    /// Stats. Queued by WatchConnectivity, so it arrives even if the phone
    /// is out of range right now. (If the phone noticed the same session end
    /// on its own, its history skips the duplicate.)
    private func report(_ completed: CompletedPhase) {
        guard completed.phase == .work else { return }
        relay.sendCompletedSession(PendingCompletedSession(
            endedAt: completed.endedAt,
            duration: completed.duration,
            profileID: profile.id,
            profileName: profile.name
        ))
    }

    private func catchUpIfNeeded() {
        if let completed = engine.catchUpIfExpired() {
            report(completed)
            // A tap on the wrist when a phase ends with the app open. (With
            // the app closed, the iPhone's phase-end notification is
            // mirrored to the watch by the system instead.)
            WKInterfaceDevice.current().play(.notification)
            persistAndSync()
        } else if state != engine.state {
            state = engine.state
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.catchUpIfNeeded() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }
}
