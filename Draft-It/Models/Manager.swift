/// Manager.swift
///
/// Defines the `Manager` model representing a selectable head coach, with a
/// name, rating, and league that feeds into team chemistry and ratings.
import Foundation

/// A draftable manager. `rating` influences team ratings via `managerBonus`,
/// and `league` matters for chemistry when the manager shares a league with
/// a player. Identifiable and Codable for persistence.
struct Manager: Identifiable, Codable {
    let id: UUID
    let name: String
    let rating: Int
    let league: String

    /// Creates a manager. The `id` defaults to a fresh UUID when not supplied.
    init(id: UUID = UUID(), name: String, rating: Int, league: String) {
        self.id = id
        self.name = name
        self.rating = rating
        self.league = league
    }
}
