import XCTest
@testable import Pomodoro

final class HolidayThemeTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testThanksgivingIsTheFourthThursdayOfNovember() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        XCTAssertEqual(HolidayTheme.thanksgivingDay(year: 2024, calendar: calendar), 28)
        XCTAssertEqual(HolidayTheme.thanksgivingDay(year: 2025, calendar: calendar), 27)
        XCTAssertEqual(HolidayTheme.thanksgivingDay(year: 2026, calendar: calendar), 26)
        XCTAssertEqual(HolidayTheme.thanksgivingDay(year: 2027, calendar: calendar), 25)
    }

    func testSeasonsFollowTheCalendar() {
        XCTAssertNil(HolidayTheme.season(on: date(2026, 9, 30), timeZone: utc))
        XCTAssertEqual(HolidayTheme.season(on: date(2026, 10, 1), timeZone: utc), .halloween)
        XCTAssertEqual(HolidayTheme.season(on: date(2026, 10, 31), timeZone: utc), .halloween)
        XCTAssertEqual(HolidayTheme.season(on: date(2026, 11, 1), timeZone: utc), .thanksgiving)
        XCTAssertEqual(HolidayTheme.season(on: date(2026, 11, 26), timeZone: utc), .thanksgiving) // Thanksgiving Day
        XCTAssertEqual(HolidayTheme.season(on: date(2026, 11, 27), timeZone: utc), .christmas)
        XCTAssertEqual(HolidayTheme.season(on: date(2026, 12, 31), timeZone: utc), .christmas)
        XCTAssertNil(HolidayTheme.season(on: date(2027, 1, 1), timeZone: utc))
    }

    func testThemeSettingPicksTheActiveTheme() {
        let midsummer = date(2026, 7, 4)
        XCTAssertNil(ThemeSetting.off.activeTheme(on: date(2026, 10, 15), timeZone: utc))
        XCTAssertNil(ThemeSetting.automatic.activeTheme(on: midsummer, timeZone: utc))
        XCTAssertEqual(ThemeSetting.automatic.activeTheme(on: date(2026, 12, 20), timeZone: utc), .christmas)
        // A specific theme shows all year.
        XCTAssertEqual(ThemeSetting.halloween.activeTheme(on: midsummer, timeZone: utc), .halloween)
        XCTAssertEqual(ThemeSetting.christmas.activeTheme(on: midsummer, timeZone: utc), .christmas)
    }

    func testThemeAccentsAreReadableOnBlack() {
        for theme in HolidayTheme.allCases {
            XCTAssertFalse(theme.accent.isLowContrastOnBlack, theme.displayName)
        }
    }

    func testStoreDefaultsToOffAndUsesThemeAccentWhileActive() {
        let store = PomodoroStateStore(defaults: UserDefaults(suiteName: "test-suite-\(UUID().uuidString)")!)
        store.save(.preset(.cyan))
        XCTAssertEqual(store.loadThemeSetting(), .off)
        XCTAssertEqual(store.loadEffectiveAccentColor(), .preset(.cyan))

        store.save(themeSetting: .halloween)
        XCTAssertEqual(store.loadThemeSetting(), .halloween)
        XCTAssertEqual(store.loadEffectiveAccentColor(), HolidayTheme.halloween.accent)
        XCTAssertEqual(store.loadAccentColor(), .preset(.cyan), "the user's own color is untouched")

        store.save(themeSetting: .automatic)
        XCTAssertEqual(store.loadEffectiveAccentColor(now: date(2026, 7, 4)), .preset(.cyan))
        XCTAssertEqual(store.loadEffectiveAccentColor(now: date(2026, 12, 20)), HolidayTheme.christmas.accent)
    }
}
