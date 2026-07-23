import Foundation

struct Manager: Identifiable, Codable {
    let id: UUID
    let name: String
    let rating: Int
    let league: String

    init(id: UUID = UUID(), name: String, rating: Int, league: String) {
        self.id = id
        self.name = name
        self.rating = rating
        self.league = league
    }
}
