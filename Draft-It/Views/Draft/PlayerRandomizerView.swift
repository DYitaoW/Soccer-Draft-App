/// PlayerRandomizerView.swift
///
/// Draft-slot picker that randomly offers up to five eligible players for a
/// position, revealed one by one with a cycling animation.
/// Supports limited re-rolls and optional rating/league visibility toggles.
import SwiftUI

/// Modal presented when the user taps a starter slot or substitute slot.
/// Filters the player pool by position, league toggles, and minimum rating,
/// shows a lottery-style reveal, and reports the selected player via `onSelect`.
struct PlayerRandomizerView: View {
    let position: Position?
    let allPlayers: [Player]
    let excludedIds: Set<UUID>
    let excludedNames: Set<String>
    let maxRerolls: Int
    let showRatings: Bool
    let showPremierLeague: Bool
    let showOtherLeagues: Bool
    let showGlobalSuperstars: Bool
    let showPastLegends: Bool
    let showUpgradedPlayers: Bool
    let showCultHeros: Bool
    let showFutureSuperstars: Bool
    let showWomensStars: Bool
    let showRandomBums: Bool
    let minRating: Int
    let onSelect: (Player) -> Void
    let onCancel: () -> Void
    let onReroll: () -> Void

    /// Optional pre-picked candidates. When provided, the reveal reuses them instead
    /// of rolling a fresh set, so dismissing and reopening the popup keeps the same
    /// players. Only a re-roll produces a new randomization.
    let initialCandidates: [Player]?
    /// Reports the candidates currently offered (after a fresh pick or a re-roll)
    /// so the parent can cache them for the next time this popup is opened.
    let onCandidatesChanged: (([Player]) -> Void)?

    /// Transfer budget mode support: remaining budget and value calculator.
    let transferBudgetRemaining: Int
    let transferValue: ((Player) -> Int)?
    let gameMode: GameMode

    @State private var finalCandidates: [Player] = []
    @State private var displayNames: [String] = Array(repeating: "", count: 5)
    @State private var slotLocked: [Bool] = Array(repeating: false, count: 5)
    @State private var revealedSlots = 0
    @State private var animationDone = false
    @State private var rerollsUsed = 0
    @State private var animationId = 0
    @State private var startingRerolls = 0

    /// The eligible player pool after applying position, exclusion, league,
    /// minimum-rating, and transfer budget filters.
    private var pool: [Player] {
        var f = allPlayers.filter { !excludedIds.contains($0.id) }
        if !excludedNames.isEmpty {
            f = f.filter { !excludedNames.contains($0.name) }
        }
        if let pos = position {
            f = f.filter { $0.canPlay(pos) }
        }
        f = f.filter { player in
            // No Premier League mode: block PL, force Other Leagues + Global Superstars on
            if gameMode == .noPremierLeague {
                switch player.league {
                case "Premier League": return false
                case "Other Leagues", "Global Superstars": return true
                case "Past Legends": return showPastLegends
                case "Upgraded Players": return showUpgradedPlayers
                case "Cult Heros": return showCultHeros
                case "Future Superstars": return showFutureSuperstars
                case "Womens Stars": return showWomensStars
                case "Random Bums": return showRandomBums
                default: return true
                }
            }
            switch player.league {
            case "Premier League": return showPremierLeague
            case "Other Leagues": return showOtherLeagues
            case "Global Superstars": return showGlobalSuperstars
            case "Past Legends": return showPastLegends
            case "Upgraded Players": return showUpgradedPlayers
            case "Cult Heros": return showCultHeros
            case "Future Superstars": return showFutureSuperstars
            case "Womens Stars": return showWomensStars
            case "Random Bums": return showRandomBums
            default: return true
            }
        }
        if minRating > 0 {
            f = f.filter { $0.ovrRating >= minRating }
        }
        // In transfer budget mode, only show players the user can afford
        if gameMode == .transferBudget, let valueFn = transferValue {
            f = f.filter { valueFn($0) <= transferBudgetRemaining }
        }
        return f
    }

    /// Number of re-rolls still available before the max is reached. The baseline is
    /// snapshotted once (`startingRerolls`) so the count isn't double-decremented when
    /// the parent re-renders the view after `onReroll` mutates the game state.
    private var rerollsLeft: Int { max(0, startingRerolls - rerollsUsed) }

