/// GameState.swift
///
/// Defines the central `GameState` model that tracks a draft session (squad,
/// formation, manager, filters, and ratings) plus `SavedGame`, the codable
/// snapshot used to persist and restore a session to disk.
import Combine
import Foundation

/// The difficulty level of a draft, which controls the number of rerolls
/// available (Easy: 3, Normal: 1, 38-0: 1, Hard: 0).
enum GameMode: String, CaseIterable, Codable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case extreme = "Extreme"
    case mode38 = "38-0"
    case positionsFirst = "Positions First"
    case transferBudget = "Transfer Budget"
    case onePerClub = "One Per Club"
    case noPremierLeague = "No Premier League"

    /// The label shown in the UI. "Normal" is presented as "Medium" so the
    /// difficulty row reads Easy / Medium / Hard.
    var displayName: String {
        self == .normal ? "Medium" : rawValue
    }

    /// Whether the mode is a special draft variant (team roll / position pick)
    /// rather than a plain difficulty selection.
    var isSpecialMode: Bool {
        self == .mode38 || self == .positionsFirst || self == .transferBudget || self == .onePerClub || self == .noPremierLeague
    }

    /// Short description for the game mode selector.
    var description: String {
        switch self {
        case .easy: return "5 rerolls"
        case .normal: return "3 rerolls"
        case .hard: return "1 reroll"
        case .extreme: return "No rerolls"
        case .mode38: return "Play just like the viral game"
        case .positionsFirst: return "Pick a position first"
        case .transferBudget: return "Draft within a transfer budget"
        case .onePerClub: return "Max 1 player per club"
        case .noPremierLeague: return "Draft from the world, not the PL"
        }
    }

    /// Full description shown on the home screen button.
    var fullDescription: String {
        switch self {
        case .easy: return "5 rerolls, opponents weakened"
        case .normal: return "3 rerolls, standard difficulty"
        case .hard: return "1 reroll, opponents boosted"
        case .extreme: return "No rerolls, opponents heavily boosted"
        case .mode38: return "Draft all 20 PL teams in one go"
        case .positionsFirst: return "Pick positions before players"
        case .transferBudget: return "Draft within a transfer budget"
        case .onePerClub: return "38-0 with a 1 player per club cap"
        case .noPremierLeague: return "3 rerolls, Premier League blocked"
        }
    }

    /// Number of rerolls for this mode.
    var rerolls: Int {
        switch self {
        case .easy: return 5
        case .normal: return 3
        case .hard: return 1
        case .extreme: return 0
        case .mode38, .positionsFirst, .onePerClub: return 1
        case .transferBudget: return 2
        case .noPremierLeague: return 3
        }
    }

    /// OVR boost applied to AI opponents (positive = harder).
    var opponentBoost: Int {
        switch self {
        case .easy: return -4
        case .normal: return 0
        case .hard: return 2
        case .extreme: return 5
        case .mode38, .positionsFirst, .transferBudget, .onePerClub, .noPremierLeague: return 0
        }
    }

    /// OVR boost applied to the player's team (positive = easier).
    var playerBoost: Int {
        0
    }
}

/// Broad position buckets used when computing category ratings and the
/// player team's offense/midfield/defense breakdown.
enum PositionCategory {
    case gk, defense, midfield, attack
}

/// The observable model for one draft session. Holds the selected formation,
/// assigned starters and substitutes, manager, season odds, team filters, and
/// derived rating values. Created by `ContentView` and injected into the view
/// hierarchy as an environment object.
class GameState: ObservableObject {
    @Published var selectedFormation: Formation
    @Published var assignedPlayers: [Int: Player] = [:]
    @Published var substitutes: [Player?] = Array(repeating: nil, count: 5)
    @Published var selectedManager: Manager?
    @Published var seasonOdds: SeasonOdds?
    @Published var gameMode: GameMode
    @Published var selectedTeam: String? = nil
    @Published var teamPlayers: [Player] = []
    @Published var usedTeams: Set<String> = []
    @Published var showRatings: Bool = true
    @Published var totalRerollsRemaining: Int = 0
    @Published var showPremierLeague: Bool = true
    @Published var showOtherLeagues: Bool = true
    @Published var showGlobalSuperstars: Bool = true
    @Published var showPastLegends: Bool = true
    @Published var showUpgradedPlayers: Bool = true
    @Published var showCultHeros: Bool = true
    @Published var showFutureSuperstars: Bool = true
    @Published var showWomensStars: Bool = true
    @Published var showRandomBums: Bool = true
    @Published var managerRevealed: Bool = false
    @Published var gamePhase: String = "drafting"
    @Published var cupCompetitionTypeRaw: String? = nil
    @Published var transferBudget: Int = 0
    @Published var transferBudgetRemaining: Int = 0

