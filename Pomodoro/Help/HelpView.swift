// Pomodoro/Help/HelpView.swift
import SwiftUI

struct HelpView: View {
    let accentColor: AccentColorOption
    let durations: PomodoroDurations
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How Pomodoro Works")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    helpSection(
                        title: "Where the name comes from",
                        body: "Pomodoro is Italian for \"tomato.\" University student Francesco Cirillo invented the technique in the late 1980s, using a tomato-shaped kitchen timer to break his study sessions into focused intervals — the name stuck."
                    )
                    helpSection(
                        title: "The cycle",
                        body: "Work in a \(durations.workMinutes)-minute Focus session, then take a \(durations.shortBreakMinutes)-minute Short Break. Repeat. Every 4th Focus session is followed by a longer \(durations.longBreakMinutes)-minute Long Break, after which the cycle count resets and you start back at Focus #1. The 4 dots below the countdown fill in one at a time as each Focus session in the current cycle completes. (Durations can be changed in Settings.)"
                    )
                    helpSection(
                        title: "Controls",
                        body: "Pause and Resume freeze and continue the current phase's countdown. Skip jumps straight to the next phase without waiting it out."
                    )
                    helpSection(
                        title: "Lock Screen & StandBy",
                        body: "While a session is running, a Live Activity shows the countdown on your Lock Screen, in the Dynamic Island, and on StandBy — with the same Pause/Resume/Skip controls, so you don't need to open the app."
                    )
                    helpSection(
                        title: "Restart",
                        body: "The circular-arrow button stops the current session entirely and resets back to the start of a fresh Focus session, cycle count included."
                    )

                    Button("Got it") { dismiss() }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                }
                .padding()
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(accentColor.color)
    }

    private func helpSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(accentColor.color.opacity(0.85))
        }
    }
}
