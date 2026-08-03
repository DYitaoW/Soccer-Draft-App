/// DraftHistory.swift
///
/// Persists a history of completed drafts/seasons. `DraftHistory` captures
/// the final squad, result, and optional Super League data for one season;
/// `PlayerSeasonStats` records individual goals and assists per player.
/// Entries are stored as JSON in UserDefaults.
import Foundation

/// Per-player goals and assists for a single season, used to show individual
/// contributions in a season's history detail.
struct PlayerSeasonStats: Codable, Identifiable, Equatable {
    let id: UUID
    let playerName: String
    var goals: Int
    var assists: Int

    /// Creates stats for a player, starting at zero goals/assists unless given.
    init(playerName: String, goals: Int = 0, assists: Int = 0) {
        self.id = UUID()
        self.playerName = playerName
        self.goals = goals
        self.assists = assists
    }
}

/// A completed season's snapshot: the squad that was drafted, the manager,
/// the formation, the final league record and position, and optional Super
/// League and per-player stats. Provides persistence helpers over the full
/// history stored in UserDefaults.
struct DraftHistory: Codable, Identifiable {
    let id: UUID
    let date: Date
    let gameMode: GameMode
    let teamOverall: Int
    let record: SeasonRecord
    let position: Int
    let formation: Formation
    let assignedPlayers: [Int: Player]
    let substitutes: [Player?]
    let manager: Manager?

    var superLeagueRound: SuperLeagueRound? = nil
    var superLeagueRecord: SeasonRecord? = nil
    var playerStats: [PlayerSeasonStats] = []
    var superLeaguePlayerStats: [PlayerSeasonStats] = []
    var matches: [SimulatedMatch] = []
    var standings: [LeagueStanding] = []

    /// The date formatted as MM/dd/yy for display.
    var formattedDate: String {
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yy"
        return df.string(from: date)
    }

    /// A short label for the Super League result: "DNQ" when the team did not
    /// qualify, or an abbreviation of the round reached.
    var superLeagueDisplay: String {
        guard let round = superLeagueRound else { return "DNQ" }
        switch round {
        case .league: return "League"
        case .firstRound: return "KO"
        case .roundOf16: return "R16"
        case .quarterFinal: return "QF"
        case .semiFinal: return "SF"
        case .final: return "Final"
        case .winner: return "Winner"
        }
    }

    /// Inserts an entry at the front of the persisted history.
    /// - Parameter entry: The season entry to save.
    static func save(_ entry: DraftHistory) {
        var history = Self.loadAll()
        history.insert(entry, at: 0)
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: "draftHistory")
    }

    /// Mutates an existing entry in place, then re-persists the history.
    /// No-op if no entry with the given id exists.
    /// - Parameter id: The id of the entry to update.
    /// - Parameter transform: A closure that modifies the matching entry.
    static func update(_ id: UUID, with transform: (inout DraftHistory) -> Void) {
        var history = Self.loadAll()
        guard let idx = history.firstIndex(where: { $0.id == id }) else { return }
        transform(&history[idx])
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: "draftHistory")
    }

    /// Loads all saved season entries, newest first.
    /// - Returns: The full history, or an empty array if none exists.
    static func loadAll() -> [DraftHistory] {
        guard let data = UserDefaults.standard.data(forKey: "draftHistory"),
              let history = try? JSONDecoder().decode([DraftHistory].self, from: data) else {
            return []
        }
        return history
    }

    /// Removes all saved draft history from UserDefaults.
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: "draftHistory")
    }
}
