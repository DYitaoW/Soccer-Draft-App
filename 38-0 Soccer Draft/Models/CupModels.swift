import Foundation

enum CupCompetitionType: String, Codable {
    case superLeague = "Super League"
}

struct CupTeam: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let offense: Int
    let midfield: Int
    let defense: Int
    let pot: Int

    init(id: UUID = UUID(), name: String, offense: Int, midfield: Int, defense: Int, pot: Int) {
        self.id = id
        self.name = name
        self.offense = offense
        self.midfield = midfield
        self.defense = defense
        self.pot = pot
    }

    var overall: Int { Int((Double(offense + midfield + defense) / 3).rounded()) }
}

struct CupFixture: Identifiable {
    let id: UUID
    let week: Int
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    var homeScore: Int
    var awayScore: Int

    var homeWin: Bool { homeScore > awayScore }
    var awayWin: Bool { awayScore > homeScore }
    var draw: Bool { homeScore == awayScore }
}

struct CupStanding: Hashable {
    let team: CupTeam
    var wins: Int
    var draws: Int
    var losses: Int
    var goalsFor: Int
    var goalsAgainst: Int
    var points: Int { wins * 3 + draws }
    var goalDiff: Int { goalsFor - goalsAgainst }
    var played: Int { wins + draws + losses }
}

struct CupKnockoutMatch: Identifiable {
    let id: UUID
    let round: String
    let teamA: CupTeam
    let teamB: CupTeam
    let leg1Home: CupTeam
    let leg1ScoreA: Int
    let leg1ScoreB: Int
    let leg2ScoreA: Int
    let leg2ScoreB: Int

    var aggregateA: Int { leg1ScoreA + leg2ScoreA }
    var aggregateB: Int { leg1ScoreB + leg2ScoreB }

    var winner: CupTeam? {
        if aggregateA == aggregateB { return nil }
        return aggregateA > aggregateB ? teamA : teamB
    }

    var extraTimeNeeded: Bool { aggregateA == aggregateB }
}

struct CupSeasonResult {
    let competitionType: CupCompetitionType
    let fixtures: [CupFixture]
    let standings: [CupStanding]
    let playerTeamId: UUID
    let knockoutMatches: [CupKnockoutMatch]
    let eliminatedIn: String?
    let isChampion: Bool

    var playerStanding: CupStanding? {
        standings.first { $0.team.id == playerTeamId }
    }

    var playerPosition: Int {
        standings.firstIndex { $0.team.id == playerTeamId }.map { $0 + 1 } ?? 0
    }
}

// MARK: - Minute-by-Minute Match Simulation

struct GoalEvent: Identifiable {
    let id: UUID
    let minute: Int
    let scorer: String
    let teamId: UUID
    let isExtraTime: Bool
    let isPenalty: Bool
    var isOwnGoal: Bool = false
    var isFirstHalf: Bool { minute <= 45 }
}

struct SimulatedKnockoutLeg {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    let homeScore: Int
    let awayScore: Int
    let goals: [GoalEvent]
    var etHomeScore: Int = 0
    var etAwayScore: Int = 0
    var etGoals: [GoalEvent] = []
    var penaltyHome: Int = 0
    var penaltyAway: Int = 0

    var totalHomeScore: Int { homeScore + etHomeScore }
    var totalAwayScore: Int { awayScore + etAwayScore }
    var neededExtraTime: Bool { homeScore == awayScore }
    var neededPenalties: Bool { totalHomeScore == totalAwayScore }

