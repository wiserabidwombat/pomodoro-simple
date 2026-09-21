// Pomodoro/Onboarding/NotificationPrimerView.swift
import SwiftUI

/// Shown once, before the real system permission dialog, so the user has
/// context for why it's asking — priming like this measurably raises
/// opt-in rates versus a cold system prompt with no explanation. Only
/// calls into NotificationScheduler if the user opts in here; choosing
/// "Not Now" skips the system prompt entirely for this launch.
struct NotificationPrimerView: View {
    let accentColor: AccentColorOption
    let onChoice: (_ enableNotifications: Bool) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "bell.badge")
                    .font(.system(size: 52))
                Text("Stay on Track")
                    .font(.title2.bold())
                Text("Simple: StandBy Timer can let you know the moment a Focus session or break ends — even if the app is closed or your phone is locked. That's the only thing it sends; no ads, no other reminders.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .opacity(0.85)
                    .padding(.horizontal, 32)
                Spacer()
                Button("Enable Notifications") { onChoice(true) }
                    .font(.headline)
                Button("Not Now") { onChoice(false) }
                    .opacity(0.6)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: 500)
        }
        .foregroundStyle(accentColor.color)
    }
}
