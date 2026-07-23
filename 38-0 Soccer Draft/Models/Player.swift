import Foundation

struct Player: Identifiable, Codable {
    let id: UUID
    let name: String
    let ovrRating: Int
    let positions: [Position]
    let team: String
    let league: String

    init(id: UUID = UUID(), name: String, ovrRating: Int, positions: [Position], team: String, league: String) {
        self.id = id
        self.name = name
        self.ovrRating = ovrRating
        self.positions = positions
        self.team = team
        self.league = league
    }
}