    init(home: CupTeam, away: CupTeam, isFinal: Bool, homePlayerNames: [String]? = nil, awayPlayerNames: [String]? = nil) {
        homeTeam = home
        awayTeam = away

        let homeStr = Double(home.offense) * 0.4 + Double(home.midfield) * 0.3 + Double(home.defense) * 0.3 + 2
        let awayStr = Double(away.offense) * 0.4 + Double(away.midfield) * 0.3 + Double(away.defense) * 0.3
        let homeBonus = home.name == "Your Team" ? 0.4 : 0.0
        let awayBonus = away.name == "Your Team" ? 0.4 : 0.0
        let homeExp = max(0.2, homeStr / 26 - awayStr / 38 + 0.3 + homeBonus)
        let awayExp = max(0.1, awayStr / 30 - homeStr / 46 + 0.2 + awayBonus)

        let rawHome = CupModels.poisson(homeExp)
        let rawAway = CupModels.poisson(awayExp)

        let (homeScorers, awayScorers) = Self.generateScorers(
            home: home, away: away,
            homeScore: rawHome, awayScore: rawAway, isET: false,
            homePlayerNames: homePlayerNames, awayPlayerNames: awayPlayerNames
        )

        homeScore = rawHome
        awayScore = rawAway
        goals = homeScorers + awayScorers

        if isFinal && rawHome == rawAway {
            let etHomeStr = homeStr * 0.6
            let etAwayStr = awayStr * 0.6
            let etHomeBonus = home.name == "Your Team" ? 0.3 : 0.0
            let etAwayBonus = away.name == "Your Team" ? 0.3 : 0.0
            let etHomeExp = max(0.1, etHomeStr / 30 - etAwayStr / 45 + 0.15 + etHomeBonus)
            let etAwayExp = max(0.1, etAwayStr / 30 - etHomeStr / 45 + 0.15 + etAwayBonus)
            let etRawHome = CupModels.poisson(etHomeExp + 0.15)
            let etRawAway = CupModels.poisson(etAwayExp + 0.15)
            let (etHomeS, etAwayS) = Self.generateScorers(
                home: home, away: away,
                homeScore: etRawHome, awayScore: etRawAway, isET: true,
                homePlayerNames: homePlayerNames, awayPlayerNames: awayPlayerNames
            )
            etHomeScore = etRawHome
            etAwayScore = etRawAway
            etGoals = etHomeS + etAwayS
            if totalHomeScore == totalAwayScore {
                penaltyHome = Int.random(in: 2...5)
                penaltyAway = Int.random(in: 2...5)
                while penaltyHome == penaltyAway {
                    (penaltyHome, penaltyAway) = (Int.random(in: 2...5), Int.random(in: 2...5))
                }
            }
        } else if !isFinal && rawHome == rawAway {
            let coinFlip = Bool.random()
            etHomeScore = coinFlip ? 1 : 0
            etAwayScore = coinFlip ? 0 : 1
            let (etHomeS, etAwayS) = Self.generateScorers(
                home: home, away: away,
                homeScore: etHomeScore, awayScore: etAwayScore, isET: true,
                homePlayerNames: homePlayerNames, awayPlayerNames: awayPlayerNames
            )
            etGoals = etHomeS + etAwayS
        }
    }

    private static func generateScorers(home: CupTeam, away: CupTeam, homeScore: Int, awayScore: Int, isET: Bool, homePlayerNames: [String]? = nil, awayPlayerNames: [String]? = nil) -> ([GoalEvent], [GoalEvent]) {
        var homeGoals: [GoalEvent] = []
        var awayGoals: [GoalEvent] = []

        let homePlayers = homePlayerNames ?? Self.squadNames(for: home.name, count: 11)
        let awayPlayers = awayPlayerNames ?? Self.squadNames(for: away.name, count: 11)

        let homeMinutes = Self.distributeMinutes(goals: homeScore, isET: isET)
        let awayMinutes = Self.distributeMinutes(goals: awayScore, isET: isET)

        for min in homeMinutes {
            let scorer = homePlayers.randomElement() ?? home.name
            homeGoals.append(GoalEvent(id: UUID(), minute: min, scorer: scorer, teamId: home.id, isExtraTime: isET, isPenalty: false))
        }
        for min in awayMinutes {
            let scorer = awayPlayers.randomElement() ?? away.name
            awayGoals.append(GoalEvent(id: UUID(), minute: min, scorer: scorer, teamId: away.id, isExtraTime: isET, isPenalty: false))
        }

        return (homeGoals.sorted { $0.minute < $1.minute }, awayGoals.sorted { $0.minute < $1.minute })
    }

    static func distributeMinutes(goals: Int, isET: Bool) -> [Int] {
        guard goals > 0 else { return [] }
        let range = isET ? (91...120) : (1...90)
        var minutes: [Int] = []
        for _ in 0..<goals {
            minutes.append(Int.random(in: range))
        }
        return minutes.sorted()
    }

    static func squadNames(for team: String, count: Int) -> [String] {
        let pool = surnamePool(for: team)
        var names: [String] = []
        for i in 0..<count {
            let first = firstNames[i % firstNames.count]
            let last = pool[i % pool.count]
            names.append("\(first) \(last)")
        }
        return names
    }

    private static let firstNames = ["Marcus", "Lucas", "Gabriel", "Rafael", "Diego", "Carlos", "James", "Daniel", "Thomas", "Alexander", "Luis"]

