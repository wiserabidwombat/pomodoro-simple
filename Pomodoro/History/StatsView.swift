// Pomodoro/History/StatsView.swift
import SwiftUI

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
}
