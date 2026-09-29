// Pomodoro/History/StatsView.swift
import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var viewModel: TimerViewModel
    let historyStore: HistoryStore
    /// Computed once per appearance and whenever new sessions are recorded
    /// (historyRevision), not queried from SwiftData inside `body` on every
    /// render as before.
    @State private var stats = StatsSnapshot()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            List {
                Section {
                    statRow("Today", "\(stats.todayCount)")
                    statRow("All time", "\(stats.totalCount)")
                    statRow("Current streak", "\(stats.currentStreak) day\(stats.currentStreak == 1 ? "" : "s")")
                    statRow("Total focus time", Self.formattedFocusTime(stats.totalFocusSeconds))
                }
                Section("Last 7 Days") {
                    Chart(stats.lastSevenDays) { entry in
                        BarMark(
                            x: .value("Day", entry.day, unit: .day),
                            y: .value("Sessions", entry.count)
                        )
                        .foregroundStyle(viewModel.accentColor.color)
                    }
                    // A fixed floor keeps an all-zero week (fresh install,
                    // or a week off) from asking Charts to scale a 0...0
                    // axis.
                    .chartYScale(domain: 0...max(4, stats.lastSevenDays.map(\.count).max() ?? 0))
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                Section("History") {
                    if stats.byDay.isEmpty {
                        Text("Completed Focus sessions will show up here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(stats.byDay) { entry in
                            statRow(entry.day.formatted(date: .abbreviated, time: .omitted), "\(entry.count)")
                        }
                    }
                }
            }
            // Lists paint their own opaque background by default in iOS 16+;
            // hiding it is what lets the black ZStack background show through.
            .scrollContentBackground(.hidden)
            .foregroundStyle(viewModel.accentColor.color)
        }
        .onAppear { reload() }
        .onChange(of: viewModel.historyRevision) { _, _ in reload() }
    }

    private func reload() {
        stats = historyStore.snapshot()
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
    }

    nonisolated static func formattedFocusTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0m" }
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