    /// Title, five candidate slots, and the re-roll button. Starts candidate
    /// selection and the reveal animation on appear.
    var body: some View {
        VStack(spacing: 10) {
            Text(position != nil ? "Select \(position!.rawValue)" : "Select Substitute")
                .font(.title2).fontWeight(.bold)
            if gameMode == .transferBudget {
                HStack {
                    Text("Budget Remaining:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(transferBudgetRemaining)M")
                        .font(.headline).fontWeight(.bold)
                        .foregroundColor(transferBudgetRemaining > 20 ? .green : .red)
                }
                .padding(.horizontal, 4)
            }
            if pool.isEmpty {
                Text("No eligible players available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(0..<5, id: \.self) { i in candidateSlot(i) }
            }

            HStack(spacing: 20) {
                if animationDone && rerollsLeft > 0 && !pool.isEmpty {
                    Button("Roll Again   (\(rerollsLeft))") { reroll() }
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .buttonStyle(.borderedProminent)
                        //.cornerRadius(20)
                } else {
                    Button("Roll Again   (\(rerollsLeft))") { }
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .buttonStyle(.borderedProminent)
                        .tint(Color(.systemGray4))
                       // .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .frame(maxWidth: 350)
        .frame(maxHeight: 475)
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(32)
        .onAppear {
            if startingRerolls == 0 { startingRerolls = maxRerolls }
            if let cached = initialCandidates, !cached.isEmpty {
                finalCandidates = cached
            } else {
                pickCandidates()
                onCandidatesChanged?(finalCandidates)
            }
            startAnimation()
        }
    }

    /// Renders one candidate slot: a tappable card once locked in, a cycling
    /// "???" slot during the reveal, or an empty placeholder when out of range.
    @ViewBuilder
    private func candidateSlot(_ i: Int) -> some View {
        if i < finalCandidates.count, slotLocked[i] {
            Button { onSelect(finalCandidates[i]) } label: {
                PlayerCard(player: finalCandidates[i], showRatings: showRatings, transferValue: transferValue?(finalCandidates[i]))
            }
            .buttonStyle(.plain)
        } else if i < finalCandidates.count {
            cyclingSlot(i)
        } else {
            emptySlot
        }
    }

    /// Placeholder card shown when fewer than five candidates are available.
    private var emptySlot: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.clear)
                .frame(width: 5)

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
                    .font(.title3).fontWeight(.bold)
                Text("")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Slot in "rolling" state showing masked "???" text while cycling names.
    private func cyclingSlot(_ i: Int) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.clear)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayNames[i].isEmpty ? "???" : displayNames[i])
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundColor(.primary)
                Text("???")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("???")
                    .font(.title3).fontWeight(.bold)
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

    /// Randomly selects up to five players from the eligible pool as final
    /// candidates. Duplicate names (regular + upgraded versions of the same
    /// player) are collapsed to the highest-rated copy so one name never
    /// occupies two slots.
    private func pickCandidates() {
        var bestByName: [String: Player] = [:]
        for player in pool where bestByName[player.name].map({ player.ovrRating > $0.ovrRating }) ?? true {
            bestByName[player.name] = player
        }
        let deduped = Array(bestByName.values)
        finalCandidates = Array(deduped.shuffled().prefix(5))
    }

    /// Resets slot state and kicks off the reveal. In "fastMode" slots lock
    /// immediately; otherwise each slot cycles then locks in after a delay.
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

    /// Cycles random names through a slot every 0.08s until it locks in.
    private func startCycling(slot: Int, id: Int) {
        func cycle() {
            guard id == animationId, slot < finalCandidates.count, !slotLocked[slot] else { return }
            displayNames[slot] = pool.randomElement()?.name ?? "???"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: cycle)
        }
        cycle()
    }

    /// Reveals the final candidate for a slot and marks it locked; when all
    /// slots are locked the overall animation is marked complete.
    private func lockIn(slot: Int, id: Int) {
        guard id == animationId, slot < finalCandidates.count else { return }
        displayNames[slot] = finalCandidates[slot].name
        slotLocked[slot] = true
        revealedSlots += 1
        if revealedSlots == finalCandidates.count {
            animationDone = true
        }
    }

    /// Consumes a re-roll (notifying the caller via `onReroll`) and re-picks
    /// and re-animates a fresh set of candidates.
    private func reroll() {
        rerollsUsed += 1
        onReroll()
        pickCandidates()
        onCandidatesChanged?(finalCandidates)
        startAnimation()
    }
}

/// A revealed player candidate card showing name, team, OVR rating (or "??"
/// when ratings are hidden), and effective positions, bordered in the player's
/// position color.
struct PlayerCard: View {
    let player: Player
    let showRatings: Bool
    let transferValue: Int?

    /// Color derived from the player's first position.
    private var positionColor: Color? {
        player.positions.first?.categoryColor
    }

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(positionColor ?? Color.clear)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(player.team)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if showRatings {
                    Text("\(player.ovrRating)")
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(.blue)
                } else {
                    Text("??")
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                if let value = transferValue {
                    Text("$\(value)M")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(.green)
                } else {
                    Text(player.effectivePositions.map(\.rawValue).joined(separator: "/"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(positionColor?.opacity(0.5) ?? Color.clear, lineWidth: 3)
        )
    }
}

#Preview("ST - Full Pools") {
    PlayerRandomizerView(
        position: .ST,
        allPlayers: GameData.players,
        excludedIds: [],
        excludedNames: [],
        maxRerolls: 3,
        showRatings: true,
        showPremierLeague: true,
        showOtherLeagues: true,
        showGlobalSuperstars: true,
        showPastLegends: true,
        showUpgradedPlayers: true,
        showCultHeros: true,
        showFutureSuperstars: true,
        showWomensStars: true,
        showRandomBums: true,
        minRating: 0,
        onSelect: { _ in },
        onCancel: {},
        onReroll: {},
        initialCandidates: nil,
        onCandidatesChanged: nil,
        transferBudgetRemaining: 100,
        transferValue: nil,
        gameMode: .normal
    )
    .padding()
}

#Preview("GK - No Rerolls") {
    PlayerRandomizerView(
        position: .GK,
        allPlayers: GameData.players,
        excludedIds: [],
        excludedNames: [],
        maxRerolls: 0,
        showRatings: true,
        showPremierLeague: true,
        showOtherLeagues: false,
        showGlobalSuperstars: false,
        showPastLegends: false,
        showUpgradedPlayers: false,
        showCultHeros: false,
        showFutureSuperstars: false,
        showWomensStars: false,
        showRandomBums: false,
        minRating: 0,
        onSelect: { _ in },
        onCancel: {},
        onReroll: {},
        initialCandidates: nil,
        onCandidatesChanged: nil,
        transferBudgetRemaining: 100,
        transferValue: nil,
        gameMode: .normal
    )
    .padding()
}
