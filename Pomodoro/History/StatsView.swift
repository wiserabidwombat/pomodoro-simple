// Pomodoro/History/StatsView.swift
import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var viewModel: TimerViewModel
    let historyStore: HistoryStore

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            List {
                Section {
                    HStack {
                        Text("Today")
                        Spacer()
                        Text("\(historyStore.todayCount)")
                    }
                    HStack {
                        Text("All time")
                        Spacer()
                        Text("\(historyStore.totalCount)")
                    }
                    HStack {
                        Text("Current streak")
                        Spacer()
                        Text(streakText)
                    }
                    HStack {
                        Text("Total focus time")
                        Spacer()
                        Text(Self.formattedFocusTime(historyStore.totalFocusSeconds))
                    }
                }
                Section("Last 7 Days") {
                    Chart(historyStore.lastSevenDaysCounts()) { entry in
                        BarMark(
                            x: .value("Day", entry.day, unit: .day),
                            y: .value("Sessions", entry.count)
                        )
                        .foregroundStyle(viewModel.accentColor.color)
                    }
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
                    ForEach(historyStore.countByDay(), id: \.day) { entry in
                        HStack {
                            Text(entry.day.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text("\(entry.count)")
                        }
                    }
                }
            }
            // Lists paint their own opaque background by default in iOS 16+;
            // hiding it is what lets the black ZStack background show through.
            .scrollContentBackground(.hidden)
            .foregroundStyle(viewModel.accentColor.color)
        }
    }

    private var streakText: String {
        let streak = historyStore.currentStreak()
        return "\(streak) day\(streak == 1 ? "" : "s")"
    }

    private static func formattedFocusTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
