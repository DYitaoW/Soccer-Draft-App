/// CupModels.swift
///
/// Cup competition data models and the match-simulation engine used to generate
/// fixtures, standings, knockout legs, and per-goal scorer/assist events.
import Foundation

/// Identifies the cup competitions that can be simulated.
enum CupCompetitionType: String, Codable {
    case superLeague = "Super League"
}

/// A team in cup competition, carrying the ratings the match engine simulates with.
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

    /// The team's overall rating: the rounded mean of its three ratings.
    var overall: Int { Int((Double(offense + midfield + defense) / 3).rounded()) }
}

/// A single cup match between two teams, scheduled for a given week.
struct CupFixture: Identifiable {
    let id: UUID
    let week: Int
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    var homeScore: Int
    var awayScore: Int

    /// True when the home team outscored the away team.
    var homeWin: Bool { homeScore > awayScore }
    /// True when the away team outscored the home team.
    var awayWin: Bool { awayScore > homeScore }
    /// True when both teams scored the same number of goals.
    var draw: Bool { homeScore == awayScore }
}

/// One row in a cup league table, tracking results for a single team.
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

/// A two-legged knockout tie storing both leg scores for aggregation.
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

    /// The team that won on aggregate, or nil if the tie is level.
    var winner: CupTeam? {
        if aggregateA == aggregateB { return nil }
        return aggregateA > aggregateB ? teamA : teamB
    }

    /// True when the tie is level on aggregate and extra time is needed.
    var extraTimeNeeded: Bool { aggregateA == aggregateB }
}

/// The outcome of a full simulated cup season for one competition.
struct CupSeasonResult {
    let competitionType: CupCompetitionType
    let fixtures: [CupFixture]
    let standings: [CupStanding]
    let playerTeamId: UUID
    let knockoutMatches: [CupKnockoutMatch]
    let eliminatedIn: String?
    let isChampion: Bool

    /// The player's team's standing, or nil if the team is not in the table.
    var playerStanding: CupStanding? {
        standings.first { $0.team.id == playerTeamId }
    }

    /// The player's team's final position (1-based), or 0 if not found.
    var playerPosition: Int {
        standings.firstIndex { $0.team.id == playerTeamId }.map { $0 + 1 } ?? 0
    }
}

// MARK: - Minute-by-Minute Match Simulation

/// A single goal scored during a simulated match, including scorer and assist.
struct GoalEvent: Identifiable {
    let id: UUID
    let minute: Int
    let scorer: String
    let teamId: UUID
    let isExtraTime: Bool
    let isPenalty: Bool
    var isOwnGoal: Bool = false
    var assist: String? = nil
    var isFirstHalf: Bool { minute <= 45 }
}

/// A single booking (yellow or red) handed out during a simulated match.
struct CardEvent: Identifiable {
    let id: UUID
    let minute: Int
    let playerName: String
    let teamId: UUID
    let isSecondYellow: Bool
    let isExtraTime: Bool
    var isFirstHalf: Bool { minute <= 45 }
    var isRed: Bool { isSecondYellow }
}

/// A single kick taken during a penalty shootout.
struct PenaltyKick: Identifiable, Equatable {
    let id = UUID()
    let teamIsHome: Bool
    let shooter: String
    let scored: Bool
    let round: Int
}

/// The complete result of one simulated knockout leg: goals, cards, extra time,
/// and any penalty shootout, plus per-player stats derived from its events.
struct SimulatedKnockoutLeg {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    let homeScore: Int
    let awayScore: Int
    let goals: [GoalEvent]
    let cards: [CardEvent]
    var etHomeScore: Int = 0
    var etAwayScore: Int = 0
    var etGoals: [GoalEvent] = []
    var etCards: [CardEvent] = []
    var penaltyHome: Int = 0
    var penaltyAway: Int = 0
    var penaltyKicks: [PenaltyKick] = []
    /// True when this leg actually went to extra time before any penalties.
    var playedExtraTime: Bool = false

