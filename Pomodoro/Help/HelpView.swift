// Pomodoro/Help/HelpView.swift
import SwiftUI

struct HelpView: View {
    let accentColor: AccentColorOption
    let profile: TimerProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How Pomodoro Works")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    helpSection(
                        title: "Where the name comes from",
                        body: "Pomodoro is Italian for \"tomato.\" University student Francesco Cirillo invented the technique in the late 1980s, using a tomato-shaped kitchen timer to break his study sessions into focused intervals — the name stuck."
                    )
                    helpSection(
                        title: "The cycle",
                        body: cycleDescription
                    )
                    helpSection(
                        title: "Timer profiles",
                        body: "Save different setups — like Deep Work or Study — under Settings → Timer Profiles, each with its own lengths and number of Focus sessions per cycle. Switch between them with the button above the timer whenever no session is running. Stats shows each profile on its own and everything combined."
                    )
                    helpSection(
                        title: "Controls",
                        body: "Pause and Resume freeze and continue the current phase's countdown. Skip jumps straight to the next phase without waiting it out. During Focus, Skip first asks: once you're at least halfway through, you can Finish & Count It to record the session in Stats (with the time you actually focused); otherwise it moves on without counting."
                    )
                    helpSection(
                        title: "Siri, Shortcuts & the Action Button",
                        body: "Say \"Start Deep Work with Simple Timer\" (use any of your profile names), or just \"Start Simple Timer\" for the current profile. To start a profile with one press, go to Settings → Action Button → Shortcut and choose Start Timer Profile; the same action works in any Shortcut."
                    )
                    helpSection(
                        title: "Lock Screen & StandBy",
                        body: "While a session is running, a Live Activity shows the countdown on your Lock Screen, in the Dynamic Island, and on StandBy — with the same Pause/Resume/Skip controls, so you don't need to open the app. When a phase ends while your phone is locked, tap Continue (or just dismiss the notification) to start the next one."
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
                // iPad's sheets are much wider than a phone; keep the text
                // at a readable line length, centered.
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(accentColor.color)
    }

    private var cycleDescription: String {
        let d = profile.durations
        let n = profile.sessionsBeforeLongBreak
        let longBreakTiming = n == 1
            ? "Every Focus session is followed by a longer \(d.longBreakMinutes)-minute Long Break."
            : "After every \(n) Focus sessions you get a longer \(d.longBreakMinutes)-minute Long Break, then the cycle starts over."
        return "Work in a \(d.workMinutes)-minute Focus session, then take a \(d.shortBreakMinutes)-minute Short Break. Repeat. \(longBreakTiming) The dots below the countdown fill in as each Focus session in the current cycle completes. (These are the \(profile.name) profile's settings.)"
    }

    private func helpSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.body)
                .foregroundStyle(accentColor.color.opacity(0.85))
        }
    }
}