    /// How many formation slots are still unfilled.
    var remainingSlots: Int {
        selectedFormation.slots.count - assignedPlayers.count
    }

    /// Whether the squad is fully drafted. Only the starting lineup slots need
    /// to be filled; substitutes are optional in every mode.
    var isComplete: Bool {
        assignedPlayers.count == selectedFormation.slots.count
    }

    /// Whether the current session is the 38-0 game mode.
    var isMode38: Bool { gameMode == .mode38 }

    /// Whether the current session is the "Positions First" game mode.
    var isPositionsFirst: Bool { gameMode == .positionsFirst }

    /// Whether the current session is the "Transfer Budget" game mode.
    var isTransferBudget: Bool { gameMode == .transferBudget }

    /// Whether the mode uses the roll-a-team draft (38-0, Positions First, One Per Club).
    var usesTeamDraft: Bool { isMode38 || isPositionsFirst || gameMode == .onePerClub }

    /// Whether the mode has a substitute bench. Team-draft modes have no bench.
    var hasBench: Bool { !usesTeamDraft }

    /// The union of all player IDs currently assigned as starters or subs.
    var usedPlayerIds: Set<UUID> {
        let starterIds = Set(assignedPlayers.values.map(\.id))
        let subIds = Set(substitutes.compactMap { $0?.id })
        return starterIds.union(subIds)
    }

    /// The names of all players currently assigned as starters or subs. Used to
    /// prevent a squad from containing both the regular and upgraded versions
    /// of the same player.
    var usedPlayerNames: Set<String> {
        Set(assignedPlayers.values.map(\.name)).union(substitutes.compactMap { $0?.name })
    }

    var maxRerolls: Int { totalRerollsRemaining }

    /// Consumes one reroll. Does nothing if no rerolls remain.
    func useReroll() {
        guard totalRerollsRemaining > 0 else { return }
        totalRerollsRemaining -= 1
    }

    /// Calculates a player's transfer value based on overall rating and position.
    /// Returns value in millions (e.g. 25 means $25M).
    /// Pricing is non-linear: 87+ has big jumps, 80-86 is linear, 79- drops fast.
    func transferValue(for player: Player) -> Int {
        let ovr = player.ovrRating
        let primary = player.positions.first ?? .ST

        // Position multiplier
        let posMul: Double
        switch primary {
        case .ST, .CF: posMul = 1.4
        case .LW, .RW, .LM, .RM: posMul = 1.2
        case .CAM: posMul = 1.2
        case .CM: posMul = 1.0
        case .CDM: posMul = 1.1
        case .CB: posMul = ovr >= 90 ? 0.95 : ovr >= 87 ? 0.92 : ovr >= 85 ? 0.88 : 0.8
        case .LB, .RB, .LWB, .RWB: posMul = 0.65
        case .GK: posMul = 0.65
        }

        // Non-linear OVR curve: big jumps at 87+, linear 80-86, fast drop below 79
        let ovrBase: Double
        switch ovr {
        case 99: ovrBase = 200
        case 98: ovrBase = 180
        case 97: ovrBase = 160
        case 96: ovrBase = 140
        case 95: ovrBase = 120
        case 94: ovrBase = 105
        case 93: ovrBase = 92
        case 92: ovrBase = 82
        case 91: ovrBase = 78
        case 90: ovrBase = 74
        case 89: ovrBase = 75
        case 88: ovrBase = 70
        case 87: ovrBase = 68
        // Linear band 80-86 (~$6-7M per point)
        case 86: ovrBase = 65
        case 85: ovrBase = 58
        case 84: ovrBase = 50
        case 83: ovrBase = 42
        case 82: ovrBase = 35
        case 81: ovrBase = 28
        case 80: ovrBase = 22
        // Fast drop below 80
        case 79: ovrBase = 17
        case 78: ovrBase = 13
        case 77: ovrBase = 9
        case 76: ovrBase = 6
        case 75: ovrBase = 3.5
        default: ovrBase = max(1, Double(ovr - 68) * 0.5)
        }

        return max(1, Int(ovrBase * posMul))
    }

