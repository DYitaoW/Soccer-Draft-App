/// TeamDraftView.swift
///
/// Main draft screen for the team-draft modes (38-0 and Positions First): rolls
/// a team, assigns its players to formation slots, swaps/moves players on the
/// pitch, and finally reports completion. Driven by the shared `GameState`.
import SwiftUI

/// Primary draft UI for roll-a-team modes: tactical pitch, team stats, a
/// position picker (Positions First only), the rolled team's player list, and
/// the completion flow. Supports starter↔starter swaps and moving a player to
/// an empty slot, with dimmed ineligible targets.
struct TeamDraftView: View {
    @EnvironmentObject var gameState: GameState
    @State private var isAnimatingTeam = false
    @State private var displayTeam: String = "???"
    @State private var showTeamPlayers = false
    @State private var animationId = 0
    @State private var expandedPlayer: Player?
    @State private var swapSource: (isStarter: Bool, index: Int)? = nil
    @State private var draftPosition: Position? = nil
    let onComplete: () -> Void
    let onStartSeason: () -> Void

    /// Whether every formation starter slot is filled.
    private var startersComplete: Bool {
        gameState.assignedPlayers.count == gameState.selectedFormation.slots.count
    }

    /// Formation positions that still have at least one unassigned slot.
    private var openPositions: Set<Position> {
        Set(gameState.selectedFormation.slots.enumerated().compactMap { idx, slot in
            gameState.assignedPlayers[idx] == nil ? slot.position : nil
        })
    }

    /// The set of positions treated as unfilled for the player list. In the
    /// Positions First mode this is just the currently selected position, so
    /// the list behaves as if only that position is open.
    private var unfilledPositions: Set<Position> {
        if gameState.isPositionsFirst {
            guard let pos = draftPosition else { return [] }
            return [pos]
        }
        return openPositions
    }

    /// Slots dimmed during a swap: any slot (filled or empty) the source player
    /// cannot play is ineligible and grayed out.
    private var dimmedIndices: Set<Int>? {
        guard let source = swapSource, source.isStarter else { return nil }
        guard let player = gameState.assignedPlayers[source.index] else { return nil }
        let indices = Set(gameState.selectedFormation.slots.indices.compactMap { idx in
            player.canPlay(gameState.selectedFormation.slots[idx].position) ? nil : idx
        })
        var result = indices
        result.remove(source.index)
        return result.isEmpty ? nil : result
    }

    /// Slot highlighted during a swap: the source starter slot.
    private var highlightedIndex: Int? {
        guard let source = swapSource else { return nil }
        return source.isStarter ? source.index : nil
    }

    /// Scrollable layout of the pitch, team stats, position picker, team section,
    /// player list, and the completion button. Auto-scrolls to the team section
    /// when the player list is revealed.
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    FieldView(
                        formation: gameState.selectedFormation,
                        assignedPlayers: gameState.assignedPlayers,
                        onEmptySlotTap: { index, position in
                            if gameState.isPositionsFirst {
                                if swapSource == nil {
                                    draftPosition = position
                                } else {
                                    handleEmptySlotTap(index: index, position: position)
                                }
                            } else {
                                handleEmptySlotTap(index: index, position: position)
                            }
                        },
                        onFilledSlotTap: { idx, _ in handleStarterTap(index: idx) },
                        highlightedIndex: highlightedIndex,
                        dimmedIndices: dimmedIndices,
                        highlightedPositions: gameState.isPositionsFirst ? (draftPosition.map { [$0] } ?? nil) : nil
                    )
                    .aspectRatio(0.7, contentMode: .fit)
                    .padding(.horizontal, 8)
                    .id("field")

                    TeamStatsView(
                        attack: gameState.attackRating,
                        midfield: gameState.midfieldRating,
                        defense: gameState.defenseRating,
                        gk: gameState.gkRating,
                        teamOvr: gameState.teamRating,
                        manager: gameState.selectedManager,
                        isMode38: true
                    )
                    .id("stats")

