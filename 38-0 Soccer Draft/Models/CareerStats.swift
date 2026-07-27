import Foundation

struct SeasonRecord: Codable, Equatable {
    var wins: Int
    var draws: Int
    var losses: Int

    var winPct: Double {
        let total = wins + draws + losses
        guard total > 0 else { return 0 }
        return Double(wins) / Double(total)
    }

    var display: String { "\(wins)-\(draws)-\(losses)" }
}

enum SuperLeagueRound: String, Codable, Comparable {
    case league = "League"
    case firstRound = "First Round"
    case roundOf16 = "RO16"
    case quarterFinal = "QF"
    case semiFinal = "SF"
    case final = "Final"
    case winner = "Winner"

    static func < (lhs: SuperLeagueRound, rhs: SuperLeagueRound) -> Bool {
        let order: [SuperLeagueRound] = [.league, .firstRound, .roundOf16, .quarterFinal, .semiFinal, .final, .winner]
        guard let li = order.firstIndex(of: lhs), let ri = order.firstIndex(of: rhs) else { return false }
        return li < ri
    }

    static func from(eliminatedIn: String?, isChampion: Bool, leaguePosition: Int) -> SuperLeagueRound {
        if isChampion { return .winner }
        guard let round = eliminatedIn else { return .league }
        switch round {
        case "Knockout Playoffs": return .firstRound
        case "Round of 16": return .roundOf16
        case "Quarter-finals": return .quarterFinal
        case "Semi-finals": return .semiFinal
        case "Final": return .final
        default:
            if round.hasPrefix("Group Stage") { return .league }
            return .league
        }
    }
}

struct CareerStats: Codable {
    var totalSeasons: Int = 0
    var mode38Seasons: Int = 0
    var mostPoints: Int = 0
    var bestRecord: SeasonRecord? = nil
    var bestWinPct: Double = 0
    var mostGoalsFor: Int = 0
    var leastGoalsAgainst: Int = Int.max
    var highestOverall: Int = 0
    var titles: Int = 0
    var perfectSeasons: Int = 0

    // Super League stats
    var superLeagueSeasons: Int = 0
    var mostSuperLeaguePoints: Int = 0
    var bestSuperLeagueResult: Int = Int.max
    var mostSuperLeagueGoalsFor: Int = 0
    var leastSuperLeagueGoalsAgainst: Int = Int.max
    var mostSuperLeagueWins: Int = 0

    // New Super League tracking
    var bestSuperLeagueRound: SuperLeagueRound = .league
    var superLeagueFinalsAppearances: Int = 0
    var superLeagueCupsWon: Int = 0

