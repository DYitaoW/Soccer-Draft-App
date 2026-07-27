import SwiftUI

struct TeamDraftView: View {
    @EnvironmentObject var gameState: GameState
    @State private var pickingPlayer: Player?
    @State private var availablePositions: [Position] = []
    @State private var isAnimatingTeam = false
    @State private var displayTeam: String = "???"
    @State private var showTeamPlayers = false
    @State private var animationId = 0
    let onComplete: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
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

                    teamSection
                        .id("teamSection")

                    if showTeamPlayers, let _ = gameState.selectedTeam {
                        playerList
                            .frame(minHeight: 200)

                        if let pick = pickingPlayer {
                            posPicker(for: pick)
                        }
                    }

                    if gameState.isComplete {
                        Button(action: {
                            onComplete()
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
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .onChange(of: showTeamPlayers) { visible in
                if visible {
                    withAnimation {
                        proxy.scrollTo("teamSection", anchor: .top)
                    }
                }
            }
        }
    }

    private var teamSection: some View {
        VStack(spacing: 6) {
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
            .frame(height: 44)
            .padding(.horizontal, 8)

            if gameState.isComplete {
                Text("Lineup complete!")
                    .font(.headline).foregroundColor(.green)
                    .padding(.vertical, 4)
            } else if showTeamPlayers, let _ = gameState.selectedTeam {
                Text("\(gameState.remainingSlots) left")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            } else if !isAnimatingTeam {
                Button("Roll Team") { startTeamRoll() }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 10)).controlSize(.large).tint(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func posPicker(for player: Player) -> some View {
        VStack(spacing: 6) {
            Text("Choose position for \(player.name):")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach(availablePositions, id: \.self) { pos in
                    Button(pos.rawValue) {
                        assign(player: player, to: pos)
                        pickingPlayer = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(pos.categoryColor)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var playerList: some View {
        LazyVStack(spacing: 4) {
            let unfilled = unfilledPositions
            let eligible = gameState.teamPlayers.filter {
                $0.effectivePositions.contains(where: { unfilled.contains($0) })
                && !gameState.usedPlayerIds.contains($0.id)
            }.sorted { $0.ovrRating > $1.ovrRating }
            let ineligible = gameState.teamPlayers.filter {
                !$0.effectivePositions.contains(where: { unfilled.contains($0) })
                && !gameState.usedPlayerIds.contains($0.id)
            }

            ForEach(eligible) { player in
                PlayerRow(player: player, unfilledPositions: unfilled, isEligible: true, onTap: { selectPlayer(player) })
            }
            ForEach(ineligible) { player in
                PlayerRow(player: player, unfilledPositions: unfilled, isEligible: false, onTap: {})
            }

            if eligible.isEmpty, !ineligible.isEmpty, !gameState.isComplete {
                Text("No eligible players for remaining positions — re-roll")
                    .font(.caption).foregroundColor(.secondary).padding(.top)
            }
        }
        .padding(.horizontal, 8)
    }

    private var unfilledPositions: Set<Position> {
        Set(gameState.selectedFormation.slots.enumerated().compactMap { idx, slot in
            gameState.assignedPlayers[idx] == nil ? slot.position : nil
        })
    }

    private func selectPlayer(_ player: Player) {
        let compatible = player.effectivePositions.filter { unfilledPositions.contains($0) }
        if compatible.isEmpty { return }
        if compatible.count == 1, let pos = compatible.first {
            assign(player: player, to: pos)
        } else {
            pickingPlayer = player
            availablePositions = compatible
        }
    }

    private func assign(player: Player, to position: Position) {
        for (idx, slot) in gameState.selectedFormation.slots.enumerated() {
            if slot.position == position && gameState.assignedPlayers[idx] == nil {
                gameState.assignPlayer(player, toSlot: idx)
                pickingPlayer = nil
                withAnimation {
                    showTeamPlayers = false
                    gameState.selectedTeam = nil
                    gameState.teamPlayers = []
                }
                return
            }
        }
    }

    private func startTeamRoll() {
        let id = animationId + 1
        animationId = id
        let allTeams = GameData.allTeams
        withAnimation { isAnimatingTeam = true }
        showTeamPlayers = false
        gameState.selectedTeam = nil
        gameState.teamPlayers = []
        pickingPlayer = nil

        let fast = UserDefaults.standard.bool(forKey: "fastMode")

        guard !fast else {
            let chosen = allTeams.randomElement()!
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
                let chosen = allTeams.randomElement()!
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

struct PlayerRow: View {
    let player: Player
    let unfilledPositions: Set<Position>
    let isEligible: Bool
    let onTap: () -> Void

    private var matchedPositions: [Position] {
        player.effectivePositions.filter { unfilledPositions.contains($0) }
    }

    private var positionColor: Color? {
        guard isEligible, let first = matchedPositions.first else { return nil }
        return first.categoryColor
    }

    var body: some View {
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
    }
}

#Preview("Empty Draft") {
    TeamDraftView(onComplete: {})
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
    gs.substitutes[0] = Player(name: "Sub GK", ovrRating: 80, positions: [.GK], team: "Your Team", league: "Premier League")
    return TeamDraftView(onComplete: {})
        .environmentObject(gs)
}
