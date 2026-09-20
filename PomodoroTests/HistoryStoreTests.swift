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

    @MainActor
    func testTotalFocusSecondsSumsAllSessions() {
        let store = makeInMemoryStore()
        store.recordCompletedSession(duration: 1500)
        store.recordCompletedSession(duration: 300)
        XCTAssertEqual(store.totalFocusSeconds, 1800)
    }

    @MainActor
    func testCurrentStreakCountsConsecutiveDaysEndingToday() {
        let store = makeInMemoryStore()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!
        store.recordCompletedSession(duration: 1500, on: today)
        store.recordCompletedSession(duration: 1500, on: yesterday)
        store.recordCompletedSession(duration: 1500, on: twoDaysAgo)
        store.recordCompletedSession(duration: 1500, on: fourDaysAgo) // gap at 3 days ago breaks it
        XCTAssertEqual(store.currentStreak(), 3)
    }

    @MainActor
    func testCurrentStreakDoesNotResetJustBecauseTodayIsIncomplete() {
        let store = makeInMemoryStore()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        store.recordCompletedSession(duration: 1500, on: yesterday)
        XCTAssertEqual(store.currentStreak(), 1)
    }

    @MainActor
    func testCurrentStreakIsZeroWithNoSessions() {
        let store = makeInMemoryStore()
        XCTAssertEqual(store.currentStreak(), 0)
    }

    @MainActor
    func testLastSevenDaysCountsIsZeroFilledAndOrderedOldestFirst() {
        let store = makeInMemoryStore()
        let calendar = Calendar.current
        let today = Date()
        store.recordCompletedSession(duration: 1500, on: today)
        let series = store.lastSevenDaysCounts()
        XCTAssertEqual(series.count, 7)
        XCTAssertTrue(calendar.isDate(series.last!.day, inSameDayAs: today))
        XCTAssertEqual(series.last!.count, 1)
        XCTAssertEqual(series.first!.count, 0)
    }
}
