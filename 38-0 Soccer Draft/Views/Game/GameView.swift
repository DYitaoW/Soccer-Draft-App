import SwiftUI

enum GamePhase {
    case drafting, lineComplete, seasonResults
}

struct GameView: View {
    let onRestart: () -> Void

    @EnvironmentObject var gameState: GameState
    @State private var showRandomizer = false
    @State private var editingSlotIndex = 0
    @State private var editingSlotPosition: Position = .ST
    @State private var showSubRandomizer = false
    @State private var editingSubIndex = 0
    @State private var phase: GamePhase = .drafting
    @State private var showManagerReveal = false
    @State private var managerDisplayName = "???"
    @State private var managerAnimating = false
    @State private var managerRevealed = false
    @State private var swapSource: (isStarter: Bool, index: Int)? = nil
    @State private var showPlaySeason = false
    @State private var showCupDraw = false
    @State private var cupCompetitionType: CupCompetitionType?
    @State private var cupResult: CupSeasonResult?
    @State private var seasonResult: SeasonSimulationResult?
    @AppStorage("enableCupCompetitions") private var enableCups = false
    @Environment(\.colorScheme) private var colorScheme

    private var adaptiveOverlay: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.35)
    }

    private var adaptiveGray: Color {
        Color(.systemGray5)
    }

    private var activeLeaguesText: String {
        var parts: [String] = []
        if gameState.showPremierLeague { parts.append("PL") }
        if gameState.showOtherLeagues { parts.append("Other") }
        if gameState.showGlobalSuperstars { parts.append("Stars") }
        if gameState.showPastLegends { parts.append("Legends") }
        return parts.isEmpty ? "None" : parts.joined(separator: " + ")
    }

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

    private var highlightedIndex: Int? {
        guard let source = swapSource else { return nil }
        return source.isStarter ? source.index : nil
    }

    var body: some View {
        routingContent
            .onAppear { handleAutoRoute() }
    }

    private func handleAutoRoute() {
        if gameState.managerRevealed {
            managerRevealed = true
            if let mgr = gameState.selectedManager {
                managerDisplayName = mgr.name
            }
        }
        switch gameState.gamePhase {
        case "lineComplete": phase = .lineComplete
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

    @ViewBuilder
    private var routingContent: some View {
        if showPlaySeason {
            PlaySeasonView(
                playerTeam: gameState.adjustedPlayerTeam,
                projectedPosition: gameState.seasonOdds?.expectedPosition ?? 10,
                isMode38: gameState.isMode38,
                overall: Int(gameState.adjustedTeamRating.rounded()),
                onRestart: onRestart,
                onSeasonComplete: { result in
                    seasonResult = result
                    if enableCups {
                        let pos = result.playerPosition
                        if let comp = CupModels.determineCompetition(position: pos) {
                            cupCompetitionType = comp
                            gameState.cupCompetitionTypeRaw = comp.rawValue
                            showPlaySeason = false
                            showCupDraw = true
                            gameState.gamePhase = "cupDraw"
                            SavedGame.save(gameState)
                            return
                        }
                    }
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
                            manager: gameState.selectedManager
                        )
                        DraftHistory.save(entry)
                    }
                    SavedGame.clear()
                    onRestart()
                }
            )
        } else if showCupDraw, let cupType = cupCompetitionType {
            let userNames = gameState.assignedPlayers.values.map { $0.name }
            CupFlowView(
                competitionType: cupType,
                overall: Int(gameState.adjustedTeamRating.rounded()),
                attack: Int(gameState.adjustedAttackRating.rounded()),
                midfield: Int(gameState.adjustedMidfieldRating.rounded()),
                defense: Int((gameState.adjustedDefenseRating + gameState.adjustedGkRating / 2.0).rounded()),
                seasonResult: seasonResult,
                userPlayerNames: userNames,
                onRestart: onRestart
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
        } else if gameState.isMode38, phase == .drafting {
            TeamDraftView(onComplete: {
                if !gameState.managerRevealed {
                    gameState.selectedManager = GameData.managers.randomElement()
                }
                gameState.managerRevealed = true
                gameState.simulateSeason()
                withAnimation {
                    phase = .seasonResults
                    gameState.gamePhase = "seasonResults"
                    SavedGame.save(gameState)
                }
            })
            .environmentObject(gameState)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) { topBar }
        } else if gameState.isMode38 {
            mode38LineCompleteView
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
        }
    }

    // MARK: - Main Layout

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

            if !gameState.isMode38 { draftingSubRow }

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

            if !gameState.isMode38 { lineCompleteSubRow }

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

    private var draftingSubRow: some View {
        subRowContent { index in
            if gameState.substitutes[index] == nil {
                editingSubIndex = index
                withAnimation { showSubRandomizer = true }
            }
        }
    }

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
                    .frame(width: 60)
            } else {
                Text("Sub \(index + 1)")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 60)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Overlays

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
                maxRerolls: gameState.totalRerollsRemaining,
                showRatings: gameState.showRatings,
                showPremierLeague: gameState.showPremierLeague,
                showOtherLeagues: gameState.showOtherLeagues,
                showGlobalSuperstars: gameState.showGlobalSuperstars,
                showPastLegends: gameState.showPastLegends,
                onSelect: { player in
                    gameState.assignPlayer(player, toSlot: editingSlotIndex)
                    SavedGame.save(gameState)
                    withAnimation { showRandomizer = false }
                },
                onCancel: { showRandomizer = false },
                onReroll: { gameState.useReroll() }
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
                maxRerolls: gameState.totalRerollsRemaining,
                showRatings: gameState.showRatings,
                showPremierLeague: gameState.showPremierLeague,
                showOtherLeagues: gameState.showOtherLeagues,
                showGlobalSuperstars: gameState.showGlobalSuperstars,
                showPastLegends: gameState.showPastLegends,
                onSelect: { player in
                    gameState.addSubstitute(player, at: editingSubIndex)
                    SavedGame.save(gameState)
                    withAnimation { showSubRandomizer = false }
                },
                onCancel: { showSubRandomizer = false },
                onReroll: { gameState.useReroll() }
            )
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

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

            
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 0)
        .background(.ultraThinMaterial)
    }

    // MARK: - Swap Logic

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

    private var managerRevealCard: some View {
        VStack(spacing: 20) {
            Text("Your Manager")
                .font(.title2).fontWeight(.bold)

            if managerRevealed, let mgr = gameState.selectedManager {
                VStack(spacing: 8) {
                   /* Text(mgr.name)
                        .font(.title3).fontWeight(.semibold) */
                    HStack(spacing: 4) {
                        Text(mgr.name)
                            .font(.title3).fontWeight(.semibold)
                       // Text("Rating:")
                       //     .foregroundColor(.secondary)
                        Text("  (\(mgr.rating))")
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    }
                /*    Text(mgr.league)
                        .font(.caption)
                        .foregroundColor(.secondary) */
                }
            } else {
                Text(managerDisplayName)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            if !managerRevealed && !managerAnimating {
                Button(action: {
                    startManagerReveal()
                }) {
                    Text("Reveal Manager")
                       // .frame(maxWidth: .infinity)
                        .font(.headline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.large)
                .tint(.green)
                .padding(.horizontal)
            }

            if managerRevealed {
                Button("Done") {
                    showManagerReveal = false
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
               // .frame(maxWidth: .infinity)
                .controlSize(.large)
                .tint(.green)
                .padding(.horizontal)
            }
        }
        .padding(25)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(25)
    }

    private func startManagerReveal() {
        managerAnimating = true
        managerRevealed = false
        let pool = GameData.managers
        guard !pool.isEmpty else { return }

        let finalMgr = pool.randomElement()!

        guard !UserDefaults.standard.bool(forKey: "fastMode") else {
            managerDisplayName = finalMgr.name
            managerAnimating = false
            managerRevealed = true
            gameState.managerRevealed = true
            gameState.selectedManager = finalMgr
            SavedGame.save(gameState)
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
                return
            }
            managerDisplayName = pool.randomElement()?.name ?? "???"
            count += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: cycle)
        }
        cycle()
    }

    // MARK: - Completion Section

    private var completionContent: some View {
        VStack(spacing: 10) {
            Text("Squad Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)

            if !managerRevealed {
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
            }

            Spacer()
        }
        .padding(.bottom)
    }

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
    }

    private var completionSection: some View {
        VStack(spacing: 16) {
            completionContent
            if managerRevealed {
                completionButton
            }
            Spacer()
        }
        .padding(.bottom)
    }

    private var mode38LineCompleteView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    FieldView(
                        formation: gameState.selectedFormation,
                        assignedPlayers: gameState.assignedPlayers,
                        onEmptySlotTap: { _, _ in },
                        onFilledSlotTap: nil,
                        highlightedIndex: nil,
                        dimmedIndices: nil
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

                    completionContent
                }
                .padding(.horizontal, 8)
            }

            if managerRevealed {
                completionButton
                    .padding(.bottom, 8)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay { managerOverlay }
        .animation(.easeOut(duration: 0.2), value: showManagerReveal)
    }
}