    private static func surnamePool(for team: String) -> [String] {
        let pools: [String: [String]] = [
            "Spanish": ["Garcia", "Rodriguez", "Martinez", "Lopez", "Gonzalez", "Hernandez", "Perez", "Sanchez", "Ramirez", "Torres", "Flores", "Morales"],
            "Italian": ["Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco", "Bruno", "Gallo"],
            "German": ["Muller", "Schmidt", "Schneider", "Fischer", "Weber", "Wagner", "Becker", "Hoffmann", "Schafer", "Koch", "Bauer", "Richter"],
            "French": ["Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy", "Moreau", "Simon", "Laurent"],
            "English": ["Smith", "Johnson", "Williams", "Brown", "Jones", "Davis", "Wilson", "Taylor", "Clark", "Wright", "Hall", "Young"],
            "Portuguese": ["Silva", "Santos", "Pereira", "Oliveira", "Costa", "Rodrigues", "Martins", "Sousa", "Fernandes", "Goncalves", "Gomes", "Lima"],
            "Dutch": ["de Jong", "van Dijk", "de Vries", "Bakker", "Visser", "Smit", "Meijer", "Dijkstra", "Bos", "Vos", "Mulder", "Groot"],
        ]

        let mapping: [String: String] = [
            "Barcelona": "Spanish", "Real Madrid": "Spanish", "Atlético Madrid": "Spanish",
            "Sevilla": "Spanish", "Villarreal": "Spanish", "Athletico": "Spanish",
            "AC Milan": "Italian", "Inter": "Italian", "Inter Milan": "Italian",
            "Juventus": "Italian", "Napoli": "Italian", "Roma": "Italian", "Atalanta": "Italian",
            "Bayern": "German", "Bayern Munich": "German", "Dortmund": "German",
            "Leverkusen": "German", "Leipzig": "German",
            "PSG": "French", "Marseille": "French", "Lyon": "French",
            "Monaco": "French", "Lille": "French",
            "Porto": "Portuguese", "Benfica": "Portuguese", "Sporting": "Portuguese",
            "Ajax": "Dutch", "Brugge": "Dutch",
        ]

        let lang = mapping[team] ?? "English"
        return pools[lang] ?? pools["English"]!
    }
}

struct CupModels {
    static func determineCompetition(position: Int) -> CupCompetitionType? {
        if position <= 4 { return .superLeague }
        return nil
    }

    static func teams(for competition: CupCompetitionType) -> [CupTeam] {
        superLeagueTeams
    }

    static func simulateCupMatch(home: CupTeam, away: CupTeam) -> (Int, Int) {
        let homeRating = Double(home.offense) * 0.5 + Double(home.midfield) * 0.3 + Double(home.defense) * 0.2
        let awayRating = Double(away.offense) * 0.5 + Double(away.midfield) * 0.3 + Double(away.defense) * 0.2
        let homeBonus = home.name == "Your Team" ? 0.4 : 0.0
        let awayBonus = away.name == "Your Team" ? 0.4 : 0.0
        let homeExp = max(0.3, homeRating / 35.0 + 0.3 + homeBonus)
        let awayExp = max(0.2, awayRating / 40.0 + 0.15 + awayBonus)
        return (poisson(homeExp), poisson(awayExp))
    }

    static func poisson(_ lambda: Double) -> Int {
        let L = exp(-lambda)
        var k = 0, p = 1.0
        repeat { k += 1; p *= Double.random(in: 0...1) } while p > L
        return k - 1
    }

    static var playerTeam: CupTeam {
        CupTeam(name: "Your Team", offense: 85, midfield: 83, defense: 82, pot: 0)
    }

