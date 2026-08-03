/// MatchRatingsLive.swift
///
/// INACTIVE — reserved for a future app that re-enables the advanced (live)
/// match engine. Builds per-player match performances from a `LiveKnockoutMatch`.
///
/// This file is excluded from the Draft-It app target; it is preserved for
/// reuse alongside `LiveKnockoutMatch.swift` if the live engine is revived.
import Foundation

extension MatchRatings {
    /// Produces performances for every player who featured in a live match,
    /// deriving stats from its events and penalty kicks. Saves are estimated
    /// as the opponent's shots on target minus goals conceded.
    /// - Parameter match: The finished live match to evaluate.
    /// - Returns: A performance record per participating player.
    static func fromLive(_ match: LiveKnockoutMatch) -> [PlayerMatchPerformance] {
        let homeGK = match.homePlayers.first { $0.name.contains("GK") }
        let awayGK = match.awayPlayers.first { $0.name.contains("GK") }
        let homeSaves = max(0, match.awayShotsOnTarget - (match.awayScore + match.etAwayScore))
        let awaySaves = max(0, match.homeShotsOnTarget - (match.homeScore + match.etHomeScore))
        let homeConceded = match.awayScore + match.etAwayScore
        let awayConceded = match.homeScore + match.etHomeScore

        var goalsDict: [String: Int] = [:]
        var ownGoalsDict: [String: Int] = [:]
        var assistDict: [String: Int] = [:]
        var yellowDict: [String: Int] = [:]
        var redDict: [String: Int] = [:]
        for ev in match.events {
            switch ev {
            case .goal(let g):
                if g.isOwnGoal { ownGoalsDict[g.scorer, default: 0] += 1 }
                else { goalsDict[g.scorer, default: 0] += 1 }
                if let a = g.assist { assistDict[a, default: 0] += 1 }
            case .card(let c):
                if c.isSecondYellow { redDict[c.playerName, default: 0] += 1 }
                else { yellowDict[c.playerName, default: 0] += 1 }
            default: break
            }
        }
        var penTaken: [String: Int] = [:]
        var penScored: [String: Int] = [:]
        for k in match.penaltyKicks {
            penTaken[k.shooter, default: 0] += 1
            if k.scored { penScored[k.shooter, default: 0] += 1 }
        }

        let teamSeed = uuidSeed(match.homeTeam.id) ^ uuidSeed(match.awayTeam.id)

        func perf(for player: LiveMatchPlayer, teamId: UUID) -> PlayerMatchPerformance? {
            let played = player.isOnPitch || player.isSubbedOff || goalsDict[player.name] != nil
                || player.yellowCard || player.redCard || penTaken[player.name] != nil
            guard played else { return nil }
            let isGK = player.name == homeGK?.name || player.name == awayGK?.name
            let saves = player.name == homeGK?.name ? homeSaves : player.name == awayGK?.name ? awaySaves : 0
            let conceded = player.name == homeGK?.name ? homeConceded : player.name == awayGK?.name ? awayConceded : 0
            let goals = player.goals
            let assists = assistDict[player.name] ?? 0
            let ownGoals = ownGoalsDict[player.name] ?? 0
            let yellows = yellowDict[player.name] ?? 0
            let reds = redDict[player.name] ?? 0
            let taken = penTaken[player.name] ?? 0
            let scored = penScored[player.name] ?? 0
            let seed = stringSeed(player.name) ^ uuidSeed(player.id) ^ teamSeed
            let variance = (seededUnit(seed) - 0.5) * 0.8
            return PlayerMatchPerformance(
                name: player.name,
                teamId: teamId,
                isGoalkeeper: isGK,
                ovrRating: player.rating,
                goals: goals,
                assists: assists,
                ownGoals: ownGoals,
                yellowCards: yellows,
                redCards: reds,
                saves: saves,
                goalsConceded: conceded,
                penaltiesTaken: taken,
                penaltiesScored: scored,
                rating: computeRating(ovr: player.rating, goals: goals, assists: assists, ownGoals: ownGoals, saves: saves, goalsConceded: conceded, yellowCards: yellows, redCards: reds, penaltiesTaken: taken, penaltiesScored: scored, isGoalkeeper: isGK, variance: variance)
            )
        }

        var result: [PlayerMatchPerformance] = []
        for p in match.homePlayers {
            if let perf = perf(for: p, teamId: match.homeTeam.id) { result.append(perf) }
        }
        for p in match.awayPlayers {
            if let perf = perf(for: p, teamId: match.awayTeam.id) { result.append(perf) }
        }
        return result
    }
}
