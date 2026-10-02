// Pomodoro/PomodoroAppShortcuts.swift
import AppIntents

struct PomodoroAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPomodoroIntent(),
            phrases: [
                "Start a focus session with \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "play.fill"
        )
        // "Start Deep Work with Steady." Siri fills \.$profile from
        // the user's own profile names (TimerProfileQuery); the app calls
        // updateAppShortcutParameters() whenever profiles change so new or
        // renamed ones are recognized. Also the action to pick for the
        // Action Button (Settings → Action Button → Shortcut).
        AppShortcut(
            intent: StartProfileIntent(),
            phrases: [
                "Start \(\.$profile) with \(.applicationName)",
                "Start \(\.$profile) in \(.applicationName)",
                "Start a \(\.$profile) session with \(.applicationName)"
            ],
            shortTitle: "Start Profile",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: PausePomodoroIntent(),
            phrases: [
                "Pause my \(.applicationName) timer",
                "Pause \(.applicationName)"
            ],
            shortTitle: "Pause",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: ResumePomodoroIntent(),
            phrases: [
                "Resume my \(.applicationName) timer",
                "Resume \(.applicationName)"
            ],
            shortTitle: "Resume",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: SkipPomodoroIntent(),
            phrases: [
                "Skip my \(.applicationName) phase",
                "Skip \(.applicationName)"
            ],
            shortTitle: "Skip",
            systemImageName: "forward.fill"
        )
    }
}