    /// Whether the player can be afforded with the remaining budget.
    func canAfford(_ player: Player) -> Bool {
        guard gameMode == .transferBudget else { return true }
        return transferValue(for: player) <= transferBudgetRemaining
    }

    /// Deducts a player's transfer value from the remaining budget.
    func spendBudget(for player: Player) {
        guard gameMode == .transferBudget else { return }
        transferBudgetRemaining -= transferValue(for: player)
    }

    /// Total unfilled starting slots.
    var totalRemaining: Int {
        selectedFormation.slots.count - assignedPlayers.count
    }

    /// Creates a game state for a draft session. Reroll count is derived from
    /// the game mode.
    init(formation: Formation, mode: GameMode = .normal, showRatings: Bool = true, showPremierLeague: Bool = true, showOtherLeagues: Bool = true, showGlobalSuperstars: Bool = true, showPastLegends: Bool = true, showUpgradedPlayers: Bool = true, showCultHeros: Bool = true, showFutureSuperstars: Bool = true, showWomensStars: Bool = true, showRandomBums: Bool = true, managerRevealed: Bool = false, gamePhase: String = "drafting", cupCompetitionTypeRaw: String? = nil, transferBudgetAmount: Int = 100) {
        self.selectedFormation = formation
        self.gameMode = mode
        self.showRatings = showRatings
        self.showPremierLeague = showPremierLeague
        self.showOtherLeagues = showOtherLeagues
        self.showGlobalSuperstars = showGlobalSuperstars
        self.showPastLegends = showPastLegends
        self.showUpgradedPlayers = showUpgradedPlayers
        self.showCultHeros = showCultHeros
        self.showFutureSuperstars = showFutureSuperstars
        self.showWomensStars = showWomensStars
        self.showRandomBums = showRandomBums
        self.managerRevealed = managerRevealed
        self.gamePhase = gamePhase
        self.cupCompetitionTypeRaw = cupCompetitionTypeRaw
        self.totalRerollsRemaining = mode.rerolls
        if mode == .transferBudget {
            self.transferBudget = transferBudgetAmount
            self.transferBudgetRemaining = transferBudgetAmount
        }
    }

    /// Assigns a player to the given formation slot index and saves progress.
    /// - Parameter player: The player to place.
    /// - Parameter index: The slot index into `selectedFormation.slots`.
    func assignPlayer(_ player: Player, toSlot index: Int) {
        assignedPlayers[index] = player
        SavedGame.save(self)
    }

    /// Places a player on the substitute bench at the given index and saves.
    /// No-op if `index` is out of the bench's range.
    /// - Parameter player: The player to add to the bench.
    /// - Parameter index: The bench position, 0-4.
    func addSubstitute(_ player: Player, at index: Int) {
        guard index < substitutes.count else { return }
        substitutes[index] = player
        SavedGame.save(self)
    }

    /// Swaps a starter and a substitute. No-op if either slot is empty.
    /// - Parameter starterIndex: The formation slot to swap out.
    /// - Parameter subIndex: The bench slot to swap in.
    func swapStarter(_ starterIndex: Int, withSub subIndex: Int) {
        guard let subPlayer = substitutes[subIndex] else { return }
        guard let starterPlayer = assignedPlayers[starterIndex] else { return }
        assignedPlayers[starterIndex] = subPlayer
        substitutes[subIndex] = starterPlayer
    }

    /// Reorders the bench by swapping two substitute slots.
    /// - Parameter fromIndex: The bench slot to move.
    /// - Parameter toIndex: The bench slot to swap with.
    func swapSub(_ fromIndex: Int, withSub toIndex: Int) {
        let temp = substitutes[fromIndex]
        substitutes[fromIndex] = substitutes[toIndex]
        substitutes[toIndex] = temp
    }

