/// PlayablePenaltyShootoutView.swift
///
/// Interactive penalty kick: the user taps a spot on a hidden goal grid, a countdown
/// plays, and the attempt resolves to a goal or save before reporting the result via
/// `onComplete`.
import SwiftUI

/// Lets the player pick a target spot on the goal. Spot outcomes are decided up front
/// by `newAttempt()` (10 of 15 spots score); a 3-2-1 countdown adds suspense before the
/// result is revealed and `onComplete(scored)` is called. When `isCPU` is true the same
/// grid and animation run automatically: the CPU picks a random spot after a short pause.
struct PlayablePenaltyShootoutView: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    let homeScore: Int
    let awayScore: Int
    let round: Int
    let shooter: String
    let isUserHome: Bool
    let isCPU: Bool
    let onComplete: (Bool) -> Void

    @State private var grid: [Bool] = []
    @State private var picked: Int? = nil
    @State private var countdown = 0
    @State private var resultShown = false

    private let gridSize = 15
    private let goalCount = 10

    private var goalFrameColor: Color { Color.white }

    /// Shows the shootout score, current kicker, the goal grid, and status area; starts
    /// a fresh hidden grid on appear, auto-picking a spot for the CPU.
    var body: some View {
        VStack(spacing: 12) {
            Text("Penalty Shootout")
                .font(.title2.weight(.bold))
                .padding(.top, 8)

            scoreHeader

            kickerText

            goalGrid

            statusArea

            Spacer()
        }
        .onAppear {
            if isCPU {
                startCPUAttempt()
            } else {
                newAttempt()
            }
        }
    }

    // MARK: - Views

    /// Boldens the user's team in the running shootout score header.
    private var scoreHeader: some View {
        HStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(homeTeam.name)
                    .font(.subheadline.weight(isUserHome ? .bold : .semibold))
                    .foregroundColor(teamColor(named: homeTeam.name))
                    .lineLimit(1)
                Text("\(homeScore)")
                    .font(.system(size: 34, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            Text("-")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.secondary)
            VStack(spacing: 2) {
                Text(awayTeam.name)
                    .font(.subheadline.weight(isUserHome ? .semibold : .bold))
                    .foregroundColor(teamColor(named: awayTeam.name))
                    .lineLimit(1)
                Text("\(awayScore)")
                    .font(.system(size: 34, weight: .bold))
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    /// Labels the current attempt number and the kicking team.
    private var kickerText: some View {
        VStack(spacing: 2) {
            Text("Attempt \(round)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(isCPU ? opponentName : shooter)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 5)
    }

    /// Name of the team that is not the user's, used while the CPU kicks.
    private var opponentName: String {
        isUserHome ? awayTeam.name : homeTeam.name
    }

    /// Goal frame with a 3x5 grid of tappable target spots.
    private var goalGrid: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(goalFrameColor)
                .frame(height: 12)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                //.shadow(color: .black.opacity(0.25), radius: 2)
            HStack(spacing: 0) {
                Capsule()
                    .fill(goalFrameColor)
                    .frame(width: 12)
                    .padding(.vertical, -5)
                    .padding(.horizontal, -5)
               //     .shadow(color: .black.opacity(0.25), radius: 2)
                VStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 5) {
                            ForEach(0..<5, id: \.self) { col in
                                spot(row * 5 + col)
                            }
                        }
                    }
                }
                //.padding(.vertical, 0)
                .padding(.horizontal, 11)
                Capsule()
                    .fill(goalFrameColor)
                    .frame(width: 12)
                    .padding(.vertical, -5)
                    .padding(.horizontal, -5)
                  //  .shadow(color: .black.opacity(0.25), radius: 2)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    /// A single goal spot; shows the picked highlight during countdown and the
    /// goal/save icon once the result is revealed.
    @ViewBuilder
    private func spot(_ index: Int) -> some View {
        let isPicked = picked == index
        Button(action: { tapSpot(index) }) {
            RoundedRectangle(cornerRadius: 5)
                .fill(spotColor(index))
                .frame(width: 46, height: 38)
                .overlay {
                    if resultShown {
                        Image(systemName: isPicked ? (grid[index] ? "soccerball" : "hand.raised.fill")
                                                    : (grid[index] ? "checkmark" : "xmark"))
                            .font(.system(size: isPicked ? 15 : 10, weight: isPicked ? .medium : .bold))
                            .foregroundColor(.white)
                    }
                }
                .overlay {
                    if isPicked && !resultShown {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.orange, lineWidth: 2)
                    }
                }
                .scaleEffect(isPicked && countdown > 0 ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isPicked && countdown > 0)
        }
        .buttonStyle(.plain)
        .disabled(picked != nil || isCPU)
    }

    /// Spot color: neutral before the result, green/red once it is revealed.
    private func spotColor(_ index: Int) -> Color {
        if resultShown {
            return grid[index] ? Color.green : Color.red
        }
        return Color(.systemGray5)
    }

    /// Countdown number, then GOAL!/SAVED! text after the result is revealed.
    /// Once a spot is picked, the "Don't Miss!"/"Opponent taking penalty..."
    /// prompts never reappear, even during the brief moment before the result
    /// reveal.
    @ViewBuilder
    private var statusArea: some View {
        Group {
            if countdown > 0 {
                Text("\(countdown)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                    .contentTransition(.numericText())
            } else if resultShown, let p = picked {
                Text(grid[p] ? "GOAL!" : "SAVED!")
                    .font(.title.weight(.bold))
                    .foregroundColor(grid[p] ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            } else if picked != nil {
                Color.clear
                    .frame(height: 20)
            } else if isCPU {
                Text("Opponent taking penalty...")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("Don't Miss!")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(height: 20)
    }

    // MARK: - Logic

    /// Resets the hidden grid: 10 scoring spots and 5 misses, shuffled and unknown.
    private func newAttempt() {
        var spots = Array(repeating: true, count: goalCount) + Array(repeating: false, count: gridSize - goalCount)
        spots.shuffle()
        grid = spots
        picked = nil
        countdown = 0
        resultShown = false
    }

    /// CPU mode: resets the grid, then after a short pause automatically picks a
    /// random spot and runs the same countdown/reveal animation as the user.
    private func startCPUAttempt() {
        newAttempt()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard !resultShown, picked == nil, countdown == 0 else { return }
            tapSpot(Int.random(in: 0..<gridSize))
        }
    }

    /// Selects a spot and begins the 3-2-1 countdown, ignoring taps once picked.
    private func tapSpot(_ index: Int) {
        guard picked == nil, countdown == 0, !resultShown else { return }
        picked = index
        startCountdown(from: 3)
    }

    /// Counts down one second at a time, then reveals the outcome.
    private func startCountdown(from n: Int) {
        countdown = n
        guard n > 0 else {
            revealResult()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard picked != nil else { return }
            startCountdown(from: n - 1)
        }
    }

    /// Animates the result and, after a short pause, reports whether the picked spot
    /// scored via `onComplete`.
    private func revealResult() {
        countdown = 0
        withAnimation { resultShown = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard let p = picked else { return }
            onComplete(grid[p])
        }
    }
}

#Preview("In-Game with Background") {
    PenaltyShootoutGameScenePreview()
}

/// Standalone preview scene that reproduces the knockout penalty popup in context.
private struct PenaltyShootoutGameScenePreview: View {
    @State private var shot = false
    @State private var showPopup = true

    private let homeTeam = CupTeam(name: "Your Team", offense: 85, midfield: 83, defense: 82, pot: 1)
    private let awayTeam = CupTeam(name: "Barcelona", offense: 94, midfield: 90, defense: 85, pot: 1)

    private var homeGoals: [GoalEvent] {
        [
            GoalEvent(id: UUID(), minute: 12, scorer: "Player 1", teamId: homeTeam.id, isExtraTime: false, isPenalty: false),
            GoalEvent(id: UUID(), minute: 67, scorer: "Player 2", teamId: homeTeam.id, isExtraTime: false, isPenalty: true)
        ]
    }

    private var awayGoals: [GoalEvent] {
        [
            GoalEvent(id: UUID(), minute: 34, scorer: "Pedri", teamId: awayTeam.id, isExtraTime: false, isPenalty: false),
            GoalEvent(id: UUID(), minute: 89, scorer: "Lewandowski", teamId: awayTeam.id, isExtraTime: false, isPenalty: false)
        ]
    }

    private var commentary: [(minute: Int, text: String, teamId: UUID?)] {
        [
            (12, "GOAL! Player 1 (assist: Player 3)", homeTeam.id),
            (34, "GOAL! Pedri", awayTeam.id),
            (45, "Half time: 1-1", nil),
            (67, "GOAL! Player 2 (penalty)", homeTeam.id),
            (89, "GOAL! Lewandowski", awayTeam.id),
            (90, "Full time: 2-2", nil),
            (105, "End of extra time: 2-2", nil),
            (121, "Penalty shootout underway", nil)
        ]
    }

    private var adaptiveOverlay: Color { Color.black.opacity(0.35) }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("Final")
                    .font(.title2.weight(.bold))
                    .padding()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        previewScoreboard

                        KnockoutScorersBox(homeGoals: homeGoals, awayGoals: awayGoals)

                        KnockoutCommentaryBox(events: commentary)

                        penaltyStatusPanel
                    }
                    .padding(.top, 4)
                }

                footer
            }

            if showPopup {
                adaptiveOverlay
                    .ignoresSafeArea()
                popup
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showPopup)
        .previewLayout(.fixed(width: 390, height: 844))
    }

    private var previewScoreboard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                teamColumn(name: homeTeam.name, score: 2, isPlayer: true)
                Text("vs")
                    .font(.caption).foregroundColor(.secondary)
                teamColumn(name: awayTeam.name, score: 2, isPlayer: false)
            }

            HStack(spacing: 4) {
                Text("120'")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Text("ET")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.orange)
            }

            HStack(spacing: 8) {
                Text("Agg: 2-2")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.yellow)
                Text("(ET / Pens)")
                    .font(.caption.weight(.bold)).foregroundColor(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func teamColumn(name: String, score: Int, isPlayer: Bool) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption.weight(isPlayer ? .bold : .semibold))
                .lineLimit(1)
                .foregroundColor(teamColor(named: name))
            Text("\(score)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(teamColor(named: name))
        }
        .frame(maxWidth: .infinity)
    }

    private var penaltyStatusPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Penalty Shootout")
                    .font(.headline.weight(.bold))
                Spacer()
                Text("\(homeTeam.name) 2 - 2 \(awayTeam.name)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 8) {
                Image(systemName: "soccerball")
                    .foregroundColor(.green)
                Text("Your turn to take a penalty")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.green)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("Penalties  \(homeTeam.name) 2 - 2 \(awayTeam.name)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.orange)
            Text("Tap a spot on the goal to take your penalty")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.bottom, 20)
    }

    private var popup: some View {
        PlayablePenaltyShootoutView(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            homeScore: 2,
            awayScore: 2,
            round: 5,
            shooter: "Player 1",
            isUserHome: true,
            isCPU: false,
            onComplete: { _ in
                withAnimation { showPopup = false }
            }
        )
        .frame(maxWidth: 360, maxHeight: 430)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(24)
    }
}
