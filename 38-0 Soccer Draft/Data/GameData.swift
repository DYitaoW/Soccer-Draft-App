import Foundation

struct GameData {
    static let formations: [Formation] = [
        Formation(name: "4-4-2", lines: [
            [.ST, .ST],
            [.LM, .CM, .CM, .RM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "4-3-3", lines: [
            [.LW, .ST, .RW],
            [.CM, .CM, .CM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "4-2-3-1", lines: [
            [.ST],
            [.LW, .CAM, .RW],
            [.CDM, .CDM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "3-5-2", lines: [
            [.ST, .ST],
            [.LM, .CM, .CM, .CM, .RM],
            [.CB, .CB, .CB],
            [.GK]
        ]),
        Formation(name: "3-4-3", lines: [
            [.LW, .ST, .RW],
            [.LM, .CM, .CM, .RM],
            [.CB, .CB, .CB],
            [.GK]
        ]),
        Formation(name: "5-3-2", lines: [
            [.ST, .ST],
            [.CM, .CM, .CM],
            [.LB, .CB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "4-1-4-1", lines: [
            [.ST],
            [.LM, .CM, .CM, .RM],
            [.CDM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "4-3-2-1", lines: [
            [.ST],
            [.CAM, .CAM],
            [.CM, .CM, .CM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "3-4-1-2", lines: [
            [.ST, .ST],
            [.CAM],
            [.LM, .CM, .CM, .RM],
            [.CB, .CB, .CB],
            [.GK]
        ]),
        Formation(name: "4-2-2-2", lines: [
            [.ST, .ST],
            [.CAM, .CAM],
            [.CDM, .CDM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "5-2-3", lines: [
            [.LW, .ST, .RW],
            [.CM, .CM],
            [.LB, .CB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "4-5-1", lines: [
            [.ST],
            [.LM, .CM, .CM, .CM, .RM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ]),
    ]

    static let managers: [Manager] = [
        Manager(name: "Pep Guardiola", rating: 92, league: "Premier League"),
        Manager(name: "Jürgen Klopp", rating: 90, league: "Premier League"),
        Manager(name: "Mikel Arteta", rating: 88, league: "Premier League"),
        Manager(name: "Carlo Ancelotti", rating: 91, league: "La Liga"),
        Manager(name: "Diego Simeone", rating: 89, league: "La Liga"),
        Manager(name: "Xabi Alonso", rating: 87, league: "Bundesliga"),
        Manager(name: "Simone Inzaghi", rating: 87, league: "Serie A"),
        Manager(name: "Luis Enrique", rating: 88, league: "Ligue 1"),
    ]

    static let players: [Player] = _players

    static var leagues: [String] {
        ["Premier League", "Other Leagues"]
    }

    static var allTeams: [String] {
        Set(players.map { $0.team }).sorted()
    }
}