                    if gameState.isPositionsFirst {
                        Text("Tap an empty slot on the pitch to draft that position")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    teamSection
                        .id("teamSection")

                    if showTeamPlayers, let _ = gameState.selectedTeam {
                        playerList
                            .frame(minHeight: 200)
                            .id("playerList")
                    }

                    if gameState.isComplete {
                        if gameState.managerRevealed {
                            Button(action: { onStartSeason() }) {
                                Text("Start Season")
                                    .frame(maxWidth: .infinity)
                                    .font(.headline.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 10))
                            .controlSize(.large)
                            .tint(.green)
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        } else {
                            Button(action: { onComplete() }) {
                                Text("Complete Lineup")
                                    .frame(maxWidth: .infinity)
                                    .font(.headline.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 10))
                            .controlSize(.large)
                            .tint(.green)
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .onChange(of: showTeamPlayers) {
                if showTeamPlayers {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("teamSection", anchor: .center)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Team Section

    /// Team name display, Roll/Re-roll button, and completion status. Offers a
    /// "Free Re-roll" when the rolled team has no eligible players for the
    /// remaining position(s).
    private var teamSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 2)

                    if let team = gameState.selectedTeam {
                        Text(team)
                            .font(.title3.weight(.bold))
                            .transition(.opacity)
                    } else {
                        Text(displayTeam)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    }
                }
                .frame(height: 50)

                if gameState.isComplete {

                } else if showTeamPlayers, let _ = gameState.selectedTeam, !hasEligiblePlayers {
                    Button { startTeamRoll(isFreeReroll: true) } label: {
                        Text("Free Re-roll")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .controlSize(.large)
                        .tint(.orange)
                        .frame(width: 160)
                } else {
                    let isReRoll = showTeamPlayers && gameState.selectedTeam != nil
                    let canReroll = gameState.totalRerollsRemaining > 0 || !isReRoll
                    let rerollLabel: String = {
                        if !isReRoll { return "Roll Team" }
                        let rem = gameState.totalRerollsRemaining
                        return rem > 0 ? "Re-roll (\(rem))" : "Re-roll"
                    }()
                    Button { startTeamRoll(isFreeReroll: !isReRoll) } label: {
                        Text(rerollLabel)
                            .frame(maxWidth: .infinity)
                    }
                        .frame(width: 160)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .controlSize(.large)
                        .tint(.green)
                        .disabled(isAnimatingTeam || (isReRoll && !canReroll) || (gameState.isPositionsFirst && draftPosition == nil))
                }
            }
            .padding(.horizontal, 8)

            if gameState.isComplete {
                Text("Squad complete!")
                    .font(.headline).foregroundColor(.green)
            } else if showTeamPlayers, let _ = gameState.selectedTeam {
                Text("\(gameState.remainingSlots) left")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            } else if gameState.isPositionsFirst, draftPosition == nil {
                Text("Tap a position on the pitch to draft it")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Player List

    /// Whether the current team can still field a usable player, accounting for
    /// the rating filter and remaining slots.
    private var hasEligiblePlayers: Bool {
        let unfilled = unfilledPositions
        guard !unfilled.isEmpty else { return false }
        let eligible = gameState.teamPlayers.filter {
            $0.effectivePositions.contains(where: { unfilled.contains($0) })
            && !gameState.usedPlayerIds.contains($0.id)
        }
        return !filterForMode(eligible, minimumRequired: gameState.remainingSlots).isEmpty
    }

    /// Applies the minimum-rating filter for regular modes unless it would leave
    /// fewer than `minimumRequired` usable players. Team-draft modes skip it.
    private func filterForMode(_ players: [Player], minimumRequired: Int) -> [Player] {
        guard !gameState.usesTeamDraft else { return players }
        let filtered = players.filter { $0.ovrRating > 75 }
        return filtered.count >= minimumRequired ? filtered : players
    }

    /// List of the rolled team's players. Shows eligible players (matching the
    /// unfilled position(s)) and ineligible players dimmed below.
    private var playerList: some View {
        VStack(spacing: 4) {
            let unfilled = unfilledPositions
            let eligible = filterForMode(
                gameState.teamPlayers.filter {
                    $0.effectivePositions.contains(where: { unfilled.contains($0) })
                    && !gameState.usedPlayerIds.contains($0.id)
                },
                minimumRequired: gameState.remainingSlots
            ).sorted { $0.ovrRating > $1.ovrRating }
            let ineligible = filterForMode(
                gameState.teamPlayers.filter {
                    !$0.effectivePositions.contains(where: { unfilled.contains($0) })
                    && !gameState.usedPlayerIds.contains($0.id)
                },
                minimumRequired: 0
            )

            ForEach(eligible) { player in
                PlayerRow(
                    player: player,
                    unfilledPositions: unfilled,
                    isEligible: true,
                    isExpanded: expandedPlayer?.id == player.id,
                    onTap: { selectPlayer(player) },
                    onSelectPosition: { pos in assign(player: player, to: pos) }
                )
            }
            ForEach(ineligible) { player in
                PlayerRow(
                    player: player,
                    unfilledPositions: unfilled,
                    isEligible: false,
                    isExpanded: false,
                    onTap: {},
                    onSelectPosition: nil
                )
            }

            if eligible.isEmpty, !ineligible.isEmpty, !gameState.isComplete {
                Text("This team has no players for remaining positions")
                    .font(.caption).foregroundColor(.secondary).padding(.top)
            }
        }
        .padding(.horizontal, 8)
    }

    /// Tapping a player assigns it directly when it matches exactly one open
    /// position; otherwise it toggles the position-picker expansion.
    private func selectPlayer(_ player: Player) {
        let compatible = player.effectivePositions.filter { unfilledPositions.contains($0) }
        if compatible.isEmpty { return }
        if compatible.count == 1, let pos = compatible.first {
            assign(player: player, to: pos)
        } else {
            if expandedPlayer?.id == player.id {
                expandedPlayer = nil
            } else {
                expandedPlayer = player
            }
        }
    }

    /// Assigns `player` to the first empty slot matching `position`, then hides
    /// the player list and clears the selected team. In Positions First mode the
    /// selected position is cleared once it has no slots left. In One Per Club
    /// mode the team is marked as used so no further players can be taken from it.
    private func assign(player: Player, to position: Position) {
        for (idx, slot) in gameState.selectedFormation.slots.enumerated() {
            if slot.position == position && gameState.assignedPlayers[idx] == nil {
                gameState.assignPlayer(player, toSlot: idx)
                if gameState.gameMode == .onePerClub {
                    gameState.usedTeams.insert(player.team)
                }
                expandedPlayer = nil
                if gameState.isPositionsFirst, !openPositions.contains(position) {
                    draftPosition = nil
                }
                withAnimation {
                    showTeamPlayers = false
                    gameState.selectedTeam = nil
                    gameState.teamPlayers = []
                }
                return
            }
        }
    }

    // MARK: - Swap / Move Logic

    /// Moves a swap-source starter into an empty slot when it can play there.
    private func handleEmptySlotTap(index: Int, position: Position) {
        guard let source = swapSource, source.isStarter else { return }
        guard let player = gameState.assignedPlayers[source.index] else { swapSource = nil; return }
        if player.canPlay(position) {
            gameState.movePlayer(from: source.index, to: index)
        }
        swapSource = nil
    }

    /// Handles tapping a filled starter slot: begins a swap, cancels it, or
    /// executes a starter↔starter swap depending on `swapSource`.
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
                }
                swapSource = nil
            } else {
                swapSource = nil
            }
        } else {
            swapSource = (isStarter: true, index: index)
        }
    }

