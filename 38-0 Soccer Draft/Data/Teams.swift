import Foundation

let leagueTeams: [Team] = [
    Team(name: "Arsenal", offense: 88, midfield: 92, defense: 95),
    Team(name: "Chelsea", offense: 93, midfield: 93, defense: 87),
    Team(name: "Man United", offense: 87, midfield: 87, defense: 86),
    Team(name: "Man City", offense: 93, midfield: 90, defense: 90),
    Team(name: "Liverpool", offense: 90, midfield: 87, defense: 87),
    Team(name: "Spurs", offense: 85, midfield: 83, defense: 83),
    Team(name: "Aston Villa", offense: 83, midfield: 83, defense: 83),
    Team(name: "Bournemouth", offense: 80, midfield: 78, defense: 77),
    Team(name: "Sunderland", offense: 79, midfield: 77, defense: 75),
    Team(name: "Brighton", offense: 81, midfield: 80, defense: 77),
    Team(name: "Fulham", offense: 80, midfield: 82, defense: 80),
    Team(name: "Brentford", offense: 81, midfield: 76, defense: 78),
    Team(name: "Newcastle", offense: 85, midfield: 83, defense: 82),
    Team(name: "Everton", offense: 83, midfield: 82, defense: 76),
    Team(name: "Leeds", offense: 75, midfield: 74, defense: 74),
    Team(name: "Palace", offense: 77, midfield: 78, defense: 80),
    Team(name: "Ipswich", offense: 77, midfield: 71, defense: 73),
    Team(name: "Coventry", offense: 78, midfield: 74, defense: 74),
    Team(name: "Forest", offense: 80, midfield: 76, defense: 74),
    Team(name: "Wolves", offense: 76, midfield: 78, defense: 77),
]

// MARK: - Cup Competition Teams
// Fill in the stats for each team. pot values: 1 = strongest, 4 = weakest.
// The draw picks 2 opponents from each pot (8 games total, 4H/4A).

let superLeagueTeams: [CupTeam] = [
    // pot 1
    CupTeam(name: "Arsenal", offense: 88, midfield: 92, defense: 95, pot: 1),
    CupTeam(name: "Barcelona", offense: 94, midfield: 90, defense: 85, pot: 1),
    CupTeam(name: "Real Madrid", offense: 95, midfield: 90, defense: 88, pot: 1),
    CupTeam(name: "Bayern", offense: 94, midfield: 87, defense: 90, pot: 1),
    CupTeam(name: "PSG", offense: 98, midfield: 95, defense: 90, pot: 1),
    CupTeam(name: "Inter", offense: 90, midfield: 87, defense: 86, pot: 1),
    CupTeam(name: "Liverpool", offense: 90, midfield: 87, defense: 87, pot: 1),
    CupTeam(name: "Man City", offense: 93, midfield: 90, defense: 90, pot: 1),
    CupTeam(name: "Chelsea", offense: 93, midfield: 93, defense: 87, pot: 1),
    // pot 2
    CupTeam(name: "Spurs", offense: 85, midfield: 83, defense: 83, pot: 2),
    CupTeam(name: "Dortmund", offense: 86, midfield: 83, defense: 83, pot: 2),
    CupTeam(name: "Leverkusen", offense: 84, midfield: 84, defense: 83, pot: 2),
    CupTeam(name: "Juventus", offense: 85, midfield: 83, defense: 86, pot: 2),
    CupTeam(name: "Milan", offense: 83, midfield: 85, defense: 84, pot: 2),
    CupTeam(name: "Napoli", offense: 84, midfield: 83, defense: 84, pot: 2),
    CupTeam(name: "Athletico", offense: 80, midfield: 86, defense: 96, pot: 2),
    CupTeam(name: "Man United", offense: 87, midfield: 87, defense: 86, pot: 2),
    CupTeam(name: "Porto", offense: 83, midfield: 80, defense: 80, pot: 2),
    // pot 3
    CupTeam(name: "Atalanta", offense: 80, midfield: 84, defense: 82, pot: 3),
    CupTeam(name: "Sporting", offense: 82, midfield: 84, defense: 83, pot: 3),
    CupTeam(name: "Leipzig", offense: 85, midfield: 82, defense: 83, pot: 3),
    CupTeam(name: "Marseille", offense: 80, midfield: 81, defense: 80, pot: 3),
    CupTeam(name: "Lyon", offense: 82, midfield: 80, defense: 79, pot: 3),
    CupTeam(name: "Benfica", offense: 81, midfield: 80, defense: 78, pot: 3),
    CupTeam(name: "Aston Villa", offense: 83, midfield: 83, defense: 83, pot: 3),
    CupTeam(name: "Newcastle", offense: 85, midfield: 83, defense: 82, pot: 3),
    CupTeam(name: "Lille", offense: 84, midfield: 80, defense: 80, pot: 3),
    // pot 4
    CupTeam(name: "Roma", offense: 80, midfield: 81, defense: 77, pot: 4),
    CupTeam(name: "Benfica", offense: 83, midfield: 80, defense: 80, pot: 4),
    CupTeam(name: "Fenerbache", offense: 81, midfield: 83, defense: 76, pot: 4),
    CupTeam(name: "Monaco", offense: 76, midfield: 75, defense: 81, pot: 4),
    CupTeam(name: "Galatasaray", offense: 81, midfield: 70, defense: 78, pot: 4),
    CupTeam(name: "Brugge", offense: 79, midfield: 80, defense: 78, pot: 4),
    CupTeam(name: "Sevilla", offense: 76, midfield: 80, defense: 80, pot: 4),
    CupTeam(name: "Villareal", offense: 80, midfield: 83, defense: 82, pot: 4),
    CupTeam(name: "Ajax", offense: 84, midfield: 80, defense: 79, pot: 4),
]