    /// Reorders the starting lineup by swapping two formation slots.
    /// - Parameter from: The slot to move.
    /// - Parameter to: The slot to swap with.
    func swapStarterWithStarter(_ from: Int, to: Int) {
        let temp = assignedPlayers[from]
        assignedPlayers[from] = assignedPlayers[to]
        assignedPlayers[to] = temp
    }

    /// Moves a starter from one slot to another empty slot. No-op if the target
    /// slot is occupied or the source slot is empty.
    /// - Parameter from: The slot to move from.
    /// - Parameter to: The empty slot to move to.
    func movePlayer(from: Int, to: Int) {
        guard let player = assignedPlayers[from], assignedPlayers[to] == nil else { return }
        assignedPlayers[to] = player
        assignedPlayers[from] = nil
    }

    /// Picks a manager at random from the given list.
    /// - Parameter managers: The candidate managers to choose from.
    func randomizeManager(in managers: [Manager]) {
        selectedManager = managers.randomElement()
    }

    /// Runs a season simulation. Requires a full starting lineup; otherwise it does
    /// nothing. Stores the result in `seasonOdds`. A missing manager does not block
    /// the prediction: `managerBonus` is 0 with no manager, so the odds are simply
    /// computed without one. Dynasty seasons raise the difficulty each title won.
    func simulateSeason() {
        let players = assignedPlayers.values.map { $0 }
        guard players.count == selectedFormation.slots.count else { return }
        let dynastyCount = UserDefaults.standard.integer(forKey: "dynastySeasonCount")
        let difficulty = min(3.0, Double(dynastyCount) * 0.25)
        let dynastyBoost = min(6, dynastyCount)
        seasonOdds = SeasonOdds.calculate(playerTeam: adjustedPlayerTeam, opponents: leagueTeams, difficulty: difficulty, gameMode: gameMode, dynastyBoost: dynastyBoost)
    }

    /// Picks a random club as the user's team and loads its players, then saves.
    func randomizeTeam() {
        let teams = GameData.allTeams
        selectedTeam = teams.randomElement()
        teamPlayers = GameData.players.filter { $0.team == selectedTeam }
        SavedGame.save(self)
    }

    // MARK: - Team Ratings

    /// Maps a position to its broad `PositionCategory`.
    /// - Parameter position: The position to classify.
    /// - Returns: The matching category, or `.gk`/`.defense`/`.midfield`/`.attack`.
    private func category(for position: Position) -> PositionCategory {
        switch position {
        case .GK: return .gk
        case .LB, .CB, .RB, .LWB, .RWB: return .defense
        case .CDM, .CM, .CAM, .LM, .RM: return .midfield
        case .LW, .RW, .CF, .ST: return .attack
        }
    }

    /// Average overall rating of starters in the given category, with star
    /// multiplier applied. Returns 0 when no starters occupy that category.
    /// - Parameter category: The position category to average.
    /// - Returns: The adjusted average rating, or 0 if empty.
    func rating(for category: PositionCategory) -> Double {
        let ratings: [Double] = selectedFormation.slots.enumerated().compactMap { index, slot in
            guard self.category(for: slot.position) == category,
                  let player = assignedPlayers[index] else { return nil }
            let ovr = Double(player.ovrRating)
            // Star multiplier: non-linear boost for elite players
            if ovr >= 95 { return ovr + 4.0 }
            if ovr >= 92 { return ovr + 2.5 }
            if ovr >= 90 { return ovr + 1.5 }
            return ovr
        }
        guard !ratings.isEmpty else { return 0 }
        return ratings.reduce(0, +) / Double(ratings.count)
    }

    /// Calculates the weak-link penalty for a category. Players well below the
    /// category average drag the team down, especially when mismatched against
    /// the opponent's strength. Returns a negative adjustment (penalty).
    /// - Parameters:
    ///   - category: The position category to evaluate.
    ///   - opponentStrength: The opposing team's relevant strength rating
    ///     (offense for defenders, defense for attackers, either for midfield).
    func weakLinkPenalty(for category: PositionCategory, opponentStrength: Double) -> Double {
        let slots = selectedFormation.slots.enumerated().compactMap { index, slot -> Double? in
            guard self.category(for: slot.position) == category,
                  let player = assignedPlayers[index] else { return nil }
            return Double(player.ovrRating)
        }
        guard slots.count > 1 else { return 0 }

        let avg = slots.reduce(0, +) / Double(slots.count)
        guard let minRating = slots.min() else { return 0 }

        let gap = avg - minRating
        guard gap > 5 else { return 0 }

        // Base penalty scales with the gap
        var penalty = (gap - 5) * 0.08

        // Amplify penalty when weak link is mismatched against opponent strength
        let strengthGap = opponentStrength - minRating
        if strengthGap > 10 {
            penalty *= 1.0 + (strengthGap - 10) * 0.03
        }

        // Midfield weak links affect both attack and defense
        if category == .midfield {
            penalty *= 1.2
        }

        return -min(penalty, 4.0)
    }

