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
}