    /// Rolls a team name weighted by category: 50% Premier League, 34% Other
    /// Leagues, 8% Past Legends, 8% Global Superstars, uniform within a bucket.
    private func rollTeamName() -> String {
        let classify: (String) -> [String] = { league in
            Array(Set(GameData.players.filter { $0.league == league }.map { $0.team })).sorted()
        }
        let pl = classify("Premier League")
        let other = classify("Other Leagues")
        let legends = classify("Past Legends")
        let global = classify("Global Superstars")
        let r = Double.random(in: 0..<1)
        let pool: [String]
        if r < 0.50 {
            pool = pl
        } else if r < 0.84 {
            pool = other
        } else if r < 0.92 {
            pool = legends
        } else {
            pool = global
        }
        let available = pool.filter { !gameState.usedTeams.contains($0) }
        if available.isEmpty {
            let fallback = pool.filter { !gameState.usedTeams.contains($0) }
            if fallback.isEmpty {
                let allAvailable = pl + other + legends + global
                let anyLeft = allAvailable.filter { !gameState.usedTeams.contains($0) }
                return anyLeft.isEmpty ? (GameData.allTeams.first ?? "Unknown") : anyLeft.randomElement()!
            }
            return fallback.randomElement()!
        }
        return available.randomElement()!
    }

