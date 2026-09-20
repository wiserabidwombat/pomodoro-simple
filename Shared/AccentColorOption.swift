// Shared/AccentColorOption.swift
import SwiftUI

/// Either one of the 7 curated presets, or an arbitrary RGB color chosen via
/// the Settings ColorPicker. Kept as one Codable/Hashable type (rather than
/// widening the old String-backed enum) since this same type crosses process
/// boundaries as-is — into PomodoroActivityAttributes.ContentState for the
/// Live Activity, and into the widget extension's timeline entries.
enum AccentColorOption: Codable, Hashable {
    case preset(Preset)
    case custom(red: Double, green: Double, blue: Double)

    enum Preset: String, CaseIterable, Codable, Hashable, Identifiable {
        case white, red, orange, yellow, green, cyan, purple

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .white: return .white
            case .red: return Color(red: 1.0, green: 0.31, blue: 0.31)
            case .orange: return Color(red: 1.0, green: 0.58, blue: 0.0)
            case .yellow: return Color(red: 1.0, green: 0.84, blue: 0.0)
            case .green: return Color(red: 0.20, green: 0.84, blue: 0.29)
            case .cyan: return Color(red: 0.20, green: 0.85, blue: 0.95)
            case .purple: return Color(red: 0.75, green: 0.35, blue: 1.0)
            }
        }
    }

    static let white = AccentColorOption.preset(.white)
    static let red = AccentColorOption.preset(.red)
    static let orange = AccentColorOption.preset(.orange)
    static let yellow = AccentColorOption.preset(.yellow)
    static let green = AccentColorOption.preset(.green)
    static let cyan = AccentColorOption.preset(.cyan)
    static let purple = AccentColorOption.preset(.purple)

    static let presets: [AccentColorOption] = Preset.allCases.map(AccentColorOption.preset)

    var color: Color {
        switch self {
        case .preset(let preset): return preset.color
        case .custom(let red, let green, let blue): return Color(red: red, green: green, blue: blue)
        }
    }
}
