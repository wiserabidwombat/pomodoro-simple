// PomodoroTests/HistoryStoreTests.swift
import XCTest
import SwiftData
@testable import Pomodoro

final class HistoryStoreTests: XCTestCase {
    @MainActor
    private func makeInMemoryStore() -> HistoryStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: CompletedSession.self, configurations: config)
        return HistoryStore(context: container.mainContext)
    }

    @MainActor
    func testTotalCountStartsAtZero() {
        let store = makeInMemoryStore()
        XCTAssertEqual(store.totalCount, 0)
    }

    @MainActor
    func testRecordCompletedSessionIncreasesTotalAndTodayCount() {
        let store = makeInMemoryStore()
        store.recordCompletedSession(duration: PomodoroPhase.work.duration)
        XCTAssertEqual(store.totalCount, 1)
        XCTAssertEqual(store.todayCount, 1)
    }

    @MainActor
    func testCountByDayGroupsSessionsByCalendarDay() {
        let store = makeInMemoryStore()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        store.recordCompletedSession(duration: PomodoroPhase.work.duration, on: today)
        store.recordCompletedSession(duration: PomodoroPhase.work.duration, on: today)
        store.recordCompletedSession(duration: PomodoroPhase.work.duration, on: yesterday)

        let byDay = store.countByDay()
        XCTAssertEqual(byDay.count, 2)
        XCTAssertEqual(byDay.first(where: { calendar.isDate($0.day, inSameDayAs: today) })?.count, 2)
        XCTAssertEqual(byDay.first(where: { calendar.isDate($0.day, inSameDayAs: yesterday) })?.count, 1)
    }
}
