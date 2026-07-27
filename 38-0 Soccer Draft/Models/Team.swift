import Foundation

struct Team: Identifiable, Hashable {
    let id: UUID
    let name: String
    let offense: Int
    let midfield: Int
    let defense: Int

    init(id: UUID = UUID(), name: String, offense: Int, midfield: Int, defense: Int) {
        self.id = id
        self.name = name
        self.offense = offense
        self.midfield = midfield
        self.defense = defense
    }

    var overall: Int { Int((Double(offense + midfield + defense) / 3).rounded()) }
}

struct SimulatedMatch: Identifiable {
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

    var homeWin: Bool { homeScore > awayScore }
    var awayWin: Bool { awayScore > homeScore }
    var draw: Bool { homeScore == awayScore }
}

struct LeagueStanding: Hashable {
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

struct SeasonSimulationResult {
    let matches: [SimulatedMatch]
    let standings: [LeagueStanding]
    let playerTeamId: UUID
    let projectedPosition: Int

    var playerStanding: LeagueStanding? {
        standings.first { $0.team.id == playerTeamId }
    }

    var playerPosition: Int {
        standings.firstIndex { $0.team.id == playerTeamId }.map { $0 + 1 } ?? 0
    }
}

struct SeasonSimulator {
    static func simulateSeason(
        playerTeam: Team,
        opponents: [Team],
        projectedPosition: Int
    ) -> SeasonSimulationResult {
        let allTeams = [playerTeam] + opponents
        var standings: [UUID: LeagueStanding] = [:]
        for team in allTeams {
            standings[team.id] = LeagueStanding(
                team: team, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0
            )
        }

        let schedule = generateRoundRobinSchedule(teams: allTeams)
        var matches: [SimulatedMatch] = []

        for (week, fixtures) in schedule.enumerated() {
            for (homeIdx, awayIdx) in fixtures {
                let home = allTeams[homeIdx]
                let away = allTeams[awayIdx]
                let (hScore, aScore) = simulateMatch(home: home, away: away)

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

    private static func generateRoundRobinSchedule(teams: [Team]) -> [[(Int, Int)]] {
        let n = teams.count
        guard n > 1 else { return [] }
        let isOdd = n % 2 == 1
        let m = isOdd ? n + 1 : n
        var rounds: [[(Int, Int)]] = []

        // First half of season
        for round in 0..<(m - 1) {
            var fixtures: [(Int, Int)] = []
            for i in 0..<(m / 2) {
                let home = (round + i) % (m - 1)
                let away = (m - 1 - i + round) % (m - 1)
                if isOdd, (home == m - 1 || away == m - 1) { continue }
                let homeIdx = home < n ? home : -1
                let awayIdx = away < n ? away : -1
                if homeIdx >= 0, awayIdx >= 0 {
                    if round % 2 == 0 {
                        fixtures.append((homeIdx, awayIdx))
                    } else {
                        fixtures.append((awayIdx, homeIdx))
                    }
                }
            }
            if !fixtures.isEmpty {
                rounds.append(fixtures)
            }
        }

        // Second half of season (reverse fixtures)
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

    private static func simulateMatch(home: Team, away: Team) -> (Int, Int) {
        let homeStr = Double(home.offense) * 0.4 + Double(home.midfield) * 0.3 + Double(home.defense) * 0.3 + 2
        let awayStr = Double(away.offense) * 0.4 + Double(away.midfield) * 0.3 + Double(away.defense) * 0.3

        let homeBonus = home.name == "Your Team" ? 0.4 : 0.0
        let awayBonus = away.name == "Your Team" ? 0.4 : 0.0

        let homeExp = max(0.2, homeStr / 26 - awayStr / 38 + 0.3 + homeBonus)
        let awayExp = max(0.1, awayStr / 30 - homeStr / 46 + 0.2 + awayBonus)

        return (poisson(homeExp), poisson(awayExp))
    }

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
