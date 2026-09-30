// Pomodoro/History/StatsView.swift
import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var viewModel: TimerViewModel
    let historyStore: HistoryStore
    /// Fetched once per appearance and whenever new sessions are recorded
    /// (historyRevision) — never queried from SwiftData inside `body`.
    @State private var sessions: [StatsSnapshot.Session] = []
    /// nil = all profiles combined.
    @State private var profileFilter: UUID?

    private struct ProfileOption: Identifiable {
        let id: UUID
        let name: String
    }

    var body: some View {
        let overall = StatsSnapshot(sessions: sessions)
        let stats = profileFilter.map { id in
            StatsSnapshot(sessions: sessions.filter { $0.profileID == id })
        } ?? overall
        let options = filterOptions(overall)

        ZStack {
            Color.black.ignoresSafeArea()
            List {
                if options.count > 1 {
                    Section {
                        Picker("Showing", selection: $profileFilter) {
                            Text("All Profiles").tag(UUID?.none)
                            ForEach(options) { option in
                                Text(option.name).tag(Optional(option.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section(sectionTitle(options)) {
                    statRow("Today", "\(stats.todayCount)")
                    statRow("All time", "\(stats.totalCount)")
                    statRow("Current streak", "\(stats.currentStreak) day\(stats.currentStreak == 1 ? "" : "s")")
                    statRow("Total focus time", Self.formattedFocusTime(stats.totalFocusSeconds))
                }
                // The overall view breaks the combined totals down by
                // profile; tapping one switches the whole screen to it.
                if profileFilter == nil && overall.byProfile.count > 1 {
                    Section("By Profile") {
                        ForEach(overall.byProfile) { total in
                            Button {
                                profileFilter = total.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayName(total.id, fallback: total.name))
                                        Text("\(total.count) session\(total.count == 1 ? "" : "s") · \(Self.formattedFocusTime(total.totalFocusSeconds))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(total.todayCount) today")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
        sessions = historyStore.sessions()
    }

    /// Current profiles in their Settings order, then any deleted profile
    /// that still has history (so its past sessions stay reachable).
    private func filterOptions(_ overall: StatsSnapshot) -> [ProfileOption] {
        var options = viewModel.profiles.map { ProfileOption(id: $0.id, name: $0.name) }
        for total in overall.byProfile where !options.contains(where: { $0.id == total.id }) {
            options.append(ProfileOption(id: total.id, name: total.name))
        }
        return options
    }

    private func sectionTitle(_ options: [ProfileOption]) -> String {
        guard let profileFilter else { return options.count > 1 ? "Overall" : "" }
        return options.first(where: { $0.id == profileFilter })?.name ?? ""
    }

    /// Prefers a profile's current name, in case it was renamed since.
    private func displayName(_ id: UUID, fallback: String) -> String {
        viewModel.profiles.first(where: { $0.id == id })?.name ?? fallback
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
