/// CupSeasonView.swift
///
/// Animated league-phase reveal for a cup campaign: reveals match weeks one at a time,
/// tracks the player's record and cumulative standings, then reports the final
/// standings and player position so the flow can continue to the knockouts.
import SwiftUI

/// Reveals a simulated cup league season week-by-week (header, recent player matches,
/// live league table) and presents a finish recap with a "Continue to Knockouts" action
/// that invokes `onComplete` with the final standings and player position.
struct CupSeasonView: View {
    let competitionType: CupCompetitionType
    let allFixtures: [CupFixture]
    let standings: [CupStanding]
    let playerTeamId: UUID
    let cupTeams: [CupTeam]
    let userPlayerNames: [String]
    let assignedPlayers: [Int: Player]
    let onComplete: ([CupStanding], Int) -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var revealedWeeks = 0
    @State private var finished = false
    @State private var skipAnimation = false
    @State private var matchScorers: [UUID: [String]] = [:]

    private let weekCount = 8
    private var delay: Double { UserDefaults.standard.bool(forKey: "fastMode") ? 0.05 : 0.8 }

    /// Drives the weekly reveal via `animateWeeks()`, renders the header, match list,
    /// and table, and offers "Skip to End" before the season finish section appears.
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                matchList
                leagueTable

                if revealedWeeks > 0 && !finished {
                    Button("Skip to End") {
                        skipAnimation = true
                        revealedWeeks = weekCount
                        withAnimation { finished = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .tint(.green)
                    .padding(.top, 30)
                }

                if finished {
                    seasonEndSection
                }
            }
        }
        .onAppear {
            precomputeMatchScorers()
            animateWeeks()
        }
    }

    /// Pre-distributes the player team's goals in each fixture to user players
    /// (weighted by position) so the game-by-game results can show scorer names
    /// just like the regular season. Computed once so results stay stable.
    private func precomputeMatchScorers() {
        var scorers: [UUID: [String]] = [:]
        for fixture in playerFixtures {
            let goals = fixture.homeTeam.id == playerTeamId ? fixture.homeScore : fixture.awayScore
            scorers[fixture.id] = CupGoalDistributor.distributeForMatch(
                goals: goals,
                userPlayerNames: userPlayerNames,
                assignedPlayers: assignedPlayers
            )
        }
        matchScorers = scorers
    }

    // MARK: - Player stats from revealed weeks

    /// All fixtures involving the player's team.
    private var playerFixtures: [CupFixture] {
        allFixtures.filter { $0.homeTeam.id == playerTeamId || $0.awayTeam.id == playerTeamId }
    }

    /// The player's fixtures whose week has been revealed so far.
    private var revealedPlayerFixtures: [CupFixture] {
        playerFixtures.filter { $0.week <= revealedWeeks }
    }

    /// Running W-D-L and goals record for the player from revealed fixtures.
    private var playerStanding: (wins: Int, draws: Int, losses: Int, gf: Int, ga: Int) {
        var w = 0, d = 0, l = 0, gf = 0, ga = 0
        for m in revealedPlayerFixtures {
            if m.homeTeam.id == playerTeamId {
                if m.homeWin { w += 1 } else if m.draw { d += 1 } else { l += 1 }
                gf += m.homeScore; ga += m.awayScore
            } else {
                if m.awayWin { w += 1 } else if m.draw { d += 1 } else { l += 1 }
                gf += m.awayScore; ga += m.homeScore
            }
        }
        return (w, d, l, gf, ga)
    }

    private var playerPoints: Int { playerStanding.wins * 3 + playerStanding.draws }

    // MARK: - Cumulative standings

    /// Standings recomputed for the weeks revealed so far.
    private var cumulativeStandings: [CupStanding] {
        CupModels.cumulativeStandings(from: allFixtures, upToWeek: revealedWeeks, allTeams: cupTeams)
    }

    /// The season's final standings from the parent flow.
    private var finalStandings: [CupStanding] {
        standings
    }

    // MARK: - Header

    /// Season title and the player's live W-D-L / points record.
    private var header: some View {
        VStack(spacing: 4) {
            Text(competitionType.rawValue)
                .font(.system(size: 20).weight(.bold))
            HStack(spacing: 15) {
                resultBox(label: "W", value: "\(playerStanding.wins)", color: .green)
                resultBox(label: "D", value: "\(playerStanding.draws)", color: .gray)
                resultBox(label: "L", value: "\(playerStanding.losses)", color: .red)
                resultBox(label: "Pts", value: "\(playerPoints)", color: .yellow)
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func resultBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(minWidth: 65)
        .padding(.vertical, 8)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Match List

    /// The three most recent revealed player fixtures, animated as weeks progress.
    private var matchList: some View {
        VStack(spacing: 0) {
            let visible = revealedPlayerFixtures.suffix(3)
            VStack(spacing: 0) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { i, match in
                    matchRow(match: match)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                    if i < visible.count - 1 { Divider().padding(.leading, 12) }
                }
                if visible.isEmpty && revealedWeeks == 0 {
                    ProgressView().padding(.vertical, 8)
                }
            }
            .frame(minHeight: CGFloat(min(visible.count, 1)) * 50)
            .animation(.easeInOut(duration: 0.3), value: revealedWeeks)

        }
    }

    /// One fixture row: game week, opponent with home/away marker, score, a
    /// W/D/L badge colored by the result for the player, and the distributed
    /// scorer names for that game.
    private func matchRow(match: CupFixture) -> some View {
        let isPlayerHome = match.homeTeam.id == playerTeamId
        let isPlayerAway = match.awayTeam.id == playerTeamId
        let playerWon = (match.homeWin && isPlayerHome) || (match.awayWin && isPlayerAway)
        let playerDrew = match.draw
        let resultChar = playerWon ? "W" : playerDrew ? "D" : "L"
        let resultColor: Color = playerWon ? .green : playerDrew ? .gray : .red
        let opponentName = isPlayerHome ? match.awayTeam.name : match.homeTeam.name
        let homeAway = isPlayerHome ? "(H)" : "(A)"
        let playerScore = isPlayerHome ? match.homeScore : match.awayScore
        let opponentScore = isPlayerHome ? match.awayScore : match.homeScore
        let scorers = matchScorers[match.id] ?? []

        return VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("GW \(match.week)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                    .padding(.trailing, 5)

                Text("\(opponentName) \(homeAway)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(playerScore)-\(opponentScore)")
                    .font(.title3.weight(.bold))
                    .frame(width: 56, alignment: .center)

                Text(resultChar)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(resultColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.vertical, 2)

            HStack(spacing: 4) {
                if !scorers.isEmpty {
                    Image(systemName: "soccerball")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(scorers.joined(separator: ", "))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 52)
            .padding(.bottom, 2)
            .frame(height: 14)
        }
        .padding(.vertical, 2)
        .background(
            playerWon ? Color.green.opacity(colorScheme == .dark ? 0.18 : 0.08)
            : playerDrew ? Color.gray.opacity(colorScheme == .dark ? 0.12 : 0.05)
            : Color.red.opacity(colorScheme == .dark ? 0.18 : 0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - League Table

    /// League table: cumulative while the season animates, final once finished, with
    /// qualification and relegation zones sized for the competition.
    private var leagueTable: some View {
        let table = finished ? finalStandings : cumulativeStandings
        let totalTeams = table.count
        let superLeague = totalTeams >= 36
        let qualEnd = superLeague ? 8 : 5
        let relStart = superLeague ? totalTeams - 11 : totalTeams - 3
        let rows = table.enumerated().map { idx, st in
            LeagueTableRowData(
                id: st.team.id as AnyHashable,
                teamName: st.team.name,
                wins: st.wins,
                draws: st.draws,
                losses: st.losses,
                goalsFor: st.goalsFor,
                goalsAgainst: st.goalsAgainst,
                points: st.points,
                isPlayer: st.team.id == playerTeamId
            )
        }
        return LeagueTableSection(
            rows: rows,
            totalTeams: totalTeams,
            showGP: true,
            showGSGA: true,
            qualStart: 1,
            qualEnd: qualEnd,
            relStart: relStart
        )
        .padding(.horizontal)
    }

    // MARK: - Season End

    /// Final-season recap tiles and the "Continue to Knockouts" button that reports
    /// the final standings and player position via `onComplete`.
    private var seasonEndSection: some View {
        VStack(spacing: 10) {
            if let pos = finalStandings.firstIndex(where: { $0.team.id == playerTeamId }) {
                let position = pos + 1
                HStack(spacing: 8) {
                    TileView(label: "Finish", value: ordinal(position), color: .blue)
                    TileView(label: "W", value: "\(playerStanding.wins)", color: .green)
                    TileView(label: "D", value: "\(playerStanding.draws)", color: .gray)
                    TileView(label: "L", value: "\(playerStanding.losses)", color: .red)
                    TileView(label: "Pts", value: "\(playerPoints)", color: .yellow)
                }
            }

            Button(action: {
                let pos = finalStandings.firstIndex { $0.team.id == playerTeamId } ?? 0
                onComplete(finalStandings, pos + 1)
            }) {
                Text("Continue to Knockouts")
                    .frame(maxWidth: .infinity)
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal)
            .padding(.bottom, 15)
        }
    }

    // MARK: - Animation

    /// Sequentially reveals each of the eight game weeks with a delay between them,
    /// finishing when all weeks are shown or when the user taps "Skip to End".
    private func animateWeeks() {
        var week = 0
        func showNext() {
            guard !skipAnimation else { return }
            guard week < weekCount else {
                withAnimation { finished = true }
                return
            }
            week += 1
            withAnimation(.easeInOut(duration: 0.3)) {
                revealedWeeks = week
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { showNext() }
        }
        showNext()
    }

    // MARK: - Helpers
}

#Preview("Super League Season") {
    let pid = UUID()
    let team = CupTeam(id: pid, name: "Your Team", offense: 85, midfield: 83, defense: 82, pot: 1)
    let opp = CupTeam(name: "Barcelona", offense: 94, midfield: 90, defense: 85, pot: 1)
    let fixtures = CupModels.generateFullSchedule(teams: [team, opp] + superLeagueTeams.filter { $0.id != team.id && $0.id != opp.id })
    CupSeasonView(
        competitionType: .superLeague,
        allFixtures: fixtures,
        standings: CupModels.computeStandings(from: fixtures, allTeams: [team, opp] + superLeagueTeams.filter { $0.id != team.id && $0.id != opp.id }),
        playerTeamId: pid,
        cupTeams: [team, opp] + superLeagueTeams.filter { $0.id != team.id && $0.id != opp.id },
        userPlayerNames: ["Player 1", "Player 2"],
        assignedPlayers: [:],
        onComplete: { _, _ in }
    )
}
