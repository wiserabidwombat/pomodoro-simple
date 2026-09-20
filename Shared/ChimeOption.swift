// Shared/ChimeOption.swift
import Foundation

/// Wraps a handful of curated AudioToolbox system sound IDs — these are
/// long-standing public UI sound effect IDs playable via
/// AudioServicesPlaySystemSound, not files bundled with this app. Labeled
/// generically (not "Bell"/"Glass"/etc.) since there's no reliable way to
/// assert what each actually sounds like without hearing it — the Settings
/// picker lets the user preview each one instead.
enum ChimeOption: UInt32, CaseIterable, Codable, Identifiable {
    case chime1 = 1000
    case chime2 = 1003
    case chime3 = 1005
    case chime4 = 1013
    case chime5 = 1016
    case chime6 = 1025

    var id: UInt32 { rawValue }

    var displayName: String {
        switch self {
        case .chime1: return "Chime 1"
        case .chime2: return "Chime 2"
        case .chime3: return "Chime 3"
        case .chime4: return "Chime 4"
        case .chime5: return "Chime 5"
        case .chime6: return "Chime 6"
        }
    }

    static let `default` = ChimeOption.chime3
}
