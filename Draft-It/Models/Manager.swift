/// Manager.swift
///
/// Defines the `Manager` model representing a selectable head coach, with a
/// name, rating, league that feeds into team chemistry and ratings, and
/// a tactical tendency.
import Foundation

/// Manager tactical tendencies that affect playstyle.
enum ManagerTendency: String, Codable, CaseIterable {
    case attackMinded = "Attack Minded"
    case defensive = "Defensive"
    case balanced = "Balanced"
    case counterAttack = "Counter-Attacking"
    case possession = "Possession-Based"
    case highPress = "High Press"
}

/// A draftable manager. `rating` influences team ratings via `managerBonus`,
/// `league` matters for chemistry when the manager shares a league with
/// a player, and `tendency` describes their tactical approach.
/// Identifiable and Codable for persistence.
struct Manager: Identifiable, Codable {
    let id: UUID
    let name: String
    let rating: Int
    let league: String
    let tendency: ManagerTendency

    /// Creates a manager. The `id` defaults to a fresh UUID when not supplied.
    init(id: UUID = UUID(), name: String, rating: Int, league: String, tendency: ManagerTendency = .balanced) {
        self.id = id
        self.name = name
        self.rating = rating
        self.league = league
        self.tendency = tendency
    }
}
