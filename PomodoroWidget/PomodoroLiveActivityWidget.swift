// PomodoroWidget/PomodoroLiveActivityWidget.swift
import WidgetKit
import SwiftUI
import ActivityKit

/// The Lock Screen, StandBy, and Dynamic Island, plus on iOS 18 and later
/// a layout made for the Apple Watch Smart Stack (the `.small` family).
/// Without it, watchOS built its own card from the Dynamic Island's tiny
/// views, which showed a stuck "0:00" and nothing else.
struct PomodoroLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        // Explicit returns rather than result-builder syntax: Swift lets an
        // opaque `some` type differ between the branches of a top-level
        // `if #available` (SE-0360), and that's the only way to add an
        // iOS 18 modifier while still supporting iOS 17. WidgetBundleBuilder
        // has no `if` support at all, so this can't live in the bundle.
        if #available(iOS 18.0, *) {
            return Self.configuration()
                .supplementalActivityFamilies([.small])
        } else {
            return Self.configuration()
        }
    }

    static func configuration() -> ActivityConfiguration<PomodoroActivityAttributes> {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            PomodoroLiveActivityContent(state: context.state, isStale: context.isStale)
                // Tapping the Lock Screen/StandBy banner (anywhere but a
                // button) opens the app straight to the Timer tab.
                .widgetURL(PomodoroDeepLink.timerURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    PomodoroLiveActivityView(state: context.state, isStale: context.isStale)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .accessibilityLabel(context.state.title)
            } compactTrailing: {
                if context.state.pausedAt != nil {
                    Text(context.state.formattedRemainingWhilePaused)
                        .monospacedDigit()
                        .frame(width: 40)
                        .accessibilityLabel(SpokenDuration.pausedLabel(endDate: context.state.endDate, pausedAt: context.state.pausedAt))
                } else {
                    Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                }
            } minimal: {
                Image(systemName: "timer")
                    .accessibilityLabel(context.state.title)
            }
            .widgetURL(PomodoroDeepLink.timerURL)
        }
    }
}

/// Chooses the layout for where the Live Activity is showing: the small
/// watch card, or the usual Lock Screen / StandBy banner.
struct PomodoroLiveActivityContent: View {
    let state: PomodoroActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if #available(iOS 18.0, *) {
            FamilyAwareLiveActivityContent(state: state, isStale: isStale)
        } else {
            PomodoroLiveActivityView(state: state, isStale: isStale)
        }
    }
}

@available(iOS 18.0, *)
private struct FamilyAwareLiveActivityContent: View {
    let state: PomodoroActivityAttributes.ContentState
    let isStale: Bool
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        switch activityFamily {
        case .small:
            PomodoroWatchActivityView(state: state, isStale: isStale)
        default:
            PomodoroLiveActivityView(state: state, isStale: isStale)
        }
    }
}

/// The Apple Watch Smart Stack card: the phase, a live countdown big
/// enough to read at a glance, and icon buttons for Pause/Resume and Skip
/// (or Continue once the phase has run out). The buttons run the same
/// intents as the Lock Screen, on the iPhone.
struct PomodoroWatchActivityView: View {
    let state: PomodoroActivityAttributes.ContentState
    let isStale: Bool

