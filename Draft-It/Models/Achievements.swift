/// Achievements.swift
///
/// The achievement system: catalog, persistence, and season-end evaluation.
/// Achievements persist unlocked ids in UserDefaults (mirroring `CareerStats`)
/// and are evaluated against the completed season's context.
import Foundation

/// Rarity tier used for coloring achievement tiles.
enum AchievementTier: String, Codable {
    case bronze, silver, gold
}

/// A single achievement: identifier, display text, SF Symbol icon, tier, and a
/// hidden flag. Hidden achievements show as "???" until unlocked.
struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let tier: AchievementTier
    let isHidden: Bool

    init(id: String, title: String, detail: String, icon: String, tier: AchievementTier, isHidden: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.icon = icon
        self.tier = tier
        self.isHidden = isHidden
    }
}

/// All season-outcome data the achievement evaluator needs. Assembled by the
/// call sites (GameView for a regular season, CupFlowView for a cup campaign)
/// and passed to `AchievementStore.evaluateSeason`.
struct SeasonAchievementContext {
    /// The squad's base overall rating (no manager bonus), matching the OVR
    /// shown in the draft UI.
    var teamOverall: Int = 0
    var bestDraftedPlayerRating: Int = 0
    var managerRating: Int = 0
    var leaguePosition: Int = 0
    var leagueRecord: SeasonRecord? = nil
    var leagueGoalsFor: Int = 0
    var leagueGoalsAgainst: Int = 0
    /// League-wide standings aggregates used for scoring-defensive extremes.
    var leagueTeamCount: Int = 0
    var leagueMaxGoalsFor: Int = 0
    var leagueMinGoalsFor: Int = 0
    var leagueMaxGoalsAgainst: Int = 0
    var leagueMinGoalsAgainst: Int = 0
    var leagueTopScorerGoals: Int = 0
    var leagueTopAssists: Int = 0
    var superLeagueRound: SuperLeagueRound? = nil
    var superLeagueChampion: Bool = false
    var backToBackChampion: Bool = false
    /// The full drafted squad (starters + substitutes) for squad-based checks.
    var draftedPlayers: [Player] = []
    /// The leagues of the starting lineup players (for the all-legends check).
    var starterLeagues: [String] = []
}

