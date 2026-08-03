/// SeasonSimulator.swift
///
/// Full-league season simulation: builds a round-robin schedule, plays every
/// fixture with a rating-based Poisson model, and computes final standings.
import Foundation

/// A single played match in a simulated season.
struct SimulatedMatch: Identifiable, Codable {
    let id: UUID
    let week: Int
    let homeTeam: Team
    let awayTeam: Team
    let homeScore: Int
    let awayScore: Int

    init(week: Int, homeTeam: Team, awayTeam: Team, homeScore: Int, awayScore: Int) {
        self.id = UUID()
        self.week = week
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
    }

    /// True when the home team won.
    var homeWin: Bool { homeScore > awayScore }
    /// True when the away team won.
    var awayWin: Bool { awayScore > homeScore }
    /// True when the match was a draw.
    var draw: Bool { homeScore == awayScore }
}

/// One row in a league table for a simulated season.
struct LeagueStanding: Hashable, Codable {
    let team: Team
    var wins: Int
    var draws: Int
    var losses: Int
    var goalsFor: Int
    var goalsAgainst: Int
    var points: Int { wins * 3 + draws }
    var goalDiff: Int { goalsFor - goalsAgainst }
    var played: Int { wins + draws + losses }
}

/// The outcome of a simulated season: every match, the final standings, and
/// the player team's place in them.
struct SeasonSimulationResult {
    let matches: [SimulatedMatch]
    /// Standings sorted best-first (points, goal difference, goals scored).
    let standings: [LeagueStanding]
    let playerTeamId: UUID
    let projectedPosition: Int

    /// The player team's standing, or nil if the team is not in the table.
    var playerStanding: LeagueStanding? {
        standings.first { $0.team.id == playerTeamId }
    }

    /// The player team's final position (1-based), or 0 if not found.
    var playerPosition: Int {
        standings.firstIndex { $0.team.id == playerTeamId }.map { $0 + 1 } ?? 0
    }
}

/// Stateless engine that simulates a full league season.
struct SeasonSimulator {
    /// Simulates a complete season: rolls per-team form, generates a double
    /// round-robin schedule, plays every fixture, and sorts the final table.
    /// - Parameters:
    ///   - playerTeam: The user's team, included in the league.
    ///   - opponents: The other teams in the league.
    ///   - projectedPosition: A caller-provided predicted position, echoed back.
    ///   - difficulty: Dynasty ramp 0...1; raises the bar each title won so later
    ///     seasons are progressively harder.
    /// - Returns: Matches, standings, and the player team's placement.
    static func simulateSeason(
        playerTeam: Team,
        opponents: [Team],
        projectedPosition: Int,
        difficulty: Double = 0
    ) -> SeasonSimulationResult {
        let allTeams = [playerTeam] + opponents
        var standings: [UUID: LeagueStanding] = [:]
        for team in allTeams {
            standings[team.id] = LeagueStanding(
                team: team, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0
            )
        }

        var seasonForm: [UUID: Double] = [:]
        for team in allTeams {
            let roll = Double.random(in: 0...1)
            if roll < 0.001 {
                // Juggernaut season (~0.1% odds): the team is nearly impossible
                // to beat, with the edge growing for elite (90+) squads.
                let ratingBoost = Double(max(team.overall, 77)) - 77.0
                seasonForm[team.id] = 1.30 + ratingBoost * 0.015
            } else if roll < 0.002 {
                // Winless season (~0.1% odds): the team is hopeless, barely able
                // to score or win any match.
                seasonForm[team.id] = 0.35
            } else {
                seasonForm[team.id] = 1.0 + (Double.random(in: 0...1) * 2 - 1) * 0.10
            }
        }

        let schedule = generateRoundRobinSchedule(teams: allTeams)
        var matches: [SimulatedMatch] = []

        for (week, fixtures) in schedule.enumerated() {
            for (homeIdx, awayIdx) in fixtures {
                let home = allTeams[homeIdx]
                let away = allTeams[awayIdx]
                let (hScore, aScore) = simulateMatch(
                    home: home, away: away,
                    homeForm: seasonForm[home.id] ?? 1.0,
                    awayForm: seasonForm[away.id] ?? 1.0,
                    difficulty: difficulty
                )

                matches.append(SimulatedMatch(
                    week: week + 1, homeTeam: home, awayTeam: away,
                    homeScore: hScore, awayScore: aScore
                ))

                standings[home.id]!.wins += hScore > aScore ? 1 : 0
                standings[home.id]!.draws += hScore == aScore ? 1 : 0
                standings[home.id]!.losses += hScore < aScore ? 1 : 0
                standings[home.id]!.goalsFor += hScore
                standings[home.id]!.goalsAgainst += aScore

                standings[away.id]!.wins += aScore > hScore ? 1 : 0
                standings[away.id]!.draws += aScore == hScore ? 1 : 0
                standings[away.id]!.losses += aScore < hScore ? 1 : 0
                standings[away.id]!.goalsFor += aScore
                standings[away.id]!.goalsAgainst += hScore
            }
        }

        let sorted = standings.values.sorted { a, b in
            if a.points != b.points { return a.points > b.points }
            if a.goalDiff != b.goalDiff { return a.goalDiff > b.goalDiff }
            return a.goalsFor > b.goalsFor
        }

        return SeasonSimulationResult(
            matches: matches,
            standings: sorted,
            playerTeamId: playerTeam.id,
            projectedPosition: projectedPosition
        )
    }

