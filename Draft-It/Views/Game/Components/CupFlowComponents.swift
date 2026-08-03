/// CupFlowComponents.swift
///
/// Group stage transition UI and goal-distribution helpers for the Super
/// League cup flow: the completion summary view, an ordinal formatting
/// helper, and weighted random goal/assist assignment logic.

import SwiftUI

/// Summary screen shown after the Super League group stage finishes.
///
/// Displays the player's finishing position, points, goal difference, and
/// whether they qualified for the knockout stage. Used by the cup flow
/// between the group stage and the knockout rounds.
struct CupLeagueCompleteView: View {
    let cupTeams: [CupTeam]
    let standings: [CupStanding]
    let playerTeamId: UUID
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Text("Super League Group Stage Complete")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if let pos = standings.firstIndex(where: { $0.team.id == playerTeamId }) {
                    let position = pos + 1
                    let totalTeams = cupTeams.count
                    let qualified = position <= min(totalTeams, 24)
                    HStack(spacing: 8) {
                        TileView(label: "Finish", value: ordinal(position), color: qualified ? .green : .red)
                        TileView(label: "Pts", value: "\(standings[pos].points)", color: .yellow)
                        TileView(label: "GD", value: gdText(standings[pos].goalDiff), color: standings[pos].goalDiff >= 0 ? .green : .red)
                    }
                    .padding(.horizontal)
                    if qualified {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            Text("Knockout Stage Qualified!")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.green)
                            Text("You advanced from the group stage")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            Text("Eliminated in Group Stage")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.red)
                            Text("Finished \(ordinal(position)) of \(totalTeams)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.top, 40)

            Button(action: onContinue) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal)

            Spacer()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

/// Assigns goals and assists to player names using position-based weights,
/// used to generate individual scoring stats for simulated cup matches.
enum CupGoalDistributor {
    /// Distributes `totalGoals` across `userPlayerNames`, weighted by each
    /// player's position (via `goalWeight`/`assistWeight`) and heavily reduced
    /// for players not in the assigned starting lineup. Each goal has a ~40%
    /// chance of also awarding an assist to a different player.
    static func distribute(totalGoals: Int, userPlayerNames: [String], assignedPlayers: [Int: Player]) -> [String: PlayerSeasonStats] {
        var dict: [String: PlayerSeasonStats] = [:]
        guard !userPlayerNames.isEmpty else { return dict }
        for name in userPlayerNames {
            dict[name] = PlayerSeasonStats(playerName: name)
        }
        let nameList = userPlayerNames
        let assignedNames = Set(assignedPlayers.values.map { $0.name })
        func goalWeightFor(_ name: String) -> Double {
            let isSub = !assignedNames.contains(name)
            let base = assignedPlayers.values.first { $0.name == name }.flatMap { $0.positions.first }.map { goalWeight(for: $0) } ?? 1.0
            return isSub ? base * 0.05 : base
        }
        func assistWeightFor(_ name: String) -> Double {
            let isSub = !assignedNames.contains(name)
            let base = assignedPlayers.values.first { $0.name == name }.flatMap { $0.positions.first }.map { assistWeight(for: $0) } ?? 1.0
            return isSub ? base * 0.05 : base
        }
        for _ in 0..<totalGoals {
            let weights = nameList.map { goalWeightFor($0) }
            let total = weights.reduce(0, +)
            let r = Double.random(in: 0..<total)
            var cum = 0.0
            var scorer = nameList[0]
            for (i, w) in zip(nameList, weights) {
                cum += w
                if r < cum { scorer = i; break }
            }
            dict[scorer, default: PlayerSeasonStats(playerName: scorer)].goals += 1
            let others = nameList.filter { $0 != scorer }
            if !others.isEmpty && Double.random(in: 0...1) < 0.4 {
                let aWeights = others.map { assistWeightFor($0) }
                let aTotal = aWeights.reduce(0, +)
                let aR = Double.random(in: 0..<aTotal)
                var aCum = 0.0
                var assister = others[0]
                for (i, w) in zip(others, aWeights) {
                    aCum += w
                    if aR < aCum { assister = i; break }
                }
                dict[assister, default: PlayerSeasonStats(playerName: assister)].assists += 1
            }
        }
        return dict
    }

    /// Returns the relative likelihood of a player scoring based on position
    /// (strikers highest, goalkeepers essentially never).
    static func goalWeight(for pos: Position) -> Double {
        switch pos {
        case .ST, .CF: return 4.0
        case .LW, .RW: return 3.5
        case .CAM: return 3.0
        case .LM, .RM, .CM: return 2.0
        case .CDM: return 1.0
        case .LB, .RB, .LWB, .RWB: return 0.4
        case .CB: return 0.3
        case .GK: return 0.0
        }
    }

    /// Returns the relative likelihood of a player providing an assist based
    /// on position (attackers and wide players highest).
    static func assistWeight(for pos: Position) -> Double {
        switch pos {
        case .CAM, .LW, .RW: return 3.0
        case .ST, .CF, .LM, .RM, .CM: return 2.0
        case .CDM: return 1.0
        case .LB, .RB, .LWB, .RWB: return 1.5
        case .CB: return 0.3
        case .GK: return 0.02
        }
    }
}
