// Shared/AccentColorOption.swift
import SwiftUI

enum AccentColorOption: String, CaseIterable, Codable, Hashable, Identifiable {
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
