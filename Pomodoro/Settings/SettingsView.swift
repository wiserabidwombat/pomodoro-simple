// Pomodoro/Settings/SettingsView.swift
import AudioToolbox
import Intents
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.self) private var environment
    @State private var editingProfile: TimerProfile?

    private var themeCaption: String {
        var parts: [String] = []
        if viewModel.themeSetting == .automatic {
            parts.append("Halloween in October, Thanksgiving through Thanksgiving Day, and Christmas through the end of December.")
        }
        if let theme = viewModel.activeTheme {
            parts.append("\(theme.displayName) is showing now, with its own colors. Your accent color comes back when the theme ends.")
        } else if viewModel.themeSetting == .off {
            parts.append("Seasonal colors and a little animation on the Timer screen.")
        } else {
            parts.append("No holiday right now, so your accent color is showing.")
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        ZStack {
            ThemedBackground(theme: viewModel.activeTheme)
            ScrollView {
                VStack(spacing: 16) {
                    Text("Accent Color")
                        .foregroundStyle(viewModel.displayAccent.color)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(AccentColorOption.presets, id: \.self) { option in
                            // A real Button (not a tap gesture on a shape) so
                            // VoiceOver can find, name, and activate it.
                            Button {
                                viewModel.accentColor = option
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle().strokeBorder(.white, lineWidth: option == viewModel.accentColor ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.accessibilityName)
                            .accessibilityAddTraits(option == viewModel.accentColor ? .isSelected : [])
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
                        .accessibilityLabel("Custom color")
                    }
                    .padding()
                    if viewModel.accentColor.isLowContrastOnBlack {
                        Text("This color is hard to read on the black background. A lighter shade will be easier on the eyes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Text("Holiday Theme")
                        .foregroundStyle(viewModel.displayAccent.color)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Theme")
                                .foregroundStyle(.white)
                            Spacer()
                            Picker("Holiday Theme", selection: $viewModel.themeSetting) {
                                ForEach(ThemeSetting.allCases) { setting in
                                    Text(setting.displayName).tag(setting)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(viewModel.displayAccent.color)
                        }
                        Text(themeCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Text("Timer Profiles")
                        .foregroundStyle(viewModel.displayAccent.color)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
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
                                            .foregroundStyle(viewModel.displayAccent.color)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(profile.name)
                            .accessibilityValue(profile.id == viewModel.activeProfile.id
                                ? "In use. \(profile.spokenSummary)"
                                : profile.spokenSummary)
                            .accessibilityHint("Edit this profile.")
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
                        .foregroundStyle(viewModel.displayAccent.color)
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
                    .tint(viewModel.displayAccent.color)
                    .padding(.horizontal)

                    Stepper(value: $viewModel.dailyGoal, in: PomodoroStateStore.dailyGoalRange) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Daily Goal")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(viewModel.dailyGoal == 0 ? "Off" : "\(viewModel.dailyGoal) sessions")
                                    .foregroundStyle(.secondary)
                            }
                            Text("Focus sessions to aim for each day, across all profiles. Shows on the Timer screen, the medium widget, and Stats.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Daily goal")
                    .accessibilityValue(viewModel.dailyGoal == 0 ? "Off" : "\(viewModel.dailyGoal) Focus sessions")
                    .padding(.horizontal)

                    Toggle(isOn: $viewModel.keepScreenAwake) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep Screen Awake")
                                .foregroundStyle(.white)
                            Text("Stops the phone from locking while a session is running and the Timer screen is open — handy with the phone propped on a desk. Uses more battery, so it's best while charging.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(viewModel.displayAccent.color)
                    .padding(.horizontal)

                    Text("Sound")
                        .foregroundStyle(viewModel.displayAccent.color)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Toggle(isOn: $viewModel.soundEnabled) {
                        Text("Play Sound")
                            .foregroundStyle(.white)
                    }
                    .tint(viewModel.displayAccent.color)
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
                                            .foregroundStyle(viewModel.displayAccent.color)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(viewModel.chime == option ? .isSelected : [])
                            .accessibilityHint("Selects this sound and plays a preview.")
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
                accentColor: viewModel.displayAccent,
                onSave: { viewModel.saveProfile($0) },
                onDelete: { viewModel.deleteProfile(id: profile.id) }
            )
        }
    }

}
