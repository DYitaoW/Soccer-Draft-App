/// CupKnockoutView.swift
///
/// Playable knockout-stage flow: draws, two-legged ties, live/simulated matches,
/// penalties, and advancement to the next round.
import SwiftUI

/// Data shown in the full-screen goal popup that flashes when a knockout goal
/// is scored: who scored, the updated scoreline (home score on the left, away
/// on the right, matching the scoreboard), and whether it was the user.
private struct GoalPopupInfo {
    let id: UUID
    let teamName: String
    let isPlayer: Bool
    let homeScore: Int
    let awayScore: Int
}

/// Drives the knockout rounds of a cup competition as a phase state machine
/// (`.drawing` -> `.intro` -> `.simulating`, with break phases, then
/// `.showingResults`/`.end`). Requires pre-generated `knockoutRounds` and the
/// league `standings`; reports the player's final result and player stats via `onComplete`.
struct CupKnockoutView: View {
    let competitionType: CupCompetitionType
    let playerTeamId: UUID
    let cupTeams: [CupTeam]
    let standings: [CupStanding]
    let knockoutRounds: [[CupKnockoutMatch]]
    let userPlayerNames: [String]
    let userSubstituteNames: Set<String>
    let startingRoundIndex: Int
    let onComplete: (Bool, String?, Bool, [PlayerSeasonStats]) -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentRoundIndex = 0
    @State private var roundTeams: [[CupTeam]] = []
    @State private var phase: CupKnockoutPhase = .drawing
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
    @State private var showETBreak = false
    @State private var etBreakDone = false
    @State private var showETSecondBreak = false
    @State private var currentLegData: SimulatedKnockoutLeg? = nil
    @State private var aggregateTiebreakerWon: Bool = false
    @State private var showPenaltyPopup = false
    @State private var penaltyKicks: [PenaltyKick] = []
    @State private var penaltyActive = false
    @State private var penaltyOpponentResolving = false
    @State private var penaltyOpponentResult: Bool? = nil

    @State private var commentaryEvents: [(minute: Int, text: String, teamId: UUID?)] = []
    @State private var goalFlashId: UUID? = nil
    @State private var goalPopup: GoalPopupInfo? = nil
    @State private var hPlayerNames: [String] = []
    @State private var aPlayerNames: [String] = []
    @AppStorage("playablePenalties") private var playablePenalties = false