    var attackRating: Double { rating(for: .attack) }
    var midfieldRating: Double { rating(for: .midfield) }
    var defenseRating: Double { rating(for: .defense) }
    var gkRating: Double { rating(for: .gk) }

    var teamOvrWithChemistry: Double { teamRating }

    /// The squad's overall rating: the simple average of all starters.
    /// Substitutes do not contribute to any team rating. Returns 0 if no starters.
    var teamRating: Double {
        let starterSum = assignedPlayers.values.map { Double($0.ovrRating) }.reduce(0, +)
        let starterCount = Double(assignedPlayers.count)
        guard starterCount > 0 else { return 0 }
        return starterSum / starterCount
    }

    /// The rating boost (or penalty) contributed by the selected manager,
    /// based on how the manager's rating compares to the team's. Capped so a
    /// manager can add at most +3 to a weaker team and subtract at most -5
    /// from a team far above their level. Requires a selected manager.
    private var managerBonus: Double {
        guard let mgr = selectedManager else { return 0 }
        let delta = (Double(mgr.rating) - teamRating) * 0.6
        return min(max(delta, -5.0), 3.0)
    }

    /// A category rating adjusted by the manager bonus.
    /// - Parameter category: The position category to adjust.
    /// - Returns: `rating(for:)` plus the manager bonus.
    func adjustedRating(for category: PositionCategory) -> Double {
        rating(for: category) + managerBonus
    }

    var adjustedAttackRating: Double { adjustedRating(for: .attack) }
    var adjustedMidfieldRating: Double { adjustedRating(for: .midfield) }
    var adjustedDefenseRating: Double { adjustedRating(for: .defense) }
    var adjustedGkRating: Double { adjustedRating(for: .gk) }
    var adjustedTeamRating: Double { teamRating + managerBonus }

    /// The user's squad expressed as a `Team` from raw category ratings. Attack,
    /// defense, and goalkeeper are kept as separate ratings so the simulation can
    /// weight them independently (a strong attack scores freely, a weak defense
    /// or keeper concedes freely).
    var playerTeam: Team {
        Team(
            name: customTeamName(),
            offense: Int(attackRating.rounded()),
            midfield: Int(midfieldRating.rounded()),
            defense: Int(rating(for: .defense).rounded()),
            goalkeeper: Int(gkRating.rounded())
        )
    }

    /// The user's squad expressed as a `Team` with manager-adjusted ratings.
    var adjustedPlayerTeam: Team {
        Team(
            name: customTeamName(),
            offense: Int(adjustedAttackRating.rounded()),
            midfield: Int(adjustedMidfieldRating.rounded()),
            defense: Int(adjustedRating(for: .defense).rounded()),
            goalkeeper: Int(adjustedGkRating.rounded())
        )
    }

    /// Returns weak-link penalties for each outfield category against a given
    /// opponent team. The penalties are additive adjustments to apply to the
    /// corresponding expected-goals calculation.
    /// - Parameter opponent: The opposing team's ratings.
    /// - Returns: (attack, midfield, defense) penalties as Doubles.
    func weakLinkPenalties(vs opponent: Team) -> (attack: Double, midfield: Double, defense: Double) {
        let atkPen = weakLinkPenalty(for: .attack, opponentStrength: Double(opponent.defense))
        let midPen = weakLinkPenalty(for: .midfield, opponentStrength: Double(max(opponent.offense, opponent.defense)))
        let defPen = weakLinkPenalty(for: .defense, opponentStrength: Double(opponent.offense))
        return (atkPen, midPen, defPen)
    }

