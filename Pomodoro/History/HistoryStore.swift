// Pomodoro/History/HistoryStore.swift
import Foundation
import SwiftData

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

    func sessions(on day: Date, calendar: Calendar = .current) -> [CompletedSession] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = #Predicate<CompletedSession> { $0.date >= start && $0.date < end }
        return (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
    }

    func countByDay(calendar: Calendar = .current) -> [(day: Date, count: Int)] {
        let all = (try? context.fetch(FetchDescriptor<CompletedSession>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        let grouped = Dictionary(grouping: all) { calendar.startOfDay(for: $0.date) }
        return grouped.map { (day: $0.key, count: $0.value.count) }.sorted { $0.day > $1.day }
    }

    var totalCount: Int {
        (try? context.fetchCount(FetchDescriptor<CompletedSession>())) ?? 0
    }

    var todayCount: Int {
        sessions(on: Date()).count
    }

    var totalFocusSeconds: TimeInterval {
        let all = (try? context.fetch(FetchDescriptor<CompletedSession>())) ?? []
        return all.reduce(0) { $0 + $1.durationSeconds }
    }

    /// Consecutive days with at least one completed session, counting
    /// backward from today. A day that hasn't happened yet (no session
    /// today) doesn't break a streak built on prior days — it only breaks
    /// once a full day passes with nothing recorded.
    func currentStreak(calendar: Calendar = .current, referenceDate: Date = Date()) -> Int {
        let daysWithSessions = Set(countByDay(calendar: calendar).map { $0.day })
        var day = calendar.startOfDay(for: referenceDate)
        if !daysWithSessions.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var streak = 0
        while daysWithSessions.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    struct DailyCount: Identifiable, Hashable {
        let day: Date
        let count: Int
        var id: Date { day }
    }

    /// The last 7 days including today, oldest first, with zero-filled gaps
    /// — unlike countByDay(), which only returns days that have a session at
    /// all (unsuitable for a fixed-width chart axis).
    func lastSevenDaysCounts(calendar: Calendar = .current, referenceDate: Date = Date()) -> [DailyCount] {
        let countsByDay = Dictionary(uniqueKeysWithValues: countByDay(calendar: calendar).map { ($0.day, $0.count) })
        let today = calendar.startOfDay(for: referenceDate)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return DailyCount(day: day, count: countsByDay[day] ?? 0)
        }
    }
}