    /// Home team's score including any extra-time goals.
    var totalHomeScore: Int { homeScore + etHomeScore }
    /// Away team's score including any extra-time goals.
    var totalAwayScore: Int { awayScore + etAwayScore }
    /// True when the match was level after normal time.
    var neededExtraTime: Bool { homeScore == awayScore }
    /// True when the match was still level after extra time.
    var neededPenalties: Bool { totalHomeScore == totalAwayScore }

    /// Goals scored by each home player, keyed by player name.
    var homePlayerStats: [String: Int] { playerStats(for: homeTeam.id) }
    /// Goals scored by each away player, keyed by player name.
    var awayPlayerStats: [String: Int] { playerStats(for: awayTeam.id) }

    /// Every goal and card merged into one timeline, sorted by minute, with
    /// ready-to-display text describing each event.
    var allEvents: [(minute: Int, isGoal: Bool, teamId: UUID, detail: String)] {
        var result: [(Int, Bool, UUID, String)] = []
        for g in (goals + etGoals).sorted(by: { $0.minute < $1.minute }) {
            let suffix = g.isExtraTime ? " ET" : ""
            let penSuffix = g.isPenalty ? " (P)" : ""
            let ogSuffix = g.isOwnGoal ? " (OG)" : ""
            let assistText = g.assist.map { " (assist: \($0))" } ?? ""
            result.append((g.minute, true, g.teamId, "\(g.minute)' GOAL \(g.scorer)\(penSuffix)\(ogSuffix)\(assistText)\(suffix)"))
        }
        for c in (cards + etCards).sorted(by: { $0.minute < $1.minute }) {
            let suffix = c.isExtraTime ? " ET" : ""
            let type = c.isSecondYellow ? "SECOND YELLOW → RED" : "YELLOW CARD"
            result.append((c.minute, false, c.teamId, "\(c.minute)' \(type) - \(c.playerName)\(suffix)"))
        }
        return result.sorted { $0.0 < $1.0 }.map { (minute: $0.0, isGoal: $0.1, teamId: $0.2, detail: $0.3) }
    }