/// Static catalog plus a UserDefaults-backed store of unlocked achievement ids.
/// `evaluateSeason` unlocks any newly-satisfied achievements and returns them
/// so the caller can present an unlock popup.
enum AchievementStore {
    /// The full catalog, ordered from easiest to hardest: bronze -> silver ->
    /// gold -> hidden. `legendOfTheGame` (the final meta achievement) is last
    /// and rendered full-width at the top of the grid by the view.
    static let all: [Achievement] = [
        // Bronze: achievable on a normal first run.
        Achievement(id: "seasonOne", title: "First Season", detail: "Complete your first full season.", icon: "calendar", tier: .bronze),
        Achievement(id: "topOfTable", title: "League Finish", detail: "Finish in the top 5 of the league.", icon: "medal.fill", tier: .bronze),
        Achievement(id: "reachedCup", title: "Continental Stage", detail: "Qualify for the Super League.", icon: "globe", tier: .bronze),
        Achievement(id: "loseEveryGame", title: "Rock Bottom", detail: "Lose every league game in a season.", icon: "arrow.down.circle.fill", tier: .bronze),
        Achievement(id: "relegated", title: "Relegated", detail: "Finish in the relegation zone.", icon: "arrow.down.to.line", tier: .bronze),
        Achievement(id: "leakyDefense", title: "Leaky Defense", detail: "Concede the most goals in the league in a season.", icon: "drop.fill", tier: .bronze),
        Achievement(id: "poorFinishing", title: "Poor Finishing", detail: "Score the fewest goals in the league in a season.", icon: "xmark.circle.fill", tier: .bronze),
        // Silver: harder season performances and early career milestones.
        Achievement(id: "firstTitle", title: "Champions", detail: "Win the league title.", icon: "trophy.fill", tier: .silver),
        Achievement(id: "goldenBoot", title: "Golden Boot", detail: "A player scores 20+ league goals.", icon: "soccerball", tier: .silver),
        Achievement(id: "hundredGoals", title: "Century Club", detail: "Score 100+ league goals in a season.", icon: "number.circle.fill", tier: .silver),
        Achievement(id: "assistKing", title: "Assist King", detail: "A player records 15+ league assists.", icon: "shoe.fill", tier: .silver),
        Achievement(id: "topScorers", title: "Top Scorers", detail: "Score the most goals in the league in a season.", icon: "flame.fill", tier: .silver),
        Achievement(id: "parkTheBus", title: "Park the Bus", detail: "Concede the fewest goals in the league in a season.", icon: "shield.lefthalf.filled", tier: .silver),
        Achievement(id: "clubIcon", title: "Club Icon", detail: "Draft 5 players from a single club.", icon: "building.columns.fill", tier: .silver),
        Achievement(id: "seasons10", title: "Veteran", detail: "Complete 10 seasons.", icon: "calendar.badge.clock", tier: .silver),
        Achievement(id: "titles5", title: "Five-Time Winners", detail: "Win 5 league titles.", icon: "trophy", tier: .silver),
        Achievement(id: "superLeague3", title: "Continental Force", detail: "Win 3 Super Leagues.", icon: "globe.americas.fill", tier: .silver),
        // Gold: standout individual feats and long career milestones.
        Achievement(id: "goalMachine", title: "Goal Machine", detail: "A player scores 30+ league goals.", icon: "soccerball.fill", tier: .gold),
        Achievement(id: "starCatcher", title: "Star Catcher", detail: "Draft a player rated 95+.", icon: "star.fill", tier: .gold),
        Achievement(id: "eliteManager", title: "Elite Manager", detail: "Draft a manager rated 92+.", icon: "person.fill", tier: .gold),
        Achievement(id: "centurians", title: "Centurians", detail: "Earn 100 points in a single league season.", icon: "100.circle.fill", tier: .gold),
        Achievement(id: "perfect38", title: "38-0", detail: "Win every regular season game.", icon: "checkmark.seal.fill", tier: .gold),
        Achievement(id: "seasons50", title: "Loyal Legend", detail: "Complete 50 seasons.", icon: "calendar.badge.checkmark", tier: .gold),
        Achievement(id: "titles10", title: "Dynasty", detail: "Win 10 league titles.", icon: "trophy.fill", tier: .gold),
        Achievement(id: "superLeague5", title: "European Elite", detail: "Win 5 Super Leagues.", icon: "globe.europe.africa.fill", tier: .gold),
        Achievement(id: "seasons100", title: "Century", detail: "Complete 100 seasons.", icon: "calendar.circle.fill", tier: .gold),
        Achievement(id: "titles25", title: "Royalty", detail: "Win 25 league titles.", icon: "crown.fill", tier: .gold),
        Achievement(id: "superLeague10", title: "European Legends", detail: "Win 10 Super Leagues.", icon: "globe.europe.africa.fill", tier: .gold),
        Achievement(id: "superLeagueWinner", title: "Continental Glory", detail: "Win the Super League.", icon: "globe.europe.africa.fill", tier: .gold),
        // Hidden: much harder or more specific milestones.
        Achievement(id: "amateurs", title: "Amateurs", detail: "Draft a team rated 78 or lower.", icon: "person.3.fill", tier: .gold),
        Achievement(id: "timoTime", title: "Timo Time", detail: "Draft Timo Werner.", icon: "stopwatch.fill", tier: .gold, isHidden: true),
        Achievement(id: "fiveStar", title: "Five-Star Team", detail: "Build a squad rated 90+ overall.", icon: "star.circle.fill", tier: .gold, isHidden: true),
        Achievement(id: "unbeaten", title: "Invincibles", detail: "Win the league without a single defeat.", icon: "shield.fill", tier: .gold, isHidden: true),
        Achievement(id: "backToBack", title: "Back-to-Back", detail: "Win the league in consecutive seasons.", icon: "repeat", tier: .gold, isHidden: true),
        Achievement(id: "threepeat", title: "3 Peat", detail: "Win the league three seasons in a row.", icon: "3.circle.fill", tier: .gold, isHidden: true),
        Achievement(id: "how", title: "How?", detail: "Draw 25+ league games in a single season.", icon: "exclamationmark.triangle.fill", tier: .gold, isHidden: true),
        Achievement(id: "quadTargets", title: "Win the Double", detail: "Win the league and the Super League in the same season.", icon: "4.circle.fill", tier: .gold, isHidden: true),
        Achievement(id: "legendary", title: "Legendary", detail: "Field a starting lineup of Past Legends.", icon: "crown.circle.fill", tier: .gold, isHidden: true),
        Achievement(id: "who", title: "Who?", detail: "Draft Sebastian Berhalter.", icon: "questionmark.circle.fill", tier: .gold, isHidden: true),
        Achievement(id: "chelseaChant", title: "Chelsea! Chelsea! Chelsea!", detail: "Draft 5 Chelsea players in a single draft.", icon: "building.columns.circle.fill", tier: .gold, isHidden: true),
        // Final meta achievement: unlock every other achievement.
        Achievement(id: "legendOfTheGame", title: "Legend of the Game", detail: "Unlock every other achievement.", icon: "medal.fill", tier: .gold)
    ]

