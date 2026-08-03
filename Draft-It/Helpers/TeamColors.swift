/// TeamColors.swift
///
/// Maps club names to their brand colors. Provides primary and secondary
/// colors for team UI elements, with alias handling for alternate names and
/// a global convenience function.
import SwiftUI

/// Returns the primary brand color for a team name.
/// - Parameter name: The team's name.
/// - Returns: The team's primary color, or gray if unknown.
func teamColor(named name: String) -> Color {
    TeamColors.color(for: name)
}

/// Namespace for team color lookup. Holds the primary and secondary color
/// tables plus aliases so alternate club names resolve to the same colors.
struct TeamColors {
    /// Returns the primary brand color for a team, resolving aliases and
    /// falling back to gray for unknown teams.
    /// - Parameter name: The team's name.
    /// - Returns: The team's primary color.
    static func color(for name: String) -> Color {
        alias[name] ?? primary[name] ?? .gray
    }

    /// Returns the secondary (accent) color for a team, falling back to a
    /// translucent gray for unknown teams.
    /// - Parameter name: The team's name.
    /// - Returns: The team's secondary color.
    static func secondaryColor(for name: String) -> Color {
        aliasSecondary[name] ?? secondary[name] ?? .gray.opacity(0.5)
    }

    /// Maps alternate club names to the canonical primary color entries.
    private static let alias: [String: Color] = [
        "Atletico": primary["Athletico"]!,
        "RB Leipzig": primary["Leipzig"]!,
        "Athletic Club": primary["Athletico"]!,
        "Inter Milan": primary["Inter"]!,
        "AC Milan": primary["Milan"]!,
        "Bayern Munich": primary["Bayern"]!,
        "Villarreal": primary["Villareal"]!,
        "Fenerbahce": primary["Fenerbache"]!,
    ]

    /// Maps alternate club names to the canonical secondary color entries.
    private static let aliasSecondary: [String: Color] = [
        "Atletico": .white,
        "RB Leipzig": .white,
    ]

