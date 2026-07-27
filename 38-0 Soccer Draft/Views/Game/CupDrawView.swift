import SwiftUI

struct CupDrawView: View {
    let competitionType: CupCompetitionType
    let cupTeams: [CupTeam]
    let playerTeamId: UUID
    let onStart: ([CupFixture], [CupStanding]) -> Void

    @State private var phase: DrawPhase = .ready
    @State private var drawnFixtures: [CupFixture] = []
    @State private var drawSlots: [(teamName: String, homeAway: String)] = []
    @State private var displayNames: [String] = []
    @State private var slotLocked: [Bool] = []
    @State private var revealedSlots = 0
    @State private var animationDone = false

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
                    var standingsDict: [UUID: CupStanding] = [:]
                    for team in cupTeams {
                        standingsDict[team.id] = CupStanding(team: team, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0)
                    }
                    onStart(drawnFixtures, Array(standingsDict.values))
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
    }

    @ViewBuilder
    private func slotRow(i: Int) -> some View {
        let isLocked = i < slotLocked.count && slotLocked[i]
        let bgColor: Color = isLocked ? Color(.systemGray6) : Color(.systemGray5)
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
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 4)
    }

    private func startDraw() {
        phase = .animating

        let pots = [1, 2, 3, 4]
        var fixtures: [CupFixture] = []
        var slots: [(String, String)] = []

        for pot in pots {
            let potTeams = cupTeams.filter { $0.pot == pot && $0.id != playerTeamId }.shuffled()
            let opponents = Array(potTeams.prefix(2))
            for opponent in opponents {
                let isHome = Bool.random()
                let playerTeam = cupTeams.first { $0.id == playerTeamId }!
                fixtures.append(CupFixture(
                    id: UUID(), week: fixtures.count + 1,
                    homeTeam: isHome ? playerTeam : opponent,
                    awayTeam: isHome ? opponent : playerTeam,
                    homeScore: 0, awayScore: 0
                ))
                slots.append((opponent.name, isHome ? "(H)" : "(A)"))
            }
        }

        drawnFixtures = fixtures
        drawSlots = slots
        displayNames = Array(repeating: "", count: slots.count)
        slotLocked = Array(repeating: false, count: slots.count)
        revealedSlots = 0
        animationDone = false

        let allPoolTeams = cupTeams.filter { $0.id != playerTeamId }.map { $0.name }

        guard !UserDefaults.standard.bool(forKey: "fastMode") else {
            for slot in 0..<slots.count {
                displayNames[slot] = drawSlots[slot].teamName
                slotLocked[slot] = true
            }
            revealedSlots = slots.count
            animationDone = true
            phase = .complete
            return
        }

        for slot in 0..<slots.count {
            startCycling(slot: slot, pool: allPoolTeams)
        }
        for slot in 0..<slots.count {
            let delay = 0.6 + Double(slot) * 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                lockIn(slot: slot)
            }
        }
    }

    private func startCycling(slot: Int, pool: [String]) {
        func cycle() {
            guard slot < displayNames.count, slot >= slotLocked.count || !slotLocked[slot] else { return }
            displayNames[slot] = pool.randomElement() ?? "???"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: cycle)
        }
        cycle()
    }

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
        onStart: { _, _ in }
    )
}
