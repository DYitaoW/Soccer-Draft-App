/// LiveKnockoutResults.swift
///
/// Full-time summary screens for live-simulated knockout matches: final
/// score with extra time/penalties, scorers, cards, player ratings, and
/// per-team match statistics.

import SwiftUI

/// Full-time result screen for a live knockout match. Shows the final score
/// (including extra time), penalty result with kick list, then delegates to
/// the goals, cards, ratings, and stats summary sections, plus a Continue
/// button via `onComplete`.
struct LiveKnockoutFinishedView: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    @ObservedObject var match: LiveKnockoutMatch
    let onComplete: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                let tH = match.homeScore + match.etHomeScore
                let tA = match.awayScore + match.etAwayScore
                Text("Full Time").font(.largeTitle.weight(.bold)).padding(.top, 24)

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        VStack(spacing: 2) {
                            Text(homeTeam.name).font(.headline.weight(.bold)).foregroundColor(teamColor(named: homeTeam.name))
                            Text("\(tH)").font(.system(size: 48, weight: .bold))
                                .foregroundColor(tH > tA ? .green : tH < tA ? .red : .primary)
                        }.frame(maxWidth: .infinity)
                        Text("-").font(.system(size: 36, weight: .bold)).foregroundColor(.secondary)
                        VStack(spacing: 2) {
                            Text(awayTeam.name).font(.headline.weight(.bold)).foregroundColor(teamColor(named: awayTeam.name))
                            Text("\(tA)").font(.system(size: 48, weight: .bold))
                                .foregroundColor(tA > tH ? .green : tA < tH ? .red : .primary)
                        }.frame(maxWidth: .infinity)
                    }

                    if match.etHomeScore > 0 || match.etAwayScore > 0 {
                        Text("After Extra Time").font(.subheadline.weight(.semibold)).foregroundColor(.orange)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15)).clipShape(Capsule())
                    }
                    if match.penaltyHome > 0 || match.penaltyAway > 0 {
                        HStack(spacing: 6) {
                            Text("Penalties:").font(.subheadline.weight(.semibold))
                            Text("\(match.penaltyHome)-\(match.penaltyAway)").font(.title3.weight(.bold)).foregroundColor(.orange)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15)).clipShape(Capsule())
                        LiveKnockoutPenaltySummary(match: match)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                LiveKnockoutGoalsSummary(homeTeam: homeTeam, awayTeam: awayTeam, match: match)

                LiveKnockoutCardsSummary(homeTeam: homeTeam, awayTeam: awayTeam, match: match)

                LiveKnockoutRatingsSummary(match: match)

                LiveKnockoutStatsSummary(match: match)

                Spacer(minLength: 16)

                Button(action: onComplete) {
                    Text("Continue").frame(maxWidth: .infinity).font(.headline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.large)
                .tint(.green)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }
}

