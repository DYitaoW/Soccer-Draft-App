/// Teams.swift
///
/// Static opponent data. Defines `leagueTeams`, the Premier League clubs the
/// user faces each season, and `superLeagueTeams`, the seeded European clubs
/// used for the Super League cup competition.
import Foundation

/// The Premier League opponents with offense, midfield, and defense ratings.
let leagueTeams: [Team] = [
    Team(name: "Arsenal", offense: 84, midfield: 87, defense: 88),
    Team(name: "Chelsea", offense: 84, midfield: 86, defense: 85),
    Team(name: "Man United", offense: 83, midfield: 82, defense: 81),
    Team(name: "Man City", offense: 87, midfield: 85, defense: 87),
    Team(name: "Liverpool", offense: 84, midfield: 84, defense: 83),
    Team(name: "Spurs", offense: 80, midfield: 80, defense: 81),
    Team(name: "Aston Villa", offense: 82, midfield: 81, defense: 82),
    Team(name: "Bournemouth", offense: 79, midfield: 82, defense: 80),
    Team(name: "Sunderland", offense: 79, midfield: 77, defense: 75),
    Team(name: "Brighton", offense: 80, midfield: 82, defense: 80),
    Team(name: "Fulham", offense: 80, midfield: 78, defense: 80),
    Team(name: "Brentford", offense: 79, midfield: 80, defense: 78),
    Team(name: "Newcastle", offense: 81, midfield: 81, defense: 82),
    Team(name: "Everton", offense: 80, midfield: 80, defense: 78),
    Team(name: "Leeds", offense: 80, midfield: 77, defense: 78),
    Team(name: "Palace", offense: 78, midfield: 80, defense: 80),
    Team(name: "Ipswich", offense: 75, midfield: 74, defense: 74),
    Team(name: "Coventry", offense: 72, midfield: 74, defense: 72),
    Team(name: "Forest", offense: 78, midfield: 80, defense: 78),
    Team(name: "Hull", offense: 72, midfield: 73, defense: 73)
   // Team(name: "Wolves", offense: 78, midfield: 78, defense: 78),
]

// MARK: - Cup Competition Teams
// Fill in the stats for each team. pot values: 1 = strongest, 4 = weakest.
// The draw picks 2 opponents from each pot (8 games total, 4H/4A).

/// The Super League cup competition teams, seeded into pots 1-4 by strength
/// (1 = strongest, 4 = weakest). The draw picks opponents from these pots.
let superLeagueTeams: [CupTeam] = [
    // pot 1
    CupTeam(name: "Arsenal", offense: 86, midfield: 86, defense: 88, pot: 1),
    CupTeam(name: "Barcelona", offense: 87, midfield: 85, defense: 80, pot: 1),
    CupTeam(name: "Real Madrid", offense: 87, midfield: 86, defense: 86, pot: 1),
    CupTeam(name: "Bayern", offense: 88, midfield: 87, defense: 84, pot: 1),
    CupTeam(name: "PSG", offense: 89, midfield: 88, defense: 92, pot: 1),
    CupTeam(name: "Inter", offense: 82, midfield: 84, defense: 86, pot: 1),
    CupTeam(name: "Liverpool", offense: 85, midfield: 83, defense: 85, pot: 1),
    CupTeam(name: "Man City", offense: 87, midfield: 85, defense: 85, pot: 1),
    CupTeam(name: "Chelsea", offense: 85, midfield: 85, defense: 81, pot: 1),
    // pot 2
    CupTeam(name: "Spurs", offense: 80, midfield: 84, defense: 82, pot: 2),
    CupTeam(name: "Dortmund", offense: 81, midfield: 83, defense: 85, pot: 2),
    CupTeam(name: "Leverkusen", offense: 83, midfield: 84, defense: 81, pot: 2),
    CupTeam(name: "Juventus", offense: 83, midfield: 82, defense: 83, pot: 2),
    CupTeam(name: "Milan", offense: 83, midfield: 81, defense: 81, pot: 2),
    CupTeam(name: "Napoli", offense: 82, midfield: 82, defense: 81, pot: 2),
    CupTeam(name: "Atletico", offense: 82, midfield: 83, defense: 86, pot: 2),
    CupTeam(name: "Man United", offense: 83, midfield: 81, defense: 83, pot: 2),
    CupTeam(name: "Newcastle", offense: 80, midfield: 82, defense: 81, pot: 2),
    // pot 3
    CupTeam(name: "Atalanta", offense: 80, midfield: 81, defense: 84, pot: 3),
    CupTeam(name: "Ajax", offense: 80, midfield: 81, defense: 83, pot: 3),
    CupTeam(name: "Leipzig", offense: 82, midfield: 81, defense: 81, pot: 3),
    CupTeam(name: "Marseille", offense: 80, midfield: 82, defense: 81, pot: 3),
    CupTeam(name: "Lyon", offense: 80, midfield: 81, defense: 80, pot: 3),
    CupTeam(name: "Benfica", offense: 81, midfield: 83, defense: 82, pot: 3),
    CupTeam(name: "Aston Villa", offense: 80, midfield: 84, defense: 84, pot: 3),
    CupTeam(name: "Porto", offense: 80, midfield: 82, defense: 83, pot: 3),
    CupTeam(name: "Lille", offense: 78, midfield: 80, defense: 78, pot: 3),
    // pot 4
    CupTeam(name: "Roma", offense: 80, midfield: 79, defense: 80, pot: 4),
    CupTeam(name: "Feyenoord", offense: 78, midfield: 80, defense: 79, pot: 4),
    CupTeam(name: "Fenerbahce", offense: 79, midfield: 80, defense: 78, pot: 4),
    CupTeam(name: "Monaco", offense: 80, midfield: 79, defense: 80, pot: 4),
    CupTeam(name: "Galatasaray", offense: 78, midfield: 76, defense: 80, pot: 4),
    CupTeam(name: "Brugge", offense: 80, midfield: 81, defense: 80, pot: 4),
    CupTeam(name: "Sevilla", offense: 78, midfield: 81, defense: 82, pot: 4),
    CupTeam(name: "Villarreal", offense: 81, midfield: 80, defense: 83, pot: 4),
    CupTeam(name: "Sporting", offense: 83, midfield: 80, defense: 81, pot: 4),
]
