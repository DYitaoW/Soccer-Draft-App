import Foundation

struct Chemistry {
    static func individual(player: Player, slotPosition: Position, manager: Manager?) -> Int {
        if player.canPlay(slotPosition) {
            var chem = 10
            if let manager = manager, manager.league == player.league {
                chem = min(chem + 1, 10)
            }
            return chem
        }
        var best = 0
        for natural in player.positions {
            let c = positionChemistry[natural]?[slotPosition] ?? 0
            best = max(best, c)
        }
        return best
    }

    static func canPlay(player: Player, at position: Position) -> Bool {
        individual(player: player, slotPosition: position, manager: nil) > 0
    }

    static func teamChemistry(
        assignedPlayers: [Int: Player],
        formation: Formation,
        manager: Manager?
    ) -> Int {
        var total = 0
        for (index, slot) in formation.slots.enumerated() {
            guard let player = assignedPlayers[index] else { continue }
            total += individual(player: player, slotPosition: slot.position, manager: manager)
        }
        let maxChem = formation.slots.count * 10
        guard maxChem > 0 else { return 0 }
        return min(Int((Double(total) / Double(maxChem)) * 100), 100)
    }

    // tuning: add/edit entries below; unmapped combos default to 0
    private static let positionChemistry: [Position: [Position: Int]] = [
        .GK: gkMap(),
        .RB: [.RM: 6, .LM: 6, .LW: 2, .RW: 2, .ST: 2, .CF: 2],
        .LB: [.RM: 6, .LM: 6, .LW: 2, .RW: 2, .ST: 2, .CF: 2],
        .RWB: [.RM: 6, .LM: 6, .LW: 2, .RW: 2, .ST: 2],
        .LWB: [.RM: 6, .LM: 6, .LW: 2, .RW: 2, .ST: 2],
        .CB: [.LB: 7, .RB: 7, .CM: 3, .CDM: 4, .LM: 1, .RM: 1, .LW: 1, .RW: 1, .ST: 1, .CF: 1, .CAM: 1],
        .CDM: [.CM: 8, .CB: 5, .LM: 6, .RM: 6, .CAM: 7],
        .CM: [.LM: 8, .RM: 8, .CB: 4, .LB: 6, .RB: 6, .LW: 4, .RW: 4, .ST: 4, .CF: 4, .CAM: 8, .CDM: 8],
        .CAM: [.LM: 7, .RM: 7, .CM: 9, .CDM: 6, .LW: 5, .RW: 5, .ST: 6, .CF: 8],
        .LM: [.LW: 8, .RM: 6, .CM: 8, .CAM: 7, .CDM: 6, .LB: 6, .RB: 4, .RW: 5, .ST: 3, .CF: 3],
        .RM: [.RW: 8, .LM: 6, .CM: 8, .CAM: 7, .CDM: 6, .LB: 4, .RB: 6, .LW: 5, .ST: 3, .CF: 3],
        .LW: [.LM: 8, .RM: 5, .CM: 5, .CAM: 5, .CDM: 5, .LB: 2, .RB: 2, .CB: 2, .ST: 7, .CF: 6, .RW: 7],
        .RW: [.LM: 5, .RM: 8, .CM: 5, .CAM: 5, .CDM: 5, .LB: 2, .RB: 2, .CB: 2, .ST: 7, .CF: 6, .LW: 7],
        .ST: [.LW: 7, .RW: 7, .LM: 4, .RM: 4, .CM: 4, .CAM: 5, .CDM: 3, .LB: 1, .RB: 1, .CB: 1, .CF: 8],
        .CF: [.ST: 8, .CAM: 8, .LW: 7, .RW: 7, .CM: 6, .LM: 5, .RM: 5],
    ]

    private static func gkMap() -> [Position: Int] {
        var m = [Position: Int]()
        for p in Position.allCases where p != .GK {
            m[p] = 0
        }
        return m
    }
}
