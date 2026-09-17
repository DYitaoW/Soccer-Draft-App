/// GameView.swift
///
/// Root in-game coordinator: handles squad drafting, lineup completion, manager reveal,
/// the playable season, cup campaigns, and season-end routing, persisting progress
/// via SavedGame between phases.
import SwiftUI

/// High-level game phases for the standard mode. `.drafting` -> `.lineComplete` ->
/// `.seasonResults`; mode-38 shortcuts to its own draft/complete flow.
enum GamePhase {
    case drafting, lineComplete, seasonResults
}

/// Container view that reads `gameState` and routes to the drafting UI, the playable
/// season (`PlaySeasonView`), the cup flow (`CupFlowView`), or the season result/
/// summary screens based on its phase and saved progress. Reports home via `onRestart`.
struct GameView: View {
    let onRestart: () -> Void

    @EnvironmentObject var gameState: GameState
    @State private var showRandomizer = false
    @State private var editingSlotIndex = 0
    @State private var editingSlotPosition: Position = .ST
    @State private var showSubRandomizer = false
    @State private var editingSubIndex = 0
    @State private var randomizerCache: [String: [Player]] = [:]
    @State private var phase: GamePhase = .drafting
    @State private var showManagerReveal = false
    @State private var managerDisplayName = "???"
    @State private var managerAnimating = false
    @State private var managerRevealed = false
    @State private var swapSource: (isStarter: Bool, index: Int)? = nil
    @State private var showPlaySeason = false
    @State private var showCupDraw = false
    @State private var cupCompetitionType: CupCompetitionType?
    @State private var seasonResult: SeasonSimulationResult?
    @State private var showBudgetBust = false
    @State private var regularDraftId: UUID?
    @State private var regularSeasonPlayerStats: [PlayerSeasonStats] = []
    @State private var showRegularSeasonEnd = false
    @State private var newlyUnlockedAchievements: [Achievement] = []
    @State private var managerCandidates: [Manager] = []
    @State private var managerDisplayNames: [String] = Array(repeating: "", count: 3)
    @State private var managerSlotLocked: [Bool] = Array(repeating: false, count: 3)
    @State private var managerRevealedSlots = 0
    @State private var managerAnimationDone = false
    @State private var managerAnimationId = 0

    @State private var seasonQualifiedForSuperLeague = false
    @AppStorage("enableCupCompetitions") private var enableCups = false
    @AppStorage("dynastyMode") private var dynastyMode = true
    @AppStorage("advancedManagers") private var advancedManagers = true
    @Environment(\.colorScheme) private var colorScheme

    private var adaptiveOverlay: Color { adaptiveOverlayColor(for: colorScheme) }

    /// Cache key for the player randomizer's candidate pool. Each position keeps its
    /// own pool so dismissing the popup and reopening it shows the same players.
    private func randomizerKey(for position: Position?) -> String {
        position?.rawValue ?? "SUB"
    }

    private var adaptiveGray: Color {
        Color(.systemGray5)
    }

    private var activeLeaguesText: String {
        var parts: [String] = []
        if gameState.showPremierLeague { parts.append("PL") }
        if gameState.showOtherLeagues { parts.append("Other") }
        if gameState.showGlobalSuperstars { parts.append("Stars") }
        if gameState.showPastLegends { parts.append("Legends+") }
        return parts.isEmpty ? "None" : parts.joined(separator: " + ")
    }

    /// Dims all field slots the currently selected swap player cannot occupy.
    private var dimmedIndices: Set<Int>? {
        guard let source = swapSource else { return nil }
        let player: Player?
        if source.isStarter { player = gameState.assignedPlayers[source.index] }
        else { player = gameState.substitutes[source.index] }
        guard let p = player else { return nil }
        let indices = Set(gameState.selectedFormation.slots.indices.compactMap { idx in
            p.canPlay(gameState.selectedFormation.slots[idx].position) ? nil : idx
        })
        var result = indices
        if source.isStarter { result.remove(source.index) }
        return result.isEmpty ? nil : result
    }

    /// Highlights the starter slot being swapped, if any.
    private var highlightedIndex: Int? {
        guard let source = swapSource else { return nil }
        return source.isStarter ? source.index : nil
    }

    /// Routes to the active sub-view and restores saved progress on launch.
    var body: some View {
        routingContent
            .onAppear { handleAutoRoute() }
    }

