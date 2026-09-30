// Pomodoro/Settings/SettingsView.swift
import AudioToolbox
import Intents
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.self) private var environment
    @State private var editingProfile: TimerProfile?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text("Accent Color")
                        .foregroundStyle(viewModel.accentColor.color)
                        .font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(AccentColorOption.presets, id: \.self) { option in
                            Circle()
                                .fill(option.color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle().strokeBorder(.white, lineWidth: option == viewModel.accentColor ? 3 : 0)
                                )
                                .onTapGesture { viewModel.accentColor = option }
                        }
                        ColorPicker("Custom", selection: Binding(
                            get: { viewModel.accentColor.color },
                            set: { newColor in
                                let resolved = newColor.resolve(in: environment)
                                viewModel.accentColor = .custom(
                                    red: Double(resolved.red),
                                    green: Double(resolved.green),
                                    blue: Double(resolved.blue)
                                )
                            }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(1.5)
                        .frame(width: 44, height: 44)
                    }
                    .padding()

                    Text("Timer Profiles")
                        .foregroundStyle(viewModel.accentColor.color)
                        .font(.headline)
                    VStack(spacing: 12) {
                        ForEach(viewModel.profiles) { profile in
                            Button {
                                editingProfile = profile
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name)
                                            .foregroundStyle(.white)
                                        Text(profile.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if profile.id == viewModel.activeProfile.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(viewModel.accentColor.color)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            // New profiles start from the active one's
                            // settings; the name is left blank to fill in.
                            editingProfile = TimerProfile(
                                name: "",
                                durations: viewModel.activeProfile.durations,
                                sessionsBeforeLongBreak: viewModel.activeProfile.sessionsBeforeLongBreak
                            )
                        } label: {
                            Label("Add Profile", systemImage: "plus")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(viewModel.accentColor.color)
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

                    Text("Sound")
                        .foregroundStyle(viewModel.accentColor.color)
                        .font(.headline)
                    Toggle(isOn: $viewModel.soundEnabled) {
                        Text("Play Sound")
                            .foregroundStyle(.white)
                    }
                    .tint(viewModel.accentColor.color)
                    .padding(.horizontal)

                    VStack(spacing: 8) {
                        ForEach(ChimeOption.allCases) { option in
                            Button {
                                viewModel.chime = option
                                AudioServicesPlaySystemSound(option.rawValue)
                            } label: {
                                HStack {
                                    Text(option.displayName)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if viewModel.chime == option {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(viewModel.accentColor.color)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(
                profile: profile,
                isNew: !viewModel.profiles.contains(where: { $0.id == profile.id }),
                canDelete: viewModel.canDeleteProfile(profile),
                accentColor: viewModel.accentColor,
                onSave: { viewModel.saveProfile($0) },
                onDelete: { viewModel.deleteProfile(id: profile.id) }
            )
        }
    }

}
