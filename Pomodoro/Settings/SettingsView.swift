// Pomodoro/Settings/SettingsView.swift
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
            }
        }
    }
}
