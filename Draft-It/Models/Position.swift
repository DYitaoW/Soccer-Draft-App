/// Position.swift
///
/// Defines the `Position` enum representing every football role on the pitch,
/// along with the compatibility rules and display colors used across the app.
import SwiftUI

/// All football positions a player can occupy. `RawValue` is the short label
/// (e.g. "GK", "CAM"). Codable so positions persist with saved games.
enum Position: String, CaseIterable, Codable {
    case GK = "GK"
    case LB = "LB"
    case CB = "CB"
    case RB = "RB"
    case LWB = "LWB"
    case RWB = "RWB"
    case CDM = "CDM"
    case CM = "CM"
    case CAM = "CAM"
    case LM = "LM"
    case RM = "RM"
    case LW = "LW"
    case RW = "RW"
    case CF = "CF"
    case ST = "ST"

    /// Whether this position is interchangeable with `other`. Wingers and
    /// wide midfielders are freely swappable, and central midfield roles
    /// partially convert. `firstPosition` disambiguates CAM-to-CM moves
    /// based on the player's listed primary role.
    /// - Parameter other: The position to compare against.
    /// - Parameter firstPosition: The player's first listed position, if any.
    /// - Returns: `true` if the two positions are considered compatible.
    func matches(_ other: Position, firstPosition: Position? = nil) -> Bool {
        if self == other { return true }
        switch (self, other) {
        case (.LM, .LW), (.LW, .LM), (.RM, .RW), (.RW, .RM): return true
        case (.CM, .CAM), (.CDM, .CM): return true
        case (.CM, .CDM): return true
        case (.CAM, .CM): return firstPosition == .CAM || firstPosition == nil
        default: return false
        }
    }

    /// The UI color representing this position's category: red for attackers,
    /// blue for midfielders, green for defenders, and purple for goalkeepers.
    var categoryColor: Color {
        switch self {
        case .ST, .CF, .LW, .RW: return .red
        case .CM, .CDM, .CAM, .LM, .RM: return .blue
        case .CB, .LB, .RB, .LWB, .RWB: return Color(red: 0.1, green: 0.55, blue: 0.1)
        case .GK: return .purple
        }
    }
}
