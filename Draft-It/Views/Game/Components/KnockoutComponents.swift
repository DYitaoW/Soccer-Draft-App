/// KnockoutComponents.swift
///
/// Reusable knockout UI pieces: scoreboard headers, commentary boxes, penalty
/// shootout lists, and matchup rows used across the cup screens.

import SwiftUI

/// Compact two-column list of goal scorers with minute, penalty/own-goal
/// markers, and assists. Used by knockout result screens to show scorers
/// for a single match.
struct KnockoutScorersBox: View {
    let homeGoals: [GoalEvent]
    let awayGoals: [GoalEvent]

    var body: some View {
        VStack(spacing: 4) {
            Text("Scorers")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(homeGoals) { g in
                        HStack(spacing: 4) {
                            Text("\(g.minute)'")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(g.scorer)
                                .font(.system(size: 10))
                            if g.isPenalty { Text("(P)").font(.system(size: 8)).foregroundColor(.orange) }
                            if g.isOwnGoal { Text("(OG)").font(.system(size: 8)).foregroundColor(.secondary) }
                            if let a = g.assist {
                                Text("(\(a))")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(awayGoals) { g in
                        HStack(spacing: 4) {
                            if let a = g.assist {
                                Text("(\(a))")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            if g.isOwnGoal { Text("(OG)").font(.system(size: 8)).foregroundColor(.secondary) }
                            if g.isPenalty { Text("(P)").font(.system(size: 8)).foregroundColor(.orange) }
                            Text(g.scorer)
                                .font(.system(size: 10))
                            Text("\(g.minute)'")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 80)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

/// Scrollable live match feed showing timestamped commentary events.
/// Auto-scrolls to the newest event as the event count grows, showing a
/// placeholder when no events have occurred yet.
struct KnockoutCommentaryBox: View {
    let events: [(minute: Int, text: String, teamId: UUID?)]

    var body: some View {
        VStack(spacing: 2) {
            Text("Match Feed")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                            HStack(spacing: 4) {
                                Text("\(event.minute)'")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, alignment: .leading)
                                Text(event.text)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .id(idx)
                        }
                        if events.isEmpty {
                            Text("Match starting soon...")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .onChange(of: events.count) {
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(events.count - 1, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(height: 200)
        .padding(6)
        .background(Color(.systemGray5).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

/// Single matchup row in the "All Matchups" list. Shows both teams, a
/// checkmark on the winner, per-leg and aggregate scores when complete, and
/// highlights the player's in-progress match.
struct KnockoutMatchupRow: View {
    let matchup: RoundMatchup
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isPlayer = matchup.isPlayerMatch

        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Circle()
                        .fill(teamColor(named: matchup.teamA.name))
                        .frame(width: 8, height: 8)
                    Text(matchup.teamA.name)
                        .font(.system(size: 11, weight: matchup.winner?.id == matchup.teamA.id ? .bold : .regular))
                    if matchup.winner?.id == matchup.teamA.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10)).foregroundColor(.green)
                    }
                }
                HStack {
                    Circle()
                        .fill(teamColor(named: matchup.teamB.name))
                        .frame(width: 8, height: 8)
                    Text(matchup.teamB.name)
                        .font(.system(size: 11, weight: matchup.winner?.id == matchup.teamB.id ? .bold : .regular))
                    if matchup.winner?.id == matchup.teamB.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10)).foregroundColor(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if matchup.isComplete {
                Text("\(matchup.leg1ScoreA!)-\(matchup.leg1ScoreB!)")
                    .font(.system(size: 10, weight: .semibold))
                if let l2a = matchup.leg2ScoreA {
                    Text("\(l2a)-\(matchup.leg2ScoreB!)")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text("\(matchup.aggregateScore)")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 36, alignment: .trailing)
            } else if isPlayer {
                Text("In Progress")
                    .font(.system(size: 10)).foregroundColor(teamColor(named: matchup.teamA.name))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isPlayer ? teamColor(named: matchup.teamA.name).opacity(colorScheme == .dark ? 0.18 : 0.08) : Color.clear)
    }
}

/// Renders the full list of matchups for a knockout round with column headers
/// (G1, G2, Agg), one `KnockoutMatchupRow` per matchup separated by dividers.
struct KnockoutMatchupsSection: View {
    let matchups: [RoundMatchup]

    var body: some View {
        VStack(spacing: 0) {
            Text("All Matchups")
                .font(.headline)
                .padding(.vertical, 8)

            HStack(spacing: 8) {
                Spacer()
                Text("G1")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 32)
                Text("G2")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 32)
                Text("Agg")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 2)

            ForEach(matchups) { matchup in
                KnockoutMatchupRow(matchup: matchup)
                if matchup.id != matchups.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

/// Interactive penalty shootout screen. Reveals each kick one at a time at a
/// fixed interval, updating running scores, until all kicks are shown and a
/// Continue button appears. Used when a knockout tie is decided on penalties.
struct KnockoutPenaltyShootoutView: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    let kicks: [PenaltyKick]
    let onFinish: () -> Void

    private let revealInterval: TimeInterval = 2.5

    @State private var revealed = 0
    @State private var showFinish = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Penalty Shootout")
                .font(.title2.weight(.bold))
                .padding(.top, 8)

            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text(homeTeam.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(teamColor(named: homeTeam.name))
                        .lineLimit(1)
                    Text("\(homeScore)")
                        .font(.system(size: 34, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                Text("-")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.secondary)
                VStack(spacing: 2) {
                    Text(awayTeam.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(teamColor(named: awayTeam.name))
                        .lineLimit(1)
                    Text("\(awayScore)")
                        .font(.system(size: 34, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            VStack(spacing: 8) {
                Text("Kicks")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(0..<revealed, id: \.self) { i in
                            let kick = kicks[i]
                            HStack(spacing: 6) {
                                if kick.teamIsHome { Spacer() }
                                HStack(spacing: 4) {
                                    Image(systemName: kick.scored ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(kick.scored ? .green : .red)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                if !kick.teamIsHome { Spacer() }
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        if revealed == 0 {
                            Text("First taker approaches...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 260)
            }
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer()

            if showFinish {
                Button(action: onFinish) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .font(.headline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.large)
                .tint(.green)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            revealLoop()
        }
    }

    /// Count of home-team penalties scored among kicks revealed so far.
    private var homeScore: Int {
        kicks.prefix(revealed).filter { $0.teamIsHome && $0.scored }.count
    }

    /// Count of away-team penalties scored among kicks revealed so far.
    private var awayScore: Int {
        kicks.prefix(revealed).filter { !$0.teamIsHome && $0.scored }.count
    }

    /// True once the shootout is mathematically decided: the trailing team
    /// cannot catch up even if every remaining kick scores. Ends the reveal
    /// early so the shootout never plays out pointless rounds.
    private var shootoutDecided: Bool {
        let homeTaken = kicks.prefix(revealed).filter { $0.teamIsHome }.count
        let awayTaken = kicks.prefix(revealed).filter { !$0.teamIsHome }.count
        guard homeTaken == awayTaken, homeTaken > 0 else { return false }
        let remaining = homeTaken < 5 ? 5 - homeTaken : 0
        return abs(homeScore - awayScore) > remaining
    }

    /// Reveals one kick per interval; once all kicks are revealed (or the
    /// shootout is already decided), shows the Continue button. Recurses via a
    /// delayed dispatch until complete.
    private func revealLoop() {
        guard revealed < kicks.count, !shootoutDecided else {
            showFinish = true
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) { revealed += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + revealInterval) { revealLoop() }
    }
}

/// Static (non-animated) list of all penalty kicks for a shootout, aligned
/// left or right depending on whether the kicker's team is home. Embedded in
/// knockout result summaries.
struct KnockoutPenaltyKicksList: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    let kicks: [PenaltyKick]

    var body: some View {
        VStack(spacing: 6) {
            Text("Penalty Kicks")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                Text(homeTeam.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(teamColor(named: homeTeam.name))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(kicks.filter { $0.teamIsHome && $0.scored }.count)-\(kicks.filter { !$0.teamIsHome && $0.scored }.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Text(awayTeam.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(teamColor(named: awayTeam.name))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)

            ForEach(kicks) { kick in
                HStack(spacing: 6) {
                    if kick.teamIsHome { Spacer() }
                    HStack(spacing: 4) {
                        Image(systemName: kick.scored ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(kick.scored ? .green : .red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemBackground).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    if !kick.teamIsHome { Spacer() }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(10)
        .background(Color(.systemGray5).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