// MARK: - SeasonResultView

struct SeasonResultView: View {
    let odds: SeasonOdds?
    let onRestart: () -> Void
    let onPlaySeason: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var adaptiveGray6: Color {
        Color(.systemGray6)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                Text("Season Prediction")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 45)

                if let odds = odds {
                    HStack(spacing: 32) {
                        VStack(spacing: 4) {
                            Text("Expected Finish")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ordinal(odds.expectedPosition))
                                .font(.system(size: 40, weight: .bold))
                        }

                        VStack(spacing: 4) {
                            Text("Expected Points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(odds.expectedPoints)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }

                    VStack(spacing: 20) {
                        Text("Season Odds")
                            .font(.title2)
                            .fontWeight(.bold)

                        OutcomeRow(label: "Win Title", pct: odds.winTitle, color: .yellow)
                        OutcomeRow(label: "Top 4 (2-4)", pct: odds.top4, color: .green)
                        OutcomeRow(label: "Top 8 (5-8)", pct: odds.top8, color: .blue)
                        OutcomeRow(label: "Mid Table (9-17)", pct: odds.midTable, color: .orange)
                        OutcomeRow(label: "Relegation (18-20)", pct: odds.relegation, color: .red)
                    }
                    .padding()
                    .background(adaptiveGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                } else {
                    Text("Error calculating season odds.")
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 15) {
                    Button(action: {
                        onPlaySeason()
                    }) {
                        Text("Play Upcoming Season")
                            .frame(maxWidth: .infinity)
                            .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .tint(.green)
                    .padding(.horizontal)

                    
                    Button(action: {
                        onRestart()
                    }) {
                        Text("Back to Home")
                            .frame(maxWidth: .infinity)
                            .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                 //   .controlSize(.s)
                    .tint(.gray)
                   // .tint(.green)
                    .padding(.horizontal)
                  // .padding(.bottom, 10)
                    /*Button("Back to Home", action: onRestart)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.horizontal)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        . */
                }
                .padding(.top, 20)
            }
            .padding()
        }
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

#Preview("SeasonResultView") {
    SeasonResultView(
        odds: SeasonOdds(winTitle: 8, top4: 22, top8: 35, midTable: 28, relegation: 7, expectedPoints: 62, expectedPosition: 8),
        onRestart: {},
        onPlaySeason: {}
    )
}

struct OutcomeRow: View {
    let label: String
    let pct: Int
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(pct)%")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 15)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(pct) / 100), height: 15)
                }
            }
            .frame(height: 10)
        }
    }
}

#Preview("OutcomeRow") {
    OutcomeRow(label: "Win Title", pct: 45, color: .yellow)
        .padding()
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
    gs.seasonOdds = SeasonOdds(winTitle: 8, top4: 22, top8: 35, midTable: 28, relegation: 7, expectedPoints: 62, expectedPosition: 8)
    return GameView(onRestart: {})
        .environmentObject(gs)
}

#Preview("Drafting") {
    let gs = GameState(formation: GameData.formations[0])
    gs.selectedManager = GameData.managers[0]
    return GameView(onRestart: {})
        .environmentObject(gs)
}
