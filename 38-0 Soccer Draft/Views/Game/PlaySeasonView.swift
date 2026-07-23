import SwiftUI
import Combine

struct PlaySeasonView: View {
    let playerTeam: PlaceholderTeam
    let projectedPosition: Int
    let onRestart: () -> Void

    @State private var result: SeasonSimulationResult?
    @State private var revealedMatches = 0
    @State private var finished = false

    var body: some View {
        VStack(spacing: 0) {
            if let result = result {
                header(result: result)
                matchList(result: result)
            } else {
                ProgressView("Simulating season...")
            }
        }
        .onAppear { simulateAndAnimate() }
    }

    private func simulateAndAnimate() {
        let simulated = SeasonSimulator.simulateSeason(
            playerTeam: playerTeam,
            opponents: placeholderTeams,
            projectedPosition: projectedPosition
        )
        result = simulated
        animateMatches(result: simulated)
    }

    private func animateMatches(result: SeasonSimulationResult) {
        let playerMatches = result.matches.filter { $0.homeTeam.id == result.playerTeamId || $0.awayTeam.id == result.playerTeamId }
        var idx = 0
        func showNext() {
            guard idx < playerMatches.count else {
                finished = true
                return
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                revealedMatches = idx + 1
            }
            idx += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showNext() }
        }
        showNext()
    }

    private func header(result: SeasonSimulationResult) -> some View {
        VStack(spacing: 4) {
            Text("Season")
                .font(.headline)
            if let st = playerStanding(result: result) {
                HStack(spacing: 12) {
                    StatBox(label: "W", value: "\(st.wins)", color: .green)
                    StatBox(label: "D", value: "\(st.draws)", color: .gray)
                    StatBox(label: "L", value: "\(st.losses)", color: .red)
                    StatBox(label: "GF", value: "\(st.goalsFor)", color: .blue)
                    StatBox(label: "GA", value: "\(st.goalsAgainst)", color: .orange)
                    StatBox(label: "GD", value: gdText(st.goalDiff), color: st.goalDiff >= 0 ? .green : .red)
                    StatBox(label: "Pts", value: "\(st.points)", color: .yellow)
                }
                .padding(.top, 4)

                if finished {
                    HStack(spacing: 16) {
                        Text("Finish: \(ordinal(result.playerPosition))")
                            .font(.title3.weight(.bold))
                        Text("(Proj: \(ordinal(result.projectedPosition)))")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding(.top, 4)

                    seasonSummary(result: result)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func playerStanding(result: SeasonSimulationResult) -> LeagueStanding? {
        computeCumulativeStanding(result: result, upTo: revealedMatches)
    }

    private func computeCumulativeStanding(result: SeasonSimulationResult, upTo: Int) -> LeagueStanding? {
        let playerMatches = result.matches.filter { $0.homeTeam.id == result.playerTeamId || $0.awayTeam.id == result.playerTeamId }
        let visible = playerMatches.prefix(upTo)
        var w = 0, d = 0, l = 0, gf = 0, ga = 0
        for match in visible {
            if match.homeTeam.id == result.playerTeamId {
                if match.homeWin { w += 1 }
                else if match.draw { d += 1 }
                else { l += 1 }
                gf += match.homeScore
                ga += match.awayScore
            } else {
                if match.awayWin { w += 1 }
                else if match.draw { d += 1 }
                else { l += 1 }
                gf += match.awayScore
                ga += match.homeScore
            }
        }
        return LeagueStanding(
            team: playerTeam,
            wins: w, draws: d, losses: l,
            goalsFor: gf, goalsAgainst: ga
        )
    }

    private func gdText(_ gd: Int) -> String {
        gd >= 0 ? "+\(gd)" : "\(gd)"
    }

    private func seasonSummary(result: SeasonSimulationResult) -> some View {
        let diff = result.projectedPosition - result.playerPosition
        let text = summaryText(diff: diff, position: result.playerPosition)
        return Text(text)
            .font(.caption).foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal).padding(.top, 2)
    }

    private func summaryText(diff: Int, position: Int) -> String {
        if position <= 1 { return "Champions! A historic season!" }
        if position <= 4 { return diff >= 2 ? "Overperformed expectations!" : "Solid top-four finish." }
        if position <= 8 { return diff <= -3 ? "Underperformed expectations." : "Respectable top-half finish." }
        if position <= 17 { return diff <= -4 ? "Disappointing — far from expectations." : "Mid-table season." }
        return "Relegated — a season to forget."
    }

    private func matchList(result: SeasonSimulationResult) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let playerMatches = result.matches.filter { $0.homeTeam.id == result.playerTeamId || $0.awayTeam.id == result.playerTeamId }
                ForEach(Array(playerMatches.prefix(revealedMatches).enumerated()), id: \.offset) { _, match in
                    matchRow(match: match, playerTeamId: result.playerTeamId)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                    Divider().padding(.leading, 12)
                }
                if finished {
                    Button("Back to Home", action: onRestart)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.vertical, 24)
                }
            }
        }
    }

    private func matchRow(match: SimulatedMatch, playerTeamId: UUID) -> some View {
        let isPlayerHome = match.homeTeam.id == playerTeamId
        let isPlayerAway = match.awayTeam.id == playerTeamId

        return HStack {
            Text("#\(match.week)")
                .font(.caption2).foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: isPlayerHome ? .trailing : .leading, spacing: 1) {
                Text(match.homeTeam.name)
                    .font(isPlayerHome ? .subheadline.weight(.bold) : .caption)
                Text("\(match.homeScore) - \(match.awayScore)")
                    .font(.title3.weight(.bold))
                Text(match.awayTeam.name)
                    .font(isPlayerAway ? .subheadline.weight(.bold) : .caption)
            }
            .frame(maxWidth: .infinity)

            Text(match.homeWin && isPlayerHome || match.awayWin && isPlayerAway ? "W"
                 : match.draw ? "D" : "L")
                .font(.caption.weight(.bold)).foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(match.homeWin && isPlayerHome || match.awayWin && isPlayerAway ? Color.green
                            : match.draw ? Color.gray : Color.red)
                .clipShape(Circle())
        }
        .padding(.vertical, 2)
        .background(
            (match.homeWin && isPlayerHome || match.awayWin && isPlayerAway ? Color.green.opacity(0.08)
             : match.draw ? Color.gray.opacity(0.05) : Color.red.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
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

struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9)).foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold)).foregroundColor(color)
        }
        .frame(minWidth: 28)
    }
}
