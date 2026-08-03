/// PlayerMatchPerformance.swift
///
/// Per-player match statistics and ratings, derived from a simulated knockout
/// leg, using deterministic seeding for stability.
import Foundation

/// Aggregated statistics and a match rating for one player in a single match.
struct PlayerMatchPerformance: Identifiable {
    let id = UUID()
    let name: String
    /// The team the player represented in the match.
    let teamId: UUID
    /// True when the player is the goalkeeper, used for saves/goals-conceded.
    let isGoalkeeper: Bool
    /// The player's overall rating used as the base for the match rating.
    let ovrRating: Int
    /// Goals scored by the player.
    var goals: Int
    /// Assists recorded by the player.
    var assists: Int
    /// Own goals scored by the player.
    var ownGoals: Int
    /// Yellow cards received by the player.
    var yellowCards: Int
    /// Red cards received by the player.
    var redCards: Int
    /// Saves made by the player (goalkeepers only).
    var saves: Int
    /// Goals conceded by the player's team while they were on the pitch.
    var goalsConceded: Int
    /// Penalties taken by the player in a shootout.
    var penaltiesTaken: Int
    /// Penalties scored by the player in a shootout.
    var penaltiesScored: Int
    /// The final match rating, clamped to 1.0...10.0.
    let rating: Double
}

/// Builds per-player match performance records from simulated legs.
enum MatchRatings {
    /// Looks up a player's overall rating by name, defaulting to 80.
    private static func ovrFor(_ name: String) -> Int {
        let dict = Dictionary(GameData.players.map { ($0.name, $0.ovrRating) }, uniquingKeysWith: { max($0, $1) })
        return dict[name] ?? 80
    }

    /// Ratings start from a player's ability, then get nudged by what actually happened.
    /// The floor is 1.0 so a catastrophic performance can score very poorly.
    static func computeRating(ovr: Int, goals: Int, assists: Int, ownGoals: Int, saves: Int, goalsConceded: Int, yellowCards: Int, redCards: Int, penaltiesTaken: Int, penaltiesScored: Int, isGoalkeeper: Bool, variance: Double) -> Double {
        var r = 6.5 + (Double(ovr - 70) / 25.0) * 2.0
        r += Double(goals) * 0.6
        r += Double(assists) * 0.25
        r -= Double(ownGoals) * 1.0
        r += Double(saves) * 0.06
        r -= Double(goalsConceded) * 0.05
        r -= Double(yellowCards) * 0.2
        r -= Double(redCards) * 1.5
        if penaltiesTaken > 0 {
            r += Double(penaltiesScored) * 0.15
            r -= Double(penaltiesTaken - penaltiesScored) * 0.5
        }
        if isGoalkeeper && goals == 0 {
            r += 0.1
        }
        r += variance
        return min(10.0, max(1.0, (r * 10).rounded() / 10))
    }

