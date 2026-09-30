// Shared/PomodoroActivityAttributes.swift
import ActivityKit
import Foundation

struct PomodoroActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phase: PomodoroPhase
        var startDate: Date
        var endDate: Date
        var pausedAt: Date?
        var accentColor: AccentColorOption
        /// Shown before the phase ("Deep Work · Focus"); nil with only one
        /// profile. Optional with a default so content encoded by an older
        /// build still decodes.
        var profileName: String? = nil

        var title: String {
            phase.title(profileLabel: profileName)
        }

        /// "MM:SS" for the frozen remaining time while paused. Used instead
        /// of `Text(timerInterval:pauseTime:)`'s own pause handling, which
        /// has proven unreliable on this SDK.
        ///
        /// Rounds up (ceiling), not to nearest — see PomodoroState's
        /// matching property for why: `Text(timerInterval:countsDown:)`
        /// holds a number until a full second has actually elapsed, so
        /// rounding to nearest would occasionally show one second less than
        /// what was just on screen, making resume look like it added a
        /// second back.
        var formattedRemainingWhilePaused: String {
            PomodoroState.formattedRemaining(endDate: endDate, asOf: pausedAt ?? Date())
        }
    }
}

extension PomodoroActivityAttributes.ContentState {
    /// The one place app-side state becomes Live Activity content — used by
    /// LiveActivityController and the Lock Screen intents alike. (Declared
    /// in an extension so the memberwise initializer stays available.)
    init(_ state: PomodoroState, accentColor: AccentColorOption, profileName: String? = nil) {
        self.init(
            phase: state.phase,
            startDate: state.startDate,
            endDate: state.endDate,
            pausedAt: state.pausedAt,
            accentColor: accentColor,
            profileName: profileName
        )
    }

    /// Only stale-mark while actually counting down — a paused display is
    /// frozen but still accurate indefinitely, so it should never be
    /// treated as stale just because endDate (a "completion time if resumed
    /// right now" snapshot) has passed while sitting paused.
    var staleDate: Date? {
        pausedAt == nil ? endDate : nil
    }
}