    enum CodingKeys: String, CodingKey {
        case totalSeasons, mode38Seasons, mostPoints, bestRecord, bestWinPct
        case mostGoalsFor, leastGoalsAgainst, highestOverall, titles, perfectSeasons
        case superLeagueSeasons, mostSuperLeaguePoints, bestSuperLeagueResult
        case mostSuperLeagueGoalsFor, leastSuperLeagueGoalsAgainst, mostSuperLeagueWins
        case bestSuperLeagueRound, superLeagueFinalsAppearances, superLeagueCupsWon
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalSeasons = try c.decodeIfPresent(Int.self, forKey: .totalSeasons) ?? 0
        mode38Seasons = try c.decodeIfPresent(Int.self, forKey: .mode38Seasons) ?? 0
        mostPoints = try c.decodeIfPresent(Int.self, forKey: .mostPoints) ?? 0
        bestRecord = try c.decodeIfPresent(SeasonRecord.self, forKey: .bestRecord)
        bestWinPct = try c.decodeIfPresent(Double.self, forKey: .bestWinPct) ?? 0
        mostGoalsFor = try c.decodeIfPresent(Int.self, forKey: .mostGoalsFor) ?? 0
        leastGoalsAgainst = try c.decodeIfPresent(Int.self, forKey: .leastGoalsAgainst) ?? Int.max
        highestOverall = try c.decodeIfPresent(Int.self, forKey: .highestOverall) ?? 0
        titles = try c.decodeIfPresent(Int.self, forKey: .titles) ?? 0
        perfectSeasons = try c.decodeIfPresent(Int.self, forKey: .perfectSeasons) ?? 0
        superLeagueSeasons = try c.decodeIfPresent(Int.self, forKey: .superLeagueSeasons) ?? 0
        mostSuperLeaguePoints = try c.decodeIfPresent(Int.self, forKey: .mostSuperLeaguePoints) ?? 0
        bestSuperLeagueResult = try c.decodeIfPresent(Int.self, forKey: .bestSuperLeagueResult) ?? Int.max
        mostSuperLeagueGoalsFor = try c.decodeIfPresent(Int.self, forKey: .mostSuperLeagueGoalsFor) ?? 0
        leastSuperLeagueGoalsAgainst = try c.decodeIfPresent(Int.self, forKey: .leastSuperLeagueGoalsAgainst) ?? Int.max
        mostSuperLeagueWins = try c.decodeIfPresent(Int.self, forKey: .mostSuperLeagueWins) ?? 0
        bestSuperLeagueRound = try c.decodeIfPresent(SuperLeagueRound.self, forKey: .bestSuperLeagueRound) ?? .league
        superLeagueFinalsAppearances = try c.decodeIfPresent(Int.self, forKey: .superLeagueFinalsAppearances) ?? 0
        superLeagueCupsWon = try c.decodeIfPresent(Int.self, forKey: .superLeagueCupsWon) ?? 0
    }

    var displayGoalsAgainst: String {
        leastGoalsAgainst == Int.max ? "-" : "\(leastGoalsAgainst)"
    }

    var displaySuperLeagueResult: String {
        bestSuperLeagueRound.rawValue
    }

    var displaySuperLeagueGA: String {
        leastSuperLeagueGoalsAgainst == Int.max ? "-" : "\(leastSuperLeagueGoalsAgainst)"
    }

    mutating func recordSeason(mode38: Bool, record: SeasonRecord, points: Int, goalsFor: Int, goalsAgainst: Int, position: Int, overall: Int) {
        totalSeasons += 1
        if mode38 { mode38Seasons += 1 }
        if points > mostPoints { mostPoints = points }
        if let best = bestRecord {
            if record.wins > best.wins { bestRecord = record }
        } else {
            bestRecord = record
        }
        let wp = record.winPct
        if wp > bestWinPct { bestWinPct = wp }
        if goalsFor > mostGoalsFor { mostGoalsFor = goalsFor }
        if goalsAgainst < leastGoalsAgainst { leastGoalsAgainst = goalsAgainst }
        if overall > highestOverall { highestOverall = overall }
        if position == 1 {
            titles += 1
            if record.losses == 0 { perfectSeasons += 1 }
        }
        save()
    }

    mutating func recordSuperLeagueSeason(wins: Int, points: Int, goalsFor: Int, goalsAgainst: Int, round: SuperLeagueRound) {
        superLeagueSeasons += 1
        if points > mostSuperLeaguePoints { mostSuperLeaguePoints = points }
        if goalsFor > mostSuperLeagueGoalsFor { mostSuperLeagueGoalsFor = goalsFor }
        if goalsAgainst < leastSuperLeagueGoalsAgainst { leastSuperLeagueGoalsAgainst = goalsAgainst }
        if wins > mostSuperLeagueWins { mostSuperLeagueWins = wins }
        if round > bestSuperLeagueRound { bestSuperLeagueRound = round }
        if round == .final || round == .winner { superLeagueFinalsAppearances += 1 }
        if round == .winner { superLeagueCupsWon += 1 }
        save()
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        if (11...13).contains(n % 100) { suffix = "th" } else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    static func load() -> CareerStats {
        guard let data = UserDefaults.standard.data(forKey: "careerStats"),
              let stats = try? JSONDecoder().decode(CareerStats.self, from: data) else {
            return CareerStats()
        }
        return stats
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: "careerStats")
        DraftHistory.clearAll()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "careerStats")
    }
}