    /// The primary color table for every known team.
    static let primary: [String: Color] = [
        "Arsenal": Color(red: 0.96, green: 0.20, blue: 0.20),
        "Aston Villa": Color(red: 0.46, green: 0.12, blue: 0.42),
        "Bournemouth": Color(red: 0.87, green: 0.15, blue: 0.15),
        "Brentford": Color(red: 0.87, green: 0.15, blue: 0.15),
        "Brighton": Color(red: 0.0, green: 0.48, blue: 0.73),
        "Chelsea": Color(red: 0.03, green: 0.23, blue: 0.62),
        "Coventry": Color(red: 0.0, green: 0.60, blue: 0.80),
        "Everton": Color(red: 0.0, green: 0.10, blue: 0.35),
        "Forest": Color(red: 0.87, green: 0.15, blue: 0.15),
        "Fulham": Color(red: 0.85, green: 0.85, blue: 0.85),
        "Hull": Color(red: 0.97, green: 0.70, blue: 0.0),
        "Ipswich": Color(red: 0.0, green: 0.25, blue: 0.55),
        "Leeds": Color(red: 1.0, green: 0.70, blue: 0.0),
        "Liverpool": Color(red: 0.92, green: 0.11, blue: 0.14),
        "Man City": Color(red: 0.42, green: 0.70, blue: 0.84),
        "Man United": Color(red: 0.90, green: 0.08, blue: 0.15),
        "Newcastle": Color(red: 0.15, green: 0.15, blue: 0.15),
        "Palace": Color(red: 0.0, green: 0.14, blue: 0.37),
        "Sunderland": Color(red: 0.87, green: 0.15, blue: 0.05),
        "Spurs": Color(red: 0.10, green: 0.10, blue: 0.25),
        "Wolves": Color(red: 0.97, green: 0.74, blue: 0.0),
        "Barcelona": Color(red: 0.0, green: 0.0, blue: 0.60),
        "Real Madrid": Color(red: 0.95, green: 0.95, blue: 0.98),
        "Bayern": Color(red: 0.85, green: 0.0, blue: 0.15),
        "Dortmund": Color(red: 0.97, green: 0.75, blue: 0.0),
        "Leverkusen": Color(red: 0.87, green: 0.15, blue: 0.20),
        "Leipzig": Color(red: 0.85, green: 0.0, blue: 0.15),
        "PSG": Color(red: 0.0, green: 0.0, blue: 0.40),
        "Marseille": Color(red: 0.0, green: 0.20, blue: 0.80),
        "Lyon": Color(red: 0.85, green: 0.0, blue: 0.20),
        "Monaco": Color(red: 0.85, green: 0.85, blue: 0.10),
        "Lille": Color(red: 0.92, green: 0.11, blue: 0.14),
        "Inter": Color(red: 0.0, green: 0.0, blue: 0.35),
        "Milan": Color(red: 0.87, green: 0.0, blue: 0.05),
        "Juventus": Color(red: 0.15, green: 0.15, blue: 0.15),
        "Napoli": Color(red: 0.0, green: 0.35, blue: 0.80),
        "Lazio": Color(red: 0.30, green: 0.60, blue: 0.90),
        "Bologna": Color(red: 0.52, green: 0.05, blue: 0.18),
        "Eintracht Frankfurt": Color(red: 0.80, green: 0.0, blue: 0.10),
        "Celtic": Color(red: 0.0, green: 0.45, blue: 0.20),
        "Roma": Color(red: 0.87, green: 0.12, blue: 0.12),
        "Atalanta": Color(red: 0.0, green: 0.0, blue: 0.60),
        "Athletico": Color(red: 0.87, green: 0.12, blue: 0.12),
        "Sevilla": Color(red: 0.85, green: 0.0, blue: 0.10),
        "Villareal": Color(red: 0.97, green: 0.74, blue: 0.0),
        "Villarreal": Color(red: 0.97, green: 0.74, blue: 0.0),
        "Porto": Color(red: 0.0, green: 0.25, blue: 0.70),
        "Benfica": Color(red: 0.87, green: 0.0, blue: 0.05),
        "Sporting": Color(red: 0.0, green: 0.45, blue: 0.20),
        "Ajax": Color(red: 0.87, green: 0.12, blue: 0.16),
        "Feyenoord": Color(red: 0.87, green: 0.12, blue: 0.16),
        "PSV": Color(red: 0.87, green: 0.0, blue: 0.10),
        "Brugge": Color(red: 0.0, green: 0.25, blue: 0.75),
        "Galatasaray": Color(red: 0.97, green: 0.70, blue: 0.0),
        "Fenerbache": Color(red: 0.97, green: 0.70, blue: 0.0),
        "Fenerbahce": Color(red: 0.97, green: 0.70, blue: 0.0),
        "Como": Color(red: 0.0, green: 0.35, blue: 0.65),
        "Global Superstars": Color(red: 1.0, green: 0.84, blue: 0.0),
        "Past Legends": Color(red: 0.50, green: 0.50, blue: 0.50),
        "Upgraded Players": Color(red: 0.55, green: 0.30, blue: 0.85),
    ]

    /// The secondary (accent) color table for select teams.
    private static let secondary: [String: Color] = [
        "Arsenal": .white,
        "Chelsea": .white,
        "Man United": .white,
        "Liverpool": .white,
        "Barcelona": Color(red: 0.75, green: 0.05, blue: 0.15),
        "Real Madrid": Color(red: 0.0, green: 0.10, blue: 0.60),
        "Bayern": Color(red: 0.0, green: 0.0, blue: 0.50),
        "PSG": Color(red: 0.87, green: 0.12, blue: 0.20),
        "Juventus": .white,
        "Milan": .white,
        "Inter": Color(red: 0.0, green: 0.0, blue: 0.50),
        "Ajax": .white,
        "Lazio": .white,
        "Bologna": .white,
        "Celtic": .white,
    ]
}
