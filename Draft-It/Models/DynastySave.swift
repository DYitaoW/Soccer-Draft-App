/// DynastySave.swift
///
/// Persists the user's dynasty team between seasons. Stores the drafted squad
/// and manager so a multi-season career can be resumed, flagged active or
/// cleared in UserDefaults.
import Foundation

/// A codable snapshot of the dynasty team: starters, substitutes, formation,
/// manager, and the number of seasons played.
struct DynastySave: Codable {
    let assignedPlayers: [Int: Player]
    let substitutes: [Player?]
    let formation: Formation
    let manager: Manager?
    let seasonCount: Int

    /// Encodes and stores the dynasty team, marking a dynasty as active.
    /// - Parameter assignedPlayers: Starters keyed by formation slot index.
    /// - Parameter substitutes: The five bench players.
    /// - Parameter formation: The formation used.
    /// - Parameter manager: The selected manager, if any.
    /// - Parameter seasonCount: How many seasons the dynasty has completed.
    static func save(assignedPlayers: [Int: Player], substitutes: [Player?], formation: Formation, manager: Manager?, seasonCount: Int) {
        let save = DynastySave(
            assignedPlayers: assignedPlayers,
            substitutes: substitutes,
            formation: formation,
            manager: manager,
            seasonCount: seasonCount
        )
        guard let data = try? JSONEncoder().encode(save) else { return }
        UserDefaults.standard.set(data, forKey: "dynastyTeamData")
        UserDefaults.standard.set(true, forKey: "dynastyActive")
    }

    /// Loads the saved dynasty team.
    /// - Returns: The restored `DynastySave`, or `nil` if none exists.
    static func load() -> DynastySave? {
        guard let data = UserDefaults.standard.data(forKey: "dynastyTeamData"),
              let save = try? JSONDecoder().decode(DynastySave.self, from: data) else { return nil }
        return save
    }

    /// Removes the dynasty team data and marks the dynasty inactive.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "dynastyTeamData")
        UserDefaults.standard.set(false, forKey: "dynastyActive")
    }
}