    /// Restores phase/cup state from the game state so the app reopens where the
    /// player left off (lineup complete, season results, or a cup draw in progress).
    private func handleAutoRoute() {
        if gameState.managerRevealed {
            managerRevealed = true
            if let mgr = gameState.selectedManager {
                managerDisplayName = mgr.name
            }
        }
        switch gameState.gamePhase {
        case "lineComplete":
            if gameState.usesTeamDraft { phase = .drafting } else { phase = .lineComplete }
        case "seasonResults": phase = .seasonResults
        case "playSeason": phase = .seasonResults
        case "cupDraw":
            if let raw = gameState.cupCompetitionTypeRaw,
               let comp = CupCompetitionType(rawValue: raw) {
                cupCompetitionType = comp
            }
            showCupDraw = true
        default:
            if gameState.isComplete && gameState.seasonOdds != nil {
                phase = .seasonResults
            } else if gameState.isComplete {
                phase = .lineComplete
            }
        }
    }

    /// Chooses the view to show: playable season, cup flow, regular season complete,
    /// season prediction, mode-38 draft/complete, or the standard draft/lineup UI.
    /// Also saves the draft history entry and dynasties when the season completes.
    @ViewBuilder
    private var routingContent: some View {
        if showPlaySeason {
            PlaySeasonView(
                playerTeam: gameState.adjustedPlayerTeam,
                projectedPosition: gameState.seasonOdds?.expectedPosition ?? 10,
                isMode38: gameState.isMode38,
                overall: Int(gameState.adjustedTeamRating.rounded()),
                userPlayerNames: {
                    let all = gameState.assignedPlayers.values.map { $0.name }
                    var seen = Set<String>()
                    return all.filter { seen.insert($0).inserted }
                }(),
                enableCups: enableCups,
                onRestart: onRestart,
                onSeasonComplete: { result, playerStats in
                    seasonResult = result
                    regularSeasonPlayerStats = playerStats
                    if let st = result.playerStanding {
                        let entry = DraftHistory(
                            id: UUID(),
                            date: Date(),
                            gameMode: gameState.gameMode,
                            teamOverall: Int(gameState.teamOvrWithChemistry.rounded()),
                            record: SeasonRecord(wins: st.wins, draws: st.draws, losses: st.losses),
                            position: result.playerPosition,
                            formation: gameState.selectedFormation,
                            assignedPlayers: gameState.assignedPlayers,
                            substitutes: gameState.substitutes,
                            manager: gameState.selectedManager,
                            playerStats: playerStats,
                            matches: result.matches,
                            standings: result.standings
                        )
                        DraftHistory.save(entry)
                        regularDraftId = entry.id
                        if dynastyMode && result.playerPosition == 1 {
                            let seasonCount = UserDefaults.standard.integer(forKey: "dynastySeasonCount") + 1
                            UserDefaults.standard.set(seasonCount, forKey: "dynastySeasonCount")
                            DynastySave.save(
                                assignedPlayers: gameState.assignedPlayers,
                                substitutes: gameState.substitutes,
                                formation: gameState.selectedFormation,
                                manager: gameState.selectedManager,
                                seasonCount: seasonCount,
                                gameMode: gameState.gameMode,
                                transferBudgetAmount: gameState.transferBudget
                            )
                        }
                    }
                    let pos = result.playerPosition
                    if enableCups, let comp = CupModels.determineCompetition(position: pos) {
                        seasonQualifiedForSuperLeague = true
                        cupCompetitionType = comp
                    }
                    showPlaySeason = false
                    if seasonQualifiedForSuperLeague, cupCompetitionType != nil {
                        showCupDraw = true
                        gameState.gamePhase = "cupDraw"
                        SavedGame.save(gameState)
                    } else {
                        let standings = result.standings
                        let draftedPlayers = gameState.assignedPlayers.values.map { $0 } + gameState.substitutes.compactMap { $0 }
                        let context = SeasonAchievementContext(
                            teamOverall: Int(gameState.teamOvrWithChemistry.rounded()),
                            bestDraftedPlayerRating: gameState.assignedPlayers.values.map(\.ovrRating).max() ?? 0,
                            managerRating: gameState.selectedManager?.rating ?? 0,
                            leaguePosition: result.playerPosition,
                            leagueRecord: result.playerStanding.map { SeasonRecord(wins: $0.wins, draws: $0.draws, losses: $0.losses) },
                            leagueGoalsFor: result.playerStanding?.goalsFor ?? 0,
                            leagueGoalsAgainst: result.playerStanding?.goalsAgainst ?? 0,
                            leagueTeamCount: standings.count,
                            leagueMaxGoalsFor: standings.map(\.goalsFor).max() ?? 0,
                            leagueMinGoalsFor: standings.map(\.goalsFor).min() ?? 0,
                            leagueMaxGoalsAgainst: standings.map(\.goalsAgainst).max() ?? 0,
                            leagueMinGoalsAgainst: standings.map(\.goalsAgainst).min() ?? 0,
                            leagueTopScorerGoals: playerStats.map(\.goals).max() ?? 0,
                            leagueTopAssists: playerStats.map(\.assists).max() ?? 0,
                            superLeagueRound: nil,
                            superLeagueChampion: false,
                            backToBackChampion: AchievementStore.backToBackChampion(position: result.playerPosition),
                            draftedPlayers: draftedPlayers,
                            starterLeagues: gameState.assignedPlayers.values.map(\.league)
                        )
                        newlyUnlockedAchievements = AchievementStore.evaluateSeason(context)
                        showRegularSeasonEnd = true
                        SavedGame.clear()
                    }
                }
            )
        } else if showCupDraw, let cupType = cupCompetitionType {
            let userNames = gameState.assignedPlayers.values.map { $0.name }
            CupFlowView(
                competitionType: cupType,
                overall: Int(gameState.adjustedTeamRating.rounded()),
                attack: Int(gameState.adjustedAttackRating.rounded()),
                midfield: Int(gameState.adjustedMidfieldRating.rounded()),
                defense: Int(gameState.adjustedDefenseRating.rounded()),
                goalkeeper: Int(gameState.adjustedGkRating.rounded()),
                seasonResult: seasonResult,
                userPlayerNames: userNames,
                gameMode: gameState.gameMode,
                formation: gameState.selectedFormation,
                assignedPlayers: gameState.assignedPlayers,
                substitutes: gameState.substitutes,
                manager: gameState.selectedManager,
                regularDraftId: regularDraftId,
                onRestart: onRestart,
                playerGameState: gameState
            )

        } else if showRegularSeasonEnd, let result = seasonResult {
            SeasonCompleteView(
                seasonResult: result,
                cupStandings: nil,
                competitionType: nil,
                eliminatedIn: nil,
                isChampion: result.playerPosition == 1,
                playerStats: regularSeasonPlayerStats,
                regularPlayerStats: regularSeasonPlayerStats,
                superPlayerStats: [],
                onRestart: {
                    SavedGame.clear()
                    onRestart()
                },
                onContinueDynasty: dynastyMode && result.playerPosition == 1 ? {
                    SavedGame.clear()
                    onRestart()
                } : nil,
                newlyUnlocked: newlyUnlockedAchievements
            )
        } else if phase == .seasonResults {
            SeasonResultView(
                odds: gameState.seasonOdds,
                onRestart: onRestart,
                onPlaySeason: {
                    showPlaySeason = true
                    gameState.gamePhase = "playSeason"
                    SavedGame.save(gameState)
                }
            )
        } else if gameState.usesTeamDraft, phase == .drafting {
            TeamDraftView(
                onComplete: {
                    withAnimation { showManagerReveal = true }
                },
                onStartSeason: {
                    gameState.simulateSeason()
                    withAnimation {
                        phase = .seasonResults
                        gameState.gamePhase = "seasonResults"
                        SavedGame.save(gameState)
                    }
                }
            )
            .environmentObject(gameState)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) { topBar }
            .overlay { managerOverlay }
            .animation(.easeOut(duration: 0.2), value: showManagerReveal)
        } else if gameState.usesTeamDraft {
            teamDraftLineCompleteView
                .navigationBarHidden(true)
                .safeAreaInset(edge: .top) { topBar }
        } else {
            mainBody
                .navigationBarHidden(true)
                .safeAreaInset(edge: .top) { topBar }
                .overlay { randomizerOverlays }
                .overlay { managerOverlay }
                .animation(.easeOut(duration: 0.2), value: showRandomizer)
                .animation(.easeOut(duration: 0.2), value: showSubRandomizer)
                .animation(.easeOut(duration: 0.2), value: showManagerReveal)
                    .onChange(of: showRandomizer) {
                        if phase == .drafting, gameState.isComplete {
                            withAnimation {
                                phase = .lineComplete
                                gameState.gamePhase = "lineComplete"
                                SavedGame.save(gameState)
                            }
                        }
                    }
                    .onChange(of: gameState.transferBudgetRemaining) {
                        checkBudgetBust()
                    }
                    .alert("Budget Busted!", isPresented: $showBudgetBust) {
                        Button("Back to Home") {
                            SavedGame.clear()
                            onRestart()
                        }
                    } message: {
                        Text("You've run out of transfer budget and can't afford any remaining players. Better luck next time!")
                    }
        }
    }

    /// Checks whether the player is "busted" — still has empty starter slots but
    /// cannot afford any eligible player from the full pool.
    private func checkBudgetBust() {
        guard gameState.gameMode == .transferBudget else { return }
        guard !gameState.isComplete else { return }
        let openPositions = Set(gameState.selectedFormation.slots.enumerated().compactMap { idx, slot in
            gameState.assignedPlayers[idx] == nil ? slot.position : nil
        })
        let eligible = GameData.players.filter { player in
            !gameState.usedPlayerIds.contains(player.id)
            && player.effectivePositions.contains(where: { openPositions.contains($0) })
            && gameState.transferValue(for: player) <= gameState.transferBudgetRemaining
        }
        if eligible.isEmpty {
            showBudgetBust = true
        }
    }




    // MARK: - Main Layout

    /// Standard-mode layout: field, substitutes, and team stats, switching between
    /// drafting and lineup-complete content based on `phase`.
    private var mainBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                if phase == .drafting {
                    draftingContent
                } else {
                    lineCompleteContent
                }
            }
            .padding(.horizontal, 8)
        }
    }

    /// Drafting UI: tappable field and team stats. Empty slot taps open the player
    /// randomizer. Substitutes are intentionally not shown.
    private var draftingContent: some View {
        Group {
            FieldView(
                formation: gameState.selectedFormation,
                assignedPlayers: gameState.assignedPlayers,
                onEmptySlotTap: { index, position in
                    editingSlotIndex = index
                    editingSlotPosition = position
                    withAnimation { showRandomizer = true }
                }
            )

            TeamStatsView(
                attack: gameState.attackRating,
                midfield: gameState.midfieldRating,
                defense: gameState.defenseRating,
                gk: gameState.gkRating,
                teamOvr: gameState.teamRating,
                manager: gameState.selectedManager
            )
        }
    }

    /// Completed-lineup UI: field with swap support, team stats, and the completion
    /// section. Substitutes are intentionally not shown.
    private var lineCompleteContent: some View {
        Group {
            FieldView(
                formation: gameState.selectedFormation,
                assignedPlayers: gameState.assignedPlayers,
                onEmptySlotTap: { _, _ in },
                onFilledSlotTap: { index, _ in handleStarterTap(index: index) },
                highlightedIndex: highlightedIndex,
                dimmedIndices: dimmedIndices
            )

            TeamStatsView(
                attack: gameState.attackRating,
                midfield: gameState.midfieldRating,
                defense: gameState.defenseRating,
                gk: gameState.gkRating,
                teamOvr: gameState.teamRating,
                manager: gameState.selectedManager
            )

            completionSection
        }
    }

    // MARK: - Substitutes Row

    /// Horizontal substitutes row used while drafting (tap empty slot to assign).
    private var draftingSubRow: some View {
        subRowContent { index in
            if gameState.substitutes[index] == nil {
                editingSubIndex = index
                withAnimation { showSubRandomizer = true }
            }
        }
    }

    /// Substitutes row after the lineup is complete (tap to swap with a starter).
    private var lineCompleteSubRow: some View {
        subRowContent { index in
            if gameState.substitutes[index] == nil {
                editingSubIndex = index
                withAnimation { showSubRandomizer = true }
            } else {
                handleSubTap(index: index)
            }
        }
    }

    /// Shared horizontal substitutes row builder, delegating taps to `onTap`.
    private func subRowContent(onTap: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 0) {
            Text("Substitutes")
                .font(.system(size: 18).weight(.bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<gameState.substitutes.count, id: \.self) { i in
                        subCircle(index: i, onTap: { onTap(i) })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 5)
            }
            .frame(height: 80)
        }
    }

    /// A single substitute slot: player rating circle, name, and position color,
    /// highlighting the current swap source.
    private func subCircle(index: Int, onTap: @escaping () -> Void) -> some View {
        let player = gameState.substitutes[index]
        let isSwapSource = swapSource.map { !$0.isStarter && $0.index == index } ?? false

        return VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isSwapSource ? Color.white.opacity(0.6) : player != nil ? player!.positions.first!.categoryColor : Color.black.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(Circle().stroke(isSwapSource ? Color.white : player != nil ? player!.positions.first!.categoryColor : Color.gray.opacity(0.4), lineWidth: isSwapSource ? 3 : 2))

                if let player = player {
                    Text("\(player.ovrRating)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.gray)
                }
            }

            if let player = player {
                Text(player.name)
                    .font(.system(size: 8))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 70)
            } else {
                Text("Sub \(index + 1)")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 70)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Overlays

    /// Modal overlays for assigning starters and substitutes via the player randomizer.
    @ViewBuilder
    private var randomizerOverlays: some View {
        if showRandomizer {
            adaptiveOverlay
                .ignoresSafeArea()
                .onTapGesture { showRandomizer = false }

            PlayerRandomizerView(
                position: editingSlotPosition,
                allPlayers: GameData.players,
                excludedIds: gameState.usedPlayerIds,
                excludedNames: gameState.usedPlayerNames,
                maxRerolls: gameState.totalRerollsRemaining,
                showRatings: gameState.showRatings,
                showPremierLeague: gameState.showPremierLeague,
                showOtherLeagues: gameState.showOtherLeagues,
                showGlobalSuperstars: gameState.showGlobalSuperstars,
                showPastLegends: gameState.showPastLegends,
                showUpgradedPlayers: gameState.showUpgradedPlayers,
                showCultHeros: gameState.showCultHeros,
                showFutureSuperstars: gameState.showFutureSuperstars,
                showWomensStars: gameState.showWomensStars,
                showRandomBums: gameState.showRandomBums,
                minRating: 0,
                onSelect: { player in
                    randomizerCache[randomizerKey(for: editingSlotPosition)] = nil
                    gameState.assignPlayer(player, toSlot: editingSlotIndex)
                    gameState.spendBudget(for: player)
                    SavedGame.save(gameState)
                    withAnimation { showRandomizer = false }
                },
                onCancel: { showRandomizer = false },
                onReroll: { gameState.useReroll() },
                initialCandidates: randomizerCache[randomizerKey(for: editingSlotPosition)],
                onCandidatesChanged: { candidates in
                    randomizerCache[randomizerKey(for: editingSlotPosition)] = candidates
                },
                transferBudgetRemaining: gameState.transferBudgetRemaining,
                transferValue: gameState.isTransferBudget ? { player in gameState.transferValue(for: player) } : nil,
                gameMode: gameState.gameMode
            )
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }

        if showSubRandomizer {
            adaptiveOverlay
                .ignoresSafeArea()
                .onTapGesture { showSubRandomizer = false }

            PlayerRandomizerView(
                position: nil,
                allPlayers: GameData.players,
                excludedIds: gameState.usedPlayerIds,
                excludedNames: gameState.usedPlayerNames,
                maxRerolls: gameState.totalRerollsRemaining,
                showRatings: gameState.showRatings,
                showPremierLeague: gameState.showPremierLeague,
                showOtherLeagues: gameState.showOtherLeagues,
                showGlobalSuperstars: gameState.showGlobalSuperstars,
                showPastLegends: gameState.showPastLegends,
                showUpgradedPlayers: gameState.showUpgradedPlayers,
                showCultHeros: gameState.showCultHeros,
                showFutureSuperstars: gameState.showFutureSuperstars,
                showWomensStars: gameState.showWomensStars,
                showRandomBums: gameState.showRandomBums,
                minRating: 0,
                onSelect: { player in
                    randomizerCache[randomizerKey(for: nil)] = nil
                    gameState.addSubstitute(player, at: editingSubIndex)
                    gameState.spendBudget(for: player)
                    SavedGame.save(gameState)
                    withAnimation { showSubRandomizer = false }
                },
                onCancel: { showSubRandomizer = false },
                onReroll: { gameState.useReroll() },
                initialCandidates: randomizerCache[randomizerKey(for: nil)],
                onCandidatesChanged: { candidates in
                    randomizerCache[randomizerKey(for: nil)] = candidates
                },
                transferBudgetRemaining: gameState.transferBudgetRemaining,
                transferValue: gameState.isTransferBudget ? { player in gameState.transferValue(for: player) } : nil,
                gameMode: gameState.gameMode
            )
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    /// Modal overlay presenting the manager reveal card.
    @ViewBuilder
    private var managerOverlay: some View {
        if showManagerReveal {
            adaptiveOverlay
                .ignoresSafeArea()

            managerRevealCard
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    // MARK: - Top Bar

    /// Top bar with the home button, formation name, and draft progress / Complete state.
    private var topBar: some View {
        VStack(spacing: 2) {
            HStack {
                Button(action: onRestart) {
                    Image(systemName: "house")
                        .font(.callout.weight(.bold))
                }
                .foregroundColor(.primary)

                Text(gameState.selectedFormation.name)
                    .font(.title3.weight(.bold))

                Spacer()

                if phase == .drafting {
                    Text("\(gameState.totalRemaining) remaining")
                        .font(.system(size: 15).weight(.bold))
                        .foregroundColor(.secondary)
                } else {
                    Text("Complete")
                        .font(.system(size: 15).weight(.bold))
                        .foregroundColor(.green)
                }
            }.padding(.bottom, 5)

            if gameState.isTransferBudget && phase == .drafting {
                HStack {
                    Text("Budget:")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("$\(gameState.transferBudgetRemaining)M")
                        .font(.caption.bold())
                        .foregroundColor(gameState.transferBudgetRemaining > 20 ? .green : .red)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 0)
        .background(.ultraThinMaterial)
    }

    // MARK: - Swap Logic

    /// Handles taps on a filled starter slot: selects it as a swap source, performs
    /// a starter-starter swap when positions are compatible, or a sub-for-starter swap.
    private func handleStarterTap(index: Int) {
        guard let tappedPlayer = gameState.assignedPlayers[index] else { return }

        if let source = swapSource {
            if source.isStarter && source.index == index {
                swapSource = nil
            } else if source.isStarter {
                guard let fromPlayer = gameState.assignedPlayers[source.index] else { swapSource = nil; return }
                let toPosition = gameState.selectedFormation.slots[index].position
                let fromPosition = gameState.selectedFormation.slots[source.index].position
                if fromPlayer.canPlay(toPosition) && tappedPlayer.canPlay(fromPosition) {
                    gameState.swapStarterWithStarter(source.index, to: index)
                    SavedGame.save(gameState)
                }
                swapSource = nil
            } else {
                gameState.swapStarter(index, withSub: source.index)
                SavedGame.save(gameState)
                swapSource = nil
            }
        } else {
            swapSource = (isStarter: true, index: index)
        }
    }

    /// Moves a selected starter into a tapped empty slot when the player can play that
    /// position; otherwise clears the swap selection. Only used in team-draft modes.
    private func handleEmptySlotTap(index: Int, position: Position) {
        guard let source = swapSource, source.isStarter else { return }
        guard let player = gameState.assignedPlayers[source.index] else { swapSource = nil; return }
        if gameState.assignedPlayers[index] == nil, player.canPlay(position) {
            gameState.movePlayer(from: source.index, to: index)
            SavedGame.save(gameState)
        }
        swapSource = nil
    }

    /// Handles taps on a substitute slot: selects it as a swap source or performs a
    /// starter-for-sub or sub-for-sub swap with the previously selected slot.
    private func handleSubTap(index: Int) {
        if let source = swapSource {
            if !source.isStarter && source.index == index {
                swapSource = nil
            } else if source.isStarter {
                gameState.swapStarter(source.index, withSub: index)
                SavedGame.save(gameState)
                swapSource = nil
            } else {
                gameState.swapSub(source.index, withSub: index)
                SavedGame.save(gameState)
                swapSource = nil
            }
        } else {
            swapSource = (isStarter: false, index: index)
        }
    }

    // MARK: - Manager Reveal

    /// Returns a color for the manager's overall rating.
    private func managerRatingColor(_ rating: Int) -> Color {
        if rating >= 88 { return .purple }
        if rating >= 81 { return .green }
        if rating >= 76 { return .orange }
        return .red
    }

    /// Returns a color for the manager's tendency.
    private func managerTendencyColor(_ tendency: ManagerTendency) -> Color {
        switch tendency {
        case .attackMinded: return .red
        case .defensive: return .blue
        case .balanced: return .green
        case .counterAttack: return .orange
        case .possession: return .purple
        case .highPress: return .yellow
        }
    }

    /// Card showing the assigned manager (or a spinning reveal before it is set).
    private var managerRevealCard: some View {
        VStack(spacing: 20) {
            if advancedManagers && !managerRevealed {
                Text("Choose Your Manager")
                    .font(.title2).fontWeight(.bold)

                if managerAnimating {
                    // Cycling animation showing random manager names in 3 slots
                    VStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { i in
                            if i < managerCandidates.count && !managerSlotLocked[i] {
                                // Cycling slot
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(managerDisplayNames[i].isEmpty ? "???" : managerDisplayNames[i])
                                            .font(.headline).fontWeight(.semibold)
                                        Text("???")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("?")
                                        .font(.title3).fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else if i < managerCandidates.count && managerSlotLocked[i] {
                                // Locked-in slot showing manager
                                let mgr = managerCandidates[i]
                                Button(action: {
                                    selectManager(mgr)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(mgr.name)
                                                .font(.headline).fontWeight(.semibold)
                                            Text(mgr.tendency.rawValue)
                                                .font(.caption)
                                                .foregroundColor(managerTendencyColor(mgr.tendency))
                                        }
                                        Spacer()
                                        Text("\(mgr.rating)")
                                            .font(.title3).fontWeight(.bold)
                                            .foregroundColor(managerRatingColor(mgr.rating))
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else if managerAnimationDone && !managerCandidates.isEmpty {
                    // All 3 managers revealed
                    VStack(spacing: 12) {
                        ForEach(managerCandidates) { mgr in
                            Button(action: {
                                selectManager(mgr)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mgr.name)
                                            .font(.headline).fontWeight(.semibold)
                                        Text(mgr.tendency.rawValue)
                                            .font(.caption)
                                            .foregroundColor(managerTendencyColor(mgr.tendency))
                                    }
                                    Spacer()
                                    Text("\(mgr.rating)")
                                        .font(.title3).fontWeight(.bold)
                                        .foregroundColor(managerRatingColor(mgr.rating))
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Text("Your Manager")
                        .font(.title2).fontWeight(.bold)

                    if managerRevealed, let mgr = gameState.selectedManager {
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Text(mgr.name)
                                    .font(.title3).fontWeight(.semibold)
                                Text("  (\(mgr.rating))")
                                    .fontWeight(.bold)
                                    .foregroundColor(managerRatingColor(mgr.rating))
                            }
                            Text(mgr.tendency.rawValue)
                                .font(.caption)
                                .foregroundColor(managerTendencyColor(mgr.tendency))
                        }
                    } else {
                        Text(managerDisplayName)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
        }
        .padding(25)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(25)
        .onAppear {
            guard !managerRevealed else { return }
            startManagerReveal()
        }
    }

    /// The manager reveal pool, filtered by the player-misc toggle settings:
    /// Legend-flagged managers only appear when Past Legends is on; when Other
    /// Leagues is off only Premier League managers are offered, otherwise every
    /// non-legend manager is eligible. The league is backend-only (chemistry).
    private var managerPool: [Manager] {
        let all = GameData.managers
        let legends = all.filter { $0.league == "Legend" }
        let nonLegend = all.filter { $0.league != "Legend" }
        let regulars = gameState.showOtherLeagues
            ? nonLegend
            : nonLegend.filter { $0.league == "Premier League" }
        return regulars + (gameState.showPastLegends ? legends : [])
    }

    /// Animates a cycling manager-name reveal, then commits the chosen manager to the
    /// game state and saves. Skips the animation entirely in fast mode.
    private func startManagerReveal() {
        managerAnimating = true
        managerRevealed = false
        managerAnimationDone = false
        managerDisplayNames = Array(repeating: "", count: 3)
        managerSlotLocked = Array(repeating: false, count: 3)
        managerRevealedSlots = 0
        managerAnimationId += 1
        let currentId = managerAnimationId
        let pool = managerPool
        guard !pool.isEmpty else { return }

        if advancedManagers {
            // Pick 3 unique random managers
            var candidates: [Manager] = []
            var available = pool
            for _ in 0..<min(3, available.count) {
                let idx = Int.random(in: 0..<available.count)
                candidates.append(available.remove(at: idx))
            }
            managerCandidates = candidates

            // Skip animation in fast mode
            guard !UserDefaults.standard.bool(forKey: "fastMode") else {
                for i in 0..<candidates.count {
                    managerDisplayNames[i] = candidates[i].name
                    managerSlotLocked[i] = true
                }
                managerRevealedSlots = candidates.count
                managerAnimating = false
                managerAnimationDone = true
                return
            }

            // Start cycling animation for each slot
            for slot in 0..<candidates.count {
                startManagerCycling(slot: slot, id: currentId)
            }
            // Lock in each slot with delay
            for slot in 0..<candidates.count {
                let delay = 1.0 + Double(slot) * 0.5
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    lockInManager(slot: slot, id: currentId)
                }
            }
        } else {
            let finalMgr = pool.randomElement()!

            guard !UserDefaults.standard.bool(forKey: "fastMode") else {
                managerDisplayName = finalMgr.name
                managerAnimating = false
                managerRevealed = true
                gameState.managerRevealed = true
                gameState.selectedManager = finalMgr
                SavedGame.save(gameState)
                autoCloseManagerReveal()
                return
            }

            var count = 0
            func cycle() {
                guard count < 25 else {
                    managerDisplayName = finalMgr.name
                    managerAnimating = false
                    managerRevealed = true
                    gameState.managerRevealed = true
                    gameState.selectedManager = finalMgr
                    SavedGame.save(gameState)
                    autoCloseManagerReveal()
                    return
                }
                managerDisplayName = pool.randomElement()?.name ?? "???"
                count += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: cycle)
            }
            cycle()
        }
    }

    /// Commits the user's chosen manager from the 3-manager selection.
    private func selectManager(_ mgr: Manager) {
        gameState.selectedManager = mgr
        gameState.managerRevealed = true
        managerRevealed = true
        SavedGame.save(gameState)
        // Immediately close for advanced mode (no delay)
        withAnimation { showManagerReveal = false }
    }

    /// Cycles random manager names through a slot every 0.08s until it locks in.
    private func startManagerCycling(slot: Int, id: Int) {
        let pool = managerPool
        func cycle() {
            guard id == managerAnimationId, slot < managerCandidates.count, !managerSlotLocked[slot] else { return }
            managerDisplayNames[slot] = pool.randomElement()?.name ?? "???"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: cycle)
        }
        cycle()
    }

    /// Reveals the final manager for a slot and marks it locked; when all
    /// slots are locked the overall animation is marked complete.
    private func lockInManager(slot: Int, id: Int) {
        guard id == managerAnimationId, slot < managerCandidates.count else { return }
        managerDisplayNames[slot] = managerCandidates[slot].name
        managerSlotLocked[slot] = true
        managerRevealedSlots += 1
        if managerRevealedSlots == managerCandidates.count {
            managerAnimating = false
            managerAnimationDone = true
        }
    }

    /// Closes the manager reveal popup shortly after the manager is committed.
    private func autoCloseManagerReveal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showManagerReveal = false }
        }
    }

    // MARK: - Completion Section

    /// "Squad Complete!" header.
    private var completionContent: some View {
        Text("Squad Complete!")
            .font(.title2)
            .fontWeight(.bold)
    }

    /// "Start Season" button: simulates the season, transitions to results, and saves.
    private var completionButton: some View {
        Button(action: {
            gameState.simulateSeason()
            withAnimation {
                phase = .seasonResults
                gameState.gamePhase = "seasonResults"
                SavedGame.save(gameState)
            }
        }) {
            Text("Start Season")
                .frame(maxWidth: .infinity)
                .font(.headline.weight(.bold))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .controlSize(.large)
        .tint(.green)
        .padding(.horizontal)
        .padding(.top, 16)
    }

    /// "Reveal Manager" button, styled to match the completion button exactly.
    private var revealButton: some View {
        Button(action: {
            withAnimation { showManagerReveal = true }
        }) {
            Text("Reveal Manager")
                .frame(maxWidth: .infinity)
                .font(.headline.weight(.bold))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .controlSize(.large)
        .tint(.green)
        .padding(.horizontal)
        .padding(.top, 16)
    }

    /// The appropriate next action under the header: Reveal while pending, Start once
    /// the manager is committed. Both share identical spacing.
    @ViewBuilder
    private var completionAction: some View {
        if managerRevealed {
            completionButton
        } else {
            revealButton
        }
    }

    /// Combines the completion header and the next action button.
    private var completionSection: some View {
        VStack(spacing: 0) {
            completionContent
            completionAction
        }
        .padding(.bottom, 8)
    }

    /// Team-draft locked lineup screen: field with position-lock swap/move support,
    /// team stats, the completion section, and the manager reveal overlay.
    private var teamDraftLineCompleteView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    FieldView(
                        formation: gameState.selectedFormation,
                        assignedPlayers: gameState.assignedPlayers,
                        onEmptySlotTap: { index, position in handleEmptySlotTap(index: index, position: position) },
                        onFilledSlotTap: { index, _ in handleStarterTap(index: index) },
                        highlightedIndex: highlightedIndex,
                        dimmedIndices: dimmedIndices
                    )

                    TeamStatsView(
                        attack: gameState.attackRating,
                        midfield: gameState.midfieldRating,
                        defense: gameState.defenseRating,
                        gk: gameState.gkRating,
                        teamOvr: gameState.teamRating,
                        manager: gameState.selectedManager,
                        isMode38: true
                    )

                    completionSection
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay { managerOverlay }
        .animation(.easeOut(duration: 0.2), value: showManagerReveal)
    }
}

#Preview("Lineup Complete") {
    let gs = GameState(formation: GameData.formations[0])
    gs.selectedManager = GameData.managers[0]
    let formation = GameData.formations[0]
    for (i, slot) in formation.slots.enumerated() {
        gs.assignedPlayers[i] = Player(
            name: "Player \(i + 1)", ovrRating: 88 - i,
            positions: [slot.position],
            team: "Your Team", league: "Premier League"
        )
    }
    gs.substitutes[0] = Player(name: "Sub GK", ovrRating: 80, positions: [.GK], team: "Your Team", league: "Premier League")
    gs.substitutes[1] = Player(name: "Sub DEF", ovrRating: 78, positions: [.CB], team: "Your Team", league: "Premier League")
    gs.substitutes[2] = Player(name: "Sub MID", ovrRating: 76, positions: [.CM], team: "Your Team", league: "Premier League")
    return GameView(onRestart: {})
        .environmentObject(gs)
}

#Preview("Season Result") {
    let gs = GameState(formation: GameData.formations[0])
    gs.selectedManager = GameData.managers[0]
    let formation = GameData.formations[0]
    for (i, slot) in formation.slots.enumerated() {
        gs.assignedPlayers[i] = Player(
            name: "Player \(i + 1)", ovrRating: 88 - i,
            positions: [slot.position],
            team: "Your Team", league: "Premier League"
        )
    }
    gs.seasonOdds = SeasonOdds(winTitle: 8, top4: 22, top8: 35, midTable: 28, relegation: 7, expectedPoints: 52, expectedPosition: 8)
    return GameView(onRestart: {})
        .environmentObject(gs)
}

#Preview("Drafting") {
    let gs = GameState(formation: GameData.formations[0])
    gs.selectedManager = GameData.managers[0]
    return GameView(onRestart: {})
        .environmentObject(gs)
}