/// Two-column summary of all goals from a live match, filtered by team,
/// with minute, penalty, extra time, and assist annotations.
struct LiveKnockoutGoalsSummary: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    @ObservedObject var match: LiveKnockoutMatch

    var body: some View {
        VStack(spacing: 6) {
            Text("Scorers").font(.caption.weight(.semibold)).foregroundColor(.secondary)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(match.events.compactMap { ev -> GoalEvent? in if case .goal(let g) = ev, g.teamId == homeTeam.id { return g }; return nil }, id: \.id) { g in
                        Text("\(g.minute)' \(g.scorer)\(g.isPenalty ? " (P)" : "")\(g.isExtraTime ? " ET" : "")\(g.assist.map { " (\($0))" } ?? "")")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 3) {
                    ForEach(match.events.compactMap { ev -> GoalEvent? in if case .goal(let g) = ev, g.teamId == awayTeam.id { return g }; return nil }, id: \.id) { g in
                        Text("\(g.minute)' \(g.scorer)\(g.isPenalty ? " (P)" : "")\(g.isExtraTime ? " ET" : "")\(g.assist.map { " (\($0))" } ?? "")")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 12)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }
}

/// Two-column card summary (yellow/red) for a live match, rendered only when
/// at least one card occurred.
struct LiveKnockoutCardsSummary: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    @ObservedObject var match: LiveKnockoutMatch

    @ViewBuilder
    var body: some View {
        let homeCards = match.events.compactMap { ev -> CardEvent? in if case .card(let c) = ev, c.teamId == homeTeam.id { return c }; return nil }
        let awayCards = match.events.compactMap { ev -> CardEvent? in if case .card(let c) = ev, c.teamId == awayTeam.id { return c }; return nil }
        if !homeCards.isEmpty || !awayCards.isEmpty {
            VStack(spacing: 6) {
                Text("Cards").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(homeCards, id: \.id) { c in
                            HStack(spacing: 4) {
                                Image(systemName: c.isSecondYellow ? "rectangle.fill" : "square.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(c.isSecondYellow ? .red : .yellow)
                                Text("\(c.minute)' \(c.playerName)").font(.system(size: 10))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(awayCards, id: \.id) { c in
                            HStack(spacing: 4) {
                                Text("\(c.minute)' \(c.playerName)").font(.system(size: 10))
                                Image(systemName: c.isSecondYellow ? "rectangle.fill" : "square.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(c.isSecondYellow ? .red : .yellow)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 12)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
        }
    }
}

/// Reuses `KnockoutRatingsSection` to display ratings computed from the live
/// match's events, with the player's team on the home side.
struct LiveKnockoutRatingsSummary: View {
    @ObservedObject var match: LiveKnockoutMatch

    var body: some View {
        KnockoutRatingsSection(
            ratings: MatchRatings.fromLive(match),
            playerTeamId: match.homeTeam.id,
            playerTeamName: match.homeTeam.name,
            opponentName: match.awayTeam.name
        )
    }
}

/// Row of per-team stat items (shots, SOT, possession, cards) from a live
/// match, comparing home and away values side by side.
struct LiveKnockoutStatsSummary: View {
    @ObservedObject var match: LiveKnockoutMatch

    var body: some View {
        HStack(spacing: 0) {
            LiveKnockoutStatItem(label: "Shots", home: "\(match.homeShots)", away: "\(match.awayShots)")
            LiveKnockoutStatItem(label: "SOT", home: "\(match.homeShotsOnTarget)", away: "\(match.awayShotsOnTarget)")
            LiveKnockoutStatItem(label: "Poss", home: "\(Int(match.homePossession))%", away: "\(100 - Int(match.homePossession))%")
            LiveKnockoutStatItem(label: "YC", home: "\(match.homeYellowCards)", away: "\(match.awayYellowCards)")
            LiveKnockoutStatItem(label: "RC", home: "\(match.homeRedCards)", away: "\(match.awayRedCards)")
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }
}

/// Single stat block showing the home value, label, and away value stacked
/// vertically. Used inside `LiveKnockoutStatsSummary`.
struct LiveKnockoutStatItem: View {
    let label: String
    let home: String
    let away: String

    var body: some View {
        VStack(spacing: 2) {
            Text(home).font(.caption.weight(.bold))
            Text(label).font(.system(size: 8)).foregroundColor(.secondary)
            Text(away).font(.caption.weight(.bold))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Lists every penalty kick from a live match's shootout, showing each
/// shooter and whether the kick was scored. Shown on the full-time screen
/// when the tie went to penalties.
struct LiveKnockoutPenaltySummary: View {
    @ObservedObject var match: LiveKnockoutMatch

    var body: some View {
        VStack(spacing: 6) {
            Text("Penalty Kicks").font(.caption.weight(.semibold)).foregroundColor(.secondary)
            ForEach(match.penaltyKicks.indices, id: \.self) { i in
                let kick = match.penaltyKicks[i]
                HStack(spacing: 6) {
                    if kick.teamIsHome { Spacer() }
                    HStack(spacing: 4) {
                        Text("\(kick.shooter)")
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: kick.scored ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(kick.scored ? .green : .red)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(.systemBackground).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    if !kick.teamIsHome { Spacer() }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }
}
