// Pomodoro/History/HistoryStore.swift
import Foundation
import SwiftData

struct DailyCount: Identifiable, Hashable {
    let day: Date
    let count: Int
    var id: Date { day }
}

/// Everything the Stats screen shows, computed in one pass over one fetch.
/// Pure value logic (no SwiftData), so every state — no sessions yet,
/// sessions only today, a long history — is directly unit-testable.
struct StatsSnapshot: Equatable {
    struct Session: Equatable {
        let date: Date
        let durationSeconds: TimeInterval
        var profileID: UUID? = nil
        var profileName: String? = nil
    }

    /// One profile's share of the sessions, for the "By Profile" summary.
    struct ProfileTotal: Identifiable, Equatable {
        let id: UUID
        var name: String
        var count: Int
        var totalFocusSeconds: TimeInterval
        var todayCount: Int
    }

    var todayCount = 0
    var totalCount = 0
    var totalFocusSeconds: TimeInterval = 0
    var currentStreak = 0
    /// The last 7 days including today, oldest first, zero-filled.
    var lastSevenDays: [DailyCount] = []
    /// Only days that have at least one session, newest first.
    var byDay: [DailyCount] = []
    /// Per-profile totals, most focus time first.
    var byProfile: [ProfileTotal] = []

    init() {}

