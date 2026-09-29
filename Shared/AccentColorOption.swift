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

        var rgb: (red: Double, green: Double, blue: Double) {
            switch self {
            case .white: return (1.0, 1.0, 1.0)
            case .red: return (1.0, 0.31, 0.31)
            case .orange: return (1.0, 0.58, 0.0)
            case .yellow: return (1.0, 0.84, 0.0)
            case .green: return (0.20, 0.84, 0.29)
            case .cyan: return (0.20, 0.85, 0.95)
            case .purple: return (0.75, 0.35, 1.0)
            }
        }

        var color: Color {
            Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
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

    private var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .preset(let preset): return preset.rgb
        case .custom(let red, let green, let blue): return (red, green, blue)
        }
    }

    /// WCAG relative luminance (0 = black, 1 = white).
    var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            let c = min(max(channel, 0), 1)
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let c = rgb
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    /// True when black text has more contrast on this color than white
    /// does (the WCAG contrast-ratio crossover, at luminance ≈ 0.18).
    var prefersDarkText: Bool {
        let contrastWithBlack = (relativeLuminance + 0.05) / 0.05
        let contrastWithWhite = 1.05 / (relativeLuminance + 0.05)
        return contrastWithBlack > contrastWithWhite
    }

    /// Label color for anything *filled* with this accent, like the
    /// Continue button: white on dark accents, black on light ones (white
    /// text on the default white accent, or on yellow, would vanish).
    var contrastingTextColor: Color {
        prefersDarkText ? .black : .white
    }
}
