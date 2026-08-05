/// Team.swift
///
/// Defines the `Team` model representing a club with offense, midfield, defense,
/// and goalkeeper ratings. Used for both the user's assembled squad and opponents.
import Foundation

/// A football team with four category ratings. `overall` is derived from the
/// outfield ratings. Identifiable, Hashable, and Codable so teams can be listed,
/// compared, and persisted.
struct Team: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let offense: Int
    let midfield: Int
    let defense: Int
    let goalkeeper: Int

    /// Creates a team. The `id` defaults to a fresh UUID when not supplied.
    /// `goalkeeper` defaults to the defense rating when omitted, so existing
    /// call sites (and older saved games) keep sensible values.
    init(id: UUID = UUID(), name: String, offense: Int, midfield: Int, defense: Int, goalkeeper: Int? = nil) {
        self.id = id
        self.name = name
        self.offense = offense
        self.midfield = midfield
        self.defense = defense
        self.goalkeeper = goalkeeper ?? defense
    }

    /// Restores a team from a saved snapshot. The goalkeeper key may be absent
    /// in saves written before the field was introduced; it falls back to the
    /// defense rating in that case.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        offense = try c.decode(Int.self, forKey: .offense)
        midfield = try c.decode(Int.self, forKey: .midfield)
        defense = try c.decode(Int.self, forKey: .defense)
        goalkeeper = try c.decodeIfPresent(Int.self, forKey: .goalkeeper) ?? defense
    }

    /// The rounded average of the three outfield ratings, 0-99.
    var overall: Int { Int((Double(offense + midfield + defense) / 3).rounded()) }
}
