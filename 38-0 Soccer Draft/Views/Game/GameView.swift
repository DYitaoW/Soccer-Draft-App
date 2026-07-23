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

    private var dimmedIndices: Set<Int>? {
        guard let source = swapSource else { return nil }
        let player: Player?
        if source.isStarter { player = gameState.assignedPlayers[source.index] }
        else { player = gameState.substitutes[source.index] }
        guard let p = player else { return nil }
        let indices = Set(gameState.selectedFormation.slots.indices.compactMap { idx in
            Chemistry.canPlay(player: p, at: gameState.selectedFormation.slots[idx].position) ? nil : idx
        })
        var result = indices
        result.remove(source.index)
        return result.isEmpty ? nil : result
    }

    private var highlightedIndex: Int? {
        guard let source = swapSource else { return nil }
        return source.isStarter ? source.index : nil
    }

    var body: some View {
        if showPlaySeason {
            PlaySeasonView(
                playerTeam: gameState.playerTeam,
                projectedPosition: gameState.seasonOdds?.expectedPosition ?? 10,
                onRestart: onRestart
            )
        } else if phase == .seasonResults {
            SeasonResultView(
                odds: gameState.seasonOdds,
                onRestart: onRestart,
                onPlaySeason: { showPlaySeason = true }
            )
        } else if gameState.isMode38, phase == .drafting {
            TeamDraftView()
                .environmentObject(gameState)
                .navigationBarHidden(true)
                .safeAreaInset(edge: .top) { topBar }
        } else {
            mainBody
                .navigationBarHidden(true)
                .overlay { overlays }
                .animation(.easeOut(duration: 0.2), value: showRandomizer)
                .animation(.easeOut(duration: 0.2), value: showSubRandomizer)
                .animation(.easeOut(duration: 0.2), value: showManagerReveal)
                .onChange(of: showRandomizer) {
                    if phase == .drafting, gameState.isComplete {
                        withAnimation { phase = .lineComplete }
                    }
                }
        }
    }

    // MARK: - Main Layout

    private var mainBody: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
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
                chemistryModifier: gameState.chemistryModifier,
                chemistry: gameState.teamChemistry
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
                chemistryModifier: gameState.chemistryModifier,
                chemistry: gameState.teamChemistry
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
        VStack(spacing: 6) {
            Text("Substitutes")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(0..<gameState.substitutes.count, id: \.self) { i in
                        subCircle(index: i, onTap: { onTap(i) })
                    }
                }
                .padding(.horizontal, 16)
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
                    .fill(isSwapSource ? Color.white.opacity(0.6) : player != nil ? Color.blue : Color.black.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(Circle().stroke(isSwapSource ? Color.white : player != nil ? Color.blue : Color.gray.opacity(0.4), lineWidth: isSwapSource ? 3 : 2))

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
    private var overlays: some View {
        if showRandomizer {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { showRandomizer = false }

            PlayerRandomizerView(
                position: editingSlotPosition,
                league: gameState.selectedLeague,
                allPlayers: SampleData.players,
                excludedIds: gameState.usedPlayerIds,
                maxRerolls: gameState.maxRerolls,
                hardMode: gameState.gameMode == .hard,
                onSelect: { player in
                    gameState.assignPlayer(player, toSlot: editingSlotIndex)
                    withAnimation { showRandomizer = false }
                },
                onCancel: { showRandomizer = false }
            )
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }

        if showSubRandomizer {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { showSubRandomizer = false }

            PlayerRandomizerView(
                position: nil,
                league: gameState.selectedLeague,
                allPlayers: SampleData.players,
                excludedIds: gameState.usedPlayerIds,
                maxRerolls: gameState.maxRerolls,
                hardMode: gameState.gameMode == .hard,
                onSelect: { player in
                    gameState.addSubstitute(player, at: editingSubIndex)
                    withAnimation { showSubRandomizer = false }
                },
                onCancel: { showSubRandomizer = false }
            )
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }

        if showManagerReveal {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            managerRevealCard
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 4) {
            HStack {
                Button(action: onRestart) {
                    Image(systemName: "house")
                        .font(.body)
                }
                .foregroundColor(.primary)

                Text(gameState.selectedFormation.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if gameState.isMode38, gameState.isComplete, phase == .drafting {
                    Spacer()
                    Button("Continue") {
                        phase = .lineComplete
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                } else {
                    Spacer()
                    if phase == .drafting {
                        Text("\(gameState.totalRemaining) remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Complete")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
            }

            HStack {
                if let manager = gameState.selectedManager {
                    Image(systemName: "person.fill")
                        .font(.caption)
                    Text(manager.name)
                        .font(.subheadline)
                }
                Spacer()
                Text(gameState.selectedLeague)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Swap Logic

    private func handleStarterTap(index: Int) {
        guard gameState.assignedPlayers[index] != nil else { return }

        if let source = swapSource {
            if source.isStarter && source.index == index {
                swapSource = nil
            } else if source.isStarter {
                gameState.swapStarterWithStarter(source.index, to: index)
                swapSource = nil
            } else {
                gameState.swapStarter(index, withSub: source.index)
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
                swapSource = nil
            } else {
                gameState.swapSub(source.index, withSub: index)
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
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    Text(mgr.name)
                        .font(.title3).fontWeight(.semibold)
                    HStack(spacing: 4) {
                        Text("Rating:")
                            .foregroundColor(.secondary)
                        Text("\(mgr.rating)")
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    }
                    Text(mgr.league)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(managerDisplayName)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            if !managerRevealed && !managerAnimating {
                Button("Tap to Reveal") {
                    startManagerReveal()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if managerRevealed {
                Button("Done") {
                    showManagerReveal = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(32)
    }

    private func startManagerReveal() {
        managerAnimating = true
        managerRevealed = false
        let pool = gameState.selectedLeague == "All"
            ? SampleData.managers
            : SampleData.managers.filter { $0.league == gameState.selectedLeague }
        guard !pool.isEmpty else { return }

        let finalMgr = pool.randomElement()!

        var count = 0
        func cycle() {
            guard count < 25 else {
                managerDisplayName = finalMgr.name
                managerAnimating = false
                managerRevealed = true
                gameState.selectedManager = finalMgr
                return
            }
            managerDisplayName = pool.randomElement()?.name ?? "???"
            count += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: cycle)
        }
        cycle()
    }

    // MARK: - Completion Section

    private var completionSection: some View {
        VStack(spacing: 16) {
            Text("Lineup Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)

            if !managerRevealed {
                Button("Reveal Manager") {
                    withAnimation { showManagerReveal = true }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if managerRevealed, let manager = gameState.selectedManager {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(manager.name)
                            .font(.headline)
                        HStack(spacing: 4) {
                            Text("Rating:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(manager.rating)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Button("Start Season") {
                    gameState.simulateSeason()
                    withAnimation { phase = .seasonResults }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
        }
        .padding(.bottom)
        .background(.ultraThinMaterial)
    }
}

// MARK: - SeasonResultView

struct SeasonResultView: View {
    let odds: SeasonOdds?
    let onRestart: () -> Void
    let onPlaySeason: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Season Simulation")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 32)

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

                    VStack(spacing: 16) {
                        Text("Season Odds")
                            .font(.title2)
                            .fontWeight(.semibold)

                        OutcomeRow(label: "Win Title", pct: odds.winTitle, color: .yellow)
                        OutcomeRow(label: "Top 4", pct: odds.top4, color: .green)
                        OutcomeRow(label: "Top 8", pct: odds.top8, color: .blue)
                        OutcomeRow(label: "Mid Table (9-17)", pct: odds.midTable, color: .orange)
                        OutcomeRow(label: "Relegation (18-20)", pct: odds.relegation, color: .red)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                } else {
                    Text("Error calculating season odds.")
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 12) {
                    Button("Play Season") {
                        onPlaySeason()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Back to Home", action: onRestart)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                .padding(.top, 8)
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

struct OutcomeRow: View {
    let label: String
    let pct: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
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
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(pct) / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    let gs = GameState(formation: SampleData.formations[0])
    gs.selectedManager = SampleData.managers[0]
    return GameView(onRestart: {})
        .environmentObject(gs)
}
