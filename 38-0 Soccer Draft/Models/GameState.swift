import Combine
import Foundation

enum GameMode: String, CaseIterable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case mode38 = "38-0 Mode"
}

enum PositionCategory {
    case gk, defense, midfield, attack
}

class GameState: ObservableObject {
    @Published var selectedLeague: String
    @Published var selectedFormation: Formation
    @Published var assignedPlayers: [Int: Player] = [:]
    @Published var substitutes: [Player?] = Array(repeating: nil, count: 5)
    @Published var selectedManager: Manager?
    @Published var seasonOdds: SeasonOdds?
    @Published var gameMode: GameMode
    @Published var selectedTeam: String? = nil
    @Published var teamPlayers: [Player] = []

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

    var maxRerolls: Int {
        switch gameMode {
        case .easy: return 3
        case .normal: return 1
        case .hard: return 0
        case .mode38: return 0
        }
    }

    var totalRemaining: Int {
        if isMode38 {
            return selectedFormation.slots.count - assignedPlayers.count
        }
        let total = selectedFormation.slots.count + 5
        let filled = assignedPlayers.count + substitutes.compactMap { $0 }.count
        return total - filled
    }

    init(formation: Formation, league: String = "All", mode: GameMode = .normal) {
        self.selectedFormation = formation
        self.selectedLeague = league
        self.gameMode = mode
    }

    func assignPlayer(_ player: Player, toSlot index: Int) {
        assignedPlayers[index] = player
    }

    func addSubstitute(_ player: Player, at index: Int) {
        guard index < substitutes.count else { return }
        substitutes[index] = player
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

    func randomizeManager(in managers: [Manager], for league: String) {
        let pool = league == "All" ? managers : managers.filter { $0.league == league }
        selectedManager = pool.randomElement()
    }

    func simulateSeason() {
        guard let manager = selectedManager else { return }
        let players = assignedPlayers.values.map { $0 }
        guard players.count == selectedFormation.slots.count else { return }
        seasonOdds = SeasonOdds.calculate(players: players, manager: manager)
    }

    func randomizeTeam() {
        let teams = SampleData.allTeams
        selectedTeam = teams.randomElement()
        teamPlayers = SampleData.players.filter { $0.team == selectedTeam }
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

    var teamChemistry: Int {
        guard !isMode38 else { return 0 }
        return Chemistry.teamChemistry(
            assignedPlayers: assignedPlayers,
            formation: selectedFormation,
            manager: selectedManager
        )
    }

    var chemistryModifier: Int {
        guard !isMode38 else { return 0 }
        let c = teamChemistry
        if c >= 90 { return 3 }
        if c >= 80 { return 1 }
        if c >= 70 { return 0 }
        if c >= 60 { return -2 }
        if c >= 50 { return -5 }
        if c >= 30 { return -8 }
        if c >= 15 { return -10 }
        return -20
    }

    var teamOvrWithChemistry: Double {
        teamRating + Double(chemistryModifier)
    }

    var teamRating: Double {
        let starterSum = assignedPlayers.values.map { Double($0.ovrRating) }.reduce(0, +)
        let subSum = substitutes.compactMap { $0 }.map { Double($0.ovrRating) }.reduce(0, +)
        let starterCount = Double(assignedPlayers.count)
        let subCount = Double(substitutes.compactMap { $0 }.count)
        guard starterCount > 0 else { return 0 }
        return (starterSum + subSum * 0.3) / (starterCount + subCount * 0.3)
    }

    var playerTeam: PlaceholderTeam {
        PlaceholderTeam(
            name: "Your Team",
            offense: Int(attackRating.rounded()),
            midfield: Int(midfieldRating.rounded()),
            defense: Int(((rating(for: .defense) + gkRating) / 2).rounded())
        )
    }
}