    /// Creates a leg from already-simulated scores, goals, cards, and penalties.
    init(homeTeam: CupTeam, awayTeam: CupTeam, homeScore: Int, awayScore: Int, goals: [GoalEvent], cards: [CardEvent], etHomeScore: Int = 0, etAwayScore: Int = 0, etGoals: [GoalEvent] = [], etCards: [CardEvent] = [], penaltyHome: Int = 0, penaltyAway: Int = 0, penaltyKicks: [PenaltyKick] = []) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.goals = goals
        self.cards = cards
        self.etHomeScore = etHomeScore
        self.etAwayScore = etAwayScore
        self.etGoals = etGoals
        self.etCards = etCards
        self.penaltyHome = penaltyHome
        self.penaltyAway = penaltyAway
        self.penaltyKicks = penaltyKicks
    }

    /// Simulates a full leg from team ratings. Goals are drawn
    /// from a Poisson distribution, assigned to named players, and cards are
    /// generated. If `allowsExtraTime` and the tie is still level after 90
    /// minutes (accounting for the aggregate from `homeAggLead`), two 15-minute
    /// halves of extra time and a penalty shootout are also simulated.
    /// - Parameters:
    ///   - isFinal: True if the leg is the single-leg final.
    ///   - allowsExtraTime: True if this leg can go to extra time before penalties
    ///     (the final, or the deciding second leg of a two-legged tie).
    ///   - homeAggLead: The home team's aggregate-goal lead entering this leg
    ///     (0 for a single-leg tie or the first leg).
    ///   - homePlayerNames: Starting XI for the home side; defaults to generated names.
    ///   - awayPlayerNames: Starting XI for the away side; defaults to generated names.
    init(home: CupTeam, away: CupTeam, isFinal: Bool, allowsExtraTime: Bool = true, homeAggLead: Int = 0, homePlayerNames: [String]? = nil, awayPlayerNames: [String]? = nil, homeSubstituteNames: Set<String> = [], awaySubstituteNames: Set<String> = []) {
        homeTeam = home
        awayTeam = away

        let baseHomeOff = Double(home.offense) * 0.50 + Double(home.midfield) * 0.30 + Double(home.defense) * 0.20
        let baseHomeDef = Double(home.defense) * 0.50 + Double(home.midfield) * 0.30 + Double(home.offense) * 0.20
        let baseAwayOff = Double(away.offense) * 0.50 + Double(away.midfield) * 0.30 + Double(away.defense) * 0.20
        let baseAwayDef = Double(away.defense) * 0.50 + Double(away.midfield) * 0.30 + Double(away.offense) * 0.20

        let homeOff = baseHomeOff
        let homeDef = baseHomeDef
        let awayOff = baseAwayOff
        let awayDef = baseAwayDef

        let homeVar = 1.0 + (Double.random(in: 0...1) * 2 - 1) * 0.14
        let awayVar = 1.0 + (Double.random(in: 0...1) * 2 - 1) * 0.14
        let playerHomeBonus = home.name == customTeamName() ? 0.24 : 0.0
        let playerAwayBonus = away.name == customTeamName() ? 0.16 : 0.0
        let homeExp = max(0.15, (homeOff / 34 - awayDef / 44 + 0.50 + playerHomeBonus) * homeVar)
        let awayExp = max(0.10, (awayOff / 34 - homeDef / 44 + 0.38 + playerAwayBonus) * awayVar)

        let rawHome = CupModels.poisson(homeExp)
        let rawAway = CupModels.poisson(awayExp)

        let homePlayers = homePlayerNames ?? Self.squadNames(for: home.name, count: 11)
        let awayPlayers = awayPlayerNames ?? Self.squadNames(for: away.name, count: 11)

        let (homeScorers, awayScorers) = Self.generateScorers(
            home: home, away: away,
            homeScore: rawHome, awayScore: rawAway, isET: false,
            homePlayers: homePlayers, awayPlayers: awayPlayers,
            homeSubstitutes: homeSubstituteNames, awaySubstitutes: awaySubstituteNames
        )

        let homeCards = Self.generateCards(teamId: home.id, players: homePlayers, isET: false)
        let awayCards = Self.generateCards(teamId: away.id, players: awayPlayers, isET: false)

        homeScore = rawHome
        awayScore = rawAway
        goals = homeScorers + awayScorers
        cards = homeCards + awayCards

        let levelAfter90 = homeAggLead + rawHome == rawAway
        if allowsExtraTime && levelAfter90 {
            playedExtraTime = true
            let etVar = 1.0 + (Double.random(in: 0...1) * 2 - 1) * 0.14
            let etHomeExp = max(0.08, (homeOff / 38 - awayDef / 48 + 0.22 + playerHomeBonus) * etVar)
            let etAwayExp = max(0.05, (awayOff / 38 - homeDef / 48 + 0.16 + playerAwayBonus) * etVar)
            let etRawHome = CupModels.poisson(etHomeExp + 0.05)
            let etRawAway = CupModels.poisson(etAwayExp + 0.05)
            let (etHomeS, etAwayS) = Self.generateScorers(
                home: home, away: away,
                homeScore: etRawHome, awayScore: etRawAway, isET: true,
                homePlayers: homePlayers, awayPlayers: awayPlayers,
                homeSubstitutes: homeSubstituteNames, awaySubstitutes: awaySubstituteNames
            )
            let etHomeCards = Self.generateCards(teamId: home.id, players: homePlayers, isET: true)
            let etAwayCards = Self.generateCards(teamId: away.id, players: awayPlayers, isET: true)
            etHomeScore = etRawHome
            etAwayScore = etRawAway
            etGoals = etHomeS + etAwayS
            etCards = etHomeCards + etAwayCards
            if totalHomeScore == totalAwayScore {
                let shootout = Self.generatePenaltyShootout(homePlayers: homePlayers, awayPlayers: awayPlayers, homeSubstitutes: homeSubstituteNames, awaySubstitutes: awaySubstituteNames)
                penaltyHome = shootout.home
                penaltyAway = shootout.away
                penaltyKicks = shootout.kicks
            }
        }
    }

    /// Generates a full penalty shootout: 5 rounds, then sudden death.
    /// Shooters come from the starting XI only, ordered attackers → midfielders → defenders → GK,
    /// and cycle around that order (no random shuffling).
    static func generatePenaltyShootout(homePlayers: [String], awayPlayers: [String], homeSubstitutes: Set<String> = [], awaySubstitutes: Set<String> = []) -> (home: Int, away: Int, kicks: [PenaltyKick]) {
        let hShooters = orderedShooters(homePlayers, substitutes: homeSubstitutes, positionFor: Self.position(for:))
        let aShooters = orderedShooters(awayPlayers, substitutes: awaySubstitutes, positionFor: Self.position(for:))
        let hSafe = hShooters.isEmpty ? ["Player 1", "Player 2", "Player 3", "Player 4", "Player 5"] : hShooters
        let aSafe = aShooters.isEmpty ? ["Player 1", "Player 2", "Player 3", "Player 4", "Player 5"] : aShooters
        var kicks: [PenaltyKick] = []
        var pH = 0
        var pA = 0
        var round = 0

        for r in 0..<5 {
            let hScored = Double.random(in: 0...1) < 0.75
            kicks.append(PenaltyKick(teamIsHome: true, shooter: hSafe[r % hSafe.count], scored: hScored, round: r + 1))
            if hScored { pH += 1 }
            let aScored = Double.random(in: 0...1) < 0.75
            kicks.append(PenaltyKick(teamIsHome: false, shooter: aSafe[r % aSafe.count], scored: aScored, round: r + 1))
            if aScored { pA += 1 }
            round = r + 1
        }

        while pH == pA {
            round += 1
            let hScored = Double.random(in: 0...1) < 0.75
            kicks.append(PenaltyKick(teamIsHome: true, shooter: hSafe[round % hSafe.count], scored: hScored, round: round))
            if hScored { pH += 1 }
            let aScored = Double.random(in: 0...1) < 0.75
            kicks.append(PenaltyKick(teamIsHome: false, shooter: aSafe[round % aSafe.count], scored: aScored, round: round))
            if aScored { pA += 1 }
        }

        return (pH, pA, kicks)
    }

    /// Orders penalty shooters: substitutes excluded, sorted attackers → midfielders → defenders → GK.
    /// Unknown positions keep their relative order (treated as midfield).
    static func orderedShooters(_ names: [String], substitutes: Set<String> = [], positionFor: (String) -> Position?) -> [String] {
        let starters = names.filter { !substitutes.contains($0) }
        let indexed = starters.enumerated().map { (index: $0.offset, name: $0.element, rank: shooterRank(positionFor($0.element))) }
        let sorted = indexed.sorted { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            return a.index < b.index
        }
        return sorted.map { $0.name }
    }

    /// Maps a position to penalty-taking priority (lower ranks shoot first).
    private static func shooterRank(_ pos: Position?) -> Int {
        switch pos {
        case .ST, .CF, .LW, .RW: return 0
        case .CAM, .CM, .CDM, .LM, .RM: return 1
        case .LB, .CB, .RB, .LWB, .RWB: return 2
        case .GK: return 3
        case .none: return 1
        }
    }

    /// Looks up the first recorded position for a player by name.
    /// - Parameter name: The player's full name.
    /// - Returns: The player's position, or nil if the player is unknown.
    static func position(for name: String) -> Position? {
        GameData.players.first { $0.name == name }?.positions.first
    }

    /// Tallies goals per player for the given team, excluding own goals.
    private func playerStats(for teamId: UUID) -> [String: Int] {
        var stats: [String: Int] = [:]
        for g in goals + etGoals where g.teamId == teamId && !g.isOwnGoal {
            stats[g.scorer, default: 0] += 1
        }
        return stats
    }

    /// Randomly assigns yellow and red cards to players for a given period.
    /// - Parameter isET: True to generate cards in extra-time minutes (91-120).
    private static func generateCards(teamId: UUID, players: [String], isET: Bool) -> [CardEvent] {
        var result: [CardEvent] = []
        let range = isET ? (91...120) : (1...90)
        let yellowChance = isET ? 0.08 : 0.12
        let redChance = isET ? 0.02 : 0.04
        var hasYellow: [String] = []

        for player in players {
            if Double.random(in: 0...1) < yellowChance {
                let minute = Int.random(in: range)
                if hasYellow.contains(player) && Double.random(in: 0...1) < 0.25 {
                    result.append(CardEvent(id: UUID(), minute: minute, playerName: player, teamId: teamId, isSecondYellow: true, isExtraTime: isET))
                } else {
                    result.append(CardEvent(id: UUID(), minute: minute, playerName: player, teamId: teamId, isSecondYellow: false, isExtraTime: isET))
                    hasYellow.append(player)
                }
            }

            if Double.random(in: 0...1) < redChance && !hasYellow.contains(player) {
                let minute = Int.random(in: range)
                result.append(CardEvent(id: UUID(), minute: minute, playerName: player, teamId: teamId, isSecondYellow: false, isExtraTime: isET))
            }
        }

        return result.sorted { $0.minute < $1.minute }
    }

    /// Distributes a team's goal tally to named players, occasionally assigning
    /// an own goal to the opposing side and an optional assist.
    /// - Returns: The home team's and away team's goal events.
    private static func generateScorers(home: CupTeam, away: CupTeam, homeScore: Int, awayScore: Int, isET: Bool, homePlayers: [String], awayPlayers: [String], homeSubstitutes: Set<String> = [], awaySubstitutes: Set<String> = []) -> ([GoalEvent], [GoalEvent]) {
        var homeGoals: [GoalEvent] = []
        var awayGoals: [GoalEvent] = []

        let homeMinutes = Self.distributeMinutes(goals: homeScore, isET: isET)
        let awayMinutes = Self.distributeMinutes(goals: awayScore, isET: isET)

        let homeOutfield = homePlayers.filter { Self.position(for: $0) != .GK }
        let awayOutfield = awayPlayers.filter { Self.position(for: $0) != .GK }

        for min in homeMinutes {
            var scorer = weightedRandomElement(from: homeOutfield, substitutes: homeSubstitutes, subWeight: 0.05, defaultName: home.name)
            var isOwnGoal = false
            if !awayPlayers.isEmpty && Double.random(in: 0...1) < 0.03 {
                scorer = weightedRandomElement(from: awayOutfield, substitutes: awaySubstitutes, subWeight: 0.05, defaultName: away.name)
                isOwnGoal = true
            }
            let others = homeOutfield.filter { $0 != scorer }
            let assist = Bool.random() && !others.isEmpty ? weightedRandomElement(from: others, substitutes: homeSubstitutes, subWeight: 0.05, defaultName: scorer) : nil
            homeGoals.append(GoalEvent(id: UUID(), minute: min, scorer: scorer, teamId: home.id, isExtraTime: isET, isPenalty: false, isOwnGoal: isOwnGoal, assist: assist))
        }
        for min in awayMinutes {
            var scorer = weightedRandomElement(from: awayOutfield, substitutes: awaySubstitutes, subWeight: 0.05, defaultName: away.name)
            var isOwnGoal = false
            if !homePlayers.isEmpty && Double.random(in: 0...1) < 0.03 {
                scorer = weightedRandomElement(from: homeOutfield, substitutes: homeSubstitutes, subWeight: 0.05, defaultName: home.name)
                isOwnGoal = true
            }
            let others = awayOutfield.filter { $0 != scorer }
            let assist = Bool.random() && !others.isEmpty ? weightedRandomElement(from: others, substitutes: awaySubstitutes, subWeight: 0.05, defaultName: scorer) : nil
            awayGoals.append(GoalEvent(id: UUID(), minute: min, scorer: scorer, teamId: away.id, isExtraTime: isET, isPenalty: false, isOwnGoal: isOwnGoal, assist: assist))
        }

        return (homeGoals.sorted { $0.minute < $1.minute }, awayGoals.sorted { $0.minute < $1.minute })
    }

    /// Picks a player at random, weighted toward starters; substitutes get a
    /// reduced weight. Falls back to `defaultName` when the list is empty.
    static func weightedRandomElement(from players: [String], substitutes: Set<String>, subWeight: Double, defaultName: String) -> String {
        guard !players.isEmpty else { return defaultName }
        var total = 0.0
        for player in players {
            total += substitutes.contains(player) ? subWeight : 1.0
        }
        var r = Double.random(in: 0..<total)
        for player in players {
            r -= substitutes.contains(player) ? subWeight : 1.0
            if r < 0 { return player }
        }
        return players[0]
    }

    /// Spreads goal minutes across a match, biasing toward the end of each half
    /// (or each extra-time period).
    /// - Parameter goals: The number of goal minutes to distribute.
    static func distributeMinutes(goals: Int, isET: Bool) -> [Int] {
        guard goals > 0 else { return [] }
        var minutes: [Int] = []
        for _ in 0..<goals {
            let r = Double.random(in: 0...1)
            if isET {
                // Bias toward the end of each extra-time period (91-105, 106-120)
                let period = Double.random(in: 0...1)
                let base = period < 0.5 ? 91 : 106
                let span = period < 0.5 ? 14 : 14
                let offset = Int(pow(r, 0.7) * Double(span))
                minutes.append(base + min(span - 1, offset))
            } else {
                // Bias toward the end of each half (1-45, 46-90)
                let period = Double.random(in: 0...1)
                let base = period < 0.5 ? 1 : 46
                let offset = Int(pow(r, 0.7) * 44.0)
                minutes.append(base + min(43, offset))
            }
        }
        return minutes.sorted()
    }

    /// Generates `count` player names for a team using its nationality's surname pool.
    /// Assumes `count` is at least 1.
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

    /// Shared pool of first names used when generating squads.
    private static let firstNames = ["Marcus", "Lucas", "Gabriel", "Rafael", "Diego", "Carlos", "James", "Daniel", "Thomas", "Alexander", "Luis"]

    /// Surname pool for the team's nationality; English is the fallback.
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
            "Barcelona": "Spanish", "Real Madrid": "Spanish", "Atletico": "Spanish",
            "Sevilla": "Spanish", "Villarreal": "Spanish", "Villareal": "Spanish",
            "Milan": "Italian", "Inter": "Italian",
            "Juventus": "Italian", "Napoli": "Italian", "Roma": "Italian", "Atalanta": "Italian",
            "Lazio": "Italian", "Bologna": "Italian",
            "Bayern": "German", "Dortmund": "German",
            "Leverkusen": "German", "Leipzig": "German", "Eintracht Frankfurt": "German",
            "PSG": "French", "Marseille": "French", "Lyon": "French",
            "Monaco": "French", "Lille": "French",
            "Porto": "Portuguese", "Benfica": "Portuguese", "Sporting": "Portuguese",
            "Ajax": "Dutch", "Feyenoord": "Dutch", "PSV": "Dutch", "Brugge": "Dutch",
            "Fenerbahce": "Italian", "Galatasaray": "Italian",
        ]

        let lang = mapping[team] ?? "English"
        return pools[lang] ?? pools["English"]!
    }
}

