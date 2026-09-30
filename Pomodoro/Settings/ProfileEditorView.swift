// Pomodoro/Settings/ProfileEditorView.swift
import SwiftUI

/// Add or edit one timer profile. Works on a draft copy, so Cancel really
/// discards; Save hands the finished profile back to the view model.
struct ProfileEditorView: View {
    let isNew: Bool
    let canDelete: Bool
    let accentColor: AccentColorOption
    let onSave: (TimerProfile) -> Void
    let onDelete: () -> Void

    @State private var draft: TimerProfile
    @State private var confirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    init(
        profile: TimerProfile,
        isNew: Bool,
        canDelete: Bool,
        accentColor: AccentColorOption,
        onSave: @escaping (TimerProfile) -> Void,
        onDelete: @escaping () -> Void
    ) {
        _draft = State(initialValue: profile)
        self.isNew = isNew
        self.canDelete = canDelete
        self.accentColor = accentColor
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Deep Work", text: $draft.name)
                }
                Section("Durations") {
                    minutesStepper("Focus", value: $draft.durations.workMinutes, range: 1...120)
                    minutesStepper("Short Break", value: $draft.durations.shortBreakMinutes, range: 1...60)
                    minutesStepper("Long Break", value: $draft.durations.longBreakMinutes, range: 1...60)
                }
                Section {
                    Stepper(value: $draft.sessionsBeforeLongBreak, in: TimerProfile.sessionsRange) {
                        HStack {
                            Text("Focus sessions per cycle")
                            Spacer()
                            Text("\(draft.sessionsBeforeLongBreak)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    // Label and value split out so swiping up/down on the
                    // stepper announces just the new number.
                    .accessibilityLabel("Focus sessions per cycle")
                    .accessibilityValue("\(draft.sessionsBeforeLongBreak)")
                } footer: {
                    Text("The Long Break comes after the last Focus session in each cycle.")
                }
                if !isNew {
                    Section {
                        Button("Delete Profile", role: .destructive) {
                            confirmingDelete = true
                        }
                        .disabled(!canDelete)
                    } footer: {
                        if !canDelete {
                            Text("You can't delete your only profile, or the one a running session is using.")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = draft
                        saved.name = trimmedName
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog(
                "Delete \(trimmedName.isEmpty ? "this profile" : trimmedName)?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("Sessions you've already finished with it stay in Stats.")
            }
        }
        .tint(accentColor.color)
        .preferredColorScheme(.dark)
    }

    private func minutesStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) min")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue("\(value.wrappedValue) minute\(value.wrappedValue == 1 ? "" : "s")")
    }
}