    /// Generates a full 144-match schedule (36 teams, 8 weeks, 18 matches/week).
    /// Each team plays exactly 4 home and 4 away games against 8 unique opponents.
    /// Home/away order is randomized across weeks.
    static func generateFullSchedule(teams: [CupTeam]) -> [CupFixture] {
        let n = teams.count
        guard n > 1 else { return [] }

        // Circle method round-robin: fix last team, rotate the rest
        var circle = teams.shuffled()
        let fixed = circle.removeLast()

        // Generate all 35 rounds of pairings (no home/away yet)
        var allRounds: [[(CupTeam, CupTeam)]] = []
        for _ in 1...(n - 1) {
            var round: [(CupTeam, CupTeam)] = []
            round.append((fixed, circle[0]))
            let mid = circle.count / 2
            for i in 1..<mid {
                round.append((circle[i], circle[circle.count - i]))
            }
            allRounds.append(round)

            let last = circle.removeLast()
            circle.insert(last, at: 0)
        }

        // Pick 8 random rounds from 35
        let selected = allRounds.shuffled().prefix(8)
        let selectedRounds = Array(selected)

        // Track home/away counts to enforce exactly 4 each
        var homeCount: [UUID: Int] = [:]
        var awayCount: [UUID: Int] = [:]
        for team in teams { homeCount[team.id] = 0; awayCount[team.id] = 0 }

        var fixtures: [CupFixture] = []
        for (weekIdx, round) in selectedRounds.enumerated() {
            let week = weekIdx + 1
            for (t1, t2) in round {
                let needHome1 = 4 - homeCount[t1.id]!
                let needAway1 = 4 - awayCount[t1.id]!
                let needHome2 = 4 - homeCount[t2.id]!
                let needAway2 = 4 - awayCount[t2.id]!

                let home: CupTeam
                let away: CupTeam
                if needHome1 > 0 && needAway2 > 0 && needHome1 >= needHome2 {
                    home = t1; away = t2
                } else if needHome2 > 0 && needAway1 > 0 {
                    home = t2; away = t1
                } else if needHome1 > 0 {
                    home = t1; away = t2
                } else if needHome2 > 0 {
                    home = t2; away = t1
                } else {
                    if Bool.random() { home = t1; away = t2 }
                    else { home = t2; away = t1 }
                }

                homeCount[home.id]! += 1
                awayCount[away.id]! += 1

                let (h, a) = simulateCupMatch(home: home, away: away)
                fixtures.append(CupFixture(id: UUID(), week: week, homeTeam: home, awayTeam: away, homeScore: h, awayScore: a))
            }
        }

        return fixtures
    }

    static func computeStandings(from fixtures: [CupFixture], allTeams: [CupTeam]) -> [CupStanding] {
        var dict: [UUID: CupStanding] = [:]
        for team in allTeams {
            dict[team.id] = CupStanding(team: team, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0)
        }
        for f in fixtures {
            guard var h = dict[f.homeTeam.id], var a = dict[f.awayTeam.id] else { continue }
            h.wins += f.homeWin ? 1 : 0
            h.draws += f.draw ? 1 : 0
            h.losses += f.awayWin ? 1 : 0
            h.goalsFor += f.homeScore
            h.goalsAgainst += f.awayScore
            a.wins += f.awayWin ? 1 : 0
            a.draws += f.draw ? 1 : 0
            a.losses += f.homeWin ? 1 : 0
            a.goalsFor += f.awayScore
            a.goalsAgainst += f.homeScore
            dict[f.homeTeam.id] = h
            dict[f.awayTeam.id] = a
        }
        return dict.values.sorted { a, b in
            if a.points != b.points { return a.points > b.points }
            if a.goalDiff != b.goalDiff { return a.goalDiff > b.goalDiff }
            return a.goalsFor > b.goalsFor
        }
    }

    static func cumulativeStandings(from fixtures: [CupFixture], upToWeek: Int, allTeams: [CupTeam]) -> [CupStanding] {
        computeStandings(from: fixtures.filter { $0.week <= upToWeek }, allTeams: allTeams)
    }

    static func playerFixtures(from fixtures: [CupFixture], playerTeamId: UUID) -> [CupFixture] {
        fixtures.filter { $0.homeTeam.id == playerTeamId || $0.awayTeam.id == playerTeamId }
    }

    static func generateKnockoutRound(teams: [CupTeam], round: String, playerTeamId: UUID) -> [CupKnockoutMatch] {
        var matches: [CupKnockoutMatch] = []
        let shuffled = teams.shuffled()
        for i in stride(from: 0, to: shuffled.count, by: 2) {
            guard i + 1 < shuffled.count else { continue }
            matches.append(singleKnockoutMatch(teamA: shuffled[i], teamB: shuffled[i + 1], round: round))
        }
        return matches
    }

    private static func singleKnockoutMatch(teamA: CupTeam, teamB: CupTeam, round: String) -> CupKnockoutMatch {
        let (s1a, s1b) = simulateCupMatch(home: teamA, away: teamB)
        let (s2a, s2b) = simulateCupMatch(home: teamB, away: teamA)
        return CupKnockoutMatch(
            id: UUID(), round: round,
            teamA: teamA, teamB: teamB,
            leg1Home: teamA, leg1ScoreA: s1a, leg1ScoreB: s1b,
            leg2ScoreA: s2a, leg2ScoreB: s2b
        )
    }
}