/// Stateless helpers that simulate cup fixtures, schedules, and standings.
struct CupModels {
    /// Maps a final league position to a cup competition, if qualified.
    /// - Parameter position: The team's final league position.
    /// - Returns: The competition, or nil if the team did not qualify.
    static func determineCompetition(position: Int) -> CupCompetitionType? {
        if position <= 5 { return .superLeague }
        return nil
    }

    /// Returns the roster of teams for the given cup competition.
    static func teams(for competition: CupCompetitionType) -> [CupTeam] {
        superLeagueTeams
    }

    /// Simulates a single cup match using the same position-wise matchup model
    /// as the regular season: each side's attack is compared to the opponent's
    /// defense and each midfield to the other's midfield, with the defense/GK
    /// rating shaping goals conceded and scoring variance. The cup weights are
    /// nudged only slightly to play a touch harder and less predictably than the
    /// regular season — a slighter player edge, a smaller home advantage, lower
    /// base rates, and a touch more variance.
    /// - Parameters:
    ///   - home: The home team.
    ///   - away: The away team.
    ///   - homeForm: Form multiplier for the home side; 1.0 is neutral.
    ///   - awayForm: Form multiplier for the away side; 1.0 is neutral.
    ///   - playerBonus: Multiplier on the player team's home/away edge (the league
    ///     phase passes ~1.15 to be friendlier; knockout uses 1.0).
    /// - Returns: A tuple of home and away goals.
    static func simulateCupMatch(home: CupTeam, away: CupTeam, homeForm: Double = 1.0, awayForm: Double = 1.0, playerBonus: Double = 1.0) -> (Int, Int) {
        let isPlayerHome = home.name == customTeamName()
        let isPlayerAway = away.name == customTeamName()

        // Slightly reduced player edge so cup games are marginally harder.
        let homeBonus = isPlayerHome ? 0.12 * playerBonus : 0.0
        let awayBonus = isPlayerAway ? 0.08 * playerBonus : 0.0

        // A touch smaller structural edge for the side playing at home.
        let homeAdvantage = 0.10

        // Position-wise matchups: offense vs the opponent's defense, and
        // midfield vs midfield.
        let homeAttackEdge = Double(home.offense - away.defense)
        let homeMidEdge = Double(home.midfield - away.midfield)
        let awayAttackEdge = Double(away.offense - home.defense)
        let awayMidEdge = Double(away.midfield - home.midfield)

        // Defensive/goalkeeper shaping. A defense below the league's 84 ceiling
        // both concedes more and opens up the match, while a high defense keeps
        // it tight.
        let homeDefFactor = 1.0 + (84.0 - Double(home.defense)) * 0.012
        let awayDefFactor = 1.0 + (84.0 - Double(away.defense)) * 0.012

        // A touch more variance than the regular season for less predictability.
        let homeVar = (1.0 + (Double.random(in: 0...1) * 2 - 1) * 0.13) * awayDefFactor
        let awayVar = (1.0 + (Double.random(in: 0...1) * 2 - 1) * 0.13) * homeDefFactor

        let homeExp = max(0.15, (1.16 + homeAttackEdge * 0.052 + homeMidEdge * 0.028 + homeAdvantage + homeBonus) * homeForm * homeVar)
        let awayExp = max(0.15, (1.04 + awayAttackEdge * 0.052 + awayMidEdge * 0.028 + awayBonus) * awayForm * awayVar)

        return (poisson(homeExp), poisson(awayExp))
    }

