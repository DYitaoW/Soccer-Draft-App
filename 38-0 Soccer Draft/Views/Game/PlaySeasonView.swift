import SwiftUI

struct PlaySeasonView: View {
    let playerTeam: Team
    let projectedPosition: Int
    let isMode38: Bool
    let overall: Int
    let onRestart: () -> Void
    let onSeasonComplete: (SeasonSimulationResult) -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var result: SeasonSimulationResult?
    @State private var revealedMatches = 0
    @State private var finished = false
    @State private var saved = false
    @State private var skipAnimation = false
    @State private var scrollTarget: Int?

    private let batchSize = 3
    private var delay: Double { UserDefaults.standard.bool(forKey: "fastMode") ? 0.05 : 0.8 }

    var body: some View {
        if let result = result {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header(result: result)
                        matchList(result: result)
                        leagueTable(result: result)
                        if revealedMatches > 0 && !finished {
                            Button("Skip to End") {
                                skipAnimation = true
                                revealedMatches = playerMatches.count
                                withAnimation { finished = true }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.top, 30)
                            .tint(.green)
                        }
                        if finished {
                            seasonEndSection(result: result)
                        }
                    }
                }
                .onChange(of: scrollTarget) { target in
                    if let t = target { withAnimation { proxy.scrollTo(t, anchor: .bottom) } }
                }
                .onChange(of: finished) { newValue in
                    if newValue { saveIfNeeded() }
                }
            }
        } else {
            ProgressView("Simulating season...")
                .onAppear { simulateAndAnimate() }
        }
    }

    private func simulateAndAnimate() {
        let shuffled = leagueTeams.shuffled()
        let selectedOpponents = Array(shuffled.prefix(19))
        let simulated = SeasonSimulator.simulateSeason(
            playerTeam: playerTeam,
            opponents: selectedOpponents,
            projectedPosition: projectedPosition
        )
        result = simulated
        animateMatches(result: simulated)
    }

    private func animateMatches(result: SeasonSimulationResult) {
        let playerMatches = result.matches.filter { $0.homeTeam.id == result.playerTeamId || $0.awayTeam.id == result.playerTeamId }
        var idx = 0
        func showNext() {
            guard !skipAnimation else { return }
            guard idx < playerMatches.count else {
                finished = true
                return
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                revealedMatches = idx + 1
            }
            idx += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { showNext() }
        }
        showNext()
    }

    private var playerMatches: [SimulatedMatch] {
        guard let result = result else { return [] }
        return result.matches.filter { $0.homeTeam.id == result.playerTeamId || $0.awayTeam.id == result.playerTeamId }
    }

    private var visibleMatches: [SimulatedMatch] {
        Array(playerMatches.prefix(revealedMatches).suffix(batchSize))
    }

    private var allRevealedMatches: [SimulatedMatch] {
        Array(playerMatches.prefix(revealedMatches))
    }

    private func playerStanding(result: SeasonSimulationResult) -> LeagueStanding? {
        computePlayerCumulative(result: result, upTo: revealedMatches)
    }

    private func computePlayerCumulative(result: SeasonSimulationResult, upTo: Int) -> LeagueStanding? {
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

    private func cumulativeStandings(result: SeasonSimulationResult, upTo: Int) -> [LeagueStanding] {
        guard upTo > 0, let lastMatch = playerMatches.prefix(upTo).last else {
            return result.standings
        }
        let currentWeek = lastMatch.week
        let matchesUpTo = result.matches.filter { $0.week <= currentWeek }

        let allTeams = Set(matchesUpTo.flatMap { [$0.homeTeam, $0.awayTeam] })
        var standingsDict: [UUID: LeagueStanding] = [:]
        for team in allTeams {
            standingsDict[team.id] = LeagueStanding(
                team: team, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0
            )
        }
        for match in matchesUpTo {
            guard var homeSt = standingsDict[match.homeTeam.id],
                  var awaySt = standingsDict[match.awayTeam.id] else { continue }
            homeSt.wins += match.homeWin ? 1 : 0
            homeSt.draws += match.draw ? 1 : 0
            homeSt.losses += match.homeWin || match.draw ? 0 : 1
            homeSt.goalsFor += match.homeScore
            homeSt.goalsAgainst += match.awayScore
            awaySt.wins += match.awayWin ? 1 : 0
            awaySt.draws += match.draw ? 1 : 0
            awaySt.losses += match.awayWin || match.draw ? 0 : 1
            awaySt.goalsFor += match.awayScore
            awaySt.goalsAgainst += match.homeScore
            standingsDict[match.homeTeam.id] = homeSt
            standingsDict[match.awayTeam.id] = awaySt
        }
        return standingsDict.values.sorted { a, b in
            if a.points != b.points { return a.points > b.points }
            if a.goalDiff != b.goalDiff { return a.goalDiff > b.goalDiff }
            return a.goalsFor > b.goalsFor
        }
    }

    private func gdText(_ gd: Int) -> String {
        gd >= 0 ? "+\(gd)" : "\(gd)"
    }

    // MARK: - Header

    private func header(result: SeasonSimulationResult) -> some View {
        VStack(spacing: 4) {
            Text("Season Results")
                .font(.system(size: 20).weight(.bold))
            if let st = playerStanding(result: result) {
                HStack(spacing: 15) {
                    resultBox(label: "W", value: "\(st.wins)", color: .green)
                    resultBox(label: "D", value: "\(st.draws)", color: .gray)
                    resultBox(label: "L", value: "\(st.losses)", color: .red)
                    resultBox(label: "Pts", value: "\(st.points)", color: .yellow)
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        //.frame(maxHeight: .infinity)
       // .background(.ultraThinMaterial)
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

    private func matchList(result: SeasonSimulationResult) -> some View {
        VStack(spacing: 0) {
            let matches = visibleMatches
            VStack(spacing: 0) {
                ForEach(0..<batchSize, id: \.self) { i in
                    if i < matches.count {
                        matchRow(match: matches[i], playerTeamId: result.playerTeamId)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                    } else {
                        Color.clear
                            .frame(height: 50)
                            .padding(.horizontal, 12)
                    }
                    if i < batchSize - 1 { Divider().padding(.leading, 12) }
                }
            }
            .frame(minHeight: CGFloat(batchSize) * 50)
            .animation(.easeInOut(duration: 0.3), value: revealedMatches)

           /*if revealedMatches > 0 && revealedMatches < playerMatches.count {
                HStack(spacing: 4) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(allRevealedMatches.indices, id: \.self) { idx in
                                Button(action: { scrollTarget = idx }) {
                                    Text("GW \(allRevealedMatches[idx].week)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(idx >= revealedMatches - batchSize ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(idx >= revealedMatches - batchSize ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .disabled(idx >= revealedMatches - batchSize)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: 28)
                }
                .padding(.vertical, 4) */
          //  }
        }
    }

    private func matchRow(match: SimulatedMatch, playerTeamId: UUID) -> some View {
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
                .frame(width: 40, alignment: .leading)
                .padding(.trailing, 5)
                
            //VStack(alignment: .leading, spacing: 3) {
                Text("\(opponentName) \(homeAway)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
           // }
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

    // MARK: - Season End

    private func seasonEndSection(result: SeasonSimulationResult) -> some View {
        VStack(spacing: 10) {
            finishTiles(result: result)

            Button(action: {
                onSeasonComplete(result)
            }) {
                Text("Continue")
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

    private func finishTiles(result: SeasonSimulationResult) -> some View {
        let diff = result.projectedPosition - result.playerPosition
        let perfText = diff > 0 ? "Overperformed" : diff < 0 ? "Underperformed" : "Met Expectations"
        let perfColor: Color = diff > 0 ? .green : diff < 0 ? .red : .yellow
        let pts = result.playerStanding?.points ?? 0

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                TileView(label: "Finish", value: ordinal(result.playerPosition), color: .blue)
                TileView(label: "Projected", value: ordinal(result.projectedPosition), color: .secondary)
                TileView(label: "Points", value: "\(pts)", color: .yellow)
            }
            TileView(label: "Result", value: perfText, color: perfColor)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

    private func leagueTable(result: SeasonSimulationResult) -> some View {
        let standings = cumulativeStandings(result: result, upTo: revealedMatches)
        let totalTeams = standings.count
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

            ForEach(Array(standings.enumerated()), id: \.element.team.id) { idx, st in
                let isPlayer = st.team.id == result.playerTeamId
                let pos = idx + 1
                let gp = st.wins + st.draws + st.losses
                let posColor: Color = pos == 1 ? .yellow : pos <= 4 ? .green : pos > totalTeams - 3 ? .red : .secondary
                HStack(spacing: 0) {
                    Text("\(pos)")
                        .frame(width: 24, alignment: .leading)
                        .foregroundColor(posColor)
                        .fontWeight(pos <= 4 || pos > totalTeams - 3 ? .bold : .regular)
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

                if idx < standings.count - 1 {
                    Divider().padding(.leading, 8)
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.bottom, finished ? 15 : 0)
    }

    // MARK: - Helpers

    private func saveIfNeeded() {
        guard finished, !saved, let result = result, let st = result.playerStanding else { return }
        saved = true
        var stats = CareerStats.load()
        stats.recordSeason(
            mode38: isMode38,
            record: SeasonRecord(wins: st.wins, draws: st.draws, losses: st.losses),
            points: st.points,
            goalsFor: st.goalsFor,
            goalsAgainst: st.goalsAgainst,
            position: result.playerPosition,
            overall: overall
        )
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

struct TileView: View {
    let label: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
        .frame(minWidth: 28)
    }
}

#Preview("TileView") {
    TileView(label: "Finish", value: "8th", color: .blue)
        .padding()
}

#Preview("StatBox") {
    StatBox(label: "Pts", value: "72", color: .yellow)
        .padding()
}

#Preview("Season Simulation") {
    PlaySeasonView(
        playerTeam: Team(name: "Your Team", offense: 85, midfield: 83, defense: 82),
        projectedPosition: 8,
        isMode38: false,
        overall: 84,
        onRestart: {},
        onSeasonComplete: { _ in }
    )
}

#Preview("38-Game Season") {
    PlaySeasonView(
        playerTeam: Team(name: "Your Team", offense: 85, midfield: 83, defense: 82),
        projectedPosition: 12,
        isMode38: true,
        overall: 84,
        onRestart: {},
        onSeasonComplete: { _ in }
    )
}
