/// Mentality.swift (INACTIVE)
///
/// The removed tactical-mentality feature: the `MatchMentality` stance enum,
/// its attacking/defensive multiplier math, the picker UI, and the half-time
/// mentality re-selection + second-half goal adjustment logic.
///
/// This folder is excluded from the Draft-It build target
/// (pbxproj membershipExceptions "Inactive/**") and is preserved as reference
/// in case the feature returns in a future app. It is NOT compiled.
import SwiftUI

// MARK: - Match Mentality

/// A tactical stance that scales a team's attacking and defensive output.
enum MatchMentality: String, CaseIterable, Codable {
    case allOutDefense = "All Out Defense"
    case defensive = "Defensive"
    case balanced = "Balanced"
    case attacking = "Attacking"
    case allOutAttack = "All Out Attack"

    /// Multiplier applied to this team's attacking output.
    var offensiveMultiplier: Double {
        switch self {
        case .allOutDefense: return 0.70
        case .defensive: return 0.85
        case .balanced: return 1.0
        case .attacking: return 1.15
        case .allOutAttack: return 1.30
        }
    }

    /// Multiplier applied to this team's defensive output.
    var defensiveMultiplier: Double {
        switch self {
        case .allOutDefense: return 1.20
        case .defensive: return 1.10
        case .balanced: return 1.0
        case .attacking: return 0.90
        case .allOutAttack: return 0.80
        }
    }

    /// Multiplier applied to the opponent's attacking output.
    var opponentOffensiveMultiplier: Double {
        switch self {
        case .allOutDefense: return 1.10
        case .defensive: return 1.05
        case .balanced: return 1.0
        case .attacking: return 1.10
        case .allOutAttack: return 1.20
        }
    }

    /// Multiplier applied to the opponent's defensive output.
    var opponentDefensiveMultiplier: Double {
        switch self {
        case .allOutDefense: return 0.90
        case .defensive: return 0.95
        case .balanced: return 1.0
        case .attacking: return 0.90
        case .allOutAttack: return 0.85
        }
    }
}

// MARK: - Mentality Label / Color Helpers

/// Returns the short display label for a match mentality ("All D", "Def", ...).
/// - Parameter m: The match mentality.
/// - Returns: Its short label.
func mentalityLabel(_ m: MatchMentality) -> String {
    switch m { case .allOutDefense: "All D" case .defensive: "Def" case .balanced: "Bal" case .attacking: "Att" case .allOutAttack: "All A" }
}

/// Returns the accent color used for a match mentality.
/// - Parameter m: The match mentality.
/// - Returns: Its accent color.
func mentalityColor(_ m: MatchMentality) -> Color {
    switch m { case .allOutDefense: .red case .defensive: .orange case .balanced: .blue case .attacking: .green case .allOutAttack: .yellow }
}

// MARK: - Mentality Picker Row

