/// MidseasonTransferView.swift
///
/// Modal midseason transfer window: shows the current squad and remaining transfer
/// budget, lets the player replace any starter via the randomizer, and reports done
/// via `onComplete`.
import SwiftUI

/// Presents each formation slot as a tappable row; tapping opens `PlayerRandomizerView`
/// with a position-filtered candidate pool. Each accepted pick decrements
/// `transfersRemaining` (bound to the parent) via `gameState.assignPlayer`.
struct MidseasonTransferView: View {
    @EnvironmentObject var gameState: GameState
    let totalTransfers: Int
    @Binding var transfersRemaining: Int
    let onComplete: () -> Void

    @State private var selectedSlotIndex: Int?
    @State private var showRandomizer = false
    @State private var randomizerPosition: Position?
    @State private var randomizerPool: [Player] = []

    /// All formation slots with their currently assigned player, if any.
    private var sortedSlots: [(index: Int, slot: FormationSlot, player: Player?)] {
        gameState.selectedFormation.slots.enumerated().map { idx, slot in
            (idx, slot, gameState.assignedPlayers[idx])
        }
    }

    /// Card layout: title, transfers-remaining header, scrollable squad grid, Done
    /// button, and the randomizer overlay for the selected slot.
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Midseason Transfer")
                    .font(.title2.weight(.bold))
                Spacer()
                Button(action: onComplete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            transferHeader
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    playerGrid
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            Button(action: onComplete) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 360, maxHeight: 520)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .overlay {
            if showRandomizer, let pos = randomizerPosition {
                Color.black.opacity(0.4)
                    .onTapGesture { showRandomizer = false }
                PlayerRandomizerView(
                    position: pos,
                    allPlayers: randomizerPool + gameState.teamPlayers,
                    excludedIds: gameState.usedPlayerIds,
                    excludedNames: gameState.usedPlayerNames,
                    maxRerolls: 0,
                    showRatings: true,
                    showPremierLeague: gameState.showPremierLeague,
                    showOtherLeagues: gameState.showOtherLeagues,
                    showGlobalSuperstars: gameState.showGlobalSuperstars,
                    showPastLegends: gameState.showPastLegends,
                    minRating: 0,
                    onSelect: { player in
                        transfer(to: player, at: selectedSlotIndex!)
                        showRandomizer = false
                    },
                    onCancel: { showRandomizer = false },
                    onReroll: {
                        randomizerPool = randomCandidates(for: pos)
                    },
                    initialCandidates: nil,
                    onCandidatesChanged: nil
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showRandomizer)
    }

    /// Shows the remaining/total transfer count, blue when transfers are available.
    private var transferHeader: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text("\(transfersRemaining) / \(totalTransfers)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(transfersRemaining > 0 ? .blue : .secondary)
                Text("transfers remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// List of current starters; rows are tappable only when transfers remain and no
    /// other slot is already selected for a swap.
    private var playerGrid: some View {
        VStack(spacing: 0) {
            Text("Current Squad")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            ForEach(sortedSlots, id: \.index) { item in
                if let player = item.player {
                    Button {
                        selectSlot(item.index, position: item.slot.position)
                    } label: {
                        playerRow(player: player, position: item.slot.position, slotIndex: item.index)
                    }
                    .buttonStyle(.plain)
                    .disabled(transfersRemaining <= 0 || selectedSlotIndex != nil)
                    .opacity(transfersRemaining > 0 && selectedSlotIndex == nil ? 1 : (selectedSlotIndex == item.index ? 1 : 0.5))
                }
            }
        }
    }

    /// A squad row: position color bar, player name/team, position capsule, and rating,
    /// highlighted when this slot is selected for transfer.
    private func playerRow(player: Player, position: Position, slotIndex: Int) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(position.categoryColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.headline)
                Text(player.team)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(position.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(position.categoryColor)
                .clipShape(Capsule())

            Text("\(player.ovrRating)")
                .font(.title3.weight(.bold))
                .foregroundColor(.blue)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(selectedSlotIndex == slotIndex ? Color.blue.opacity(0.08) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(position.categoryColor.opacity(selectedSlotIndex == slotIndex ? 0.6 : 0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    /// Opens the transfer randomizer for the given slot, preloading a candidate pool
    /// for its position.
    private func selectSlot(_ index: Int, position: Position) {
        selectedSlotIndex = index
        randomizerPosition = position
        randomizerPool = randomCandidates(for: position)
        showRandomizer = true
    }

    /// Builds up to five eligible random candidates for a position, excluding players
    /// already in the squad (by ID and by name, so the upgraded version of a player
    /// already owned is not offered) and applying the mode-38 rating floor. Duplicate
    /// names collapse to the highest-rated copy.
    private func randomCandidates(for position: Position) -> [Player] {
        let usedNames = gameState.usedPlayerNames
        var candidates = GameData.players.filter { player in
            player.effectivePositions.contains(where: { $0.matches(position) || $0 == position })
            && !gameState.usedPlayerIds.contains(player.id)
            && !usedNames.contains(player.name)
        }
        var bestByName: [String: Player] = [:]
        for player in candidates where bestByName[player.name].map({ player.ovrRating > $0.ovrRating }) ?? true {
            bestByName[player.name] = player
        }
        candidates = Array(bestByName.values)
        return Array(candidates.shuffled().prefix(5))
    }

    /// Assigns the new player to the slot, decrements the transfer budget, and clears
    /// the selection state.
    private func transfer(to newPlayer: Player, at slotIndex: Int) {
        gameState.assignPlayer(newPlayer, toSlot: slotIndex)
        transfersRemaining -= 1
        selectedSlotIndex = nil
        randomizerPosition = nil
        randomizerPool = []
    }
}
