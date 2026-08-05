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
    case mode38 = "38-0"
    case positionsFirst = "Positions First"

    /// The label shown in the UI. "Normal" is presented as "Medium" so the
    /// difficulty row reads Easy / Medium / Hard.
    var displayName: String {
        self == .normal ? "Medium" : rawValue
    }

    /// Whether the mode is a special draft variant (team roll / position pick)
    /// rather than a plain difficulty selection.
    var isSpecialMode: Bool {
        self == .mode38 || self == .positionsFirst
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
    @Published var showRatings: Bool = true
    @Published var totalRerollsRemaining: Int = 0
    @Published var showPremierLeague: Bool = true
    @Published var showOtherLeagues: Bool = true
    @Published var showGlobalSuperstars: Bool = true
    @Published var showPastLegends: Bool = true
    @Published var managerRevealed: Bool = false
    @Published var gamePhase: String = "drafting"
    @Published var cupCompetitionTypeRaw: String? = nil

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

    /// Whether the mode uses the roll-a-team draft (38-0 and Positions First).
    var usesTeamDraft: Bool { isMode38 || isPositionsFirst }

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

    /// Total unfilled starting slots.
    var totalRemaining: Int {
        selectedFormation.slots.count - assignedPlayers.count
    }

    /// Creates a game state for a draft session. Reroll count is derived from
    /// the game mode.
    init(formation: Formation, mode: GameMode = .normal, showRatings: Bool = true, showPremierLeague: Bool = true, showOtherLeagues: Bool = true, showGlobalSuperstars: Bool = true, showPastLegends: Bool = true, managerRevealed: Bool = false, gamePhase: String = "drafting", cupCompetitionTypeRaw: String? = nil) {
        self.selectedFormation = formation
        self.gameMode = mode
        self.showRatings = showRatings
        self.showPremierLeague = showPremierLeague
        self.showOtherLeagues = showOtherLeagues
        self.showGlobalSuperstars = showGlobalSuperstars
        self.showPastLegends = showPastLegends
        self.managerRevealed = managerRevealed
        self.gamePhase = gamePhase
        self.cupCompetitionTypeRaw = cupCompetitionTypeRaw
        self.totalRerollsRemaining = mode == .easy ? 3 : mode == .normal ? 1 : mode == .mode38 || mode == .positionsFirst ? 1 : 0
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
        let difficulty = min(1.0, Double(dynastyCount) * 0.25)
        seasonOdds = SeasonOdds.calculate(playerTeam: adjustedPlayerTeam, opponents: leagueTeams, difficulty: difficulty)
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

    /// Average overall rating of starters in the given category.
    /// Returns 0 when no starters occupy that category.
    /// - Parameter category: The position category to average.
    /// - Returns: The average rating, or 0 if empty.
    func rating(for category: PositionCategory) -> Double {
        let ratings: [Double] = selectedFormation.slots.enumerated().compactMap { index, slot in
            guard self.category(for: slot.position) == category,
                  let player = assignedPlayers[index] else { return nil }
            return Double(player.ovrRating)
        }
        guard !ratings.isEmpty else { return 0 }
        return ratings.reduce(0, +) / Double(ratings.count)
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
            cupCompetitionTypeRaw: gameState.cupCompetitionTypeRaw
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