    /// The club/league marker used by non-standard player pools.
    private static let excludedDraftLeagues: Set<String> = ["Past Legends", "Upgraded Players", "Global Superstars", "Cult Heros", "Future Superstars", "Womens Stars", "Random Bums"]

    private static let storeKey = "unlockedAchievements"

    /// The set of unlocked achievement ids.
    static func unlockedIds() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    /// Whether a specific achievement has been unlocked.
    static func isUnlocked(_ id: String) -> Bool {
        unlockedIds().contains(id)
    }

    /// Persists an unlocked achievement id.
    /// - Parameter id: The achievement's id.
    static func unlock(_ id: String) {
        var ids = unlockedIds()
        ids.insert(id)
        guard let data = try? JSONEncoder().encode(Array(ids)) else { return }
        UserDefaults.standard.set(data, forKey: storeKey)
    }

    /// Unlocks any newly-satisfied achievements for a completed season and
    /// returns the newly unlocked ones.
    /// - Parameter context: The assembled season outcome.
    /// - Returns: Achievements unlocked by this evaluation.
    static func evaluateSeason(_ context: SeasonAchievementContext) -> [Achievement] {
        let previously = unlockedIds()
        var newly: [Achievement] = []

        func grant(_ achievement: Achievement, _ satisfied: Bool) {
            guard satisfied, !previously.contains(achievement.id) else { return }
            unlock(achievement.id)
            newly.append(achievement)
        }

        let career = CareerStats.load()
        let record = context.leagueRecord
        let points = (record?.wins ?? 0) * 3 + (record?.draws ?? 0)

        for achievement in all {
            switch achievement.id {
            case "firstTitle":
                grant(achievement, context.leaguePosition == 1)
            case "seasonOne":
                grant(achievement, context.leaguePosition > 0)
            case "goldenBoot":
                grant(achievement, context.leagueTopScorerGoals >= 20)
            case "goalMachine":
                grant(achievement, context.leagueTopScorerGoals >= 30)
            case "assistKing":
                grant(achievement, context.leagueTopAssists >= 15)
            case "topOfTable":
                grant(achievement, context.leaguePosition >= 1 && context.leaguePosition <= 5)
            case "reachedCup":
                grant(achievement, context.superLeagueRound != nil)
            case "hundredGoals":
                grant(achievement, context.leagueGoalsFor >= 100)
            case "starCatcher":
                grant(achievement, context.bestDraftedPlayerRating >= 95)
            case "eliteManager":
                grant(achievement, context.managerRating >= 92)
            case "topScorers":
                grant(achievement, context.leagueTeamCount > 0 && context.leagueGoalsFor == context.leagueMaxGoalsFor && context.leagueMaxGoalsFor > 0)
            case "parkTheBus":
                grant(achievement, context.leagueTeamCount > 0 && context.leagueGoalsAgainst == context.leagueMinGoalsAgainst)
            case "centurians":
                grant(achievement, points >= 100)
            case "perfect38":
                grant(achievement, (record?.wins ?? 0) > 0 && (record?.draws ?? 0) == 0 && (record?.losses ?? 0) == 0)
            case "clubIcon":
                grant(achievement, maxClubCount(context.draftedPlayers) >= 5)
            case "seasons10":
                grant(achievement, career.totalSeasons >= 10)
            case "seasons50":
                grant(achievement, career.totalSeasons >= 50)
            case "seasons100":
                grant(achievement, career.totalSeasons >= 100)
            case "titles5":
                grant(achievement, career.titles >= 5)
            case "titles10":
                grant(achievement, career.titles >= 10)
            case "titles25":
                grant(achievement, career.titles >= 25)
            case "superLeague3":
                grant(achievement, career.superLeagueCupsWon >= 3)
            case "superLeague5":
                grant(achievement, career.superLeagueCupsWon >= 5)
            case "superLeague10":
                grant(achievement, career.superLeagueCupsWon >= 10)
            case "loseEveryGame":
                grant(achievement, (record?.wins ?? 0) == 0 && (record?.draws ?? 0) == 0 && (record?.losses ?? 0) > 0)
            case "relegated":
                grant(achievement, context.leagueTeamCount > 0 && context.leaguePosition >= context.leagueTeamCount - 2)
            case "leakyDefense":
                grant(achievement, context.leagueTeamCount > 0 && context.leagueGoalsAgainst == context.leagueMaxGoalsAgainst && context.leagueMaxGoalsAgainst > 0)
            case "poorFinishing":
                grant(achievement, context.leagueTeamCount > 0 && context.leagueGoalsFor == context.leagueMinGoalsFor)
            case "fiveStar":
                grant(achievement, context.teamOverall >= 90)
            case "unbeaten":
                grant(achievement, context.leaguePosition == 1 && (record?.losses ?? 0) == 0)
            case "superLeagueWinner":
                grant(achievement, context.superLeagueChampion)
            case "backToBack":
                grant(achievement, context.backToBackChampion)
            case "threepeat":
                grant(achievement, threePeatChampion(position: context.leaguePosition))
            case "how":
                grant(achievement, (record?.draws ?? 0) >= 25)
            case "quadTargets":
                grant(achievement, context.leaguePosition == 1 && context.superLeagueChampion)
            case "amateurs":
                grant(achievement, context.teamOverall <= 78)
            case "timoTime":
                grant(achievement, context.draftedPlayers.contains { $0.name == "Timo Werner" })
            case "who":
                grant(achievement, context.draftedPlayers.contains { $0.name == "Sebastian Berhalter" })
            case "chelseaChant":
                grant(achievement, context.draftedPlayers.filter { $0.team == "Chelsea" }.count >= 5)
            case "legendary":
                grant(achievement, !context.starterLeagues.isEmpty && context.starterLeagues.allSatisfy { $0 == "Past Legends" })
            case "legendOfTheGame":
                break
            default:
                break
            }
        }

        // The meta achievement unlocks once every other achievement is earned.
        let meta = all.first { $0.id == "legendOfTheGame" }
        if let meta = meta {
            let others = all.filter { $0.id != "legendOfTheGame" }
            if others.allSatisfy({ unlockedIds().contains($0.id) }) {
                grant(meta, true)
            }
        }

        return newly
    }