    /// Rolls a random team (with a cycling animation unless fast mode is on),
    /// consuming a re-roll when applicable, and reveals that team's players.
    /// In Positions First mode a position must be selected first.
    private func startTeamRoll(isFreeReroll: Bool = false) {
        if gameState.isPositionsFirst, draftPosition == nil { return }
        let id = animationId + 1
        animationId = id
        let allTeams = GameData.allTeams
        withAnimation { isAnimatingTeam = true }
        showTeamPlayers = false
        gameState.selectedTeam = nil
        gameState.teamPlayers = []
        expandedPlayer = nil

        let fast = UserDefaults.standard.bool(forKey: "fastMode")

        guard !fast else {
            let chosen = rollTeamName()
            if !isFreeReroll { gameState.useReroll() }
            gameState.selectedTeam = chosen
            displayTeam = chosen
            isAnimatingTeam = false
            withAnimation {
                gameState.teamPlayers = GameData.players.filter { $0.team == chosen }
                showTeamPlayers = true
            }
            return
        }

        var idx = 0
        let totalCycles = 20
        func next() {
            guard id == animationId else { return }
            guard idx < totalCycles else {
                let chosen = rollTeamName()
                if !isFreeReroll { gameState.useReroll() }
                gameState.selectedTeam = chosen
                displayTeam = chosen
                isAnimatingTeam = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard id == self.animationId else { return }
                    withAnimation {
                        gameState.teamPlayers = GameData.players.filter { $0.team == chosen }
                        showTeamPlayers = true
                    }
                }
                return
            }
            displayTeam = allTeams.randomElement() ?? "???"
            idx += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { next() }
        }
        next()
    }
}

/// A single row in the draft's team player list. Eligible players can be tapped
/// to assign (expanding to a position picker when they fit multiple open
/// positions); ineligible players are shown dimmed and non-interactive.
struct PlayerRow: View {
    let player: Player
    let unfilledPositions: Set<Position>
    let isEligible: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    let onSelectPosition: ((Position) -> Void)?

    /// Positions this player could fill among the currently unfilled ones.
    private var matchedPositions: [Position] {
        player.effectivePositions.filter { unfilledPositions.contains($0) }
    }

    /// Accent color for the row, derived from the first matched position when eligible.
    private var positionColor: Color? {
        guard isEligible, let first = matchedPositions.first else { return nil }
        return first.categoryColor
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(positionColor ?? Color.clear)
                    .frame(width: 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.headline)
                    Text(player.team)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(player.ovrRating)")
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(isEligible ? .blue : .secondary)
                    Text(player.effectivePositions.map(\.rawValue).joined(separator: "/"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.trailing)
            .padding(.leading, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6).opacity(isEligible ? 1 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(positionColor ?? Color.clear, lineWidth: isEligible ? 1 : 0)
            )
            .contentShape(Rectangle())
            .onTapGesture { if isEligible { onTap() } }
            .opacity(isEligible ? 1 : 0.5)

            if isExpanded, let onSelect = onSelectPosition, matchedPositions.count > 1 {
                HStack(spacing: 8) {
                    ForEach(matchedPositions, id: \.self) { pos in
                        Button(pos.rawValue) {
                            onSelect(pos)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(pos.categoryColor)
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

#Preview("Empty Draft") {
    TeamDraftView(onComplete: {}, onStartSeason: {})
        .environmentObject(GameState(formation: GameData.formations[0], mode: .mode38))
}

#Preview("Mid Draft") {
    let gs = GameState(formation: GameData.formations[0])
    let formation = GameData.formations[0]
    for (i, slot) in formation.slots.prefix(5).enumerated() {
        gs.assignedPlayers[i] = Player(
            name: "Player \(i + 1)", ovrRating: 88 - i,
            positions: [slot.position],
            team: "Your Team", league: "Premier League"
        )
    }
    return TeamDraftView(onComplete: {}, onStartSeason: {})
        .environmentObject(gs)
}
