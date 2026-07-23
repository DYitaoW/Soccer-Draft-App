import Foundation

struct PlaceholderTeam: Identifiable, Hashable {
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
    let homeTeam: PlaceholderTeam
    let awayTeam: PlaceholderTeam
    let homeScore: Int
    let awayScore: Int

    init(week: Int, homeTeam: PlaceholderTeam, awayTeam: PlaceholderTeam, homeScore: Int, awayScore: Int) {
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
    let team: PlaceholderTeam
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
        playerTeam: PlaceholderTeam,
        opponents: [PlaceholderTeam],
        projectedPosition: Int
    ) -> SeasonSimulationResult {
        let allTeams = [playerTeam] + opponents.shuffled()
        var standings: [UUID: LeagueStanding] = [:]
        for team in allTeams {
            standings[team.id] = LeagueStanding(
                team: team, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0
            )
        }

        var matches: [SimulatedMatch] = []
        var week = 0

        for i in allTeams.indices {
            for j in allTeams.indices where i != j {
                week += 1
                let home = allTeams[i]
                let away = allTeams[j]
                let (hScore, aScore) = simulateMatch(home: home, away: away)

                matches.append(SimulatedMatch(
                    week: week, homeTeam: home, awayTeam: away,
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

    private static func simulateMatch(home: PlaceholderTeam, away: PlaceholderTeam) -> (Int, Int) {
        let homeStr = Double(home.offense) * 0.4 + Double(home.midfield) * 0.3 + Double(home.defense) * 0.3 + 3
        let awayStr = Double(away.offense) * 0.4 + Double(away.midfield) * 0.3 + Double(away.defense) * 0.3

        let homeExp = max(0.2, homeStr / 20 - awayStr / 32 + 0.4)
        let awayExp = max(0.1, awayStr / 22 - homeStr / 38 + 0.3)

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

let placeholderTeams: [PlaceholderTeam] = [
    PlaceholderTeam(name: "Dragons FC", offense: 88, midfield: 85, defense: 82),
    PlaceholderTeam(name: "Phoenix United", offense: 92, midfield: 89, defense: 87),
    PlaceholderTeam(name: "Iron Wolves", offense: 78, midfield: 82, defense: 90),
    PlaceholderTeam(name: "Storm Athletic", offense: 74, midfield: 76, defense: 72),
    PlaceholderTeam(name: "Royal Lions", offense: 86, midfield: 84, defense: 79),
    PlaceholderTeam(name: "Titan FC", offense: 82, midfield: 79, defense: 85),
    PlaceholderTeam(name: "Eagle City", offense: 70, midfield: 73, defense: 68),
    PlaceholderTeam(name: "Viper FC", offense: 90, midfield: 88, defense: 84),
    PlaceholderTeam(name: "Crystal Palace", offense: 76, midfield: 72, defense: 78),
    PlaceholderTeam(name: "Thunder FC", offense: 84, midfield: 86, defense: 81),
    PlaceholderTeam(name: "Atlas United", offense: 68, midfield: 70, defense: 75),
    PlaceholderTeam(name: "Stellar FC", offense: 80, midfield: 81, defense: 77),
    PlaceholderTeam(name: "Fury Athletic", offense: 72, midfield: 68, defense: 66),
    PlaceholderTeam(name: "Golden Eagles", offense: 86, midfield: 83, defense: 88),
    PlaceholderTeam(name: "Shadow FC", offense: 77, midfield: 80, defense: 83),
    PlaceholderTeam(name: "Nova SC", offense: 66, midfield: 65, defense: 70),
    PlaceholderTeam(name: "Apex United", offense: 85, midfield: 87, defense: 76),
    PlaceholderTeam(name: "Valor FC", offense: 82, midfield: 77, defense: 80),
    PlaceholderTeam(name: "Crimson Tide", offense: 79, midfield: 75, defense: 73),
]
