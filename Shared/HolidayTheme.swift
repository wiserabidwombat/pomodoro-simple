import Foundation
import SwiftUI

/// A seasonal look: its own accent color, a dark background tint, and the
/// emoji used for the drifting particles and the completion celebration.
/// Used by the app, the widgets and the Live Activity (accent only there).
enum HolidayTheme: String, CaseIterable, Identifiable, Codable {
    case halloween, thanksgiving, christmas

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .halloween: return "Halloween"
        case .thanksgiving: return "Thanksgiving"
        case .christmas: return "Christmas"
        }
    }

    /// Replaces the user's accent color while the theme is active. All
    /// three are bright enough to read on black (see isLowContrastOnBlack).
    var accent: AccentColorOption {
        switch self {
        case .halloween: return .custom(red: 1.0, green: 0.55, blue: 0.0)     // pumpkin orange
        case .thanksgiving: return .custom(red: 0.95, green: 0.65, blue: 0.25) // harvest gold
        case .christmas: return .custom(red: 0.95, green: 0.27, blue: 0.29)    // holly red
        }
    }

    /// A deep tint that fades into the black background from the top.
    var backgroundTint: Color {
        switch self {
        case .halloween: return Color(red: 0.20, green: 0.06, blue: 0.30)    // night purple
        case .thanksgiving: return Color(red: 0.24, green: 0.11, blue: 0.03) // autumn brown
        case .christmas: return Color(red: 0.02, green: 0.20, blue: 0.10)    // pine green
        }
    }

    /// Emoji drifting slowly behind the Timer screen.
    var ambientParticles: [String] {
        switch self {
        case .halloween: return ["🦇", "👻", "🎃"]
        case .thanksgiving: return ["🍂", "🍁", "🍂"]
        case .christmas: return ["❄️"]
        }
    }

    /// Halloween's bats and ghosts float upward; leaves and snow fall.
    var particlesRise: Bool { self == .halloween }

    /// Emoji in the burst when a Focus session finishes.
    var celebrationParticles: [String] {
        switch self {
        case .halloween: return ["🎃", "🍬", "🦇", "👻"]
        case .thanksgiving: return ["🍁", "🦃", "🥧", "🍂"]
        case .christmas: return ["🎄", "🎁", "⭐️", "❄️"]
        }
    }

    /// The holiday season `date` falls in, used by the Automatic setting:
    /// Halloween for all of October, Thanksgiving from November 1 through
    /// Thanksgiving Day (US, the fourth Thursday of November), and Christmas
    /// from the next day through December 31. nil the rest of the year.
    static func season(on date: Date, timeZone: TimeZone = .current) -> HolidayTheme? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        switch month {
        case 10:
            return .halloween
        case 11:
            let thanksgiving = thanksgivingDay(year: year, calendar: calendar) ?? 28
            return day <= thanksgiving ? .thanksgiving : .christmas
        case 12:
            return .christmas
        default:
            return nil
        }
    }

    /// Day of November that US Thanksgiving falls on in `year`.
    static func thanksgivingDay(year: Int, calendar: Calendar) -> Int? {
        // weekday 5 = Thursday in the Gregorian calendar.
        let fourthThursday = DateComponents(year: year, month: 11, weekday: 5, weekdayOrdinal: 4)
        guard let date = calendar.date(from: fourthThursday) else { return nil }
        return calendar.component(.day, from: date)
    }
}

/// The Holiday Theme choice in Settings. Off by default, so nobody's chosen
/// accent color changes unless they opt in.
enum ThemeSetting: String, CaseIterable, Identifiable, Codable {
    case off, automatic, halloween, thanksgiving, christmas

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .automatic: return "Automatic"
        case .halloween, .thanksgiving, .christmas: return HolidayTheme(rawValue: rawValue)?.displayName ?? rawValue
        }
    }

    /// The theme to show right now, or nil for the normal look.
    func activeTheme(on date: Date = Date(), timeZone: TimeZone = .current) -> HolidayTheme? {
        switch self {
        case .off: return nil
        case .automatic: return HolidayTheme.season(on: date, timeZone: timeZone)
        case .halloween, .thanksgiving, .christmas: return HolidayTheme(rawValue: rawValue)
        }
    }
}
