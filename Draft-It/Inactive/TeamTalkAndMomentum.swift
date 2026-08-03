/// TeamTalkAndMomentum.swift (INACTIVE)
///
/// The removed half-time team-talk feature and the live momentum-bar feature.
/// The team talk lets the player pick an effect (Encourage/Fight/Calm Down)
/// that boosts or reduces second-half goals. The momentum bar visualized which
/// side dominated a live match reveal.
///
/// This folder is excluded from the Draft-It build target
/// (pbxproj membershipExceptions "Inactive/**") and is preserved as reference
/// in case these features return in a future app. It is NOT compiled.
import SwiftUI

// MARK: - Team Talk Effect

/// A half-time team talk choice that nudges the second half of a knockout leg.
enum TeamTalkEffect: String, CaseIterable {
    case none = "No Talk"
    case encourage = "Encourage"
    case fight = "Fight"
    case calm = "Calm Down"

    /// Extra goals the team is given in the second half.
    var secondHalfGoalBoost: Int {
        switch self {
        case .none: return 0
        case .encourage: return 1
        case .fight: return 2
        case .calm: return 0
        }
    }

    /// Goals the opponent is prevented from scoring in the second half.
    var opponentGoalReduction: Int {
        switch self {
        case .none: return 0
        case .encourage: return 0
        case .fight: return 0
        case .calm: return 1
        }
    }

    /// Shot-conversion multiplier for the team receiving the talk in the second half.
    var secondHalfShotMultiplier: Double {
        switch self {
        case .none: return 1.0
        case .encourage: return 1.15
        case .fight: return 1.30
        case .calm: return 1.0
        }
    }

    /// Shot-conversion multiplier applied to the opponent in the second half.
    var secondHalfOpponentShotMultiplier: Double {
        switch self {
        case .none: return 1.0
        case .encourage: return 1.0
        case .fight: return 1.0
        case .calm: return 0.85
        }
    }
}

// MARK: - Team Talk Picker

/// Row of capsule buttons for choosing a team talk effect. Marks `chosen`
/// once the player picks one, visually distinguishing the selected effect.
struct KnockoutTeamTalkPicker: View {
    @Binding var selection: TeamTalkEffect
    @Binding var chosen: Bool