    /// Cup variant: returns weak-link penalties against a CupTeam opponent.
    func weakLinkPenalties(vs opponent: CupTeam) -> (attack: Double, midfield: Double, defense: Double) {
        let atkPen = weakLinkPenalty(for: .attack, opponentStrength: Double(opponent.defense))
        let midPen = weakLinkPenalty(for: .midfield, opponentStrength: Double(max(opponent.offense, opponent.defense)))
        let defPen = weakLinkPenalty(for: .defense, opponentStrength: Double(opponent.offense))
        return (atkPen, midPen, defPen)
    }
}

// MARK: - Save / Load

/// A codable snapshot of a `GameState` that can be written to and read back
/// from a JSON file in the app's documents directory.
struct SavedGame: Codable {
    let selectedFormation: Formation
    let assignedPlayers: [Int: Player]
    let substitutes: [Player?]
    let selectedManager: Manager?
    let seasonOdds: SeasonOdds?
    let gameMode: GameMode
    let selectedTeam: String?
    let teamPlayers: [Player]
    let showRatings: Bool
    let totalRerollsRemaining: Int
    let showPremierLeague: Bool
    let showOtherLeagues: Bool
    let showGlobalSuperstars: Bool
    let showPastLegends: Bool
    let managerRevealed: Bool
    let gamePhase: String
    let cupCompetitionTypeRaw: String?
    let transferBudget: Int
    let transferBudgetRemaining: Int
    let usedTeams: [String]

    /// Rebuilds a live `GameState` from this snapshot.
    /// - Returns: A `GameState` populated with the saved squad and settings.
    func restore() -> GameState {
        let gs = GameState(formation: selectedFormation, mode: gameMode, showRatings: showRatings, showPremierLeague: showPremierLeague, showOtherLeagues: showOtherLeagues, showGlobalSuperstars: showGlobalSuperstars, showPastLegends: showPastLegends, managerRevealed: managerRevealed, gamePhase: gamePhase, cupCompetitionTypeRaw: cupCompetitionTypeRaw)
        gs.assignedPlayers = assignedPlayers
        gs.substitutes = substitutes
        gs.selectedManager = selectedManager
        gs.seasonOdds = seasonOdds
        gs.selectedTeam = selectedTeam
        gs.teamPlayers = teamPlayers
        gs.totalRerollsRemaining = totalRerollsRemaining
        gs.transferBudget = transferBudget
        gs.transferBudgetRemaining = transferBudgetRemaining
        gs.usedTeams = Set(usedTeams)
        return gs
    }

    /// Encodes the given game state and writes it to disk. No-op on failure.
    /// - Parameter gameState: The session to persist.
    static func save(_ gameState: GameState) {
        let saved = SavedGame(
            selectedFormation: gameState.selectedFormation,
            assignedPlayers: gameState.assignedPlayers,
            substitutes: gameState.substitutes,
            selectedManager: gameState.selectedManager,
            seasonOdds: gameState.seasonOdds,
            gameMode: gameState.gameMode,
            selectedTeam: gameState.selectedTeam,
            teamPlayers: gameState.teamPlayers,
            showRatings: gameState.showRatings,
            totalRerollsRemaining: gameState.totalRerollsRemaining,
            showPremierLeague: gameState.showPremierLeague,
            showOtherLeagues: gameState.showOtherLeagues,
            showGlobalSuperstars: gameState.showGlobalSuperstars,
            showPastLegends: gameState.showPastLegends,
            managerRevealed: gameState.managerRevealed,
            gamePhase: gameState.gamePhase,
            cupCompetitionTypeRaw: gameState.cupCompetitionTypeRaw,
            transferBudget: gameState.transferBudget,
            transferBudgetRemaining: gameState.transferBudgetRemaining,
            usedTeams: Array(gameState.usedTeams)
        )
        guard let data = try? JSONEncoder().encode(saved),
              let url = saveURL else { return }
        try? data.write(to: url)
    }

    /// Loads a saved game from disk, if one exists.
    /// - Returns: The restored `GameState`, or `nil` if there is no save.
    static func load() -> GameState? {
        guard let url = saveURL, let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data) else { return nil }
        return saved.restore()
    }

    /// Removes the saved game file, if present.
    static func clear() {
        guard let url = saveURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// The file URL where the game save is stored.
    private static var saveURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("savedGame.json")
    }
}