    init(sessions: [Session], calendar: Calendar = .current, now: Date = Date()) {
        let byDay = Self.countByDay(sessions.map { $0.date }, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        self.todayCount = byDay.first(where: { $0.day == today })?.count ?? 0
        self.totalCount = sessions.count
        self.totalFocusSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        self.currentStreak = Self.currentStreak(daysWithSessions: Set(byDay.map { $0.day }), calendar: calendar, now: now)
        self.lastSevenDays = Self.lastSevenDays(byDay, calendar: calendar, now: now)
        self.byDay = byDay
        self.byProfile = Self.profileTotals(sessions, calendar: calendar, now: now)
    }

    /// Sessions with no profile predate profiles and count as Classic. A
    /// profile's latest recorded name wins, so a rename shows up once new
    /// sessions are finished under it (the Stats screen also prefers the
    /// current name of profiles that still exist).
    static func profileTotals(_ sessions: [Session], calendar: Calendar, now: Date) -> [ProfileTotal] {
        var totals: [UUID: ProfileTotal] = [:]
        for session in sessions.sorted(by: { $0.date < $1.date }) {
            let id = session.profileID ?? TimerProfile.classicID
            var total = totals[id] ?? ProfileTotal(
                id: id,
                name: session.profileName ?? TimerProfile.classic.name,
                count: 0,
                totalFocusSeconds: 0,
                todayCount: 0
            )
            if let name = session.profileName {
                total.name = name
            }
            total.count += 1
            total.totalFocusSeconds += session.durationSeconds
            if calendar.isDate(session.date, inSameDayAs: now) {
                total.todayCount += 1
            }
            totals[id] = total
        }
        return totals.values.sorted {
            $0.totalFocusSeconds != $1.totalFocusSeconds
                ? $0.totalFocusSeconds > $1.totalFocusSeconds
                : $0.name < $1.name
        }
    }

    static func countByDay(_ dates: [Date], calendar: Calendar) -> [DailyCount] {
        let grouped = Dictionary(grouping: dates) { calendar.startOfDay(for: $0) }
        return grouped
            .map { DailyCount(day: $0.key, count: $0.value.count) }
            .sorted { $0.day > $1.day }
    }

    /// Consecutive days with at least one completed session, counting
    /// backward from today. A day that hasn't finished yet (no session
    /// today) doesn't break a streak built on prior days — it only breaks
    /// once a full day passes with nothing recorded.
    static func currentStreak(daysWithSessions: Set<Date>, calendar: Calendar, now: Date) -> Int {
        var day = calendar.startOfDay(for: now)
        if !daysWithSessions.contains(day) {
            guard let yesterday = previousDay(before: day, calendar: calendar) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while daysWithSessions.contains(day) {
            streak += 1
            guard let previous = previousDay(before: day, calendar: calendar) else { break }
            day = previous
        }
        return streak
    }

    /// Consecutive days that met the daily goal, counting back from today;
    /// today only counts once it's met, so an unfinished today doesn't
    /// break a streak built on prior days (same rule as currentStreak).
    static func goalStreak(byDay: [DailyCount], goal: Int, calendar: Calendar, now: Date) -> Int {
        guard goal > 0 else { return 0 }
        let metDays = Set(byDay.filter { $0.count >= goal }.map { $0.day })
        return currentStreak(daysWithSessions: metDays, calendar: calendar, now: now)
    }

    /// How many of the last 7 days (today included) met the goal.
    static func goalDaysInLastSeven(_ lastSevenDays: [DailyCount], goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        return lastSevenDays.filter { $0.count >= goal }.count
    }

    /// Zero-filled, unlike countByDay() (a fixed-width chart axis needs
    /// every day). Built with uniquingKeysWith rather than
    /// uniqueKeysWithValues, which traps on a duplicate key instead of
    /// merging it.
    static func lastSevenDays(_ byDay: [DailyCount], calendar: Calendar, now: Date) -> [DailyCount] {
        let counts = Dictionary(byDay.map { ($0.day, $0.count) }, uniquingKeysWith: +)
        var day = calendar.startOfDay(for: now)
        var result: [DailyCount] = []
        for _ in 0..<7 {
            result.append(DailyCount(day: day, count: counts[day] ?? 0))
            guard let previous = previousDay(before: day, calendar: calendar) else { break }
            day = previous
        }
        return result.reversed()
    }

    /// Re-normalized with startOfDay: in time zones whose DST change
    /// happens at midnight, "start of day minus one day" isn't always the
    /// previous day's start, which would silently break streaks and leave
    /// chart days empty.
    private static func previousDay(before day: Date, calendar: Calendar) -> Date? {
        calendar.date(byAdding: .day, value: -1, to: day).map { calendar.startOfDay(for: $0) }
    }
}

@MainActor
final class HistoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func recordCompletedSession(duration: TimeInterval, on date: Date = Date(), profile: TimerProfile? = nil) {
        context.insert(CompletedSession(date: date, durationSeconds: duration, profileID: profile?.id, profileName: profile?.name))
        try? context.save()
    }

    /// Imports sessions queued in the App Group by other processes/paths
    /// (see PendingCompletedSession) with a single save.
    func recordCompletedSessions(_ pending: [PendingCompletedSession]) {
        guard !pending.isEmpty else { return }
        for session in pending {
            context.insert(CompletedSession(
                date: session.endedAt,
                durationSeconds: session.duration,
                profileID: session.profileID,
                profileName: session.profileName
            ))
        }
        try? context.save()
    }

    /// One fetch for the whole Stats screen, instead of the ~6 separate
    /// queries it used to run on every render.
    /// Pass a profile id to get that profile's stats alone.
    func snapshot(profileID: UUID? = nil, calendar: Calendar = .current, now: Date = Date()) -> StatsSnapshot {
        let all = sessions()
        let filtered = profileID.map { id in all.filter { $0.profileID == id } } ?? all
        return StatsSnapshot(sessions: filtered, calendar: calendar, now: now)
    }

    func countByDay(calendar: Calendar = .current) -> [DailyCount] {
        StatsSnapshot.countByDay(sessions().map { $0.date }, calendar: calendar)
    }

    var totalCount: Int {
        (try? context.fetchCount(FetchDescriptor<CompletedSession>())) ?? 0
    }

    var todayCount: Int {
        snapshot().todayCount
    }

    var totalFocusSeconds: TimeInterval {
        sessions().reduce(0) { $0 + $1.durationSeconds }
    }

    func currentStreak(calendar: Calendar = .current, referenceDate: Date = Date()) -> Int {
        let days = Set(countByDay(calendar: calendar).map { $0.day })
        return StatsSnapshot.currentStreak(daysWithSessions: days, calendar: calendar, now: referenceDate)
    }

    func lastSevenDaysCounts(calendar: Calendar = .current, referenceDate: Date = Date()) -> [DailyCount] {
        StatsSnapshot.lastSevenDays(countByDay(calendar: calendar), calendar: calendar, now: referenceDate)
    }

    /// Every recorded session, with pre-profiles ones attributed to Classic.
    func sessions() -> [StatsSnapshot.Session] {
        let all = (try? context.fetch(FetchDescriptor<CompletedSession>())) ?? []
        return all.map {
            StatsSnapshot.Session(
                date: $0.date,
                durationSeconds: $0.durationSeconds,
                profileID: $0.profileID ?? TimerProfile.classicID,
                profileName: $0.profileName ?? TimerProfile.classic.name
            )
        }
    }
}

/// Builds the "Export History" CSV. Kept free of UI and SwiftData so the
/// exact output is unit-testable.
enum HistoryCSV {
    static let header = "Date,Time,Profile,Focus Minutes"

    /// One row per completed Focus session, oldest first. Date and time are
    /// the moment the session ended, in the given time zone, in fixed
    /// formats (2026-09-30, 14:25) so spreadsheets parse them the same way
    /// in every locale. Minutes keep one decimal, since finished-early and
    /// custom-length sessions aren't whole numbers.
    static func make(
        _ sessions: [StatsSnapshot.Session],
        profileName: (StatsSnapshot.Session) -> String,
        timeZone: TimeZone = .current
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"

        let rows = sessions
            .sorted { $0.date < $1.date }
            .map { session in
                [
                    dateFormatter.string(from: session.date),
                    timeFormatter.string(from: session.date),
                    escape(profileName(session)),
                    String(format: "%.1f", session.durationSeconds / 60),
                ].joined(separator: ",")
            }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    /// RFC 4180: a field containing a comma, quote, or line break is
    /// wrapped in quotes, with any quotes inside doubled.
    static func escape(_ field: String) -> String {
        // Scalar-level check: Swift treats "\r\n" as one Character, which a
        // per-Character comparison against "\n" or "\r" would miss.
        guard field.rangeOfCharacter(from: CharacterSet(charactersIn: ",\"\r\n")) != nil else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
