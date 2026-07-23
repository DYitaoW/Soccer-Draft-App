import SwiftUI

struct TeamDraftView: View {
    @EnvironmentObject var gameState: GameState
    @State private var showPosPicker = false
    @State private var pickingPlayer: Player?
    @State private var availablePositions: [Position] = []
    @State private var draggingIndex: Int? = nil
    @State private var isAnimatingTeam = false
    @State private var displayTeam: String? = nil
    @State private var showTeamPlayers = false
    @State private var animationId = 0

    var body: some View {
        VStack(spacing: 4) {
            FieldView(
                formation: gameState.selectedFormation,
                assignedPlayers: gameState.assignedPlayers,
                onEmptySlotTap: { _, _ in },
                onFilledSlotTap: { index, _ in handleSlotTap(index: index) },
                highlightedIndex: draggingIndex,
                dimmedIndices: dimmedIndices
            )
            .padding(.horizontal, 8)

            teamSection

            if showTeamPlayers, let _ = gameState.selectedTeam {
                playerList
            }
        }
        .confirmationDialog("Select Position", isPresented: $showPosPicker, titleVisibility: .visible) {
            ForEach(availablePositions, id: \.self) { pos in
                Button(pos.rawValue) {
                    if let p = pickingPlayer { assign(player: p, to: pos) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var teamSection: some View {
        VStack(spacing: 6) {
            if isAnimatingTeam {
                Text(displayTeam ?? "???")
                    .font(.title3.weight(.bold))
                    .transition(.opacity)
                    .padding(.vertical, 4)
            } else if let team = gameState.selectedTeam, showTeamPlayers {
                HStack {
                    Text("Team: \(team)")
                        .font(.title3.weight(.bold))
                    Spacer()
                    if !gameState.isComplete {
                        Button("Re-roll") { startTeamRoll() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                    Text("\(gameState.remainingSlots) left")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else {
                if gameState.isComplete {
                    Text("Lineup complete!")
                        .font(.headline).foregroundColor(.green)
                        .padding(.vertical, 4)
                } else {
                    Button("Roll Team") { startTeamRoll() }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var playerList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                let unfilled = unfilledPositions
                let eligible = gameState.teamPlayers.filter {
                    $0.positions.contains(where: { unfilled.contains($0) })
                    && !gameState.usedPlayerIds.contains($0.id)
                }
                let ineligible = gameState.teamPlayers.filter {
                    !$0.positions.contains(where: { unfilled.contains($0) })
                    && !gameState.usedPlayerIds.contains($0.id)
                }

                ForEach(eligible + ineligible) { player in
                    PlayerRow(player: player, unfilledPositions: unfilled, onTap: { selectPlayer(player) })
                }

                if eligible.isEmpty, !ineligible.isEmpty, !gameState.isComplete {
                    Text("No eligible players for remaining positions — re-roll")
                        .font(.caption).foregroundColor(.secondary).padding(.top)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var unfilledPositions: Set<Position> {
        Set(gameState.selectedFormation.slots.enumerated().compactMap { idx, slot in
            gameState.assignedPlayers[idx] == nil ? slot.position : nil
        })
    }

    private func selectPlayer(_ player: Player) {
        let compatible = player.positions.filter { unfilledPositions.contains($0) }
        if compatible.isEmpty { return }
        if compatible.count == 1, let pos = compatible.first {
            assign(player: player, to: pos)
        } else {
            pickingPlayer = player
            availablePositions = compatible
            showPosPicker = true
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
        let allTeams = SampleData.allTeams
        var idx = 0
        let totalCycles = 20
        withAnimation { isAnimatingTeam = true }
        showTeamPlayers = false
        gameState.selectedTeam = nil
        gameState.teamPlayers = []

        func next() {
            guard id == animationId else { return }
            guard idx < totalCycles else {
                let chosen = allTeams.randomElement()!
                withAnimation {
                    gameState.selectedTeam = chosen
                    gameState.teamPlayers = SampleData.players.filter { $0.team == chosen }
                    displayTeam = chosen
                    isAnimatingTeam = false
                    showTeamPlayers = true
                }
                return
            }
            displayTeam = allTeams.randomElement()
            idx += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { next() }
        }
        next()
    }

    private func handleSlotTap(index: Int) {
        guard gameState.assignedPlayers[index] != nil else { return }
        if let drag = draggingIndex {
            if drag == index { draggingIndex = nil; return }
            guard let p = gameState.assignedPlayers[drag] else { return }
            let slotPos = gameState.selectedFormation.slots[index].position
            guard Chemistry.canPlay(player: p, at: slotPos) else { return }
            gameState.swapStarterWithStarter(drag, to: index)
            draggingIndex = nil
        } else {
            draggingIndex = index
        }
    }

    private var dimmedIndices: Set<Int>? {
        guard let drag = draggingIndex, let player = gameState.assignedPlayers[drag] else { return nil }
        let indices = Set(gameState.selectedFormation.slots.indices.compactMap { idx in
            Chemistry.canPlay(player: player, at: gameState.selectedFormation.slots[idx].position) ? nil : idx
        })
        return indices.isEmpty ? nil : indices
    }
}

struct PlayerRow: View {
    let player: Player
    let unfilledPositions: Set<Position>
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.subheadline.weight(.semibold))
                    Text(player.team)
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(player.positions, id: \.self) { pos in
                        Text(pos.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(unfilledPositions.contains(pos) ? pos.categoryColor : Color.gray)
                            .clipShape(Capsule())
                    }
                }
                Text("\(player.ovrRating)")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
