import Foundation

struct SampleData {
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
        Formation(name: "4-4-1-1", lines: [
            [.ST],
            [.CAM],
            [.LM, .CM, .CM, .RM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "4-2-2-2", lines: [
            [.ST, .ST],
            [.CAM, .CAM],
            [.CDM, .CDM],
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
        Formation(name: "4-3-1-2", lines: [
            [.ST, .ST],
            [.CAM],
            [.CM, .CM, .CM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "5-4-1", lines: [
            [.ST],
            [.LM, .CM, .CM, .RM],
            [.LB, .CB, .CB, .CB, .RB],
            [.GK]
        ]),
        Formation(name: "3-6-1", lines: [
            [.ST],
            [.LM, .CM, .CM, .CM, .CM, .RM],
            [.CB, .CB, .CB],
            [.GK]
        ]),
        Formation(name: "4-5-1", lines: [
            [.ST],
            [.LM, .CM, .CM, .CM, .RM],
            [.LB, .CB, .CB, .RB],
            [.GK]
        ])
    ]

    static let players: [Player] = [
        // Premier League
        Player(name: "Erling Haaland", ovrRating: 91, positions: [.ST], team: "Manchester City", league: "Premier League"),
        Player(name: "Kevin De Bruyne", ovrRating: 91, positions: [.CAM, .CM], team: "Manchester City", league: "Premier League"),
        Player(name: "Rodri", ovrRating: 91, positions: [.CDM, .CM], team: "Manchester City", league: "Premier League"),
        Player(name: "Ederson", ovrRating: 89, positions: [.GK], team: "Manchester City", league: "Premier League"),
        Player(name: "Rúben Dias", ovrRating: 89, positions: [.CB], team: "Manchester City", league: "Premier League"),
        Player(name: "Mohamed Salah", ovrRating: 89, positions: [.RW, .LW], team: "Liverpool", league: "Premier League"),
        Player(name: "Virgil van Dijk", ovrRating: 89, positions: [.CB], team: "Liverpool", league: "Premier League"),
        Player(name: "Alisson", ovrRating: 89, positions: [.GK], team: "Liverpool", league: "Premier League"),
        Player(name: "Andrew Robertson", ovrRating: 87, positions: [.LB], team: "Liverpool", league: "Premier League"),
        Player(name: "Trent Alexander-Arnold", ovrRating: 88, positions: [.RB, .CM], team: "Liverpool", league: "Premier League"),
        Player(name: "Bukayo Saka", ovrRating: 88, positions: [.RW, .LM], team: "Arsenal", league: "Premier League"),
        Player(name: "Martin Ødegaard", ovrRating: 88, positions: [.CAM, .CM], team: "Arsenal", league: "Premier League"),
        Player(name: "Declan Rice", ovrRating: 89, positions: [.CDM, .CM], team: "Arsenal", league: "Premier League"),
        Player(name: "William Saliba", ovrRating: 87, positions: [.CB], team: "Arsenal", league: "Premier League"),
        Player(name: "Phil Foden", ovrRating: 88, positions: [.LW, .RW], team: "Manchester City", league: "Premier League"),
        Player(name: "Cole Palmer", ovrRating: 86, positions: [.CAM, .RW], team: "Chelsea", league: "Premier League"),
        // La Liga
        Player(name: "Jude Bellingham", ovrRating: 90, positions: [.CAM, .CM], team: "Real Madrid", league: "La Liga"),
        Player(name: "Vinícius Jr", ovrRating: 91, positions: [.LW, .ST], team: "Real Madrid", league: "La Liga"),
        Player(name: "Kylian Mbappé", ovrRating: 91, positions: [.ST, .LW], team: "Real Madrid", league: "La Liga"),
        Player(name: "Thibaut Courtois", ovrRating: 90, positions: [.GK], team: "Real Madrid", league: "La Liga"),
        Player(name: "Antonio Rüdiger", ovrRating: 87, positions: [.CB], team: "Real Madrid", league: "La Liga"),
        Player(name: "Federico Valverde", ovrRating: 89, positions: [.CM, .RM], team: "Real Madrid", league: "La Liga"),
        Player(name: "Robert Lewandowski", ovrRating: 89, positions: [.ST], team: "Barcelona", league: "La Liga"),
        Player(name: "Lamine Yamal", ovrRating: 83, positions: [.RW, .LW], team: "Barcelona", league: "La Liga"),
        Player(name: "Pedri", ovrRating: 87, positions: [.CM, .CAM], team: "Barcelona", league: "La Liga"),
        Player(name: "Marc-André ter Stegen", ovrRating: 88, positions: [.GK], team: "Barcelona", league: "La Liga"),
        Player(name: "Antoine Griezmann", ovrRating: 86, positions: [.CF, .ST], team: "Atlético Madrid", league: "La Liga"),
        Player(name: "Jan Oblak", ovrRating: 89, positions: [.GK], team: "Atlético Madrid", league: "La Liga"),
        // Bundesliga
        Player(name: "Harry Kane", ovrRating: 90, positions: [.ST], team: "Bayern Munich", league: "Bundesliga"),
        Player(name: "Jamal Musiala", ovrRating: 88, positions: [.CAM, .LW], team: "Bayern Munich", league: "Bundesliga"),
        Player(name: "Joshua Kimmich", ovrRating: 88, positions: [.CM, .RB], team: "Bayern Munich", league: "Bundesliga"),
        Player(name: "Manuel Neuer", ovrRating: 88, positions: [.GK], team: "Bayern Munich", league: "Bundesliga"),
        Player(name: "Alphonso Davies", ovrRating: 86, positions: [.LB, .LW], team: "Bayern Munich", league: "Bundesliga"),
        Player(name: "Matthijs de Ligt", ovrRating: 86, positions: [.CB], team: "Bayern Munich", league: "Bundesliga"),
        Player(name: "Florian Wirtz", ovrRating: 86, positions: [.CAM, .CM], team: "Bayer Leverkusen", league: "Bundesliga"),
        // Serie A
        Player(name: "Lautaro Martínez", ovrRating: 88, positions: [.ST], team: "Inter Milan", league: "Serie A"),
        Player(name: "Alessandro Bastoni", ovrRating: 86, positions: [.CB], team: "Inter Milan", league: "Serie A"),
        Player(name: "Rafael Leão", ovrRating: 86, positions: [.LW, .ST], team: "AC Milan", league: "Serie A"),
        Player(name: "Theo Hernández", ovrRating: 85, positions: [.LB], team: "AC Milan", league: "Serie A"),
        Player(name: "Paulo Dybala", ovrRating: 86, positions: [.CAM, .ST], team: "Roma", league: "Serie A"),
        Player(name: "Khvicha Kvaratskhelia", ovrRating: 87, positions: [.LW, .RW], team: "Napoli", league: "Serie A"),
        // Ligue 1
        Player(name: "Gianluigi Donnarumma", ovrRating: 88, positions: [.GK], team: "PSG", league: "Ligue 1"),
        Player(name: "Achraf Hakimi", ovrRating: 86, positions: [.RB, .RWB], team: "PSG", league: "Ligue 1"),
        Player(name: "Marquinhos", ovrRating: 87, positions: [.CB, .CDM], team: "PSG", league: "Ligue 1"),
        Player(name: "Ousmane Dembélé", ovrRating: 86, positions: [.RW, .LW], team: "PSG", league: "Ligue 1"),
        Player(name: "Warren Zaïre-Emery", ovrRating: 84, positions: [.CM, .CDM], team: "PSG", league: "Ligue 1"),
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

    static var leagues: [String] {
        let unique = Set(players.map { $0.league })
        return ["All"] + unique.sorted()
    }

    static var allTeams: [String] {
        Set(players.map { $0.team }).sorted()
    }
}