    /// Draws an integer from a Poisson distribution with the given mean.
    /// - Parameter lambda: The expected number of goals.
    /// - Returns: The drawn goal count (never negative).
    static func poisson(_ lambda: Double) -> Int {
        let L = exp(-lambda)
        var k = 0, p = 1.0
        repeat { k += 1; p *= Double.random(in: 0...1) } while p > L
        return k - 1
    }

    /// The user's team as a CupTeam, using the saved custom team name and
    /// fixed high ratings.
    static var playerTeam: CupTeam {
        CupTeam(name: customTeamName(), offense: 85, midfield: 83, defense: 82, pot: 0)
    }

    /// Generates a full 144-match schedule (36 teams, 8 weeks, 18 matches/week).
    /// Each team plays exactly 4 home and 4 away games against 8 unique opponents.
    /// Home/away order is randomized across weeks.
    /// - Parameter playerBonus: Bonus multiplier for the player team's matches,
    ///   used to make the league phase friendlier.
    static func generateFullSchedule(teams: [CupTeam], playerBonus: Double = 1.0) -> [CupFixture] {
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
            for i in 1...mid {
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
        var seasonForm: [UUID: Double] = [:]
        for team in teams { seasonForm[team.id] = 1.0 + (Double.random(in: 0...1) * 2 - 1) * 0.15 }
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

                let (h, a) = simulateCupMatch(
                    home: home, away: away,
                    homeForm: seasonForm[home.id] ?? 1.0,
                    awayForm: seasonForm[away.id] ?? 1.0,
                    playerBonus: playerBonus
                )
                fixtures.append(CupFixture(id: UUID(), week: week, homeTeam: home, awayTeam: away, homeScore: h, awayScore: a))
            }
        }

