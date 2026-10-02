// Pomodoro/Timer/WideTimerComponents.swift
import Charts
import SwiftUI

// The iPad (regular width and height) Timer screen is built from these:
// a scaled countdown inside a progress ring, a side panel of cards, and
// Desk Mode. The iPhone keeps its original layout in TimerView.

/// The countdown: live while running (Text(timerInterval:) updates itself,
/// no redraws needed), a frozen string while paused, "Ready" when idle.
/// Same rules as the iPhone Timer screen; see the notes there.
struct CountdownText: View {
    let state: PomodoroState

    var body: some View {
        if state.sessionActive {
            if state.pausedAt != nil {
                Text(state.formattedRemainingWhilePaused)
                    .accessibilityLabel(SpokenDuration.pausedLabel(endDate: state.endDate, pausedAt: state.pausedAt))
            } else {
                Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                    .multilineTextAlignment(.center)
            }
        } else {
            Text("Ready")
        }
    }
}

/// A ring that drains as the phase counts down, with any content in the
/// middle. Redraws once a second only while running; paused or idle it's
/// static (full when idle).
struct TimerRing<Center: View>: View {
    let state: PomodoroState
    /// The phase's full length (endDate − startDate isn't it: pausing
    /// pushes endDate back).
    let phaseLength: TimeInterval
    let color: Color
    let lineWidth: CGFloat
    @ViewBuilder let center: () -> Center

    private var isRunning: Bool { state.sessionActive && state.pausedAt == nil }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: !isRunning)) { context in
            let fraction = progress(at: context.date)
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: fraction)
                center()
                    .padding(lineWidth * 2)
            }
            .padding(lineWidth / 2)
        }
    }

    private func progress(at date: Date) -> Double {
        guard state.sessionActive, phaseLength > 0 else { return 1 }
        return min(1, max(0, state.remainingSeconds(asOf: date) / phaseLength))
    }
}

/// A quiet rounded card with a small uppercase heading.
struct PanelCard<Content: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.7)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(accent.opacity(0.18), lineWidth: 1))
    }
}

/// Today's progress: "3 of 6" with a bar when there's a daily goal, plus
/// focus time.
struct TodayCard: View {
    let todayCount: Int
    let dailyGoal: Int
    let focusSeconds: TimeInterval
    let accent: Color

    var body: some View {
        PanelCard(title: "Today", systemImage: "sun.max", accent: accent) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(todayCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(dailyGoal > 0 ? "of \(dailyGoal)" : (todayCount == 1 ? "session" : "sessions"))
                    .font(.headline)
                    .opacity(0.7)
            }
            if dailyGoal > 0 {
                ProgressView(value: Double(min(todayCount, dailyGoal)), total: Double(dailyGoal))
                    .tint(accent)
            }
            Text(footnote)
                .font(.footnote)
                .opacity(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today")
        .accessibilityValue(spokenValue)
    }

    private var focusText: String {
        let minutes = Int(focusSeconds / 60)
        if minutes >= 60 {
            return "\(minutes / 60) h \(minutes % 60) min focused"
        }
        return "\(minutes) min focused"
    }

    private var footnote: String {
        dailyGoal > 0 && todayCount >= dailyGoal ? "Goal reached · \(focusText)" : focusText
    }

    private var spokenValue: String {
        let sessions = dailyGoal > 0
            ? "\(todayCount) of \(dailyGoal) Focus sessions"
            : "\(todayCount) Focus session\(todayCount == 1 ? "" : "s")"
        return "\(sessions), \(SpokenDuration.string(focusSeconds, units: [.hour, .minute])) focused"
    }
}

/// The next two phases and their lengths.
struct UpNextCard: View {
    let state: PomodoroState
    let profile: TimerProfile
    let accent: Color

    var body: some View {
        PanelCard(title: state.sessionActive ? "Up next" : "First up", systemImage: "arrow.turn.down.right", accent: accent) {
            let phases = profile.upcomingPhases(after: state, count: 2)
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                HStack {
                    Text(index == 0 ? phase.displayName : "then \(phase.displayName)")
                        .font(index == 0 ? .headline : .subheadline)
                    Spacer()
                    Text("\(Int(profile.durations.duration(for: phase) / 60)) min")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .opacity(index == 0 ? 1 : 0.6)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Focus sessions per day for the last 7 days, with the daily goal line.
struct WeekCard: View {
    let days: [DailyCount]
    let dailyGoal: Int
    let accent: Color

    var body: some View {
        PanelCard(title: "This week", systemImage: "chart.bar", accent: accent) {
            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Sessions", day.count)
                    )
                    .foregroundStyle(accent)
                    .cornerRadius(3)
                }
                if dailyGoal > 0 {
                    RuleMark(y: .value("Daily goal", dailyGoal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(accent.opacity(0.6))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartYAxis(.hidden)
            // A fixed floor so an empty week doesn't ask Charts to scale 0...0.
            .chartYScale(domain: 0...max(4, dailyGoal, days.map(\.count).max() ?? 0))
            .frame(height: 90)
        }
    }
}

/// iPad's take on StandBy: just the ring, the countdown, and the time of
/// day, as large as the screen allows. Tap anywhere (or press Escape) to
/// bring the controls back.
struct DeskModeView: View {
    let state: PomodoroState
    let phaseTitle: String
    let phaseLength: TimeInterval
    let accent: Color
    let onExit: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height) * 0.72
            VStack(spacing: diameter * 0.06) {
                TimerRing(state: state, phaseLength: phaseLength, color: accent, lineWidth: max(10, diameter * 0.03)) {
                    VStack(spacing: diameter * 0.02) {
                        Text(state.sessionActive ? phaseTitle : "Ready to focus")
                            .font(.system(size: diameter * 0.06, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .opacity(0.8)
                        if state.sessionActive {
                            CountdownText(state: state)
                                .font(.system(size: diameter * 0.22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                }
                .frame(width: diameter, height: diameter)
                TimelineView(.everyMinute) { context in
                    Text(context.date, style: .time)
                        .font(.system(size: max(22, diameter * 0.07), weight: .medium, design: .rounded))
                        .opacity(0.55)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(accent)
        .contentShape(Rectangle())
        .onTapGesture(perform: onExit)
        .overlay(alignment: .bottom) {
            Text("Tap anywhere to show controls")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
                .accessibilityHidden(true)
        }
        // Escape leaves Desk Mode with a keyboard; invisible but working.
        .background {
            Button("Exit Desk Mode", action: onExit)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Exit Desk Mode", onExit)
    }
}
