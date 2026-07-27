import Combine
import Foundation

enum GameMode: String, CaseIterable, Codable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case mode38 = "38-0"
}

enum PositionCategory {
    case gk, defense, midfield, attack
}

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
    @Published var showPremierLeague: Bool = true {
        didSet {
            if !showPremierLeague { showPremierLeague = true }
        }
    }
    @Published var showOtherLeagues: Bool = true
    @Published var showGlobalSuperstars: Bool = true
    @Published var showPastLegends: Bool = true
    @Published var managerRevealed: Bool = false
    @Published var gamePhase: String = "drafting"
    @Published var cupCompetitionTypeRaw: String? = nil

    var remainingSlots: Int {
        selectedFormation.slots.count - assignedPlayers.count
    }

    var isComplete: Bool {
        assignedPlayers.count == selectedFormation.slots.count
    }

    var isMode38: Bool { gameMode == .mode38 }

    var usedPlayerIds: Set<UUID> {
        let starterIds = Set(assignedPlayers.values.map(\.id))
        let subIds = Set(substitutes.compactMap { $0?.id })
        return starterIds.union(subIds)
    }

    var maxRerolls: Int { totalRerollsRemaining }

    func useReroll() {
        guard totalRerollsRemaining > 0 else { return }
        totalRerollsRemaining -= 1
    }

    var totalRemaining: Int {
        if isMode38 {
            return selectedFormation.slots.count - assignedPlayers.count
        }
        let total = selectedFormation.slots.count + 5
        let filled = assignedPlayers.count + substitutes.compactMap { $0 }.count
        return total - filled
    }

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
        self.totalRerollsRemaining = mode == .easy ? 3 : mode == .normal ? 1 : 0
    }

    func assignPlayer(_ player: Player, toSlot index: Int) {
        assignedPlayers[index] = player
        SavedGame.save(self)
    }

    func addSubstitute(_ player: Player, at index: Int) {
        guard index < substitutes.count else { return }
        substitutes[index] = player
        SavedGame.save(self)
    }

    func swapStarter(_ starterIndex: Int, withSub subIndex: Int) {
        guard let subPlayer = substitutes[subIndex] else { return }
        guard let starterPlayer = assignedPlayers[starterIndex] else { return }
        assignedPlayers[starterIndex] = subPlayer
        substitutes[subIndex] = starterPlayer
    }

    func swapSub(_ fromIndex: Int, withSub toIndex: Int) {
        let temp = substitutes[fromIndex]
        substitutes[fromIndex] = substitutes[toIndex]
        substitutes[toIndex] = temp
    }

    func swapStarterWithStarter(_ from: Int, to: Int) {
        let temp = assignedPlayers[from]
        assignedPlayers[from] = assignedPlayers[to]
        assignedPlayers[to] = temp
    }

    func randomizeManager(in managers: [Manager]) {
        selectedManager = managers.randomElement()
    }

    func simulateSeason() {
        guard let manager = selectedManager else { return }
        let players = assignedPlayers.values.map { $0 }
        guard players.count == selectedFormation.slots.count else { return }
        seasonOdds = SeasonOdds.calculate(players: players, manager: manager)
    }

    func randomizeTeam() {
        let teams = GameData.allTeams
        selectedTeam = teams.randomElement()
        teamPlayers = GameData.players.filter { $0.team == selectedTeam }
        SavedGame.save(self)
    }

    // MARK: - Team Ratings

    private func category(for position: Position) -> PositionCategory {
        switch position {
        case .GK: return .gk
        case .LB, .CB, .RB, .LWB, .RWB: return .defense
        case .CDM, .CM, .CAM, .LM, .RM: return .midfield
        case .LW, .RW, .CF, .ST: return .attack
        }
    }

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

    var teamRating: Double {
        let starterSum = assignedPlayers.values.map { Double($0.ovrRating) }.reduce(0, +)
        let starterCount = Double(assignedPlayers.count)
        guard starterCount > 0 else { return 0 }
        let bestSub = substitutes.compactMap { $0 }.map { Double($0.ovrRating) }.max()
        if let bestSub = bestSub {
            return (starterSum + bestSub * 0.1) / (starterCount + 0.1)
        }
        return starterSum / starterCount
    }

    private var managerBonus: Double {
        guard let mgr = selectedManager else { return 0 }
        return (Double(mgr.rating) - teamRating) / 2.0
    }

    func adjustedRating(for category: PositionCategory) -> Double {
        rating(for: category) + managerBonus
    }

    var adjustedAttackRating: Double { adjustedRating(for: .attack) }
    var adjustedMidfieldRating: Double { adjustedRating(for: .midfield) }
    var adjustedDefenseRating: Double { adjustedRating(for: .defense) }
    var adjustedGkRating: Double { adjustedRating(for: .gk) }
    var adjustedTeamRating: Double { teamRating + managerBonus }

    var playerTeam: Team {
        Team(
            name: "Your Team",
            offense: Int(attackRating.rounded()),
            midfield: Int(midfieldRating.rounded()),
            defense: Int(((rating(for: .defense) + gkRating) / 2).rounded())
        )
    }

    var adjustedPlayerTeam: Team {
        Team(
            name: "Your Team",
            offense: Int(adjustedAttackRating.rounded()),
            midfield: Int(adjustedMidfieldRating.rounded()),
            defense: Int(((adjustedRating(for: .defense) + adjustedGkRating) / 2).rounded())
        )
    }
}

// MARK: - Save / Load

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

    static func load() -> GameState? {
        guard let url = saveURL, let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data) else { return nil }
        return saved.restore()
    }

    static func clear() {
        guard let url = saveURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static var saveURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("savedGame.json")
    }
}
