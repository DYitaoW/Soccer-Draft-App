/// Player.swift
///
/// Defines the `Player` model used across the draft. A player carries a name,
/// an overall rating, one or more natural positions, and their club and league.
import Foundation

/// A draftee soccer player. Identifiable by a stable UUID and Codable so
/// squads can be persisted and restored.
struct Player: Identifiable, Codable {
    let id: UUID
    let name: String
    let ovrRating: Int
    let positions: [Position]
    let team: String
    let league: String

    /// Returns whether the player can be fielded in the given position,
    /// using the position's compatibility rules anchored on the player's
    /// first listed position.
    /// - Parameter position: The position to test.
    /// - Returns: `true` if the player can play the position.
    func canPlay(_ position: Position) -> Bool {
        positions.contains { $0.matches(position, firstPosition: positions.first) }
    }

    /// The player's natural positions plus nearby positions they are
    /// reasonably comfortable in (e.g. an LM can also cover LW).
    var effectivePositions: [Position] {
        var result = Set(positions)
        for p in positions {
            switch p {
            case .LM: result.insert(.LW)
            case .LW: result.insert(.LM)
            case .RM: result.insert(.RW)
            case .RW: result.insert(.RM)
            case .CAM: if positions.first == .CAM { result.insert(.CM) }
            case .CM: result.insert(.CAM); result.insert(.CDM)
            case .CDM: result.insert(.CM)
            default: break
            }
        }
        return Array(result)
    }

    /// Creates a player. The `id` defaults to a fresh UUID when not supplied.
    init(id: UUID = UUID(), name: String, ovrRating: Int, positions: [Position], team: String, league: String) {
        self.id = id
        self.name = name
        self.ovrRating = ovrRating
        self.positions = positions
        self.team = team
        self.league = league
    }
}