    private var isExpired: Bool { isStale && state.pausedAt == nil }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.85)
                countdown
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            controls
        }
        .foregroundStyle(state.accentColor.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .activityBackgroundTint(.black)
    }

    @ViewBuilder
    private var countdown: some View {
        if isExpired {
            Text("Time's up")
        } else if state.pausedAt != nil {
            Text(state.formattedRemainingWhilePaused)
                .accessibilityLabel(SpokenDuration.pausedLabel(endDate: state.endDate, pausedAt: state.pausedAt))
        } else {
            // Left-aligned here (the card reads left to right), with the
            // reserved width kept from pushing the buttons around.
            Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if isExpired {
            Button(intent: AdvancePomodoroIntent()) {
                Image(systemName: "arrow.right")
                    .foregroundStyle(state.accentColor.contrastingTextColor)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.accentColor.color)
            .accessibilityLabel("Continue")
        } else {
            VStack(spacing: 6) {
                if state.pausedAt == nil {
                    Button(intent: PausePomodoroIntent()) {
                        Image(systemName: "pause.fill")
                    }
                    .accessibilityLabel("Pause")
                } else {
                    Button(intent: ResumePomodoroIntent()) {
                        Image(systemName: "play.fill")
                    }
                    .accessibilityLabel("Resume")
                }
                Button(intent: SkipPomodoroIntent()) {
                    Image(systemName: "forward.fill")
                }
                .accessibilityLabel("Skip")
            }
            .buttonStyle(.bordered)
            .tint(state.accentColor.color)
            .font(.caption)
        }
    }
}

struct PomodoroLiveActivityView: View {
    let state: PomodoroActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(state.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if isStale && state.pausedAt == nil {
                // The system marks content stale once the current phase's
                // countdown should have ended — this fires whenever a phase
                // completes while the app never got a chance to push the
                // next phase's update (e.g. backgrounded past the OS's
                // ~8-hour Live Activity cap, or just sitting locked in
                // StandBy). Without this, a frozen countdown here would
                // look identical to a normal, accurate one.
                Text("Time's up")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            } else if state.pausedAt != nil {
                Text(state.formattedRemainingWhilePaused)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel(SpokenDuration.pausedLabel(endDate: state.endDate, pausedAt: state.pausedAt))
            } else {
                // Text(timerInterval:) reserves a wider bounding box than it
                // visually needs (to avoid jitter as the digit count
                // changes) and renders left-aligned within it by default —
                // multilineTextAlignment forces the glyphs themselves to
                // center within that reserved box.
                Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            if isStale && state.pausedAt == nil {
                // Replaces Pause/Skip entirely while expired: catching up
                // is exactly what Skip already did first internally, but
                // Skip additionally advances a second phase on top of that
                // catch-up — confusing when the phase had already silently
                // ended (it looks like Skip does nothing, then the app
                // reveals it actually skipped an extra phase). This button
                // performs only the catch-up.
                // Filled with the accent (so it matches the theme instead
                // of the system blue, which made same-hued accents
                // unreadable), with a black or white label picked for
                // contrast against that accent.
                Button(intent: AdvancePomodoroIntent()) {
                    Label("Continue", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(state.accentColor.contrastingTextColor)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.accentColor.color)
            } else {
                HStack(spacing: 16) {
                    // Fixed width so the Skip button doesn't shift when this
                    // label's text changes length between "Pause" and "Resume".
                    Group {
                        if state.pausedAt == nil {
                            Button(intent: PausePomodoroIntent()) {
                                Label("Pause", systemImage: "pause.fill")
                            }
                        } else {
                            Button(intent: ResumePomodoroIntent()) {
                                Label("Resume", systemImage: "play.fill")
                            }
                        }
                    }
                    .frame(width: 110)
                    Button(intent: SkipPomodoroIntent()) {
                        Label("Skip", systemImage: "forward.fill")
                    }
                }
                .buttonStyle(.bordered)
                // Tints the translucent button backgrounds with the accent
                // too, instead of the system's default blue-gray.
                .tint(state.accentColor.color)
            }
        }
        // Without this, the block shrinks to fit whichever countdown text is
        // narrower (the static paused string vs. the live timer text) and
        // re-centers within the banner, which reads as the whole thing
        // jumping to the left edge whenever pause/resume/skip is tapped.
        .frame(maxWidth: .infinity)
        .foregroundStyle(state.accentColor.color)
        .padding()
        // This is what actually paints the Lock Screen/StandBy banner black;
        // .containerBackground does not apply to Live Activities.
        .activityBackgroundTint(.black)
    }
}