    private let maxLegs: [Int] = [2, 2, 2, 2, 1]
    /// Renders the round title and routes to the sub-view for the current phase,
    /// overlaying the penalty shootout popup when active. Kicks off `setupRound()`
    /// on appear.
    var body: some View {
        VStack(spacing: 0) {
            Text(knockoutRoundNames[min(currentRoundIndex, 4)])
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
        .overlay {
            if showPenaltyPopup {
                adaptiveOverlay
                    .ignoresSafeArea()
                penaltyShootoutPopup
                    .id(penaltyKicks.count)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else if let popup = goalPopup {
                (popup.isPlayer ? Color.green : Color.red)
                    .opacity(0.18)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                goalPopupView(popup)
                    .id(popup.id)
                    .transition(.scale(scale: 1.25).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showPenaltyPopup)
        .animation(.easeInOut(duration: 0.18), value: goalPopup?.id)
        .onChange(of: goalPopup?.id) {
            guard goalPopup != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.2)) { goalPopup = nil }
            }
        }
        .onAppear {
            currentRoundIndex = startingRoundIndex
            setupRound()
        }
    }

    private var adaptiveOverlay: Color { adaptiveOverlayColor(for: colorScheme) }

    // MARK: - Helpers

    /// Builds a plausible 11-player name list for an AI team, falling back to
    /// Resolves real squad names for an AI club from the player database, so the
    /// live feed uses actual players where they exist. Some super-league clubs
    /// are known by a different name in the database (Leipzig vs RB Leipzig,
    /// Villarreal vs Villareal), and some have no players at all — those fall
    /// back to nationality-appropriate generated squad names.
    /// - Parameters:
    ///   - teamName: The AI club's display name.
    ///   - ids: Player IDs to exclude from the result.
    private static func playerNamesForTeam(_ teamName: String, exclude ids: Set<UUID> = []) -> [String] {
        let aliases: [String: String] = [
            "Leipzig": "RB Leipzig",
            "Villarreal": "Villareal",
        ]
        let resolvedTeam = aliases[teamName] ?? teamName
        let teamPlayers = GameData.players.filter { $0.team == resolvedTeam && !ids.contains($0.id) }
        if !teamPlayers.isEmpty {
            return teamPlayers.map { $0.name }
        }
        return SimulatedKnockoutLeg.squadNames(for: teamName, count: 11)
    }

    /// The player's cup team, looked up by `playerTeamId`.
    private var playerTeam: CupTeam {
        cupTeams.first { $0.id == playerTeamId } ?? CupModels.playerTeam
    }

    /// Player names for the current drawn opponent. Names already on the user's
    /// squad are excluded (a drafted player should not line up against his own
    /// club), falling back to the full list if that would empty it.
    private func opponentPlayerNames() -> [String] {
        guard let opp = opponent else { return [] }
        let names = Self.playerNamesForTeam(opp.name)
        guard !userPlayerNames.isEmpty else { return names }
        let filtered = names.filter { !userPlayerNames.contains($0) }
        return filtered.isEmpty ? names : filtered
    }

    // MARK: - Setup

    /// Prepares a knockout round: builds the matchups for the current round index,
    /// pre-simulates all non-player ties (using simulated legs or random penalty
    /// resolution for drawn aggregates), resolves the player's actual opponent, and
    /// transitions to `.drawing`. Eliminates the player early if they are not in
    /// this round or the round is out of range.
    private func setupRound() {
        aggregateTiebreakerWon = false
        guard currentRoundIndex < knockoutRounds.count, currentRoundIndex < maxLegs.count else {
            eliminated = true
            eliminatedIn = knockoutRoundNames[min(currentRoundIndex, 4)]
            phase = .end
            return
        }

        let isFinal = currentRoundIndex >= 4
        let roundMatches = knockoutRounds[currentRoundIndex]

        let playerInRound = roundMatches.contains { $0.teamA.id == playerTeamId || $0.teamB.id == playerTeamId }
        guard playerInRound else {
            eliminated = true
            eliminatedIn = knockoutRoundNames[min(currentRoundIndex, 4)]
            phase = .end
            return
        }

        var matchups: [RoundMatchup] = []
        var actualOpponent: CupTeam? = nil

        var allRoundTeams: [CupTeam] = []
        for match in roundMatches {
            if !allRoundTeams.contains(where: { $0.id == match.teamA.id }) {
                allRoundTeams.append(match.teamA)
            }
            if !allRoundTeams.contains(where: { $0.id == match.teamB.id }) {
                allRoundTeams.append(match.teamB)
            }
        }
        let possibleOpponents = allRoundTeams.filter { $0.id != playerTeamId }

        for match in roundMatches {
            let isPlayerMatch = match.teamA.id == playerTeamId || match.teamB.id == playerTeamId
            if isPlayerMatch {
                actualOpponent = match.teamA.id == playerTeamId ? match.teamB : match.teamA
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
                                                   allowsExtraTime: false,
                                                   homePlayerNames: homeNames, awayPlayerNames: awayNames)
                let revAwayNames = Self.playerNamesForTeam(match.teamA.name)
                let revHomeNames = Self.playerNamesForTeam(match.teamB.name)
                let leg2Sim = SimulatedKnockoutLeg(home: match.teamB, away: match.teamA, isFinal: false,
                                                   allowsExtraTime: true,
                                                   homeAggLead: leg1Sim.totalAwayScore - leg1Sim.totalHomeScore,
                                                   homePlayerNames: revHomeNames, awayPlayerNames: revAwayNames)
                let aggA = leg1Sim.totalHomeScore + leg2Sim.totalAwayScore
                let aggB = leg1Sim.totalAwayScore + leg2Sim.totalHomeScore
                let winner: CupTeam? = aggA > aggB ? match.teamA : (aggB > aggA ? match.teamB : {
                    var pA = Int.random(in: 2...5); var pB = Int.random(in: 2...5)
                    while pA == pB { (pA, pB) = (Int.random(in: 2...5), Int.random(in: 2...5)) }
                    return pA > pB ? match.teamA : match.teamB
                }())
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

        opponent = actualOpponent

        if possibleOpponents.isEmpty {
            advanceOrEnd()
            return
        }

        opponentPool = possibleOpponents
        phase = .drawing
        startDraw()
    }

    // MARK: - Draw

    /// Runs the animated opponent draw: cycles random team names for ~1.5s, locks
    /// the actual opponent, then transitions to `.intro`.
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
        KnockoutDrawView(
            displayName: displayName,
            lockedOpponent: lockedOpponent,
            opponentName: opponent?.name,
            opponentPool: opponentPool,
            playerTeamId: playerTeamId
        )
    }

    // MARK: - Intro

    private var introView: some View {
        KnockoutIntroView(
            playerTeam: playerTeam,
            opponent: opponent,
            isFinal: currentRoundIndex >= 4,
            legs: maxLegs[min(currentRoundIndex, maxLegs.count - 1)],
            currentLegIndex: currentLegIndex,
            onPlay: { startSimulation() }
        )
    }

    // MARK: - Simulation

    /// Begins a leg by simulating it up front and revealing it minute-by-minute
    /// via `simulateMinuteByMinute`. Sets up home/away teams, player names,
    /// mentality, and extra-time allowances.
    private func startSimulation() {
        let isFinal = currentRoundIndex >= 4
        guard opponent != nil else { return }

        hPlayerNames = userPlayerNames
        aPlayerNames = opponentPlayerNames()

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
                                       allowsExtraTime: isFinal,
                                       homePlayerNames: homeNames, awayPlayerNames: awayNames,
                                       homeSubstituteNames: userSubstituteNames)
            leg1 = leg
            maxMinute = 90
            if leg.playedExtraTime { maxMinute = 120 }
        } else {
            home = opponent!
            away = playerTeam
            homeNames = opponentPlayerNames()
            awayNames = userPlayerNames.isEmpty ? nil : userPlayerNames
            let aggLead = (leg1?.totalAwayScore ?? 0) - (leg1?.totalHomeScore ?? 0)
            leg = SimulatedKnockoutLeg(home: home, away: away, isFinal: false,
                                       allowsExtraTime: true, homeAggLead: aggLead,
                                       homePlayerNames: homeNames, awayPlayerNames: awayNames,
                                       awaySubstituteNames: userSubstituteNames)
            leg2 = leg
            maxMinute = 90
            if leg.playedExtraTime { maxMinute = 120 }
        }

