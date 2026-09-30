// Pomodoro/History/StatsView.swift
import SwiftUI
import Charts
import UniformTypeIdentifiers

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
        // The daily goal is across all profiles, so it only appears on the
        // combined (All Profiles) view.
        let goal = profileFilter == nil ? viewModel.dailyGoal : 0

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
                    statRow("Today", "\(stats.todayCount)", spoken: Self.spokenSessions(stats.todayCount))
                    statRow("All time", "\(stats.totalCount)", spoken: Self.spokenSessions(stats.totalCount))
                    statRow("Current streak", "\(stats.currentStreak) day\(stats.currentStreak == 1 ? "" : "s")")
                    statRow(
                        "Total focus time",
                        Self.formattedFocusTime(stats.totalFocusSeconds),
                        spoken: SpokenDuration.string(stats.totalFocusSeconds, units: [.hour, .minute])
                    )
                }
                // The overall view breaks the combined totals down by
                // profile; tapping one switches the whole screen to it.
                if goal > 0 {
                    Section("Daily Goal") {
                        statRow("Goal", "\(goal) a day", spoken: "\(Self.spokenSessions(goal)) a day")
                        statRow(
                            "Met in the last 7 days",
                            "\(StatsSnapshot.goalDaysInLastSeven(overall.lastSevenDays, goal: goal)) of 7",
                            spoken: "\(StatsSnapshot.goalDaysInLastSeven(overall.lastSevenDays, goal: goal)) of 7 days"
                        )
                        let goalStreak = StatsSnapshot.goalStreak(byDay: overall.byDay, goal: goal, calendar: .current, now: Date())
                        statRow("Goal streak", "\(goalStreak) day\(goalStreak == 1 ? "" : "s")")
                    }
                }
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
                            .accessibilityLabel(displayName(total.id, fallback: total.name))
                            .accessibilityValue("\(Self.spokenSessions(total.count)), \(SpokenDuration.string(total.totalFocusSeconds, units: [.hour, .minute])) of focus, \(total.todayCount) today")
                            .accessibilityHint("Shows this profile's stats.")
                        }
                    }
                }
                Section("Last 7 Days") {
                    Chart {
                        ForEach(stats.lastSevenDays) { entry in
                            BarMark(
                                x: .value("Day", entry.day, unit: .day),
                                y: .value("Sessions", entry.count)
                            )
                            .foregroundStyle(viewModel.accentColor.color)
                            // Swift Charts exposes each bar to VoiceOver (and
                            // Audio Graphs); these make each one read as
                            // "Tuesday, 3 sessions" instead of a raw date/number.
                            .accessibilityLabel(entry.day.formatted(.dateTime.weekday(.wide)))
                            .accessibilityValue(Self.spokenSessions(entry.count))
                        }
                        if goal > 0 {
                            // Dashed line at the daily goal: bars that reach
                            // it are goal days.
                            RuleMark(y: .value("Daily goal", goal))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .foregroundStyle(viewModel.accentColor.color.opacity(0.6))
                                .accessibilityLabel("Daily goal")
                                .accessibilityValue(Self.spokenSessions(goal))
                        }
                    }
                    // A fixed floor keeps an all-zero week (fresh install,
                    // or a week off) from asking Charts to scale a 0...0
                    // axis; the goal line always stays in view.
                    .chartYScale(domain: 0...max(4, goal, stats.lastSevenDays.map(\.count).max() ?? 0))
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
                            statRow(
                                entry.day.formatted(date: .abbreviated, time: .omitted),
                                "\(entry.count)",
                                spoken: Self.spokenSessions(entry.count)
                            )
                        }
                    }
                }
                if !sessions.isEmpty {
                    Section {
                        // Always every session, whatever profile the screen
                        // is filtered to — the Profile column covers that.
                        ShareLink(
                            item: HistoryExport(sessions: sessions, currentNames: currentProfileNames),
                            preview: SharePreview("Focus History (CSV)", image: Image(systemName: "tablecells"))
                        ) {
                            Label("Export History as CSV", systemImage: "square.and.arrow.up")
                        }
                    } footer: {
                        Text("All \(Self.spokenSessions(sessions.count)): date, time, profile, and minutes focused. Opens in Numbers, Excel, or Google Sheets.")
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

    /// id → current name, so the export uses today's names for profiles
    /// that still exist (a deleted one keeps the name stored with it).
    private var currentProfileNames: [UUID: String] {
        Dictionary(viewModel.profiles.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// Prefers a profile's current name, in case it was renamed since.
    private func displayName(_ id: UUID, fallback: String) -> String {
        viewModel.profiles.first(where: { $0.id == id })?.name ?? fallback
    }

    /// Read by VoiceOver as one item ("Today, 3 sessions") rather than two
    /// separate stops for the title and a bare number.
    private func statRow(_ title: String, _ value: String, spoken: String? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spoken ?? value)
    }

    nonisolated static func spokenSessions(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
    }

    nonisolated static func formattedFocusTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0m" }
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

/// What the Stats share button hands to the share sheet: a CSV file, only
/// built when the user actually picks a destination (not on every render).
struct HistoryExport: Transferable {
    let sessions: [StatsSnapshot.Session]
    let currentNames: [UUID: String]

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let csv = HistoryCSV.make(export.sessions) { session in
                session.profileID.flatMap { export.currentNames[$0] }
                    ?? session.profileName
                    ?? TimerProfile.classic.name
            }
            // Local date for the file name (ISO8601FormatStyle would use UTC,
            // naming an evening export after tomorrow).
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayFormatter.dateFormat = "yyyy-MM-dd"
            let day = dayFormatter.string(from: Date())
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Focus History \(day).csv")
            try Data(csv.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
