import SwiftUI

struct CupSeasonView: View {
    let competitionType: CupCompetitionType
    let allFixtures: [CupFixture]
    let standings: [CupStanding]
    let playerTeamId: UUID
    let cupTeams: [CupTeam]
    let onComplete: ([CupStanding], Int) -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var revealedWeeks = 0
    @State private var finished = false
    @State private var skipAnimation = false

    private let weekCount = 8
    private var delay: Double { UserDefaults.standard.bool(forKey: "fastMode") ? 0.05 : 0.8 }

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
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 8)
                }

                if finished {
                    seasonEndSection
                }
            }
        }
        .onAppear { animateWeeks() }
    }

    // MARK: - Player stats from revealed weeks

    private var playerFixtures: [CupFixture] {
        allFixtures.filter { $0.homeTeam.id == playerTeamId || $0.awayTeam.id == playerTeamId }
    }

    private var revealedPlayerFixtures: [CupFixture] {
        playerFixtures.filter { $0.week <= revealedWeeks }
    }

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

    private var cumulativeStandings: [CupStanding] {
        CupModels.cumulativeStandings(from: allFixtures, upToWeek: revealedWeeks, allTeams: cupTeams)
    }

    private var finalStandings: [CupStanding] {
        standings
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text(competitionType.rawValue)
                .font(.headline)
            HStack(spacing: 12) {
                StatBox(label: "W", value: "\(playerStanding.wins)", color: .green)
                StatBox(label: "D", value: "\(playerStanding.draws)", color: .gray)
                StatBox(label: "L", value: "\(playerStanding.losses)", color: .red)
                StatBox(label: "Pts", value: "\(playerPoints)", color: .yellow)
            }
            .padding(.top, 4)
            HStack(spacing: 12) {
                StatBox(label: "GS", value: "\(playerStanding.gf)", color: .blue)
                StatBox(label: "GA", value: "\(playerStanding.ga)", color: .orange)
                StatBox(label: "GD", value: gdText(playerStanding.gf - playerStanding.ga), color: playerStanding.gf >= playerStanding.ga ? .green : .red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Match List

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

        return HStack(spacing: 8) {
            Text("GW \(match.week)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(opponentName) \(homeAway)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
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
        .background(
            playerWon ? Color.green.opacity(colorScheme == .dark ? 0.18 : 0.08)
            : playerDrew ? Color.gray.opacity(colorScheme == .dark ? 0.12 : 0.05)
            : Color.red.opacity(colorScheme == .dark ? 0.18 : 0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - League Table

    private var leagueTable: some View {
        let table = finished ? finalStandings : cumulativeStandings
        let totalTeams = table.count
        let superLeague = totalTeams >= 36
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("#").frame(width: 24, alignment: .leading)
                Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                Text("GP").frame(width: 22)
                Text("W").frame(width: 22)
                Text("D").frame(width: 22)
                Text("L").frame(width: 22)
                Text("GS/GA").frame(width: 44)
                Text("GD").frame(width: 28)
                Text("Pts").frame(width: 30, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            ForEach(Array(table.enumerated()), id: \.element.team.id) { idx, st in
                let isPlayer = st.team.id == playerTeamId
                let pos = idx + 1
                let gp = st.wins + st.draws + st.losses
                let posColor: Color = pos == 1 ? .yellow : pos <= (superLeague ? 8 : 4) ? .green : pos > (superLeague ? totalTeams - 12 : totalTeams - 3) ? .red : .secondary
                let threshold = superLeague ? totalTeams - 12 : totalTeams - 3
                HStack(spacing: 0) {
                    Text("\(pos)")
                        .frame(width: 24, alignment: .leading)
                        .foregroundColor(posColor)
                        .fontWeight(pos <= (superLeague ? 8 : 4) || pos > threshold ? .bold : .regular)
                    Text(st.team.name)
                        .fontWeight(isPlayer ? .bold : .regular)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(gp)").frame(width: 22)
                    Text("\(st.wins)")
                        .foregroundColor(.green)
                        .frame(width: 22)
                    Text("\(st.draws)").frame(width: 22)
                    Text("\(st.losses)")
                        .foregroundColor(.red)
                        .frame(width: 22)
                    Text("\(st.goalsFor)/\(st.goalsAgainst)").frame(width: 44)
                    Text(gdText(st.goalDiff))
                        .foregroundColor(st.goalDiff >= 0 ? .green : .red)
                        .frame(width: 28)
                    Text("\(st.points)")
                        .fontWeight(.bold)
                        .frame(width: 30, alignment: .trailing)
                }
                .font(.system(size: 10))
                .foregroundColor(isPlayer ? .blue : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isPlayer ? Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.08) : Color.clear)

                if idx < table.count - 1 {
                    Divider().padding(.leading, 8)
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    // MARK: - Season End

    private var seasonEndSection: some View {
        VStack(spacing: 12) {
            if let pos = finalStandings.firstIndex(where: { $0.team.id == playerTeamId }) {
                let position = pos + 1
                HStack(spacing: 12) {
                    StatBox(label: "Finish", value: ordinal(position), color: .blue)
                    StatBox(label: "W", value: "\(playerStanding.wins)", color: .green)
                    StatBox(label: "D", value: "\(playerStanding.draws)", color: .gray)
                    StatBox(label: "L", value: "\(playerStanding.losses)", color: .red)
                    StatBox(label: "Pts", value: "\(playerPoints)", color: .yellow)
                }
                .padding(.horizontal)
                .padding(.top, 8)
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
            .padding(.bottom, 16)
        }
    }

    // MARK: - Animation

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

    private func gdText(_ gd: Int) -> String {
        gd >= 0 ? "+\(gd)" : "\(gd)"
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        if (11...13).contains(n % 100) { suffix = "th" } else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
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
        onComplete: { _, _ in }
    )
}