    /// Builds a double round-robin schedule from team indices. With an odd
    /// count, a dummy team is added and skipped so every real team plays each
    /// other twice (home and away). Returns rounds of `(home, away)` indices.
    private static func generateRoundRobinSchedule(teams: [Team]) -> [[(Int, Int)]] {
        let n = teams.count
        guard n > 1 else { return [] }
        let isOdd = n % 2 == 1
        let m = isOdd ? n + 1 : n
        var rounds: [[(Int, Int)]] = []

        var rotating = Array(0..<(m - 1))
        let fixed = m - 1

        for round in 0..<(m - 1) {
            var fixtures: [(Int, Int)] = []
            fixtures.append((rotating[0], fixed))
            for i in 1..<(m / 2) {
                let t1 = rotating[i]
                let t2 = rotating[m - 1 - i]
                if isOdd, (t1 >= n || t2 >= n) { continue }
                fixtures.append((t1, t2))
            }
            var cleanFixtures: [(Int, Int)] = []
            for (h, a) in fixtures {
                if h >= n || a >= n { continue }
                if round % 2 == 0 {
                    cleanFixtures.append((h, a))
                } else {
                    cleanFixtures.append((a, h))
                }
            }
            if !cleanFixtures.isEmpty {
                rounds.append(cleanFixtures)
            }
            rotating = [rotating.last!] + rotating.dropLast()
        }

        let firstHalf = rounds
        for fixtures in firstHalf {
            var reversed: [(Int, Int)] = []
            for (h, a) in fixtures {
                reversed.append((a, h))
            }
            rounds.append(reversed)
        }

        return rounds
    }

    /// Simulates one league match using position-wise matchups.
    ///
    /// Rather than comparing a single overall number, each team's attack is
    /// matched against the opponent's defense and each midfield against the
    /// other's midfield. A team's defensive rating (which for the user blends
    /// the defender and goalkeeper averages) shapes both how many goals it
    /// concedes and how much scoring variance it allows: a goalie/defense rated
    /// well below the league suppress goals and quells swings, while a weak one
    /// leaks more and more randomly. There is no hard "must be X overall to win"
    /// rule; results fall out of the matchups, so similar squads finish close and
    /// stronger squads beat weaker ones. The `difficulty` ramp erodes the
    /// player's modest home/away edge on long dynasty runs.
    /// - Returns: A tuple of home and away goals.
    private static func simulateMatch(home: Team, away: Team, homeForm: Double, awayForm: Double, difficulty: Double = 0) -> (Int, Int) {
        let isPlayerHome = home.name == customTeamName()
        let isPlayerAway = away.name == customTeamName()
        let ramp = max(0, min(1, difficulty))
        let homeBonus = isPlayerHome ? 0.15 * (1 - ramp) : 0.0
        let awayBonus = isPlayerAway ? 0.10 * (1 - ramp) : 0.0

        // Slight structural edge for the side playing at home.
        let homeAdvantage = 0.12

        // Position-wise matchups: offense vs the opponent's defense, and
        // midfield vs midfield.
        let homeAttackEdge = Double(home.offense - away.defense)
        let homeMidEdge = Double(home.midfield - away.midfield)
        let awayAttackEdge = Double(away.offense - home.defense)
        let awayMidEdge = Double(away.midfield - home.midfield)

        // Defensive/goalkeeper shaping. A defense below the league's 84 ceiling
        // both concedes more and opens up the match (wider swings), while a high
        // defense keeps things tight.
        let homeDefFactor = 1.0 + (84.0 - Double(home.defense)) * 0.012
        let awayDefFactor = 1.0 + (84.0 - Double(away.defense)) * 0.012

        // Scoring variance: shaped by the defense the shooter faces.
        let homeVar = (1.0 + (Double.random(in: 0...1) * 2 - 1) * 0.10) * awayDefFactor
        let awayVar = (1.0 + (Double.random(in: 0...1) * 2 - 1) * 0.10) * homeDefFactor

        let homeExp = max(0.15, (1.18 + homeAttackEdge * 0.055 + homeMidEdge * 0.030 + homeAdvantage + homeBonus) * homeForm * homeVar)
        let awayExp = max(0.15, (1.06 + awayAttackEdge * 0.055 + awayMidEdge * 0.030 + awayBonus) * awayForm * awayVar)

        return (poisson(homeExp), poisson(awayExp))
    }

    /// Draws an integer from a Poisson distribution with the given mean.
    /// - Parameter lambda: The expected number of goals.
    /// - Returns: The drawn goal count (never negative).
    private static func poisson(_ lambda: Double) -> Int {
        let L = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= Double.random(in: 0...1)
        } while p > L
        return k - 1
    }
}
