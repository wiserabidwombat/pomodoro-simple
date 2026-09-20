// Pomodoro/Settings/SettingsView.swift
import Intents
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Accent Color")
                    .foregroundStyle(viewModel.accentColor.color)
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(AccentColorOption.allCases) { option in
                        Circle()
                            .fill(option.color)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().strokeBorder(.white, lineWidth: option == viewModel.accentColor ? 3 : 0)
                            )
                            .onTapGesture { viewModel.accentColor = option }
                    }
                }
                .padding()

                Text("Durations")
                    .foregroundStyle(viewModel.accentColor.color)
                    .font(.headline)
                VStack(spacing: 12) {
                    durationStepper(
                        "Focus",
                        minutes: Binding(
                            get: { viewModel.durations.workMinutes },
                            set: { viewModel.durations.workMinutes = $0 }
                        ),
                        range: 1...120
                    )
                    durationStepper(
                        "Short Break",
                        minutes: Binding(
                            get: { viewModel.durations.shortBreakMinutes },
                            set: { viewModel.durations.shortBreakMinutes = $0 }
                        ),
                        range: 1...60
                    )
                    durationStepper(
                        "Long Break",
                        minutes: Binding(
                            get: { viewModel.durations.longBreakMinutes },
                            set: { viewModel.durations.longBreakMinutes = $0 }
                        ),
                        range: 1...60
                    )
                }
                .padding(.horizontal)

                Toggle(isOn: Binding(
                    get: { viewModel.silenceDuringFocus },
                    set: { newValue in
                        viewModel.silenceDuringFocus = newValue
                        if newValue {
                            INFocusStatusCenter.default.requestAuthorization { _ in }
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Silence Alerts During Focus")
                            .foregroundStyle(.white)
                        Text("Skips the phase-change sound and haptic while one of your Focus modes is on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(viewModel.accentColor.color)
                .padding(.horizontal)
            }
        }
    }

    private func durationStepper(_ title: String, minutes: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: minutes, in: range) {
            HStack {
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(minutes.wrappedValue) min")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
