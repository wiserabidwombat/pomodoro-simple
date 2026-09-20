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
