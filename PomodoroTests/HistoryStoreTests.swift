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

    // MARK: - Stats screen states

    @MainActor
    func testSnapshotWithNoSessionsIsAllZeroAndStillHasAFullWeek() {
        let snapshot = makeInMemoryStore().snapshot()
        XCTAssertEqual(snapshot.todayCount, 0)
        XCTAssertEqual(snapshot.totalCount, 0)
        XCTAssertEqual(snapshot.totalFocusSeconds, 0)
        XCTAssertEqual(snapshot.currentStreak, 0)
        XCTAssertEqual(snapshot.byDay, [])
        XCTAssertEqual(snapshot.lastSevenDays.count, 7)
        XCTAssertTrue(snapshot.lastSevenDays.allSatisfy { $0.count == 0 })
        XCTAssertEqual(StatsView.formattedFocusTime(snapshot.totalFocusSeconds), "0m")
    }

    @MainActor
    func testSnapshotWithSessionsOnlyToday() {
        let store = makeInMemoryStore()
        for _ in 0..<3 {
            store.recordCompletedSession(duration: 1500)
        }
        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot.todayCount, 3)
        XCTAssertEqual(snapshot.totalCount, 3)
        XCTAssertEqual(snapshot.totalFocusSeconds, 4500)
        XCTAssertEqual(snapshot.currentStreak, 1)
        XCTAssertEqual(snapshot.byDay.count, 1)
        XCTAssertEqual(snapshot.lastSevenDays.map(\.count), [0, 0, 0, 0, 0, 0, 3])
    }

    func testSnapshotWithALongHistory() {
        let calendar = Calendar.current
        let now = Date()
        let sessions: [StatsSnapshot.Session] = (0..<400).flatMap { daysAgo -> [StatsSnapshot.Session] in
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            // Two sessions on even days, one on odd days.
            return Array(repeating: StatsSnapshot.Session(date: day, durationSeconds: 1500), count: daysAgo.isMultiple(of: 2) ? 2 : 1)
        }
        let snapshot = StatsSnapshot(sessions: sessions, calendar: calendar, now: now)
        XCTAssertEqual(snapshot.totalCount, 600)
        XCTAssertEqual(snapshot.todayCount, 2)
        XCTAssertEqual(snapshot.currentStreak, 400)
        XCTAssertEqual(snapshot.byDay.count, 400)
        XCTAssertEqual(snapshot.byDay, snapshot.byDay.sorted { $0.day > $1.day })
        XCTAssertEqual(snapshot.lastSevenDays.count, 7)
        XCTAssertEqual(snapshot.lastSevenDays.map(\.count), [2, 1, 2, 1, 2, 1, 2])
        XCTAssertEqual(StatsView.formattedFocusTime(snapshot.totalFocusSeconds), "250h 0m")
    }

    func testStreakAndWeekSurviveAMidnightDSTChange() {
        // Brazil's DST (while it still had one) started at midnight, so
        // 2018-11-04 began at 01:00 local time — "start of day minus one
        // day" math lands on a time that isn't any day's start.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let sessions = (1...7).map { day -> StatsSnapshot.Session in
            let date = calendar.date(from: DateComponents(year: 2018, month: 11, day: day, hour: 12))!
            return StatsSnapshot.Session(date: date, durationSeconds: 1500)
        }
        let now = calendar.date(from: DateComponents(year: 2018, month: 11, day: 7, hour: 15))!
        let snapshot = StatsSnapshot(sessions: sessions, calendar: calendar, now: now)
        XCTAssertEqual(snapshot.currentStreak, 7)
        XCTAssertEqual(snapshot.lastSevenDays.map(\.count), [1, 1, 1, 1, 1, 1, 1])
    }

    func testFormattedFocusTimeNeverTrapsOnBadInput() {
        XCTAssertEqual(StatsView.formattedFocusTime(.nan), "0m")
        XCTAssertEqual(StatsView.formattedFocusTime(.infinity), "0m")
        XCTAssertEqual(StatsView.formattedFocusTime(-60), "0m")
        XCTAssertEqual(StatsView.formattedFocusTime(3660), "1h 1m")
    }

    // MARK: - Stats by profile

    @MainActor
    func testSessionsFromBeforeProfilesCountAsClassic() {
        let store = makeInMemoryStore()
        store.recordCompletedSession(duration: 1500) // no profile, like old data
        let sessions = store.sessions()
        XCTAssertEqual(sessions.first?.profileID, TimerProfile.classicID)
        XCTAssertEqual(sessions.first?.profileName, "Classic")
    }

    @MainActor
    func testSnapshotCanBeFilteredToOneProfile() {
        let store = makeInMemoryStore()
        store.recordCompletedSession(duration: 1500, profile: .classic)
        store.recordCompletedSession(duration: 3000, profile: .deepWork)
        store.recordCompletedSession(duration: 3000, profile: .deepWork)

        XCTAssertEqual(store.snapshot().totalCount, 3)
        let deepWork = store.snapshot(profileID: TimerProfile.deepWorkID)
        XCTAssertEqual(deepWork.totalCount, 2)
        XCTAssertEqual(deepWork.totalFocusSeconds, 6000)
        XCTAssertEqual(deepWork.todayCount, 2)
    }

    @MainActor
    func testImportedPendingSessionsKeepTheirProfile() {
        let store = makeInMemoryStore()
        store.recordCompletedSessions([PendingCompletedSession(
            endedAt: Date(),
            duration: 3000,
            profileID: TimerProfile.deepWorkID,
            profileName: "Deep Work"
        )])
        XCTAssertEqual(store.sessions().first?.profileID, TimerProfile.deepWorkID)
    }

    func testByProfileTotalsAreSortedByFocusTimeAndCountToday() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let study = UUID()
        let sessions = [
            StatsSnapshot.Session(date: yesterday, durationSeconds: 1500, profileID: TimerProfile.classicID, profileName: "Classic"),
            StatsSnapshot.Session(date: now, durationSeconds: 1500, profileID: TimerProfile.classicID, profileName: "Classic"),
            StatsSnapshot.Session(date: now, durationSeconds: 3000, profileID: study, profileName: "Study"),
            StatsSnapshot.Session(date: now, durationSeconds: 3000, profileID: study, profileName: "Study"),
        ]
        let totals = StatsSnapshot(sessions: sessions, now: now).byProfile
        XCTAssertEqual(totals.map(\.name), ["Study", "Classic"])
        XCTAssertEqual(totals.map(\.count), [2, 2])
        XCTAssertEqual(totals.map(\.totalFocusSeconds), [6000, 3000])
        XCTAssertEqual(totals.map(\.todayCount), [2, 1])
    }

    func testByProfileUsesTheLatestNameAfterARename() {
        let id = UUID()
        let earlier = Date().addingTimeInterval(-3600)
        let sessions = [
            StatsSnapshot.Session(date: earlier, durationSeconds: 1500, profileID: id, profileName: "Study"),
            StatsSnapshot.Session(date: Date(), durationSeconds: 1500, profileID: id, profileName: "Exam Prep"),
        ]
        XCTAssertEqual(StatsSnapshot(sessions: sessions).byProfile.map(\.name), ["Exam Prep"])
    }
}
