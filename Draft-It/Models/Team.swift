/// Team.swift
///
/// Defines the `Team` model representing a club with offense, midfield, and
/// defense ratings. Used for both the user's assembled squad and opponents.
import Foundation

/// A football team with three category ratings. `overall` is derived from
/// those ratings. Identifiable, Hashable, and Codable so teams can be listed,
/// compared, and persisted.
struct Team: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let offense: Int
    let midfield: Int
    let defense: Int

    /// Creates a team. The `id` defaults to a fresh UUID when not supplied.
    init(id: UUID = UUID(), name: String, offense: Int, midfield: Int, defense: Int) {
        self.id = id
        self.name = name
        self.offense = offense
        self.midfield = midfield
        self.defense = defense
    }

    /// The rounded average of the three category ratings, 0-99.
    var overall: Int { Int((Double(offense + midfield + defense) / 3).rounded()) }
}
