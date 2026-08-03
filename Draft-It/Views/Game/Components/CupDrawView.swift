/// CupDrawView.swift
///
/// Group stage draw screen for cup competitions. Animatedly cycles through
/// possible opponents, locks in each group fixture for the player's team,
/// then hands the generated fixtures to the tournament flow via `onStart`.

import SwiftUI

/// Full-screen view that animates the group stage draw for a cup competition.
///
/// Requires the competition type, the full pool of cup teams, the player's
/// team ID, and the pre-generated player fixtures. Progresses through
/// `DrawPhase.ready` (Begin Draw button), `.animating` (cycling slot rows),
/// and `.complete` (Start Tournament button). Used by the cup flow screens.
struct CupDrawView: View {
    let competitionType: CupCompetitionType
    let cupTeams: [CupTeam]
    let playerTeamId: UUID
    let playerFixtures: [CupFixture]
    let onStart: ([CupFixture], [CupStanding]) -> Void

    @State private var phase: DrawPhase = .ready
    @State private var drawSlots: [(teamName: String, homeAway: String)] = []
    @State private var displayNames: [String] = []
    @State private var slotLocked: [Bool] = []
    @State private var revealedSlots = 0
    @State private var animationDone = false

    /// Tracks which stage of the draw animation the view is in.
    enum DrawPhase {
        case ready, animating, complete
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(competitionType.rawValue)
                .font(.largeTitle.weight(.bold))
                .padding(.top, 32)

            Text("Group Stage Draw")
                .font(.title2)

            if phase == .ready {
                Button(action: { startDraw() }) {
                    Text("Begin Draw")
                        .frame(maxWidth: .infinity)
                        .font(.headline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.large)
                .tint(.green)
                .padding(.horizontal)
            }

            if phase == .animating || phase == .complete {
                VStack(spacing: 8) {
                    ForEach(0..<drawSlots.count, id: \.self) { i in
                        slotRow(i: i)
                    }
                }
                .padding(.horizontal)
            }

            if phase == .complete && animationDone {
                Button(action: {
                    onStart(playerFixtures, [])
                }) {
                    Text("Start Tournament")
                        .frame(maxWidth: .infinity)
                        .font(.headline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.large)
                .tint(.green)
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .padding()
        //.background(RoundedRectangle(cornerRadius: 10)
         //   .fill(Color(.systemGray6)))
    }

    /// Renders one fixture slot row, showing the team name once locked in
    /// (otherwise a cycling "???" placeholder) and the home/away marker.
    @ViewBuilder
    private func slotRow(i: Int) -> some View {
        let isLocked = i < slotLocked.count && slotLocked[i]
        let displayName = i < displayNames.count ? displayNames[i] : ""
        let homeAway = i < drawSlots.count ? drawSlots[i].homeAway : ""

        HStack(spacing: 12) {
            Text(displayName.isEmpty ? "???" : displayName)
                .font(.headline)
                .foregroundColor(.primary)
            if isLocked && !homeAway.isEmpty {
                Text(homeAway)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
            } else if !isLocked {
                Text("???")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLocked ? Color.blue : Color.gray.opacity(0.4), lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isLocked ? Color.blue.opacity(0.08) : Color(.systemGray5))
        )
        .padding(.horizontal, 4)
    }

    /// Begins the draw: builds slot data from the player's fixtures, resets
    /// state, and either reveals everything immediately (fast mode) or starts
    /// cycling animation with staggered lock-in timers.
    private func startDraw() {
        phase = .animating

        let fixtures = playerFixtures.shuffled().enumerated().map { idx, f in
            CupFixture(id: f.id, week: idx + 1, homeTeam: f.homeTeam, awayTeam: f.awayTeam, homeScore: f.homeScore, awayScore: f.awayScore)
        }
        drawSlots = fixtures.map { f in
            let isHome = f.homeTeam.id == playerTeamId
            let opponent = isHome ? f.awayTeam : f.homeTeam
            return (opponent.name, isHome ? "(H)" : "(A)")
        }
        displayNames = Array(repeating: "", count: fixtures.count)
        slotLocked = Array(repeating: false, count: fixtures.count)
        revealedSlots = 0
        animationDone = false

        let allPoolTeams = cupTeams.filter { $0.id != playerTeamId }.map { $0.name }

        guard !UserDefaults.standard.bool(forKey: "fastMode") else {
            for slot in 0..<fixtures.count {
                displayNames[slot] = drawSlots[slot].teamName
                slotLocked[slot] = true
            }
            revealedSlots = fixtures.count
            animationDone = true
            phase = .complete
            return
        }

        for slot in 0..<fixtures.count {
            startCycling(slot: slot, pool: allPoolTeams)
        }
        for slot in 0..<fixtures.count {
            let delay = 0.6 + Double(slot) * 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                lockIn(slot: slot)
            }
        }
    }

    /// Continuously swaps the displayed name for a slot with a random opponent
    /// from the pool, recursing every 0.04s until the slot is locked in.
    private func startCycling(slot: Int, pool: [String]) {
        func cycle() {
            guard slot < displayNames.count, slot >= slotLocked.count || !slotLocked[slot] else { return }
            displayNames[slot] = pool.randomElement() ?? "???"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: cycle)
        }
        cycle()
    }

    /// Permanently reveals the real opponent for a slot and marks it locked.
    /// When all slots are revealed, transitions the view to `.complete`.
    private func lockIn(slot: Int) {
        guard slot < drawSlots.count, slot < displayNames.count, slot < slotLocked.count, !slotLocked[slot] else { return }
        displayNames[slot] = drawSlots[slot].teamName
        slotLocked[slot] = true
        revealedSlots += 1
        if revealedSlots == drawSlots.count {
            animationDone = true
            phase = .complete
        }
    }
}

#Preview {
    CupDrawView(
        competitionType: .superLeague,
        cupTeams: Array(superLeagueTeams.prefix(8)),
        playerTeamId: UUID(),
        playerFixtures: [],
        onStart: { _, _ in }
    )
}
