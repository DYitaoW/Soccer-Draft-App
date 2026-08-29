/// PlaySeasonView.swift
///
/// Playable regular-season flow: simulates a full league season, reveals the player's
/// matches week-by-week, distributes goals/assists to the user's players, offers a
/// midseason transfer window, and reports the final result plus player stats via
/// `onSeasonComplete`.
import SwiftUI

/// Runs the animated regular season for the drafted squad. Requires a built `playerTeam`
/// and `userPlayerNames`; reports completion with the `SeasonSimulationResult` and per-player
/// stats so GameView can save the draft history and decide whether to enter a cup.
struct PlaySeasonView: View {
    let playerTeam: Team
    let projectedPosition: Int
    let isMode38: Bool
    let overall: Int
    let userPlayerNames: [String]
    let enableCups: Bool
    let onRestart: () -> Void
    let onSeasonComplete: (SeasonSimulationResult, [PlayerSeasonStats]) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var gameState: GameState
    @AppStorage("expandedManagerialDecisions") private var expandedManagerialDecisions = false

    @State private var result: SeasonSimulationResult?
    @State private var revealedMatches = 0
    @State private var finished = false
    @State private var saved = false
    @State private var skipAnimation = false
    @State private var scrollTarget: Int?
    @State private var playerGoals: [String: Int] = [:]
    @State private var playerAssists: [String: Int] = [:]
    @State private var matchScorers: [UUID: [String]] = [:]

    /// Maps each starter to their formation position for goal/assist weighting.
    private var playerPositions: [String: Position] {
        var result: [String: Position] = [:]
        for (idx, player) in gameState.assignedPlayers {
            let slot = gameState.selectedFormation.slots[idx]
            result[player.name] = slot.position
        }
        return result
    }

