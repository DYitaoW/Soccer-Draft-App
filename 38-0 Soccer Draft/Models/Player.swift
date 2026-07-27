import Foundation

struct Player: Identifiable, Codable {
    let id: UUID
    let name: String
    let ovrRating: Int
    let positions: [Position]
    let team: String
    let league: String

    func canPlay(_ position: Position) -> Bool {
        positions.contains { $0.matches(position) }
    }

    var effectivePositions: [Position] {
        var result = Set(positions)
        for p in positions {
            switch p {
            case .LM: result.insert(.LW)
            case .LW: result.insert(.LM)
            case .RM: result.insert(.RW)
            case .RW: result.insert(.RM)
            default: break
            }
        }
        return Array(result)
    }

    init(id: UUID = UUID(), name: String, ovrRating: Int, positions: [Position], team: String, league: String) {
        self.id = id
        self.name = name
        self.ovrRating = ovrRating
        self.positions = positions
        self.team = team
        self.league = league
    }
}