        currentGoals = leg.goals + leg.etGoals
        shownGoals = []
        commentaryEvents = []
        currentMinute = 0
        goalPopup = nil
        goalFlashId = nil
        showHTBreak = false
        htBreakDone = false
        showETBreak = false
        etBreakDone = false
        showETSecondBreak = false
        currentLegData = leg
        simulationId += 1
        let currentId = simulationId

        withAnimation { phase = .simulating }
        simulateMinuteByMinute(leg: leg, id: currentId)
    }

    /// Resumes a paused simulation, restarting the minute-by-minute reveal
    /// from the current minute.
    private func resumeSimulation() {
        guard let leg = currentLegData else { return }
        let isETResume = showETBreak || showETSecondBreak
        showHTBreak = false
        showETBreak = false
        showETSecondBreak = false

        guard !isETResume else {
            simulationId += 1
            simulateMinuteByMinute(leg: leg, id: simulationId)
            return
        }

        simulationId += 1
        let currentId = simulationId
        simulateMinuteByMinute(leg: leg, id: currentId)
    }

    /// Minute-by-minute match reveal: scoreboard, scorers, commentary, half-time /
    /// extra-time breaks, and the Continue / penalty footer. In leg 2 it shows
    /// the aggregate score.
    private var simulationView: AnyView {
        let isLeg2 = currentLegIndex == 1

        guard let opp = opponent else { return AnyView(Text("No opponent found").foregroundColor(.secondary)) }
        let hTeam = currentLegIndex == 0 ? playerTeam : opp
        let aTeam = currentLegIndex == 0 ? opp : playerTeam

        let hScore = currentGoals.filter { $0.teamId == hTeam.id && $0.minute <= currentMinute }.count
        let aScore = currentGoals.filter { $0.teamId == aTeam.id && $0.minute <= currentMinute }.count

        var aggH = hScore
        var aggA = aScore
        if isLeg2, let l1 = leg1 {
            aggH += l1.totalAwayScore
            aggA += l1.totalHomeScore
        }

        let matchDone = currentMinute >= maxMinute && shownGoals.count >= currentGoals.count

        return AnyView(ZStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        scoreboard
                            .padding(.horizontal)

                        KnockoutScorersBox(
                            homeGoals: shownGoals.filter { $0.teamId == hTeam.id },
                            awayGoals: shownGoals.filter { $0.teamId == aTeam.id }
                        )

                        KnockoutCommentaryBox(events: commentaryEvents)

                        if penaltyActive && playablePenalties {
                            penaltyShootoutStatusPanel
                        }

                        if showHTBreak {
                            VStack(spacing: 8) {
                                Text("Half Time")
                                    .font(.title2.weight(.bold))
                                let hs = currentGoals.filter { $0.teamId == hTeam.id && $0.minute <= currentMinute }.count
                                let as_ = currentGoals.filter { $0.teamId == aTeam.id && $0.minute <= currentMinute }.count
                                Text("\(hTeam.name) \(hs) - \(as_) \(aTeam.name)")
                                    .font(.title3)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }

                        if showETBreak {
                            VStack(spacing: 8) {
                                Text("Extra Time")
                                    .font(.title2.weight(.bold))
                                let hs = currentGoals.filter { $0.teamId == hTeam.id && $0.minute <= currentMinute }.count
                                let as_ = currentGoals.filter { $0.teamId == aTeam.id && $0.minute <= currentMinute }.count
                                Text("\(hTeam.name) \(hs) - \(as_) \(aTeam.name)")
                                    .font(.title3)
                                Text("Level after 90 minutes — extra time will be played")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }

                        if showETSecondBreak {
                            VStack(spacing: 8) {
                                Text("End of First Extra-Time Period")
                                    .font(.title2.weight(.bold))
                                let hs = currentGoals.filter { $0.teamId == hTeam.id && $0.minute <= currentMinute }.count
                                let as_ = currentGoals.filter { $0.teamId == aTeam.id && $0.minute <= currentMinute }.count
                                Text("\(hTeam.name) \(hs) - \(as_) \(aTeam.name)")
                                    .font(.title3)
                                Text("Second extra-time period starts at 106'")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 4)
                }

                if showHTBreak {
                    VStack(spacing: 0) {
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
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                } else if showETBreak {
                    VStack(spacing: 0) {
                        Button(action: {
                            resumeSimulation()
                        }) {
                            Text("Start Extra Time")
                                .frame(maxWidth: .infinity)
                                .font(.headline.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .controlSize(.large)
                        .tint(.orange)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                } else if showETSecondBreak {
                    VStack(spacing: 0) {
                        Button(action: {
                            resumeSimulation()
                        }) {
                            Text("Continue Extra Time")
                                .frame(maxWidth: .infinity)
                                .font(.headline.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .controlSize(.large)
                        .tint(.orange)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                } else if matchDone {
                    if penaltyActive && playablePenalties {
                        penaltyShootoutFooter
                    } else {
                        VStack(spacing: 0) {
                          //  Divider()
                            Button(action: {
                                let legs = maxLegs[min(currentRoundIndex, maxLegs.count - 1)]
                                if legs > 1 && currentLegIndex == 0 {
                                    currentLegIndex = 1
                                    withAnimation { phase = .legBreak }
                                } else if needsPenaltyShootout {
                                    beginPenaltyShootout()
                                } else {
                                    updatePlayerMatchup()
                                    withAnimation { phase = .showingResults }
                                }
                            }) {
                                Text(needsPenaltyShootout ? "Continue to Penalties" : "Continue")
                                    .frame(maxWidth: .infinity)
                                    .font(.headline.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 10))
                            .controlSize(.large)
                            .tint(.green)
                            .padding(.horizontal)
                          //  .padding(.vertical, 8)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
        })
    }

    // MARK: - Penalty Shootout Status

    private var penaltyShootoutStatusPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Penalty Shootout")
                    .font(.headline.weight(.bold))
                Spacer()
                if let leg = currentLegData {
                    Text("\(leg.homeTeam.name) \(penaltyHomeScore) - \(penaltyAwayScore) \(leg.awayTeam.name)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            if isUserTurn {
                HStack(spacing: 8) {
                    Image(systemName: "soccerball")
                        .foregroundColor(.green)
                    Text("Your turn to take a penalty")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                    Spacer()
                }
            } else if penaltyOpponentResolving {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("\(opponentName) is taking a penalty...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let r = penaltyOpponentResult {
                HStack(spacing: 8) {
                    Image(systemName: r ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(r ? .green : .red)
                    Text(r ? "GOAL!" : "SAVED!")
                        .font(.headline.weight(.bold))
                        .foregroundColor(r ? .green : .red)
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Text("\(opponentName) is up next")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var penaltyShootoutFooter: some View {
        VStack(spacing: 10) {
            if let leg = currentLegData {
                Text("Penalties  \(leg.homeTeam.name) \(penaltyHomeScore) - \(penaltyAwayScore) \(leg.awayTeam.name)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.orange)
            }
            if isUserTurn {
                Text("Tap a spot on the goal to take your penalty")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.bottom, 20)
    }

    // MARK: - Scoreboard

    private var scoreboard: AnyView {
        let isLeg2 = currentLegIndex == 1
        guard let opp = opponent else { return AnyView(EmptyView()) }

        let hTeam = currentLegIndex == 0 ? playerTeam : opp
        let aTeam = currentLegIndex == 0 ? opp : playerTeam

        let hScore = currentGoals.filter { $0.teamId == hTeam.id && $0.minute <= currentMinute }.count
        let aScore = currentGoals.filter { $0.teamId == aTeam.id && $0.minute <= currentMinute }.count

        var aggH = hScore
        var aggA = aScore
        if isLeg2, let l1 = leg1 {
            aggH += l1.totalAwayScore
            aggA += l1.totalHomeScore
        }

        return AnyView(VStack(spacing: 6) {
            HStack(spacing: 12) {
                teamScoreColumn(name: hTeam.name, score: hScore, isPlayer: hTeam.id == playerTeamId)
                Text("vs")
                    .font(.caption).foregroundColor(.secondary)
                teamScoreColumn(name: aTeam.name, score: aScore, isPlayer: aTeam.id == playerTeamId)
            }

            HStack(spacing: 4) {
                Text("\(currentMinute)'")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(currentMinute > 45 ? .orange : .primary)
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

            if let l = currentLegIndex == 0 ? leg1 : leg2, l.playedExtraTime {
                Text("Extra Time")
                    .font(.caption.weight(.bold)).foregroundColor(.orange)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        )
    }

    /// Full-screen goal celebration: soccer ball, the scoring team, the updated
    /// score, and a YOU/OPPONENT badge coloured to show whose team scored.
    private func goalPopupView(_ info: GoalPopupInfo) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "soccerball")
                .font(.system(size: 54))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 6)
            Text("GOAL!")
                .font(.system(size: 36, weight: .heavy))
                .foregroundColor(.white)
            Text(info.teamName)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            HStack(spacing: 16) {
                Text("\(info.homeScore)").font(.system(size: 48, weight: .black))
                Text("-").font(.system(size: 36, weight: .heavy))
                Text("\(info.awayScore)").font(.system(size: 48, weight: .black))
            }
            .foregroundColor(.white)
        /*    Text(info.isPlayer ? "YOUR TEAM" : "OPPONENT")
                .font(.caption.weight(.heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(info.isPlayer ? Color.green : Color.red)
                .clipShape(Capsule()) */
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(info.isPlayer ? Color.green : Color.red)
                .shadow(color: info.isPlayer ? .green : .red, radius: 26)
        )
    }

    /// Updates the live goal popup for a goal just shown in the playback, computing
    /// the new scoreline with the home team's score on the left and the away team's
    /// on the right, matching the sides used by the scoreboard.
    private func showGoalPopup(_ goal: GoalEvent, allGoals: [GoalEvent], leg: SimulatedKnockoutLeg) {
        let isPlayer = goal.teamId == playerTeamId
        let hTeam = currentLegIndex == 0 ? playerTeam : (opponent ?? playerTeam)
        let aTeam = currentLegIndex == 0 ? (opponent ?? playerTeam) : playerTeam
        let hScore = allGoals.filter { $0.teamId == hTeam.id && $0.minute <= goal.minute }.count
        let aScore = allGoals.filter { $0.teamId == aTeam.id && $0.minute <= goal.minute }.count
        let scoredTeam = goal.teamId == hTeam.id ? hTeam : aTeam
        goalPopup = GoalPopupInfo(id: goal.id, teamName: scoredTeam.name, isPlayer: isPlayer, homeScore: hScore, awayScore: aScore)
    }

    private func teamScoreColumn(name: String, score: Int, isPlayer: Bool) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption.weight(isPlayer ? .bold : .semibold))
                .lineLimit(1)
                .foregroundColor(isPlayer ? .primary : teamColor(named: name))
            Text("\(score)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(isPlayer ? .primary : teamColor(named: name))
                .contentTransition(.numericText())
                .scaleEffect(goalFlashId != nil && isPlayer ? 1.2 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.4), value: score)
                .onChange(of: score) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        goalFlashId = nil
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }

    /// Advances the match clock one minute at a time, revealing goals and cards as
    /// they happen, generating commentary, and pausing at half-time (45'), extra-time
    /// break (105'), and after each user goal when managerial decisions are enabled.
    /// - Parameters:
    ///   - leg: The pre-simulated leg being revealed.
    ///   - id: Token guarding against stale async ticks after a restart.
    private func simulateMinuteByMinute(leg: SimulatedKnockoutLeg, id: Int) {
        let allGoalEvents = (leg.goals + leg.etGoals).sorted { $0.minute < $1.minute }
        var goalIdx = shownGoals.count
        let allCardEvents = (leg.cards + leg.etCards).sorted { $0.minute < $1.minute }
        var cardIdx = 0
        var lastCommentaryMinute = 0

        func tick() {
            guard id == simulationId else { return }
            guard currentMinute < maxMinute else {
                currentMinute = maxMinute
                return
            }
            currentMinute += 1

            // Generate random commentary events every 3-7 minutes
            if currentMinute > lastCommentaryMinute + 2 && currentMinute < maxMinute && currentMinute != 45 {
                let chance = 0.15 + (allGoalEvents.count > goalIdx ? 0.10 : 0.0)
                if Double.random(in: 0...1) < chance {
                    let isHomeEvent = Bool.random()
                    let teamId = isHomeEvent ? leg.homeTeam.id : leg.awayTeam.id
                    let event = KnockoutCommentary.generateRandom(minute: currentMinute, home: leg.homeTeam, away: leg.awayTeam, hPlayers: hPlayerNames, aPlayers: aPlayerNames, isHome: isHomeEvent)
                    if !event.isEmpty {
                        commentaryEvents.append((currentMinute, event, teamId))
                        lastCommentaryMinute = currentMinute
                    }
                }
            }

            // Generate build-up commentary 1-2 minutes before the next goal
            if goalIdx < allGoalEvents.count {
                let nextGoal = allGoalEvents[goalIdx]
                let gap = nextGoal.minute - currentMinute
                if gap == 2 || gap == 1 {
                    if Double.random(in: 0...1) < 0.4 {
                        let buildUp = KnockoutCommentary.generateBuildUp(minute: currentMinute, goal: nextGoal, home: leg.homeTeam, away: leg.awayTeam, hPlayers: hPlayerNames, aPlayers: aPlayerNames)
                        if !buildUp.isEmpty {
                            commentaryEvents.append((currentMinute, buildUp, nextGoal.teamId))
                            lastCommentaryMinute = currentMinute
                        }
                    }
                }
            }

            // Show cards
            while cardIdx < allCardEvents.count && allCardEvents[cardIdx].minute <= currentMinute {
                let card = allCardEvents[cardIdx]
                commentaryEvents.append((card.minute, KnockoutCommentary.cardDescription(card), card.teamId))
                cardIdx += 1
            }

            // Show goals
            while goalIdx < allGoalEvents.count && allGoalEvents[goalIdx].minute <= currentMinute {
                let goal = allGoalEvents[goalIdx]
                withAnimation(.easeIn(duration: 0.3)) {
                    shownGoals.append(goal)
                    goalFlashId = goal.id
                }
                showGoalPopup(goal, allGoals: allGoalEvents, leg: leg)
                commentaryEvents.append((goal.minute, KnockoutCommentary.goalDescription(goal), goal.teamId))
                lastCommentaryMinute = currentMinute
                goalIdx += 1
            }

            if currentMinute == 45 && maxMinute > 45 {
                htBreakDone = true
                showHTBreak = true
                return
            }

            if currentMinute == 90 && maxMinute > 90 {
                showETBreak = true
                return
            }

            if currentMinute == 105 && maxMinute > 105 {
                showETSecondBreak = true
                return
            }

            let fast = UserDefaults.standard.bool(forKey: "fastMode")
            let d: Int
            if fast {
                d = 5
            } else if goalPopup != nil {
                // Hold a moment longer so the goal celebration is visible.
                d = 1500
            } else {
                let nextGoalMin = goalIdx < allGoalEvents.count ? allGoalEvents[goalIdx].minute : Int.max
                let nextCardMin = cardIdx < allCardEvents.count ? allCardEvents[cardIdx].minute : Int.max
                let nextEventMin = min(nextGoalMin, nextCardMin, maxMinute)
                if currentMinute >= nextEventMin - 2 {
                    d = 130
                } else {
                    d = 230
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(d), execute: tick)
        }
        tick()
    }

    // MARK: - HT Break

    private var htBreakView: some View {
        KnockoutHTBreakView(
            playerTeam: playerTeam,
            opponent: opponent,
            currentLegIndex: currentLegIndex,
            currentGoals: currentGoals,
            currentMinute: currentMinute,
            onContinue: { resumeSimulation() }
        )
    }

    // MARK: - Penalty Shootout

    /// True when the current leg is tied and must be settled by penalties: a single-leg
    /// final that finished level, or a second leg whose aggregate is level.
    private var needsPenaltyShootout: Bool {
        guard let leg = currentLegData else { return false }
        let legs = maxLegs[min(currentRoundIndex, maxLegs.count - 1)]
        if legs == 1 { return leg.neededPenalties }
        if currentLegIndex == 0 { return false }
        guard let l1 = leg1 else { return false }
        let playerTotal = l1.totalHomeScore + leg.totalAwayScore
        let oppTotal = l1.totalAwayScore + leg.totalHomeScore
        return playerTotal == oppTotal
    }

    /// Starts a penalty shootout. With playable penalties enabled the user takes
    /// kicks interactively; otherwise the shootout is simulated and shown as a popup.
    private func beginPenaltyShootout() {
        var leg = currentLegData
        if playablePenalties {
            leg?.penaltyKicks = []
            leg?.penaltyHome = 0
            leg?.penaltyAway = 0
            penaltyKicks = []
            penaltyActive = true
            penaltyOpponentResolving = false
            penaltyOpponentResult = nil
            currentLegData = leg
            if currentLegIndex == 0 { leg1 = leg } else { leg2 = leg }
            advancePenaltyTurn()
            return
        } else if leg?.penaltyKicks.isEmpty == true && leg != nil {
            let isPlayerHome = leg?.homeTeam.id == playerTeamId
            let hNames = isPlayerHome ? orderedUserShooters : orderedOpponentShooters
            let aNames = isPlayerHome ? orderedOpponentShooters : orderedUserShooters
            let hSubs = isPlayerHome ? userSubstituteNames : []
            let aSubs = isPlayerHome ? [] : userSubstituteNames
            let shootout = SimulatedKnockoutLeg.generatePenaltyShootout(homePlayers: hNames, awayPlayers: aNames, homeSubstitutes: hSubs, awaySubstitutes: aSubs)
            leg?.penaltyHome = shootout.home
            leg?.penaltyAway = shootout.away
            leg?.penaltyKicks = shootout.kicks
        }
        currentLegData = leg
        if currentLegIndex == 0 { leg1 = leg } else { leg2 = leg }
        withAnimation { showPenaltyPopup = true }
    }

    // MARK: - Playable Shootout Turns

    /// True when the user's team is listed as home in the current leg.
    private var isUserHome: Bool {
        guard let leg = currentLegData else { return false }
        return leg.homeTeam.id == playerTeamId
    }

    /// Home team is kicking when an even number of kicks have been taken.
    private var isHomeTurn: Bool { penaltyKicks.count % 2 == 0 }
    /// Whether it is the user's turn based on home/away rotation and their team side.
    private var isUserTurn: Bool { isHomeTurn == isUserHome }

    /// Shooter order for the home side of the shootout.
    private var homeShooters: [String] {
        isUserHome ? orderedUserShooters : orderedOpponentShooters
    }

    /// Shooter order for the away side of the shootout.
    private var awayShooters: [String] {
        isUserHome ? orderedOpponentShooters : orderedUserShooters
    }

    /// The user's shooter order (starters then substitutes) with realistic penalty positions.
    private var orderedUserShooters: [String] {
        SimulatedKnockoutLeg.orderedShooters(hPlayerNames, substitutes: userSubstituteNames, positionFor: SimulatedKnockoutLeg.position(for:))
    }

    /// The opponent's shooter order based on their squad's penalty positions.
    private var orderedOpponentShooters: [String] {
        SimulatedKnockoutLeg.orderedShooters(aPlayerNames, positionFor: SimulatedKnockoutLeg.position(for:))
    }

    private var penaltyHomeScore: Int { penaltyKicks.filter { $0.teamIsHome && $0.scored }.count }
    private var penaltyAwayScore: Int { penaltyKicks.filter { !$0.teamIsHome && $0.scored }.count }

    private var opponentName: String { opponent?.name ?? "Opponent" }

    /// The user's current shooter for the active kick round.
    private var currentUserShooter: String {
        let idx = penaltyKicks.count / 2
        let squad = orderedUserShooters
        return squad.isEmpty ? "Player \(idx + 1)" : squad[idx % squad.count]
    }

    /// True once the shootout cannot be caught, even if all remaining kicks score.
    private var penaltyShootoutDecided: Bool {
        let h = penaltyHomeScore
        let a = penaltyAwayScore
        let homeTaken = penaltyKicks.filter { $0.teamIsHome }.count
        let awayTaken = penaltyKicks.filter { !$0.teamIsHome }.count
        guard homeTaken == awayTaken, homeTaken > 0 else { return false }
        let remaining = homeTaken < 5 ? 5 - homeTaken : 0
        return abs(h - a) > remaining
    }

    /// Advances playable shootout turn-taking: ends the shootout if decided,
    /// otherwise presents the kick popup for the user's turn or the CPU's turn.
    private func advancePenaltyTurn() {
        guard penaltyActive else { return }
        if penaltyShootoutDecided {
            finishPenaltyShootout()
            return
        }
        penaltyOpponentResolving = false
        penaltyOpponentResult = nil
        withAnimation { showPenaltyPopup = true }
    }

    /// Records a kick (user or CPU) and advances to the next turn.
    private func handleKick(scored: Bool) {
        guard penaltyActive else { return }
        appendPenaltyKick(scored: scored)
        withAnimation { showPenaltyPopup = false }
        advancePenaltyTurn()
    }

    /// Appends a kick record to the shootout using the correct home/away rotation.
    private func appendPenaltyKick(scored: Bool) {
        let isHome = penaltyKicks.count % 2 == 0
        let round = penaltyKicks.count / 2 + 1
        let squad = isHome ? homeShooters : awayShooters
        let shooter = squad.isEmpty ? "Player \(round)" : squad[(penaltyKicks.count / 2) % squad.count]
        penaltyKicks.append(PenaltyKick(teamIsHome: isHome, shooter: shooter, scored: scored, round: round))
    }

    /// Ends the shootout: writes final penalty results back into the leg, resolves the
    /// aggregate tiebreaker, and moves on to the second leg or the results screen.
    private func finishPenaltyShootout() {
        showPenaltyPopup = false
        penaltyActive = false
        penaltyOpponentResolving = false
        penaltyOpponentResult = nil

        if playablePenalties {
            var leg = currentLegData
            leg?.penaltyHome = penaltyHomeScore
            leg?.penaltyAway = penaltyAwayScore
            leg?.penaltyKicks = penaltyKicks
            currentLegData = leg
            if currentLegIndex == 0 { leg1 = leg } else { leg2 = leg }
        }

        let legs = maxLegs[min(currentRoundIndex, maxLegs.count - 1)]
        if legs > 1 && currentLegIndex == 0 {
            currentLegIndex = 1
            withAnimation { phase = .legBreak }
            return
        }
        if legs > 1, let l2 = leg2, l2.neededPenalties {
            aggregateTiebreakerWon = l2.penaltyAway > l2.penaltyHome
        }
        updatePlayerMatchup()
        withAnimation { phase = .showingResults }
    }

    private var penaltyShootoutPopup: some View {
        Group {
            if playablePenalties {
                if let leg = currentLegData {
                    PlayablePenaltyShootoutView(
                        homeTeam: leg.homeTeam,
                        awayTeam: leg.awayTeam,
                        homeScore: penaltyHomeScore,
                        awayScore: penaltyAwayScore,
                        round: penaltyKicks.count / 2 + 1,
                        shooter: currentUserShooter,
                        isUserHome: isUserHome,
                        isCPU: !isUserTurn,
                        onComplete: { handleKick(scored: $0) }
                    )
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                        Text("Preparing penalties...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .onAppear { beginPenaltyShootout() }
                }
            } else if let leg = currentLegData, !leg.penaltyKicks.isEmpty {
                KnockoutPenaltyShootoutView(
                    homeTeam: leg.homeTeam,
                    awayTeam: leg.awayTeam,
                    kicks: leg.penaltyKicks,
                    onFinish: { finishPenaltyShootout() }
                )
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Preparing penalties...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .onAppear { beginPenaltyShootout() }
            }
        }
        .frame(maxWidth: 360, maxHeight: 420)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(24)
    }

    // MARK: - Leg Break

    /// Between-legs screen showing leg 1 score; continuing starts leg 2.
    private var legBreakView: some View {
        KnockoutLegBreakView(
            playerTeam: playerTeam,
            opponent: opponent,
            isFinal: currentRoundIndex >= 4,
            leg1: leg1,
            onContinue: { startSimulation() }
        )
    }

    // MARK: - Results

    /// Stores the player's final matchup results and winner in `allMatchups` for the
    /// results screen, using aggregate goals or penalty shootout for ties.
    private func updatePlayerMatchup() {
        goalPopup = nil
        goalFlashId = nil
        let teamA = playerTeam
        guard let teamB = opponent else { return }
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
            let winner: CupTeam?
            if totalA > totalB {
                winner = teamA
                aggregateTiebreakerWon = true
            } else if totalB > totalA {
                winner = teamB
                aggregateTiebreakerWon = false
            } else {
                let tiebreakerWon = l2.neededPenalties ? l2.penaltyAway > l2.penaltyHome
                    : l1.penaltyAway > l1.penaltyHome
                aggregateTiebreakerWon = tiebreakerWon
                winner = tiebreakerWon ? teamA : teamB
            }
            if let idx = allMatchups.firstIndex(where: { $0.isPlayerMatch }) {
                allMatchups[idx] = RoundMatchup(
                    teamA: teamA, teamB: teamB,
                    leg1ScoreA: l1.totalHomeScore, leg1ScoreB: l1.totalAwayScore,
                    leg2ScoreA: l2.totalAwayScore, leg2ScoreB: l2.totalHomeScore,
                    winner: winner, isPlayerMatch: true
                )
            }
        }
        resolveOutcome()
    }

    /// Marks the player as eliminated, champion, or still alive based on the
    /// aggregate/penalty result of the just-finished round. Called
    /// deterministically before the results screen appears so the outcome is
    /// always recorded (fixing a missing end-of-cup banner on early exits).
    private func resolveOutcome() {
        let isFinal = currentRoundIndex >= 4
        if isFinal {
            if playerAdvanced {
                isChampion = true
            } else {
                isChampion = false
                eliminated = true
                eliminatedIn = knockoutRoundNames[min(currentRoundIndex, 4)]
            }
        } else if !playerAdvanced {
            eliminated = true
            eliminatedIn = knockoutRoundNames[min(currentRoundIndex, 4)]
        }
    }

    /// Round result recap: final/two-leg result views plus the full bracket. Offers
    /// "Continue to Next Round" if the player advanced, otherwise reports elimination.
    /// Marks champion status after the Final.
    private var resultsView: some View {
        let isFinal = currentRoundIndex >= 4
        return VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    Text(knockoutRoundNames[min(currentRoundIndex, 4)] + " Results")
                        .font(.title2.weight(.bold))
                        .padding(.top)

                    if isFinal {
                        KnockoutFinalResultView(
                            playerTeam: playerTeam,
                            opponent: opponent,
                            playerTeamId: playerTeamId,
                            leg1: leg1
                        )
                    } else {
                        KnockoutTwoLegResultView(
                            playerTeam: playerTeam,
                            opponent: opponent,
                            playerTeamId: playerTeamId,
                            leg1: leg1,
                            leg2: leg2,
                            aggregateTiebreakerWon: aggregateTiebreakerWon
                        )
                    }

                    Divider().padding(.horizontal)

                    KnockoutMatchupsSection(matchups: allMatchups)
                }
            }

            VStack(spacing: 0) {
               // Divider()
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
                  //  .padding(.vertical, 8)
                    .padding(.bottom, 30)
                } else {
                    Button(action: {
                        onComplete(eliminated, eliminatedIn, isChampion, computePlayerStats())
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
                    .padding(.bottom, 30)
                  //  .padding(.vertical, 8)
                }
            }
         //   .background(Color(.systemGray6))
        }
        .onAppear {
            if !playerAdvanced {
                eliminated = true
                eliminatedIn = knockoutRoundNames[min(currentRoundIndex, 4)]
                isChampion = false
            } else if currentRoundIndex >= 4 {
                isChampion = true
            }
        }
    }

    // MARK: - End

    /// Final end-of-campaign screen shown after elimination or a championship.
    private var endView: some View {
        KnockoutEndView(
            competitionType: competitionType,
            isChampion: isChampion,
            eliminated: eliminated,
            eliminatedIn: eliminatedIn,
            onComplete: { onComplete(eliminated, eliminatedIn, isChampion, computePlayerStats()) }
        )
    }

    // MARK: - Logic

    /// Skips forward when a round has no player matchup: crowns the player champion
    /// after the Final, otherwise advances to the next round's setup.
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

    /// Tallys the user's goals (and assists) across all played legs into per-player
    /// season stats, sorted by goals then assists.
    /// - Returns: Knockout-phase player stats to merge with the league phase.
    private func computePlayerStats() -> [PlayerSeasonStats] {
        var statDict: [String: PlayerSeasonStats] = [:]
        for name in userPlayerNames {
            statDict[name] = PlayerSeasonStats(playerName: name)
        }
        for leg in [leg1, leg2].compactMap({ $0 }) {
            for g in leg.goals + leg.etGoals {
                if g.teamId == playerTeamId {
                    if !g.isOwnGoal && statDict[g.scorer] != nil {
                        statDict[g.scorer]!.goals += 1
                    }
                    if let assist = g.assist, statDict[assist] != nil {
                        statDict[assist]!.assists += 1
                    }
                }
            }
        }
        return statDict.values.sorted { $0.goals > $1.goals || ($0.goals == $1.goals && $0.assists > $1.assists) }
    }

    /// Whether the player won the current round (aggregate lead, or penalties in the
    /// final / aggregate ties).
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
            if playerTotal > opponentTotal { return true }
            if opponentTotal > playerTotal { return false }
            return aggregateTiebreakerWon
        }
        return false
    }

    private var currentRoundName: String {
        knockoutRoundNames[min(currentRoundIndex, 4)]
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
        userSubstituteNames: [],
        startingRoundIndex: 0,
        onComplete: { _, _, _, _ in }
    )
}