    /// The largest number of drafted players sharing one club, counting only
    /// standard-league players (excluding Past Legends, Upgraded Players, and
    /// Global Superstars pools).
    /// - Parameter players: The drafted squad (starters + substitutes).
    /// - Returns: The maximum players from any single club, or 0.
    static func maxClubCount(_ players: [Player]) -> Int {
        var counts: [String: Int] = [:]
        for player in players where !excludedDraftLeagues.contains(player.league) {
            counts[player.team, default: 0] += 1
        }
        return counts.values.max() ?? 0
    }

    /// Erases all unlocked achievements from UserDefaults.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: storeKey)
    }

    /// Whether the current season (position 1) plus the immediately previous
    /// saved season (also position 1) form back-to-back titles.
    /// - Parameter position: The current season's final league position.
    /// - Returns: True when consecutive seasons were both title wins.
    static func backToBackChampion(position: Int) -> Bool {
        guard position == 1 else { return false }
        let history = DraftHistory.loadAll()
        return history.count > 1 && history[1].position == 1
    }

    /// Whether the current season (position 1) plus the two immediately previous
    /// saved seasons (also position 1) form three consecutive titles.
    /// - Parameter position: The current season's final league position.
    /// - Returns: True when three consecutive seasons were all title wins.
    static func threePeatChampion(position: Int) -> Bool {
        guard position == 1 else { return false }
        let history = DraftHistory.loadAll()
        return history.count > 2 && history[1].position == 1 && history[2].position == 1
    }
}