    /// Produces performances for the named home and away squads from a
    /// simulated leg's goals, cards, and penalties. Saves are not tracked for
    /// pre-simulated legs and default to zero. Player lists fall back to
    /// generated squad names when nil.
    /// - Returns: One performance record per named player on both teams.
    static func fromLeg(_ leg: SimulatedKnockoutLeg, homeNames: [String]?, awayNames: [String]?) -> [PlayerMatchPerformance] {
        let hNames = homeNames ?? SimulatedKnockoutLeg.squadNames(for: leg.homeTeam.name, count: 11)
        let aNames = awayNames ?? SimulatedKnockoutLeg.squadNames(for: leg.awayTeam.name, count: 11)

        var goalsDict: [String: Int] = [:]
        var ownGoalsDict: [String: Int] = [:]
        var assistDict: [String: Int] = [:]
        var yellowDict: [String: Int] = [:]
        var redDict: [String: Int] = [:]
        for g in leg.goals + leg.etGoals {
            if g.isOwnGoal { ownGoalsDict[g.scorer, default: 0] += 1 }
            else { goalsDict[g.scorer, default: 0] += 1 }
            if let a = g.assist { assistDict[a, default: 0] += 1 }
        }
        for c in leg.cards + leg.etCards {
            if c.isSecondYellow { redDict[c.playerName, default: 0] += 1 }
            else { yellowDict[c.playerName, default: 0] += 1 }
        }
        var penTaken: [String: Int] = [:]
        var penScored: [String: Int] = [:]
        for k in leg.penaltyKicks {
            penTaken[k.shooter, default: 0] += 1
            if k.scored { penScored[k.shooter, default: 0] += 1 }
        }

        var legSalt = (leg.goals.count + leg.etGoals.count) * 31 + (leg.cards.count + leg.etCards.count) * 17 + leg.penaltyKicks.count * 13
        for g in leg.goals + leg.etGoals { legSalt += g.minute }
        let teamSeed = uuidSeed(leg.homeTeam.id) ^ uuidSeed(leg.awayTeam.id) ^ legSalt

        func perf(for name: String, teamId: UUID, isGK: Bool, goalsConceded: Int) -> PlayerMatchPerformance {
            let ovr = ovrFor(name)
            let goals = goalsDict[name] ?? 0
            let assists = assistDict[name] ?? 0
            let ownGoals = ownGoalsDict[name] ?? 0
            let yellows = yellowDict[name] ?? 0
            let reds = redDict[name] ?? 0
            let taken = penTaken[name] ?? 0
            let scored = penScored[name] ?? 0
            let seed = stringSeed(name) ^ teamSeed
            let variance = (seededUnit(seed) - 0.5) * 0.8
            return PlayerMatchPerformance(
                name: name,
                teamId: teamId,
                isGoalkeeper: isGK,
                ovrRating: ovr,
                goals: goals,
                assists: assists,
                ownGoals: ownGoals,
                yellowCards: yellows,
                redCards: reds,
                saves: 0,
                goalsConceded: isGK ? goalsConceded : 0,
                penaltiesTaken: taken,
                penaltiesScored: scored,
                rating: computeRating(ovr: ovr, goals: goals, assists: assists, ownGoals: ownGoals, saves: 0, goalsConceded: isGK ? goalsConceded : 0, yellowCards: yellows, redCards: reds, penaltiesTaken: taken, penaltiesScored: scored, isGoalkeeper: isGK, variance: variance)
            )
        }

        let homeConceded = leg.awayScore + leg.etAwayScore
        let awayConceded = leg.homeScore + leg.etHomeScore
        return hNames.map { perf(for: $0, teamId: leg.homeTeam.id, isGK: $0.contains("GK"), goalsConceded: homeConceded) }
            + aNames.map { perf(for: $0, teamId: leg.awayTeam.id, isGK: $0.contains("GK"), goalsConceded: awayConceded) }
    }

    // MARK: - Deterministic pseudo-randomness

    /// Stable 0...1 value derived from a seed, so ratings never flicker between renders.
    static func seededUnit(_ seed: Int) -> Double {
        var x = UInt64(bitPattern: Int64(seed))
        x &+= 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x = x ^ (x >> 31)
        return Double(x & 0xFFFF) / 65535.0
    }

    /// Hashes a player name into a stable integer seed (djb2-style).
    static func stringSeed(_ s: String) -> Int {
        var seed: UInt64 = 5381
        for b in s.utf8 {
            seed = (seed &* 33) ^ UInt64(b)
        }
        return Int(truncatingIfNeeded: seed)
    }

    /// Hashes a UUID's raw bytes into a stable integer seed (FNV-1a).
    static func uuidSeed(_ id: UUID) -> Int {
        var seed: UInt64 = 1469598103934665603
        withUnsafeBytes(of: id.uuid) { raw in
            for byte in raw {
                seed ^= UInt64(byte)
                seed = seed &* 1099511628211
            }
        }
        return Int(truncatingIfNeeded: seed)
    }
}
