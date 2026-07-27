import SwiftUI

struct CupKnockoutView: View {
    let competitionType: CupCompetitionType
    let playerTeamId: UUID
    let cupTeams: [CupTeam]
    let standings: [CupStanding]
    let knockoutRounds: [[CupKnockoutMatch]]
    let userPlayerNames: [String]
    let startingRoundIndex: Int
    let onComplete: (Bool, String?, Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentRoundIndex = 0
    @State private var roundTeams: [[CupTeam]] = []
    @State private var phase: KPhase = .drawing
    @State private var opponentPool: [CupTeam] = []
    @State private var opponent: CupTeam?
    @State private var allMatchups: [RoundMatchup] = []
    @State private var leg1: SimulatedKnockoutLeg?
    @State private var leg2: SimulatedKnockoutLeg?
    @State private var currentMinute = 0
    @State private var maxMinute = 90
    @State private var currentGoals: [GoalEvent] = []
    @State private var shownGoals: [GoalEvent] = []
    @State private var eliminated = false
    @State private var isChampion = false
    @State private var eliminatedIn: String? = nil
    @State private var showMatchups = false
    @State private var displayName = ""
    @State private var lockedOpponent = false
    @State private var currentLegIndex = 0
    @State private var simulationId = 0
    @State private var showHTBreak = false
    @State private var htBreakDone = false
    @State private var currentLegData: SimulatedKnockoutLeg? = nil

    private let maxLegs: [Int] = [2, 2, 2, 2, 1]

    enum KPhase {
        case drawing, intro, simulating, htBreak, legBreak, showingResults, end
    }

    private let roundNames = ["Knockout Playoffs", "Round of 16", "Quarter-finals", "Semi-finals", "Final"]
    private let potNames = ["Qualifying", "Round of 16", "Quarter-finals", "Semi-finals", "Final"]

    var body: some View {
        VStack(spacing: 0) {
            Text(roundNames[min(currentRoundIndex, 4)])
                .font(.title2.weight(.bold))
                .padding()

            switch phase {
            case .drawing:
                drawView
            case .intro:
                introView
            case .simulating:
                simulationView
            case .htBreak:
                htBreakView
            case .legBreak:
                legBreakView
            case .showingResults:
                resultsView
            case .end:
                endView
            }
        }
        .onAppear {
            currentRoundIndex = startingRoundIndex
            setupRound()
        }
    }

    // MARK: - Helpers

    private static func playerNamesForTeam(_ teamName: String, exclude ids: Set<UUID> = []) -> [String] {
        let teamPlayers = GameData.players.filter { $0.team == teamName && !ids.contains($0.id) }
        if !teamPlayers.isEmpty {
            return teamPlayers.map { $0.name }
        }
        return SimulatedKnockoutLeg.squadNames(for: teamName, count: 11)
    }

    private var playerTeam: CupTeam {
        cupTeams.first { $0.id == playerTeamId } ?? CupModels.playerTeam
    }

    private func opponentPlayerNames() -> [String] {
        guard let opp = opponent else { return [] }
        return Self.playerNamesForTeam(opp.name)
    }

    // MARK: - Setup

    private func setupRound() {
        guard currentRoundIndex < knockoutRounds.count, currentRoundIndex < maxLegs.count else {
            eliminated = true
            eliminatedIn = roundNames[min(currentRoundIndex, 4)]
            phase = .end
            return
        }

        let isFinal = currentRoundIndex >= 4
        let roundMatches = knockoutRounds[currentRoundIndex]

        let playerInRound = roundMatches.contains { $0.teamA.id == playerTeamId || $0.teamB.id == playerTeamId }
        guard playerInRound else {
            eliminated = true
            eliminatedIn = roundNames[min(currentRoundIndex, 4)]
            phase = .end
            return
        }

        var matchups: [RoundMatchup] = []
        var possibleOpponents: [CupTeam] = []

        for match in roundMatches {
            let isPlayerMatch = match.teamA.id == playerTeamId || match.teamB.id == playerTeamId
            if isPlayerMatch {
                let opp = match.teamA.id == playerTeamId ? match.teamB : match.teamA
                possibleOpponents.append(opp)
                matchups.append(RoundMatchup(
                    teamA: match.teamA, teamB: match.teamB,
                    leg1ScoreA: nil, leg1ScoreB: nil,
                    leg2ScoreA: nil, leg2ScoreB: nil,
                    winner: nil, isPlayerMatch: true
                ))
            } else if isFinal {
                let awayNames = Self.playerNamesForTeam(match.teamB.name)
                let homeNames = Self.playerNamesForTeam(match.teamA.name)
                let leg = SimulatedKnockoutLeg(home: match.teamA, away: match.teamB, isFinal: true,
                                               homePlayerNames: homeNames, awayPlayerNames: awayNames)
                let winner: CupTeam? = leg.totalHomeScore > leg.totalAwayScore ? match.teamA
                    : leg.totalAwayScore > leg.totalHomeScore ? match.teamB
                    : leg.penaltyHome > leg.penaltyAway ? match.teamA
                    : match.teamB
                matchups.append(RoundMatchup(
                    teamA: match.teamA, teamB: match.teamB,
                    leg1ScoreA: leg.totalHomeScore, leg1ScoreB: leg.totalAwayScore,
                    leg2ScoreA: nil, leg2ScoreB: nil,
                    winner: winner, isPlayerMatch: false
                ))
            } else {
                let awayNames = Self.playerNamesForTeam(match.teamB.name)
                let homeNames = Self.playerNamesForTeam(match.teamA.name)
                let leg1Sim = SimulatedKnockoutLeg(home: match.teamA, away: match.teamB, isFinal: false,
                                                   homePlayerNames: homeNames, awayPlayerNames: awayNames)
                let revAwayNames = Self.playerNamesForTeam(match.teamA.name)
                let revHomeNames = Self.playerNamesForTeam(match.teamB.name)
                let leg2Sim = SimulatedKnockoutLeg(home: match.teamB, away: match.teamA, isFinal: false,
                                                   homePlayerNames: revHomeNames, awayPlayerNames: revAwayNames)
                let aggA = leg1Sim.totalHomeScore + leg2Sim.totalAwayScore
                let aggB = leg1Sim.totalAwayScore + leg2Sim.totalHomeScore
                let winner: CupTeam? = aggA > aggB ? match.teamA : (aggB > aggA ? match.teamB : nil)
                matchups.append(RoundMatchup(
                    teamA: match.teamA, teamB: match.teamB,
                    leg1ScoreA: leg1Sim.totalHomeScore, leg1ScoreB: leg1Sim.totalAwayScore,
                    leg2ScoreA: leg2Sim.totalAwayScore, leg2ScoreB: leg2Sim.totalHomeScore,
                    winner: winner, isPlayerMatch: false
                ))
            }
        }

        allMatchups = matchups
        currentLegIndex = 0
        htBreakDone = false

        if possibleOpponents.isEmpty {
            advanceOrEnd()
            return
        }

        opponentPool = possibleOpponents
        opponent = possibleOpponents.first
        phase = .drawing
        startDraw()
    }

    // MARK: - Draw

    private func startDraw() {
        displayName = ""
        lockedOpponent = false

        func cycle() {
            guard !lockedOpponent else { return }
            displayName = cupTeams.filter { $0.id != playerTeamId }.randomElement()?.name ?? "???"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: cycle)
        }
        cycle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            lockedOpponent = true
            displayName = opponent?.name ?? "Unknown"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { phase = .intro }
            }
        }
    }

    private var drawView: some View {
        VStack(spacing: 20) {
            Text(lockedOpponent ? opponent?.name ?? "???" : displayName)
                .font(.system(size: 36, weight: .bold))
                .padding(.top, 40)
            Text(lockedOpponent ? "Your opponent is set!" : "Drawing opponent...")
                .foregroundColor(.secondary)
            if !lockedOpponent {
                ProgressView().padding(.top, 8)
            }
            Spacer()
        }
    }

    // MARK: - Intro

    private var introView: some View {
        let isFinal = currentRoundIndex >= 4
        let legs = maxLegs[min(currentRoundIndex, maxLegs.count - 1)]
        return VStack(spacing: 16) {
            Text("Your Team")
                .font(.headline)
            Text(playerTeam.name)
                .font(.title2.weight(.bold))

            Text("vs")
                .font(.title3).foregroundColor(.secondary)

            Text(opponent?.name ?? "???")
                .font(.title2.weight(.bold))

            if isFinal {
                Text("Final")
                    .font(.headline).foregroundColor(.yellow)
            } else if legs > 1 {
                Text(currentLegIndex == 0 ? "First Leg" : "Second Leg")
                    .font(.headline).foregroundColor(.blue)
            }

            Button(action: {
                startSimulation()
            }) {
                Text("Play Match")
                    .frame(maxWidth: .infinity)
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal)
            .padding(.top, 16)

            Spacer()
        }
        .padding()
    }

    // MARK: - Simulation

    private func startSimulation() {
        let isFinal = currentRoundIndex >= 4
        let home: CupTeam
        let away: CupTeam
        let leg: SimulatedKnockoutLeg

        let homeNames: [String]?
        let awayNames: [String]?

        if currentLegIndex == 0 {
            home = playerTeam
            away = opponent!
            homeNames = userPlayerNames.isEmpty ? nil : userPlayerNames
            awayNames = opponentPlayerNames()
            leg = SimulatedKnockoutLeg(home: home, away: away, isFinal: isFinal,
                                       homePlayerNames: homeNames, awayPlayerNames: awayNames)
            leg1 = leg
            maxMinute = 90
            if leg.neededExtraTime && isFinal { maxMinute = 120 }
        } else {
            home = opponent!
            away = playerTeam
            homeNames = opponentPlayerNames()
            awayNames = userPlayerNames.isEmpty ? nil : userPlayerNames
            leg = SimulatedKnockoutLeg(home: home, away: away, isFinal: false,
                                       homePlayerNames: homeNames, awayPlayerNames: awayNames)
            leg2 = leg
            maxMinute = 90
        }

        currentGoals = leg.goals + leg.etGoals
        shownGoals = []
        currentMinute = 0
        showHTBreak = false
        htBreakDone = false
        currentLegData = leg
        simulationId += 1
        let currentId = simulationId

        withAnimation { phase = .simulating }
        simulateMinuteByMinute(leg: leg, id: currentId)
    }

    private func resumeSimulation() {
        guard let leg = currentLegData else { return }
        showHTBreak = false
        simulationId += 1
        let currentId = simulationId
        simulateMinuteByMinute(leg: leg, id: currentId)
    }

    private var simulationView: some View {
        let isFinal = currentRoundIndex >= 4
        let isLeg2 = currentLegIndex == 1

        let hTeam = currentLegIndex == 0 ? playerTeam : opponent!
        let aTeam = currentLegIndex == 0 ? opponent! : playerTeam

        let hScore = currentGoals.filter { $0.teamId == hTeam.id && $0.minute <= currentMinute }.count
        let aScore = currentGoals.filter { $0.teamId == aTeam.id && $0.minute <= currentMinute }.count

        var aggH = hScore
        var aggA = aScore
        if isLeg2, let l1 = leg1 {
            aggH += l1.totalAwayScore
            aggA += l1.totalHomeScore
        }

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 6) {
                scoreboard

                if !shownGoals.isEmpty {
                    LazyVStack(spacing: 2) {
                        ForEach(shownGoals) { goal in
                            goalRow(goal: goal, hTeamId: hTeam.id, aTeamId: aTeam.id)
                        }
                    }
                    .padding(.horizontal, 12)
                } else {
                    Text("No goals yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }

                if showHTBreak {
                    VStack(spacing: 12) {
                        Text("Half Time")
                            .font(.title2.weight(.bold))
                        let hs = currentGoals.filter { $0.teamId == hTeam.id && $0.minute <= currentMinute }.count
                        let as_ = currentGoals.filter { $0.teamId == aTeam.id && $0.minute <= currentMinute }.count
                        Text("\(hTeam.name) \(hs) - \(as_) \(aTeam.name)")
                            .font(.title3)
                        Button(action: {
                            resumeSimulation()
                        }) {
                            Text("Continue to Second Half")
                                .frame(maxWidth: .infinity)
                                .font(.headline.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .controlSize(.large)
                        .tint(.green)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                } else if currentMinute >= maxMinute && shownGoals.count >= currentGoals.count {
                    Button(action: {
                        let legs = maxLegs[min(currentRoundIndex, maxLegs.count - 1)]
                        if legs > 1 && currentLegIndex == 0 {
                            currentLegIndex = 1
                            withAnimation { phase = .legBreak }
                        } else {
                            updatePlayerMatchup()
                            withAnimation { phase = .showingResults }
                        }
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
                    .tint(.green)
                    .padding(.bottom, 8)
                }

                if htBreakDone && !allMatchups.isEmpty {
                    allMatchupsSection
                        .padding(.bottom, 8)
                }
            }
            .padding(.top, 4)
        }
    }

    private func goalRow(goal: GoalEvent, hTeamId: UUID, aTeamId: UUID) -> some View {
        let isHome = goal.teamId == hTeamId
        return HStack(spacing: 6) {
            if isHome {
                Text("\(goal.minute)'")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 28)
                Text(goal.scorer)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if goal.isPenalty {
                    Text("(P)")
                        .font(.system(size: 9)).foregroundColor(.orange)
                }
                if goal.isOwnGoal {
                    Text("(OG)")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                if goal.isExtraTime {
                    Text("ET")
                        .font(.system(size: 9)).foregroundColor(.orange)
                }
                Spacer()
            } else {
                Spacer()
                if goal.isExtraTime {
                    Text("ET")
                        .font(.system(size: 9)).foregroundColor(.orange)
                }
                if goal.isOwnGoal {
                    Text("(OG)")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                if goal.isPenalty {
                    Text("(P)")
                        .font(.system(size: 9)).foregroundColor(.orange)
                }
                Text(goal.scorer)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(goal.minute)'")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 28)
            }
        }
        .padding(.vertical, 2)
        .transition(.opacity)
    }

    private var scoreboard: some View {
        let isFinal = currentRoundIndex >= 4
        let isLeg2 = currentLegIndex == 1

        let hTeam = currentLegIndex == 0 ? playerTeam : opponent!
        let aTeam = currentLegIndex == 0 ? opponent! : playerTeam

        let hScore = currentGoals.filter { $0.teamId == hTeam.id && $0.minute <= currentMinute }.count
        let aScore = currentGoals.filter { $0.teamId == aTeam.id && $0.minute <= currentMinute }.count

        var aggH = hScore
        var aggA = aScore
        if isLeg2, let l1 = leg1 {
            aggH += l1.totalAwayScore
            aggA += l1.totalHomeScore
        }

        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                teamScoreColumn(name: hTeam.name, score: hScore, isPlayer: hTeam.id == playerTeamId)
                Text("vs")
                    .font(.caption).foregroundColor(.secondary)
                teamScoreColumn(name: aTeam.name, score: aScore, isPlayer: aTeam.id == playerTeamId)
            }

            HStack(spacing: 4) {
                Text("\(currentMinute)'")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(currentMinute > 45 && !(currentMinute > 90 && maxMinute <= 90) && !(currentMinute > 90 && !isFinal) ? .orange : .primary)
                if currentMinute > 90 {
                    Text("ET")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.orange)
                }
            }

            if isLeg2 {
                HStack(spacing: 8) {
                    Text("Agg: \(aggH)-\(aggA)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.yellow)
                    if currentMinute >= maxMinute && shownGoals.count >= currentGoals.count {
                        if aggH > aggA {
                            Text("(\(hTeam.name) adv.)")
                                .font(.caption.weight(.bold)).foregroundColor(.green)
                        } else if aggA > aggH {
                            Text("(\(aTeam.name) adv.)")
                                .font(.caption.weight(.bold)).foregroundColor(.green)
                        } else {
                            Text("(ET / Pens)")
                                .font(.caption.weight(.bold)).foregroundColor(.orange)
                        }
                    }
                }
            }

            if !isLeg2 || !isFinal {
                if currentMinute >= maxMinute, let l = currentLegIndex == 0 ? leg1 : leg2 {
                    if l.neededExtraTime && !(isLeg2 && !isFinal) {
                        Text("Extra Time")
                            .font(.caption.weight(.bold)).foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func teamScoreColumn(name: String, score: Int, isPlayer: Bool) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption.weight(isPlayer ? .bold : .semibold))
                .lineLimit(1)
            Text("\(score)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(isPlayer ? .blue : .primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func simulateMinuteByMinute(leg: SimulatedKnockoutLeg, id: Int) {
        let allEvents = (leg.goals + leg.etGoals).sorted { $0.minute < $1.minute }
        var eventIdx = 0

        func tick() {
            guard id == simulationId else { return }
            guard currentMinute < maxMinute else {
                currentMinute = maxMinute
                return
            }
            currentMinute += 1

            while eventIdx < allEvents.count && allEvents[eventIdx].minute <= currentMinute {
                withAnimation(.easeIn(duration: 0.3)) {
                    shownGoals.append(allEvents[eventIdx])
                }
                eventIdx += 1
            }

            if currentMinute == 45 && maxMinute > 45 {
                let hTeam = currentLegIndex == 0 ? playerTeam : opponent!
                let aTeam = currentLegIndex == 0 ? opponent! : playerTeam
                let hHalfScore = currentGoals.filter { $0.teamId == hTeam.id && $0.minute <= currentMinute && $0.isFirstHalf }.count
                let aHalfScore = currentGoals.filter { $0.teamId == aTeam.id && $0.minute <= currentMinute && $0.isFirstHalf }.count
                if hHalfScore != 0 || aHalfScore != 0 || allEvents.contains(where: { $0.minute > 45 }) {
                    htBreakDone = true
                    showHTBreak = true
                    return
                }
            }

            let fast = UserDefaults.standard.bool(forKey: "fastMode")
            if eventIdx < allEvents.count {
                let nextGoalMin = allEvents[eventIdx].minute
                let nextTick = fast ? 5 : min(nextGoalMin - currentMinute, 1) * 200 + 80
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(nextTick), execute: tick)
            } else if currentMinute < maxMinute {
                let d = fast ? 5 : (currentMinute < 45 ? 60 : (currentMinute < 90 ? 50 : 80))
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(d), execute: tick)
            }
        }
        tick()
    }

    // MARK: - HT Break

    private var htBreakView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Half Time")
                .font(.largeTitle.weight(.bold))
            let hScore = currentGoals.filter { $0.teamId == (currentLegIndex == 0 ? playerTeam : opponent!).id && $0.minute <= currentMinute }.count
            let aScore = currentGoals.filter { $0.teamId == (currentLegIndex == 0 ? opponent! : playerTeam).id && $0.minute <= currentMinute }.count
            Text("\(currentLegIndex == 0 ? playerTeam.name : opponent!.name) \(hScore) - \(aScore) \(currentLegIndex == 0 ? opponent!.name : playerTeam.name)")
                .font(.title2)
            Text("Second half starting soon...")
                .foregroundColor(.secondary)
            Button(action: {
                resumeSimulation()
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
            Spacer()
        }
    }

    // MARK: - Leg Break

    private var legBreakView: some View {
        let isFinal = currentRoundIndex >= 4
        return VStack(spacing: 16) {
            if let l1 = leg1 {
                Text(isFinal ? "Full Time Result" : "First Leg Result")
                    .font(.headline)
                Text("\(playerTeam.name) \(l1.totalHomeScore) - \(l1.totalAwayScore) \(opponent?.name ?? "")")
                    .font(.title2.weight(.bold))
                if !isFinal {
                    Text("Second Leg coming up...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Button(action: {
                        startSimulation()
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
                }
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Results

    private func updatePlayerMatchup() {
        let teamA = playerTeam
        let teamB = opponent!
        let isFinal = currentRoundIndex >= 4

        if isFinal, let l1 = leg1 {
            let winner: CupTeam? = l1.totalHomeScore > l1.totalAwayScore ? teamA
                : l1.totalAwayScore > l1.totalHomeScore ? teamB
                : l1.penaltyHome > l1.penaltyAway ? teamA : teamB
            if let idx = allMatchups.firstIndex(where: { $0.isPlayerMatch }) {
                allMatchups[idx] = RoundMatchup(
                    teamA: teamA, teamB: teamB,
                    leg1ScoreA: l1.totalHomeScore, leg1ScoreB: l1.totalAwayScore,
                    leg2ScoreA: nil, leg2ScoreB: nil,
                    winner: winner, isPlayerMatch: true
                )
            }
        } else if let l1 = leg1, let l2 = leg2 {
            let totalA = l1.totalHomeScore + l2.totalAwayScore
            let totalB = l1.totalAwayScore + l2.totalHomeScore
            let winner: CupTeam? = totalA > totalB ? teamA : (totalB > totalA ? teamB : nil)
            if let idx = allMatchups.firstIndex(where: { $0.isPlayerMatch }) {
                allMatchups[idx] = RoundMatchup(
                    teamA: teamA, teamB: teamB,
                    leg1ScoreA: l1.totalHomeScore, leg1ScoreB: l1.totalAwayScore,
                    leg2ScoreA: l2.totalAwayScore, leg2ScoreB: l2.totalHomeScore,
                    winner: winner, isPlayerMatch: true
                )
            }
        }
    }

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                Text(roundNames[min(currentRoundIndex, 4)] + " Results")
                    .font(.title2.weight(.bold))
                    .padding(.top)

                let isFinal = currentRoundIndex >= 4

                if isFinal {
                    finalResultSection
                } else {
                    twoLegResultSection
                }

                Divider().padding(.horizontal)

                allMatchupsSection

                if !eliminated && !isChampion && playerAdvanced {
                    Button(action: {
                        currentLegIndex = 0
                        leg1 = nil
                        leg2 = nil
                        simulationId += 1
                        currentRoundIndex += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.setupRound()
                        }
                    }) {
                        Text("Continue to Next Round")
                            .frame(maxWidth: .infinity)
                            .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .tint(.green)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                } else {
                    Button(action: {
                        onComplete(eliminated, eliminatedIn, isChampion)
                    }) {
                        Text("View Full Results")
                            .frame(maxWidth: .infinity)
                            .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .tint(.green)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
            .onAppear {
                if !playerAdvanced {
                    eliminated = true
                    eliminatedIn = roundNames[min(currentRoundIndex, 4)]
                    isChampion = false
                } else if currentRoundIndex >= 4 {
                    isChampion = true
                }
            }
        }
    }

    private var finalResultSection: some View {
        let l1 = leg1
        let hS = l1?.homeScore ?? 0
        let aS = l1?.awayScore ?? 0
        let hET = l1?.etHomeScore ?? 0
        let aET = l1?.etAwayScore ?? 0
        let hPen = l1?.penaltyHome ?? 0
        let aPen = l1?.penaltyAway ?? 0
        let totalH = hS + hET
        let totalA = aS + aET

        return VStack(spacing: 8) {
            Text("Final Score")
                .font(.headline)

            HStack(spacing: 16) {
                Text(playerTeam.name).fontWeight(.bold)
                Text("\(totalH)-\(totalA)")
                    .font(.system(size: 32, weight: .bold))
                Text(opponent?.name ?? "").fontWeight(.bold)
            }

            if hS == aS && hET == aET && hPen > 0 {
                Text("Penalties: \(hPen)-\(aPen)")
                    .font(.title3).foregroundColor(.orange)
            } else if hS == aS {
                Text("After Extra Time")
                    .font(.subheadline).foregroundColor(.orange)
            }

            if totalH > totalA {
                Label("Champions!", systemImage: "trophy.fill").foregroundColor(.yellow).font(.title2)
            } else {
                Label("Runner-up", systemImage: "medal.fill").foregroundColor(.gray).font(.title2)
            }

            if let l1 = leg1, !l1.goals.isEmpty || !l1.etGoals.isEmpty {
                finalGoalsList(l1)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func finalGoalsList(_ leg: SimulatedKnockoutLeg) -> some View {
        VStack(spacing: 6) {
            Text("Scorers")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(playerTeam.name)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.blue)
                    ForEach(leg.goals + leg.etGoals) { g in
                        if g.teamId == playerTeamId {
                            Text("\(g.minute)' \(g.scorer)\(g.isPenalty ? " (P)" : "")\(g.isExtraTime ? " ET" : "")")
                                .font(.system(size: 11))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(opponent?.name ?? "")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.red)
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

    private var twoLegResultSection: some View {
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
            isPlayerWinner = true
            winnerName = playerTeam.name
        }

        return AnyView(
            VStack(spacing: 8) {
                Text("Aggregate: \(totalA)-\(totalB)")
                    .font(.title2.weight(.bold))
                Text("\(winnerName) advances")
                    .font(.headline)
                    .foregroundColor(isPlayerWinner ? .green : .red)

                HStack(spacing: 12) {
                    VStack {
                        Text("Leg 1").font(.caption).foregroundColor(.secondary)
                        Text("\(score1A)-\(score1B)")
                            .font(.title3.weight(.bold))
                    }
                    Text("•").foregroundColor(.secondary)
                    VStack {
                        Text("Leg 2").font(.caption).foregroundColor(.secondary)
                        Text("\(score2A)-\(score2B)")
                            .font(.title3.weight(.bold))
                    }
                }

                if let l = leg1, !l.goals.isEmpty || !l.etGoals.isEmpty {
                    twoLegGoalsList(l, label: "Leg 1")
                }
                if let l = leg2, !l.goals.isEmpty || !l.etGoals.isEmpty {
                    twoLegGoalsList(l, label: "Leg 2")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        )
    }

    private func twoLegGoalsList(_ leg: SimulatedKnockoutLeg, label: String) -> some View {
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

    private var allMatchupsSection: some View {
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

            ForEach(allMatchups) { matchup in
                matchupRow(matchup)
                if matchup.id != allMatchups.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private func matchupRow(_ m: RoundMatchup) -> some View {
        let isPlayer = m.isPlayerMatch

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(m.teamA.name)
                        .font(.system(size: 11, weight: m.winner?.id == m.teamA.id ? .bold : .regular))
                    if m.winner?.id == m.teamA.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10)).foregroundColor(.green)
                    }
                }
                HStack {
                    Text(m.teamB.name)
                        .font(.system(size: 11, weight: m.winner?.id == m.teamB.id ? .bold : .regular))
                    if m.winner?.id == m.teamB.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10)).foregroundColor(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if m.isComplete {
                Text("\(m.leg1ScoreA!)-\(m.leg1ScoreB!)")
                    .font(.system(size: 10, weight: .semibold))
                if let l2a = m.leg2ScoreA {
                    Text("\(l2a)-\(m.leg2ScoreB!)")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text("\(m.aggregateScore)")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 36, alignment: .trailing)
            } else if isPlayer {
                Text("In Progress")
                    .font(.system(size: 10)).foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isPlayer ? Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.08) : Color.clear)
    }

    // MARK: - End

    private var endView: some View {
        VStack(spacing: 20) {
            Spacer()
            if isChampion {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                Text("Champions!")
                    .font(.largeTitle.weight(.bold))
                Text("\(competitionType.rawValue) Winners")
                    .font(.title2)
            } else if eliminated {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                Text("Eliminated")
                    .font(.largeTitle.weight(.bold))
                Text(eliminatedIn ?? "")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                onComplete(eliminated, eliminatedIn, isChampion)
            }) {
                Text("View Full Results")
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
    }

    // MARK: - Logic

    private func advanceOrEnd() {
        let isFinal = currentRoundIndex >= 4 || currentRoundName == "Final"
        if isFinal {
            isChampion = true
            phase = .end
        } else {
            currentRoundIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.setupRound()
            }
        }
    }

    private var playerAdvanced: Bool {
        let isFinal = currentRoundIndex >= 4
        if isFinal {
            if let l1 = leg1 {
                return l1.totalHomeScore > l1.totalAwayScore || l1.penaltyHome > l1.penaltyAway
            }
            return false
        }
        if let l1 = leg1, let l2 = leg2 {
            let playerTotal = l1.totalHomeScore + l2.totalAwayScore
            let opponentTotal = l1.totalAwayScore + l2.totalHomeScore
            return playerTotal > opponentTotal
        }
        return false
    }

    private var currentRoundName: String {
        roundNames[min(currentRoundIndex, 4)]
    }
}

// MARK: - RoundMatchup

struct RoundMatchup: Identifiable {
    let id = UUID()
    let teamA: CupTeam
    let teamB: CupTeam
    let leg1ScoreA: Int?
    let leg1ScoreB: Int?
    let leg2ScoreA: Int?
    let leg2ScoreB: Int?
    let winner: CupTeam?
    let isPlayerMatch: Bool

    var isComplete: Bool {
        leg1ScoreA != nil
    }

    var aggregateScore: String {
        guard let l1a = leg1ScoreA, let l1b = leg1ScoreB else { return "" }
        let l2a = leg2ScoreA ?? 0
        let l2b = leg2ScoreB ?? 0
        let totalA = l1a + l2a
        let totalB = l1b + l2b
        return "\(totalA)-\(totalB)"
    }
}

#Preview {
    let pid = UUID()
    let pt = CupTeam(id: pid, name: "Your Team", offense: 85, midfield: 83, defense: 82, pot: 1)
    let opp1 = CupTeam(name: "Barcelona", offense: 94, midfield: 90, defense: 85, pot: 1)
    let opp2 = CupTeam(name: "Real Madrid", offense: 95, midfield: 90, defense: 88, pot: 1)
    CupKnockoutView(
        competitionType: .superLeague,
        playerTeamId: pid,
        cupTeams: [pt, opp1, opp2],
        standings: [],
        knockoutRounds: [[CupKnockoutMatch(id: UUID(), round: "Semi-finals", teamA: pt, teamB: opp1, leg1Home: pt, leg1ScoreA: 2, leg1ScoreB: 1, leg2ScoreA: 1, leg2ScoreB: 1)]],
        userPlayerNames: ["Player 1", "Player 2"],
        startingRoundIndex: 0,
        onComplete: { _, _, _ in }
    )
}