        return fixtures
    }

    /// Builds a league table from fixtures, sorted by points, then goal
    /// difference, then goals scored.
    /// - Returns: Standings ordered best team first.
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

    /// Standings computed only from fixtures played up to the given week.
    static func cumulativeStandings(from fixtures: [CupFixture], upToWeek: Int, allTeams: [CupTeam]) -> [CupStanding] {
        computeStandings(from: fixtures.filter { $0.week <= upToWeek }, allTeams: allTeams)
    }

    /// Returns only the fixtures involving the player's team.
    static func playerFixtures(from fixtures: [CupFixture], playerTeamId: UUID) -> [CupFixture] {
        fixtures.filter { $0.homeTeam.id == playerTeamId || $0.awayTeam.id == playerTeamId }
    }

    /// Randomly pairs teams into two-legged ties for a knockout round.
    /// Assumes an even number of teams.
    /// - Parameter round: The round name, e.g. "Quarter-finals".
    static func generateKnockoutRound(teams: [CupTeam], round: String, playerTeamId: UUID) -> [CupKnockoutMatch] {
        var matches: [CupKnockoutMatch] = []
        let shuffled = teams.shuffled()
        for i in stride(from: 0, to: shuffled.count, by: 2) {
            guard i + 1 < shuffled.count else { continue }
            matches.append(singleKnockoutMatch(teamA: shuffled[i], teamB: shuffled[i + 1], round: round))
        }
        return matches
    }

    /// Simulates both legs of a tie, swapping home advantage between them.
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

// MARK: - Custom Team Name

/// Returns the user's saved custom team name, sanitized, or "Your Team".
func customTeamName() -> String {
    UserDefaults.standard.string(forKey: "teamName")
        .map { sanitizeTeamName($0) }
        ?? "Your Team"
}

/// Cleans a raw team name: trims whitespace, caps length at 30 characters,
/// and strips disallowed characters. Falls back to "Your Team" when empty.
/// - Parameter raw: The unsanitized input.
/// - Returns: A safe display name.
func sanitizeTeamName(_ raw: String) -> String {
    let allowed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        .prefix(30)
        .filter { $0.isLetter || $0.isNumber || $0.isWhitespace || $0 == "-" || $0 == "'" || $0 == "." || $0 == "!" }
    let result = String(allowed).trimmingCharacters(in: .whitespacesAndNewlines)
    return result.isEmpty ? "Your Team" : result
}
