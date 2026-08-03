/// GameData.swift
///
/// Central static data store for the game: the available formations and
/// managers, the full player pool, and helper lists of leagues and teams.
import Foundation

/// Namespace holding static game data. `formations`, `managers`, and
/// `players` are the source lists used by the home and draft screens.
struct GameData {
    /// All selectable tactical formations, from defensive 5-3-2 to attacking
    /// 4-3-3, with slots computed from positional lines.
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

    /// The selectable pool of managers, each tied to a league for chemistry.
    static let managers: [Manager] = [
        Manager(name: "Pep Guardiola", rating: 94, league: "Unemployed"),
        Manager(name: "Jürgen Klopp", rating: 92, league: "International"),
        Manager(name: "Mikel Arteta", rating: 90, league: "Premier League"),
        Manager(name: "Carlo Ancelotti", rating: 89, league: "International"),
        Manager(name: "Diego Simeone", rating: 88, league: "La Liga"),
        Manager(name: "Xabi Alonso", rating: 88, league: "Premier League"),
        Manager(name: "Simone Inzaghi", rating: 84, league: "Saudi Pro League"),
        Manager(name: "Luis Enrique", rating: 90, league: "Ligue 1"),
        Manager(name: "Thomas Tuchel", rating: 88, league: "International"),
        Manager(name: "Arne Slot", rating: 84, league: "Unemployed"),
        Manager(name: "Unai Emery", rating: 86, league: "Premier League"),
        Manager(name: "Antonio Conte", rating: 86, league: "Serie A"),
        Manager(name: "Hansi Flick", rating: 88, league: "La Liga"),
        Manager(name: "José Mourinho", rating: 88, league: "La Liga"),
        Manager(name: "Edin Terzić", rating: 83, league: "Bundesliga"),

        // MARK: - Newly Added
        Manager(name: "Zinedine Zidane", rating: 85, league: "International"),
        Manager(name: "Mauricio Pochettino", rating: 87, league: "International"),
        Manager(name: "Julian Nagelsmann", rating: 84, league: "Unemployed"),
        Manager(name: "Ruben Amorim", rating: 82, league: "Serie A"),
        Manager(name: "Roberto De Zerbi", rating: 84, league: "Premier League"),
        Manager(name: "Ange Postecoglou", rating: 82, league: "Saudi Pro League"),
        Manager(name: "Vincent Kompany", rating: 86, league: "Bundesliga"),
        Manager(name: "Erik ten Hag", rating: 80, league: "Unemployed"),
        Manager(name: "Gian Piero Gasperini", rating: 82, league: "Serie A"),
        Manager(name: "Thomas Frank", rating: 83, league: "Unemployed"),
       // Manager(name: "Francesco Farioli", rating: 82, league: "Ligue 1"),
        //Manager(name: "Marcelino", rating: 82, league: "La Liga"),
        Manager(name: "Oliver Glasner", rating: 82, league: "Premier League"),
        Manager(name: "Liam Rosenior", rating: 77, league: "Ligue 1"),
        Manager(name: "Graham Potter", rating: 75, league: "International"),
        Manager(name: "Didier Deschamps", rating: 85, league: "International"),
        Manager(name: "Luis de la Fuente", rating: 88, league: "International"),
        Manager(name: "Nuno Espirito Santo", rating: 80, league: "Championship"),
        Manager(name: "Claudio Ranieri", rating: 79, league: "Other"),
        Manager(name: "David Moyes", rating: 82, league: "Premier League"),
        Manager(name: "Marcelo Bielsa", rating: 77, league: "Unemployed"),
        Manager(name: "Alex Ferguson", rating: 95, league: "Legend"),
        Manager(name: "Johan Cruyff", rating: 90, league: "Legend"),
        Manager(name: "Rafa Benitez", rating: 81, league: "Unemployed"),
        Manager(name: "Luis van Gaal", rating: 81, league: "Legend"),
        Manager(name: "Marco Rose", rating: 82, league: "Premier League"),
        Manager(name: "Keith Andrews", rating: 78, league: "Premier League"),
        Manager(name: "Fabian Hurzeler", rating: 81, league: "Premier League"),
        Manager(name: "Frank Lampard", rating: 80, league: "Premier League"),
        Manager(name: "Pierre Sage", rating: 78, league: "Premier League"),
        Manager(name: "Alvaro Arbeloa", rating: 75, league: "Premier League"),
        Manager(name: "Sergej Jakirovic", rating: 75, league: "Premier League"),
        Manager(name: "Gary O'Niel", rating: 78, league: "Premier League"),
        Manager(name: "Daniel Farke", rating: 80, league: "Premier League"),
        Manager(name: "Andoni Iraola", rating: 86, league: "Premier League"),
        Manager(name: "Enzo Maresca", rating: 86, league: "Premier League"),
        Manager(name: "Michael Carrick", rating: 83, league: "Premier League"),
        Manager(name: "Oliver Glasner", rating: 85, league: "Premier League"),
        Manager(name: "Regis Le Bris", rating: 81, league: "Premier League"),
        
    ]

    /// The full draftee player pool, loaded from the `Players.swift` data file.
    static let players: [Player] = _players

    /// The league buckets shown as draft filters.
    static var leagues: [String] {
        ["Premier League", "Other Leagues"]
    }

    /// All unique team names present in the player pool, sorted alphabetically.
    static var allTeams: [String] {
        Set(players.map { $0.team }).sorted()
    }
}