/// Horizontal row of buttons for choosing the match mentality, highlighting
/// the currently selected option. Used in knockout intro and break screens.
struct KnockoutMentalityRow: View {
    @Binding var selection: MatchMentality

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MatchMentality.allCases, id: \.self) { m in
                Button(action: { selection = m }) {
                    Text(mentalityLabel(m))
                        .font(.system(size: 11, weight: selection == m ? .bold : .regular))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(selection == m ? mentalityColor(m).opacity(0.25) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection == m ? mentalityColor(m) : Color(.separator), lineWidth: selection == m ? 2 : 1))
                        .foregroundColor(selection == m ? mentalityColor(m) : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Simulated Leg Mentality Multipliers

/// Applies mentality multipliers to both sides' base ratings and returns the
/// effective home/away attacking and defensive values for a simulated leg.
/// - Parameters:
///   - home: The home team.
///   - away: The away team.
///   - homeMentality: The home side's chosen stance.
///   - awayMentality: The away side's chosen stance.
/// - Returns: Tuples `(homeOff, homeDef, awayOff, awayDef)` after multipliers.
func mentalityAdjustedRatings(
    home: CupTeam,
    away: CupTeam,
    homeMentality: MatchMentality,
    awayMentality: MatchMentality
) -> (Double, Double, Double, Double) {
    let homeOffMul = homeMentality.offensiveMultiplier * awayMentality.opponentOffensiveMultiplier
    let homeDefMul = homeMentality.defensiveMultiplier * awayMentality.opponentDefensiveMultiplier
    let awayOffMul = awayMentality.offensiveMultiplier * homeMentality.opponentOffensiveMultiplier
    let awayDefMul = awayMentality.defensiveMultiplier * homeMentality.opponentDefensiveMultiplier

    let baseHomeOff = Double(home.offense) * 0.50 + Double(home.midfield) * 0.30 + Double(home.defense) * 0.20
    let baseHomeDef = Double(home.defense) * 0.50 + Double(home.midfield) * 0.30 + Double(home.offense) * 0.20
    let baseAwayOff = Double(away.offense) * 0.50 + Double(away.midfield) * 0.30 + Double(away.defense) * 0.20
    let baseAwayDef = Double(away.defense) * 0.50 + Double(away.midfield) * 0.30 + Double(away.offense) * 0.20

    return (
        baseHomeOff * homeOffMul,
        baseHomeDef * homeDefMul,
        baseAwayOff * awayOffMul,
        baseAwayDef * awayDefMul
    )
}

// MARK: - Half-Time Mentality Picker

/// Second-half mentality picker shown at the half-time break of a knockout
/// match, alongside the team-talk picker.
struct KnockoutHTMentalityPicker: View {
    @Binding var playerMentality: MatchMentality

    var body: some View {
        VStack(spacing: 4) {
            Text("Second Half Mentality")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            KnockoutMentalityRow(selection: $playerMentality)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Second-Half Mentality Goal Adjustment

/// Mutates the second-half goal list based on the player's chosen half-time
/// mentality: attacking stances add extra player goals, defensive stances can
/// remove an opponent goal.
/// - Parameters:
///   - currentGoals: The full goal event list (mutated).
///   - shownGoals: Goals revealed so far (updated alongside `currentGoals`).
///   - adj: `offensiveMultiplier - 1.0` for the chosen mentality.
///   - isHome: Whether the player's team is the home side this leg.
///   - leg: The simulated leg (for player names and team ids).
///   - userPlayerNames: The player's starting XI names.
///   - userSubstituteNames: The player's substitute names.
///   - opponentPlayerNames: The AI side's starting XI names.
func applySecondHalfMentality(
    currentGoals: inout [GoalEvent],
    shownGoals: inout [GoalEvent],
    adj: Double,
    isHome: Bool,
    leg: SimulatedKnockoutLeg,
    userPlayerNames: [String],
    userSubstituteNames: Set<String>,
    opponentPlayerNames: [String]
) {
    guard abs(adj) > 0.01 else { return }
    let halfTimeGoals = currentGoals.filter { $0.minute <= 45 }
    let secondHalfGoals = currentGoals.filter { $0.minute > 45 }
    currentGoals = halfTimeGoals
    shownGoals = halfTimeGoals

    let playerTeamId = isHome ? leg.homeTeam.id : leg.awayTeam.id

    if adj > 0 {
        let extra = Int(adj * 2.5)
        let homePlayers = isHome ? (userPlayerNames.isEmpty ? SimulatedKnockoutLeg.squadNames(for: leg.homeTeam.name, count: 11) : userPlayerNames) : opponentPlayerNames
        let subSet = isHome ? userSubstituteNames : []
        for _ in 0..<extra where Double.random(in: 0...1) < 0.35 {
            let minute = Int.random(in: 46...85)
            let scorer = SimulatedKnockoutLeg.weightedRandomElement(from: homePlayers, substitutes: subSet, subWeight: 0.05, defaultName: isHome ? leg.homeTeam.name : leg.awayTeam.name)
            let others = homePlayers.filter { $0 != scorer }
            let assist = Bool.random() && !others.isEmpty ? SimulatedKnockoutLeg.weightedRandomElement(from: others, substitutes: subSet, subWeight: 0.05, defaultName: scorer) : nil
            currentGoals.append(GoalEvent(id: UUID(), minute: minute, scorer: scorer, teamId: playerTeamId, isExtraTime: false, isPenalty: false, assist: assist))
        }
    } else if adj < 0 {
        let oppTeamId = isHome ? leg.awayTeam.id : leg.homeTeam.id
        let oppGoals = secondHalfGoals.filter { $0.teamId == oppTeamId }
        if let target = oppGoals.randomElement(), Double.random(in: 0...1) < 0.2 {
            currentGoals.removeAll { $0.id == target.id }
        }
    }

    currentGoals.sort { $0.minute < $1.minute }
}
