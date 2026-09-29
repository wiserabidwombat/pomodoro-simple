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
    }

    var todayCount = 0
    var totalCount = 0
    var totalFocusSeconds: TimeInterval = 0
    var currentStreak = 0
    /// The last 7 days including today, oldest first, zero-filled.
    var lastSevenDays: [DailyCount] = []
    /// Only days that have at least one session, newest first.
    var byDay: [DailyCount] = []

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

    func recordCompletedSession(duration: TimeInterval, on date: Date = Date()) {
        context.insert(CompletedSession(date: date, durationSeconds: duration))
        try? context.save()
    }

    /// Imports sessions queued in the App Group by other processes/paths
    /// (see PendingCompletedSession) with a single save.
    func recordCompletedSessions(_ pending: [PendingCompletedSession]) {
        guard !pending.isEmpty else { return }
        for session in pending {
            context.insert(CompletedSession(date: session.endedAt, durationSeconds: session.duration))
        }
        try? context.save()
    }

    /// One fetch for the whole Stats screen, instead of the ~6 separate
    /// queries it used to run on every render.
    func snapshot(calendar: Calendar = .current, now: Date = Date()) -> StatsSnapshot {
        StatsSnapshot(sessions: allSessions(), calendar: calendar, now: now)
    }

    func countByDay(calendar: Calendar = .current) -> [DailyCount] {
        StatsSnapshot.countByDay(allSessions().map { $0.date }, calendar: calendar)
    }

    var totalCount: Int {
        (try? context.fetchCount(FetchDescriptor<CompletedSession>())) ?? 0
    }

    var todayCount: Int {
        snapshot().todayCount
    }

    var totalFocusSeconds: TimeInterval {
        allSessions().reduce(0) { $0 + $1.durationSeconds }
    }

    func currentStreak(calendar: Calendar = .current, referenceDate: Date = Date()) -> Int {
        let days = Set(countByDay(calendar: calendar).map { $0.day })
        return StatsSnapshot.currentStreak(daysWithSessions: days, calendar: calendar, now: referenceDate)
    }

    func lastSevenDaysCounts(calendar: Calendar = .current, referenceDate: Date = Date()) -> [DailyCount] {
        StatsSnapshot.lastSevenDays(countByDay(calendar: calendar), calendar: calendar, now: referenceDate)
    }

    private func allSessions() -> [StatsSnapshot.Session] {
        let all = (try? context.fetch(FetchDescriptor<CompletedSession>())) ?? []
        return all.map { StatsSnapshot.Session(date: $0.date, durationSeconds: $0.durationSeconds) }
    }
}
