import Foundation

struct DraftHistory: Codable, Identifiable {
    let id: UUID
    let date: Date
    let gameMode: GameMode
    let teamOverall: Int
    let record: SeasonRecord
    let position: Int
    let formation: Formation
    let assignedPlayers: [Int: Player]
    let substitutes: [Player?]
    let manager: Manager?

    var formattedDate: String {
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yy"
        return df.string(from: date)
    }

    static func save(_ entry: DraftHistory) {
        var history = Self.loadAll()
        history.insert(entry, at: 0)
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: "draftHistory")
    }

    static func loadAll() -> [DraftHistory] {
        guard let data = UserDefaults.standard.data(forKey: "draftHistory"),
              let history = try? JSONDecoder().decode([DraftHistory].self, from: data) else {
            return []
        }
        return history
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: "draftHistory")
    }
}