    var body: some View {
        VStack(spacing: 4) {
            Divider()
            Text("Team Talk")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach(TeamTalkEffect.allCases, id: \.rawValue) { effect in
                    Button(effect.rawValue) {
                        selection = effect
                        chosen = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selection == effect ? Color.orange : Color.gray.opacity(0.5))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Team Talk Goal Adjustment

/// Applies a chosen team talk to the second-half goal list: boosts the
/// player's goals and/or removes opponent goals.
/// - Parameters:
///   - effect: The chosen team talk effect.
///   - currentGoals: The full goal event list (mutated in place).
///   - isHome: Whether the player's team is the home side this leg.
///   - leg: The simulated leg (for player names and team ids).
///   - userPlayerNames: The player's starting XI names.
///   - userSubstituteNames: The player's substitute names.
///   - opponentPlayerNames: The AI side's starting XI names.
func applyTeamTalk(
    effect: TeamTalkEffect,
    currentGoals: inout [GoalEvent],
    isHome: Bool,
    leg: SimulatedKnockoutLeg,
    userPlayerNames: [String],
    userSubstituteNames: Set<String>,
    opponentPlayerNames: [String]
) {
    guard effect != .none else { return }
    let playerTeamId = isHome ? leg.homeTeam.id : leg.awayTeam.id

    if effect.secondHalfGoalBoost > 0 {
        let homePlayers = isHome ? (userPlayerNames.isEmpty ? SimulatedKnockoutLeg.squadNames(for: leg.homeTeam.name, count: 11) : userPlayerNames) : opponentPlayerNames
        let subSet = isHome ? userSubstituteNames : []
        for _ in 0..<effect.secondHalfGoalBoost where Double.random(in: 0...1) < 0.5 {
            let minute = Int.random(in: 46...85)
            let scorer = SimulatedKnockoutLeg.weightedRandomElement(from: homePlayers, substitutes: subSet, subWeight: 0.05, defaultName: isHome ? leg.homeTeam.name : leg.awayTeam.name)
            let others = homePlayers.filter { $0 != scorer }
            let assist = Bool.random() && !others.isEmpty ? SimulatedKnockoutLeg.weightedRandomElement(from: others, substitutes: subSet, subWeight: 0.05, defaultName: scorer) : nil
            currentGoals.append(GoalEvent(id: UUID(), minute: minute, scorer: scorer, teamId: playerTeamId, isExtraTime: false, isPenalty: false, assist: assist))
        }
    }
    if effect.opponentGoalReduction > 0 {
        let oppTeamId = isHome ? leg.awayTeam.id : leg.homeTeam.id
        let oppSecondHalfGoals = currentGoals.filter { $0.teamId == oppTeamId && $0.minute > 45 }
        for _ in 0..<effect.opponentGoalReduction {
            if let target = oppSecondHalfGoals.randomElement(), Double.random(in: 0...1) < 0.3 {
                currentGoals.removeAll { $0.id == target.id }
            }
        }
    }
    currentGoals.sort { $0.minute < $1.minute }
}

// MARK: - Momentum Bar

/// Horizontal momentum indicator, with the marker sliding between the two
/// team abbreviations based on a -1...1 momentum value. Visualizes which side
/// currently dominates during knockout match reveals and shootouts.
struct MomentumBar: View {
    let homeName: String
    let awayName: String
    let momentum: Double

    private var homeColor: Color { teamColor(named: homeName) }
    private var awayColor: Color { teamColor(named: awayName) }

    var body: some View {
        let share = (momentum + 1) / 2
        VStack(spacing: 2) {
            Text("MOMENTUM")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
            HStack(spacing: 6) {
                Text(String(homeName.prefix(3)).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(homeColor)
                    .frame(width: 28, alignment: .leading)
                GeometryReader { geo in
                    ZStack {
                        Capsule().fill(awayColor.opacity(0.45))
                        Capsule().fill(homeColor.opacity(0.45))
                            .frame(width: geo.size.width * share, alignment: .leading)
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .shadow(radius: 1)
                            .position(x: geo.size.width * share, y: geo.size.height / 2)
                    }
                }
                .frame(height: 12)
                Text(String(awayName.prefix(3)).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(awayColor)
                    .frame(width: 28, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .animation(.easeOut(duration: 0.4), value: momentum)
    }
}

// MARK: - Live Momentum Value

/// Live momentum value (-1...1) for the reveal: a rating-based baseline pull
/// toward the stronger side plus recent goals/cards and a small per-minute
/// drift, so the bar visibly favors whichever team is on top.
func derivedMomentum(
    opponent: CupTeam?,
    playerTeam: CupTeam,
    currentLegIndex: Int,
    currentMinute: Int,
    currentGoals: [GoalEvent],
    currentLegData: SimulatedKnockoutLeg?
) -> Double {
    let isLeg2 = currentLegIndex == 1
    guard let opp = opponent else { return 0 }
    let hTeam = isLeg2 ? opp : playerTeam
    let hId = hTeam.id

    let hStrength = Double(hTeam.offense) * 0.5 + Double(hTeam.midfield) * 0.3 + Double(hTeam.defense) * 0.2
    let aStrength = Double(opp.offense) * 0.5 + Double(opp.midfield) * 0.3 + Double(opp.defense) * 0.2
    let strengthPull = (hStrength - aStrength) / max(hStrength + aStrength, 1) * 0.5

    let windowStart = max(0, currentMinute - 8)
    var m = strengthPull
    for g in currentGoals where g.minute > windowStart && g.minute <= currentMinute {
        m += g.teamId == hId ? 0.35 : -0.35
    }
    if let leg = currentLegData {
        for c in (leg.cards + leg.etCards) where c.minute > windowStart && c.minute <= currentMinute {
            m += c.teamId == hId ? -0.12 : 0.12
        }
    }
    // Per-minute drift so the marker is never frozen in the center.
    m += (Double((currentMinute % 7) - 3) / 20.0)
    m *= 0.9
    return max(-1, min(1, m))
}