    /// Likelihood weight for a player scoring, based on their position.
    private func goalWeight(for pos: Position?) -> Double {
        guard let pos = pos else { return 0.5 }
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

    /// Likelihood weight for a player assisting, based on their position.
    private func assistWeight(for pos: Position?) -> Double {
        guard let pos = pos else { return 0.5 }
        switch pos {
        case .CAM, .LW, .RW: return 3.0
        case .ST, .CF, .LM, .RM, .CM: return 2.0
        case .CDM: return 1.0
        case .LB, .RB, .LWB, .RWB: return 1.5
        case .CB: return 0.3
        case .GK: return 0.02
        }
    }

    @State private var savedOpponents: [Team] = []
    @State private var playerTeamId: UUID?
    @State private var animationIdx = 0
    @State private var showTransferConfirmation = false
    @State private var showTransferSheet = false
    @State private var transfersRemaining = 0
    @State private var totalTransfers = 0
    @State private var midseasonTransferDone = false
    @State private var animatingTransferCount = false
    @State private var displayTransferCount = 0

    private let batchSize = 3
    private let revealStep = 1
    private var delay: Double { UserDefaults.standard.bool(forKey: "fastMode") ? 0.05 : 1.0 }

    /// Dynasty difficulty ramp: each title won reduces the player's match bonus
    /// (capped at full erosion), making repeat title runs progressively harder.
    private func difficultyRamp(seasonsWon: Int) -> Double {
        min(1.0, Double(seasonsWon) * 0.25)
    }

    /// While simulating shows a progress screen; once the result exists, renders the
    /// header, match list, league table, skip button, and season-end section, plus the
    /// midseason transfer confirmation alert and sheet.
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
                                midseasonTransferDone = true
                                distributeRemainingMatchGoals()
                                animationIdx = playerMatches.count
                                revealedMatches = playerMatches.count
                                withAnimation { finished = true }
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 10))
                            .controlSize(.large)
                            .padding(.top, 30)
                            .tint(.green)
                        }
                        if finished {
                            seasonEndSection(result: result)
                        }
                    }
                }
                .onChange(of: scrollTarget) {
                    if let t = scrollTarget { withAnimation { proxy.scrollTo(t, anchor: .bottom) } }
                }
                .onChange(of: finished) {
                    if finished { saveIfNeeded() }
                }
            }
            .overlay {
                if showTransferConfirmation {
                    adaptiveOverlay
                        .ignoresSafeArea()
                    transferOfferOverlay
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                if showTransferSheet {
                    adaptiveOverlay
                        .ignoresSafeArea()
                    MidseasonTransferView(
                        totalTransfers: totalTransfers,
                        transfersRemaining: $transfersRemaining,
                        onComplete: { completeTransfers() }
                    )
                    .environmentObject(gameState)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: showTransferConfirmation)
            .animation(.easeOut(duration: 0.2), value: showTransferSheet)
        } else {
            ProgressView("Simulating season...")
                .onAppear { simulateAndAnimate() }
        }
    }

    /// Custom midseason-transfer prompt card, styled to match the app's other popups
    /// (dimmed backdrop + rounded card) instead of the default system alert.
    private var transferOfferOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)
            Text("Midseason Transfer Window")
                .font(.title3.weight(.bold))
            Text("The transfer window is open. Would you like to make transfers?")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("No") { skipTransfer() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .tint(.red)
                Button("Yes") { startTransfer() }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .tint(.green)
            }
            .padding(.top, 6)
        }
        .padding(26)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.25), radius: 20)
        .padding(30)
    }

    private var adaptiveOverlay: Color { adaptiveOverlayColor(for: colorScheme) }

    /// Picks 19 random league opponents and runs the season simulation, then starts
    /// the week-by-week reveal. Dynasty seasons raise the difficulty each title won.
    private func simulateAndAnimate() {
        let shuffled = leagueTeams.shuffled()
        let selectedOpponents = Array(shuffled.prefix(19))
        savedOpponents = selectedOpponents
        let dynastyCount = UserDefaults.standard.integer(forKey: "dynastySeasonCount")
        let simulated = SeasonSimulator.simulateSeason(
            playerTeam: playerTeam,
            opponents: selectedOpponents,
            projectedPosition: projectedPosition,
            difficulty: difficultyRamp(seasonsWon: dynastyCount)
        )
        result = simulated
        playerTeamId = simulated.playerTeamId
        animateMatches()
    }

    /// Resets the reveal index and begins revealing matches one at a time.
    private func animateMatches() {
        animationIdx = 0
        scheduleNext()
    }

    /// Advances the reveal by exactly `revealStep` matches per tick (one per second),
    /// while the UI window below still shows `batchSize` (three) games.
    private func scheduleNext() {
        guard let result = result else { return }
        let playerMatches = result.matches.filter { $0.homeTeam.id == result.playerTeamId || $0.awayTeam.id == result.playerTeamId }.sorted { $0.week < $1.week }
        guard animationIdx < playerMatches.count else {
            finished = true
            return
        }

        var end = min(animationIdx + revealStep, playerMatches.count)
        if expandedManagerialDecisions && !midseasonTransferDone && transfersRemaining == 0,
           let boundary = playerMatches[animationIdx..<end].firstIndex(where: { $0.week > 19 }) {
            if boundary == animationIdx {
                pauseForTransferConfirmation()
                return
            }
            end = boundary
        }

        for match in playerMatches[animationIdx..<end] {
            let playerScore = match.homeTeam.id == result.playerTeamId ? match.homeScore : match.awayScore
            distributePlayerGoals(goals: playerScore, matchId: match.id)
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            revealedMatches = end
        }
        animationIdx = end
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { scheduleNext() }
    }

    // MARK: - Midseason Transfer

    /// Shows the midseason transfer offer alert at the halfway point.
    private func pauseForTransferConfirmation() {
        showTransferConfirmation = true
    }

    /// Begins the transfer window, rolling a random transfer budget (1-3).
    private func startTransfer() {
        showTransferConfirmation = false
        let final = Int.random(in: 1...3)
        totalTransfers = final
        transfersRemaining = final
        displayTransferCount = final
        animatingTransferCount = false
        showTransferSheet = true
    }

    /// Declines the transfer window and resumes the season reveal.
    private func skipTransfer() {
        showTransferConfirmation = false
        midseasonTransferDone = true
        scheduleNext()
    }

    /// Closes the transfer sheet and resumes; if the player used transfers, re-simulates
    /// the second half with the upgraded squad.
    private func completeTransfers() {
        showTransferSheet = false
        midseasonTransferDone = true
        if transfersRemaining < totalTransfers {
            resimulateSecondHalf()
        }
        scheduleNext()
    }

    /// Re-simulates the season with the post-transfer squad, stitching the new second
    /// half onto the already-revealed first half and recomputing the standings.
    private func resimulateSecondHalf() {
        guard let currentResult = result, let id = playerTeamId, !savedOpponents.isEmpty else { return }
        let newTeam = Team(
            id: id,
            name: customTeamName(),
            offense: Int(gameState.adjustedAttackRating.rounded()),
            midfield: Int(gameState.adjustedMidfieldRating.rounded()),
            defense: Int(gameState.adjustedDefenseRating.rounded()),
            goalkeeper: Int(gameState.adjustedGkRating.rounded())
        )
        let newResult = SeasonSimulator.simulateSeason(
            playerTeam: newTeam,
            opponents: savedOpponents,
            projectedPosition: currentResult.projectedPosition,
            difficulty: difficultyRamp(seasonsWon: UserDefaults.standard.integer(forKey: "dynastySeasonCount"))
        )

        let firstHalf = currentResult.matches.filter { $0.week <= 19 }
        let secondHalf = newResult.matches.filter { $0.week > 19 }
        let allMatches = firstHalf + secondHalf

        var standingsDict: [UUID: LeagueStanding] = [:]
        for match in allMatches {
            standingsDict[match.homeTeam.id] = standingsDict[match.homeTeam.id] ?? LeagueStanding(team: match.homeTeam, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0)
            standingsDict[match.awayTeam.id] = standingsDict[match.awayTeam.id] ?? LeagueStanding(team: match.awayTeam, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0)
            standingsDict[match.homeTeam.id]!.wins += match.homeWin ? 1 : 0
            standingsDict[match.homeTeam.id]!.draws += match.draw ? 1 : 0
            standingsDict[match.homeTeam.id]!.losses += match.homeWin || match.draw ? 0 : 1
            standingsDict[match.homeTeam.id]!.goalsFor += match.homeScore
            standingsDict[match.homeTeam.id]!.goalsAgainst += match.awayScore
            standingsDict[match.awayTeam.id]!.wins += match.awayWin ? 1 : 0
            standingsDict[match.awayTeam.id]!.draws += match.draw ? 1 : 0
            standingsDict[match.awayTeam.id]!.losses += match.awayWin || match.draw ? 0 : 1
            standingsDict[match.awayTeam.id]!.goalsFor += match.awayScore
            standingsDict[match.awayTeam.id]!.goalsAgainst += match.homeScore
        }
        let sorted = standingsDict.values.sorted { a, b in
            if a.points != b.points { return a.points > b.points }
            if a.goalDiff != b.goalDiff { return a.goalDiff > b.goalDiff }
            return a.goalsFor > b.goalsFor
        }

        result = SeasonSimulationResult(
            matches: allMatches,
            standings: sorted,
            playerTeamId: id,
            projectedPosition: currentResult.projectedPosition
        )
    }

    /// Randomly attributes a match's goals to user players (and assists), weighted by
    /// position. Substitutes never feature in scoring.
    /// - Parameters:
    ///   - goals: Number of goals the player team scored in the match.
    ///   - matchId: The simulated match to store scorer names against.
    private func distributePlayerGoals(goals: Int, matchId: UUID) {
        guard !userPlayerNames.isEmpty else { return }
        let positions = playerPositions
        func goalWeightFor(_ name: String) -> Double {
            goalWeight(for: positions[name])
        }
        func assistWeightFor(_ name: String) -> Double {
            assistWeight(for: positions[name])
        }
        var scorersThisMatch: [String] = []
        for _ in 0..<goals {
            let weights = userPlayerNames.map { goalWeightFor($0) }
            let totalWeight = weights.reduce(0, +)
            let r = Double.random(in: 0..<totalWeight)
            var cumulative = 0.0
            var scorer = userPlayerNames[0]
            for (i, w) in zip(userPlayerNames, weights) {
                cumulative += w
                if r < cumulative { scorer = i; break }
            }
            playerGoals[scorer, default: 0] += 1
            scorersThisMatch.append(scorer)

            if Double.random(in: 0...1) < 0.5 && userPlayerNames.count > 1 {
                let otherNames = userPlayerNames.filter { $0 != scorer }
                let aR = Double.random(in: 0..<(otherNames.map { assistWeightFor($0) }.reduce(0, +)))
                var aCum = 0.0
                var assister = otherNames[0]
                for name in otherNames {
                    aCum += assistWeightFor(name)
                    if aR < aCum { assister = name; break }
                }
                playerAssists[assister, default: 0] += 1
            }
        }
        matchScorers[matchId] = scorersThisMatch
    }

    /// Distributes goals for any player matches that have not yet been revealed
    /// (used when skipping to the end so scorer totals still match the league
    /// table's goals-for column).
    private func distributeRemainingMatchGoals() {
        guard let result = result else { return }
        let playerMatches = result.matches
            .filter { $0.homeTeam.id == result.playerTeamId || $0.awayTeam.id == result.playerTeamId }
            .sorted { $0.week < $1.week }
        let remaining = playerMatches.suffix(playerMatches.count - min(animationIdx, playerMatches.count))
        for match in remaining {
            let playerScore = match.homeTeam.id == result.playerTeamId ? match.homeScore : match.awayScore
            distributePlayerGoals(goals: playerScore, matchId: match.id)
        }
    }

    /// Aggregates distributed goals/assists into sorted per-player season stats.
    private var computedPlayerStats: [PlayerSeasonStats] {
        var dict: [String: PlayerSeasonStats] = [:]
        for name in userPlayerNames {
            let g = playerGoals[name, default: 0]
            let a = playerAssists[name, default: 0]
            dict[name] = PlayerSeasonStats(playerName: name, goals: g, assists: a)
        }
        return dict.values.sorted { $0.goals > $1.goals || ($0.goals == $1.goals && $0.assists > $1.assists) }
    }

    /// The player team's matches from the simulated result, in gameweek order so the
    /// reveal and league table advance one week (each team one extra game) at a time.
    private var playerMatches: [SimulatedMatch] {
        guard let result = result else { return [] }
        return result.matches
            .filter { $0.homeTeam.id == result.playerTeamId || $0.awayTeam.id == result.playerTeamId }
            .sorted { $0.week < $1.week }
    }

    /// The most recently revealed batch of player matches (default batch of 3).
    private var visibleMatches: [SimulatedMatch] {
        Array(playerMatches.prefix(revealedMatches).suffix(batchSize))
    }

    /// All player matches revealed so far.
    private var allRevealedMatches: [SimulatedMatch] {
        Array(playerMatches.prefix(revealedMatches))
    }

    /// The player's cumulative record through the revealed matches.
    private func playerStanding(result: SeasonSimulationResult) -> LeagueStanding? {
        computePlayerCumulative(result: result, upTo: revealedMatches)
    }

    /// Computes the player's W-D-L and goals from the first `upTo` revealed matches.
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

    /// Recomputes the full league table from matches up to the current week, or returns
    /// the final standings once the whole season has been revealed.
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

    // MARK: - Header

    /// Season title and the player's live W-D-L / points record.
    private func header(result: SeasonSimulationResult) -> some View {
        VStack(spacing: 4) {
            Text("Season Results")
                .font(.system(size: 20).weight(.bold))
            if let st = finished ? result.playerStanding : playerStanding(result: result) {
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

    /// Revealed match list, showing only the most recent batch of player matches.
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

    /// One match row: game week, opponent with home/away marker, score, W/D/L badge,
    /// and the distributed scorer names for that game.
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

    // MARK: - Season End

    /// Season-end summary: finish tiles, Super League qualification indicator (if cups
    /// are enabled), and the button that reports results via `onSeasonComplete`.
    private func seasonEndSection(result: SeasonSimulationResult) -> some View {
        let qualified = enableCups && result.playerPosition <= 5
        return VStack(spacing: 10) {
            finishTiles(result: result)

            if enableCups {
                HStack(spacing: 6) {
                    Image(systemName: qualified ? "trophy.fill" : "xmark.circle")
                        .foregroundColor(qualified ? .yellow : .red)
                    Text(qualified ? "Super League Qualification!" : "Did Not Qualify for Super League")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(qualified ? .green : .red)
                }
                .padding(.vertical, 4)
            }

            Button(action: {
                onSeasonComplete(result, computedPlayerStats)
            }) {
                Text(qualified ? "Continue to Super League" : "View Season Summary")
                    .frame(maxWidth: .infinity)
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .controlSize(.large)
            .tint(qualified ? .green : .blue)
            .padding(.horizontal)
            .padding(.bottom, 15)
        }
    }

    /// Finish, projected position, points, and performance-vs-expectation tiles.
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

    /// League table: cumulative while the season reveals, final once finished, with
    /// top-5 qualification and relegation zones highlighted.
    private func leagueTable(result: SeasonSimulationResult) -> some View {
        let standings = finished ? result.standings : cumulativeStandings(result: result, upTo: revealedMatches)
        let rows = standings.enumerated().map { idx, st in
            LeagueTableRowData(
                id: st.team.id as AnyHashable,
                teamName: st.team.name,
                wins: st.wins,
                draws: st.draws,
                losses: st.losses,
                goalsFor: st.goalsFor,
                goalsAgainst: st.goalsAgainst,
                points: st.points,
                isPlayer: st.team.id == result.playerTeamId
            )
        }
        return LeagueTableSection(
            rows: rows,
            totalTeams: standings.count,
            showGP: true,
            showGSGA: true,
            qualStart: 1,
            qualEnd: 5,
            relStart: standings.count - 2
        )
        .padding(.horizontal)
        .padding(.bottom, finished ? 15 : 0)
    }

    // MARK: - Helpers

    /// Records the completed season into `CareerStats` exactly once, when the reveal
    /// finishes.
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

}

#Preview("Season Simulation") {
    PlaySeasonView(
        playerTeam: Team(name: "Your Team", offense: 85, midfield: 83, defense: 82),
        projectedPosition: 8,
        isMode38: false,
        overall: 84,
        userPlayerNames: ["Player 1", "Player 2"],
        enableCups: false,
        onRestart: {},
        onSeasonComplete: { _, _ in }
    )
}

#Preview("38-Game Season") {
    PlaySeasonView(
        playerTeam: Team(name: "Your Team", offense: 85, midfield: 83, defense: 82),
        projectedPosition: 12,
        isMode38: true,
        overall: 84,
        userPlayerNames: ["Player 1", "Player 2"],
        enableCups: false,
        onRestart: {},
        onSeasonComplete: { _, _ in }
    )
}
