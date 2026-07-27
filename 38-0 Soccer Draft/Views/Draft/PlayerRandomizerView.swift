import SwiftUI

struct PlayerRandomizerView: View {
    let position: Position?
    let allPlayers: [Player]
    let excludedIds: Set<UUID>
    let maxRerolls: Int
    let showRatings: Bool
    let showPremierLeague: Bool
    let showOtherLeagues: Bool
    let showGlobalSuperstars: Bool
    let showPastLegends: Bool
    let onSelect: (Player) -> Void
    let onCancel: () -> Void
    let onReroll: () -> Void

    @State private var finalCandidates: [Player] = []
    @State private var displayNames: [String] = Array(repeating: "", count: 5)
    @State private var slotLocked: [Bool] = Array(repeating: false, count: 5)
    @State private var revealedSlots = 0
    @State private var animationDone = false
    @State private var rerollsUsed = 0
    @State private var animationId = 0

    private var pool: [Player] {
        var f = allPlayers.filter { !excludedIds.contains($0.id) }
        if let pos = position {
            f = f.filter { $0.canPlay(pos) }
        }
        f = f.filter { player in
            switch player.league {
            case "Premier League": return showPremierLeague
            case "Other Leagues": return showOtherLeagues
            case "Global Superstars": return showGlobalSuperstars
            case "Past Legends": return showPastLegends
            default: return true
            }
        }
        return f
    }

    private var rerollsLeft: Int { maxRerolls - rerollsUsed }

    var body: some View {
        VStack(spacing: 14) {
            Text(position != nil ? "Select \(position!.rawValue)" : "Select Substitute")
                .font(.title2).fontWeight(.bold)
            if pool.isEmpty {
                Text("No eligible players available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(0..<5, id: \.self) { i in candidateSlot(i) }
            }

            HStack(spacing: 16) {
                if animationDone && rerollsLeft > 0 && !pool.isEmpty {
                    Button("Re-roll (\(rerollsLeft))") { reroll() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: 340)
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(32)
        .onAppear { pickCandidates(); startAnimation() }
    }

    @ViewBuilder
    private func candidateSlot(_ i: Int) -> some View {
        if i < finalCandidates.count, slotLocked[i] {
            Button { onSelect(finalCandidates[i]) } label: {
                PlayerCard(player: finalCandidates[i], showRatings: showRatings)
            }
            .buttonStyle(.plain)
        } else if i < finalCandidates.count {
            cyclingSlot(i)
        } else {
            emptySlot
        }
    }

    private var emptySlot: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("")
                    .font(.headline)
                Text("")
                    .font(.subheadline)
                Text("")
                    .font(.caption)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("")
                    .font(.title2).fontWeight(.bold)
                Text("")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func cyclingSlot(_ i: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayNames[i].isEmpty ? "???" : displayNames[i])
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("???")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("???")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text(position?.rawValue ?? "SUB")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func pickCandidates() {
        let shuffled = pool.shuffled()
        finalCandidates = Array(shuffled.prefix(5))
    }

    private func startAnimation() {
        revealedSlots = 0
        displayNames = Array(repeating: "", count: 5)
        slotLocked = Array(repeating: false, count: 5)
        animationDone = false
        animationId += 1
        let currentId = animationId

        guard !UserDefaults.standard.bool(forKey: "fastMode") else {
            for slot in 0..<finalCandidates.count {
                displayNames[slot] = finalCandidates[slot].name
                slotLocked[slot] = true
            }
            revealedSlots = finalCandidates.count
            animationDone = true
            return
        }

        for slot in 0..<finalCandidates.count {
            startCycling(slot: slot, id: currentId)
        }
        for slot in 0..<finalCandidates.count {
            let delay = 1.0 + Double(slot) * 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                lockIn(slot: slot, id: currentId)
            }
        }
    }

    private func startCycling(slot: Int, id: Int) {
        func cycle() {
            guard id == animationId, slot < finalCandidates.count, !slotLocked[slot] else { return }
            displayNames[slot] = pool.randomElement()?.name ?? "???"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: cycle)
        }
        cycle()
    }

    private func lockIn(slot: Int, id: Int) {
        guard id == animationId, slot < finalCandidates.count else { return }
        displayNames[slot] = finalCandidates[slot].name
        slotLocked[slot] = true
        revealedSlots += 1
        if revealedSlots == finalCandidates.count {
            animationDone = true
        }
    }

    private func reroll() {
        rerollsUsed += 1
        onReroll()
        pickCandidates()
        startAnimation()
    }
}

struct PlayerCard: View {
    let player: Player
    let showRatings: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.headline)
                Text(player.team)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if showRatings {
                    Text("\(player.ovrRating)")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.blue)
                } else {
                    Text("??")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                Text(player.positions.map(\.rawValue).joined(separator: "/"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("ST - Full Pools") {
    PlayerRandomizerView(
        position: .ST,
        allPlayers: GameData.players,
        excludedIds: [],
        maxRerolls: 3,
        showRatings: true,
        showPremierLeague: true,
        showOtherLeagues: true,
        showGlobalSuperstars: true,
        showPastLegends: true,
        onSelect: { _ in },
        onCancel: {},
        onReroll: {}
    )
    .padding()
}

#Preview("GK - No Rerolls") {
    PlayerRandomizerView(
        position: .GK,
        allPlayers: GameData.players,
        excludedIds: [],
        maxRerolls: 0,
        showRatings: true,
        showPremierLeague: true,
        showOtherLeagues: false,
        showGlobalSuperstars: false,
        showPastLegends: false,
        onSelect: { _ in },
        onCancel: {},
        onReroll: {}
    )
    .padding()
}
