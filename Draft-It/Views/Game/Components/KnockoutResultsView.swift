/// KnockoutResultsView.swift
///
/// Result breakdown views for single-leg (final) and two-leg knockout ties,
/// including scorers, player ratings, extra time/penalty indicators, and
/// aggregate advance logic.

import SwiftUI

/// Full result card for a single-leg final. Shows the combined regulation +
/// extra time score, penalty result after extra time, champion/runner-up
/// label, scorers, and player ratings. Used by the final's result screen.
struct KnockoutFinalResultView: View {
    let playerTeam: CupTeam
    let opponent: CupTeam?
    let playerTeamId: UUID
    let leg1: SimulatedKnockoutLeg?

    /// Player team's total across regulation and extra time.
    private var totalH: Int {
        (leg1?.homeScore ?? 0) + (leg1?.etHomeScore ?? 0)
    }

    /// Opponent team's total across regulation and extra time.
    private var totalA: Int {
        (leg1?.awayScore ?? 0) + (leg1?.etAwayScore ?? 0)
    }

    var body: some View {
        let hS = leg1?.homeScore ?? 0
        let aS = leg1?.awayScore ?? 0
        let hET = leg1?.etHomeScore ?? 0
        let aET = leg1?.etAwayScore ?? 0
        let hPen = leg1?.penaltyHome ?? 0
        let aPen = leg1?.penaltyAway ?? 0

        return VStack(spacing: 12) {
            Text("Final Score")
                .font(.title2.weight(.bold))

            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text(playerTeam.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(teamColor(named: playerTeam.name))
                        .lineLimit(1)
                    Text("\(totalH)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(totalH > totalA ? .green : .primary)
                }
                .frame(maxWidth: .infinity)

                Text("-")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(spacing: 4) {
                    Text(opponent?.name ?? "")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(teamColor(named: opponent?.name ?? ""))
                        .lineLimit(1)
                    Text("\(totalA)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(totalA > totalH ? .green : .primary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if hS == aS && hET == aET && hPen > 0 {
                HStack(spacing: 8) {
                    Text("Penalties:")
                        .font(.subheadline.weight(.semibold))
                    Text("\(hPen)-\(aPen)")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            } else if hS == aS {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamation")
                        .foregroundColor(.orange)
                    Text("After Extra Time")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }

            if let l1 = leg1, !l1.penaltyKicks.isEmpty {
                KnockoutPenaltyKicksList(homeTeam: playerTeam, awayTeam: opponent ?? playerTeam, kicks: l1.penaltyKicks)
            }

            if totalH > totalA {
                Label("Champions!", systemImage: "trophy.fill")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.yellow)
                    .padding(.vertical, 8)
            } else {
                Label("Runner-up", systemImage: "medal.fill")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            }

            if let l1 = leg1, !l1.goals.isEmpty || !l1.etGoals.isEmpty {
                KnockoutScorersListView(
                    leg: l1,
                    playerTeamName: playerTeam.name,
                    opponentName: opponent?.name ?? "",
                    playerTeamId: playerTeamId
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

/// Two-column scorer list for a knockout leg, splitting goals by player team
/// and annotating penalties and extra-time goals.
struct KnockoutScorersListView: View {
    let leg: SimulatedKnockoutLeg
    let playerTeamName: String
    let opponentName: String
    let playerTeamId: UUID

    var body: some View {
        VStack(spacing: 6) {
            Text("Scorers")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(playerTeamName)
                        .font(.caption.weight(.bold))
                        .foregroundColor(teamColor(named: playerTeamName))
                    ForEach(leg.goals + leg.etGoals) { g in
                        if g.teamId == playerTeamId {
                            Text("\(g.minute)' \(g.scorer)\(g.isPenalty ? " (P)" : "")\(g.isExtraTime ? " ET" : "")")
                                .font(.system(size: 11))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(opponentName)
                        .font(.caption.weight(.bold))
                        .foregroundColor(teamColor(named: opponentName))
                    ForEach(leg.goals + leg.etGoals) { g in
                        if g.teamId != playerTeamId {
                            Text("\(g.minute)' \(g.scorer)\(g.isPenalty ? " (P)" : "")\(g.isExtraTime ? " ET" : "")")
                                .font(.system(size: 11))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)
        }
    }
}

/// Two-column player ratings table, one column per team, sorted by rating and
/// color-coded by performance band. Used by the archived live-match results.
struct KnockoutRatingsSection: View {
    let ratings: [PlayerMatchPerformance]
    let playerTeamId: UUID
    let playerTeamName: String
    let opponentName: String

    var body: some View {
        let playerRatings = ratings.filter { $0.teamId == playerTeamId }.sorted { ratingSort($0, $1) }
        let oppRatings = ratings.filter { $0.teamId != playerTeamId }.sorted { ratingSort($0, $1) }
        VStack(spacing: 6) {
            Text("Player Ratings")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(alignment: .top, spacing: 12) {
                column(playerRatings, name: playerTeamName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                column(oppRatings, name: opponentName)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 12)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }

    private func ratingSort(_ a: PlayerMatchPerformance, _ b: PlayerMatchPerformance) -> Bool {
        if a.rating != b.rating { return a.rating > b.rating }
        if a.goals != b.goals { return a.goals > b.goals }
        return a.assists > b.assists
    }

    private func ratingColor(_ r: Double) -> Color {
        if r >= 8.5 { return .green }
        if r >= 7.5 { return .blue }
        if r >= 6.5 { return .primary }
        if r >= 5.5 { return .orange }
        if r >= 4.0 { return .red }
        return .purple
    }

    @ViewBuilder
    private func column(_ list: [PlayerMatchPerformance], name: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption.weight(.bold))
                .foregroundColor(teamColor(named: name))
                .lineLimit(1)
            ForEach(list.prefix(11)) { p in
                HStack(spacing: 3) {
                    Text(p.name)
                        .font(.system(size: 10))
                        .lineLimit(1)
                    if p.goals > 0 { Text("G\(p.goals)").font(.system(size: 8, weight: .bold)).foregroundColor(.green) }
                    if p.assists > 0 { Text("A\(p.assists)").font(.system(size: 8, weight: .bold)).foregroundColor(.blue) }
                    Spacer(minLength: 2)
                    Text(String(format: "%.1f", p.rating))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ratingColor(p.rating))
                }
            }
        }
    }
}

/// Result card for a two-leg knockout tie. Shows both leg scores, the
/// aggregate, who advances (falling back to `aggregateTiebreakerWon` when
/// level), a penalties section if needed, and per-leg goals.
struct KnockoutTwoLegResultView: View {    let playerTeam: CupTeam
    let opponent: CupTeam?
    let playerTeamId: UUID
    let leg1: SimulatedKnockoutLeg?
    let leg2: SimulatedKnockoutLeg?
    let aggregateTiebreakerWon: Bool

    /// Computes the aggregate scores and winner, then renders the full
    /// two-leg result card. Returns an empty view if either leg is missing.
    private var resultContent: some View {
        guard let l1 = leg1, let l2 = leg2 else {
            return AnyView(EmptyView())
        }

        let score1A = l1.totalHomeScore
        let score1B = l1.totalAwayScore
        let score2A = l2.totalAwayScore
        let score2B = l2.totalHomeScore
        let totalA = score1A + score2A
        let totalB = score1B + score2B

        var isPlayerWinner = false
        let winnerName: String
        if totalA > totalB {
            isPlayerWinner = true
            winnerName = playerTeam.name
        } else if totalB > totalA {
            isPlayerWinner = false
            winnerName = opponent?.name ?? ""
        } else {
            isPlayerWinner = aggregateTiebreakerWon
            winnerName = isPlayerWinner ? playerTeam.name : (opponent?.name ?? "")
        }

        return AnyView(
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text("Leg 1")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text("\(score1A)-\(score1B)")
                            .font(.title2.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(spacing: 2) {
                        Text("Leg 2")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text("\(score2A)-\(score2B)")
                            .font(.title2.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Text("Aggregate: \(totalA)-\(totalB)")
                    .font(.title2.weight(.bold))

                HStack(spacing: 4) {
                    Image(systemName: isPlayerWinner ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isPlayerWinner ? .green : .red)
                    Text("\(winnerName) advances")
                        .font(.headline)
                        .foregroundColor(isPlayerWinner ? .green : .red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background((isPlayerWinner ? Color.green : Color.red).opacity(0.12))
                .clipShape(Capsule())

                if l2.neededPenalties && totalA == totalB && !l2.penaltyKicks.isEmpty {
                    VStack(spacing: 8) {
                        Text("Penalties decided it")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.orange)
                        Text("\(l2.penaltyHome)-\(l2.penaltyAway)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.orange)
                        KnockoutPenaltyKicksList(homeTeam: l2.homeTeam, awayTeam: l2.awayTeam, kicks: l2.penaltyKicks)
                    }
                }

                if let l = leg1, !l.goals.isEmpty || !l.etGoals.isEmpty {
                    KnockoutTwoLegGoalsList(leg: l, label: "Leg 1", playerTeamId: playerTeamId)
                }
                if let l = leg2, !l.goals.isEmpty || !l.etGoals.isEmpty {
                    KnockoutTwoLegGoalsList(leg: l, label: "Leg 2", playerTeamId: playerTeamId)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        )
    }

    var body: some View {
        resultContent
    }
}

/// Per-leg goal list for a two-leg tie, split by team, annotating penalties
/// and extra-time goals. Shown under each leg score in the aggregate result.
struct KnockoutTwoLegGoalsList: View {
    let leg: SimulatedKnockoutLeg
    let label: String
    let playerTeamId: UUID

    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundColor(.secondary)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(leg.goals + leg.etGoals) { g in
                        if g.teamId == playerTeamId {
                            Text("\(g.minute)' \(g.scorer)\(g.isPenalty ? " (P)" : "")\(g.isExtraTime ? " ET" : "")")
                                .font(.system(size: 10))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(leg.goals + leg.etGoals) { g in
                        if g.teamId != playerTeamId {
                            Text("\(g.minute)' \(g.scorer)\(g.isPenalty ? " (P)" : "")\(g.isExtraTime ? " ET" : "")")
                                .font(.system(size: 10))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)
        }
    }
}
