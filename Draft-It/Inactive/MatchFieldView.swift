/// MatchFieldView.swift
///
/// Live, animated match pitch showing both teams' players, the ball, and team
/// colors during real-time Super League knockout simulations.
/// Shared with the match simulator screen.
import SwiftUI

/// A 1.6 aspect-ratio pitch rendering a live match. Draws the field, players
/// of both teams (with injury/card indicators), and a ball animated to the
/// given normalized coordinates. Requires normalized positions in [0,1] for
/// player and ball placement; players without a position fall back to a
/// computed default layout.
struct MatchFieldView: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    let homeMentality: MatchMentality
    let awayMentality: MatchMentality
    let ballX: CGFloat
    let ballY: CGFloat
    let homePlayers: [LiveMatchPlayer]
    let awayPlayers: [LiveMatchPlayer]
    let playerPositions: [String: CGPoint]
    let action: LiveKnockoutMatch.VisualAction
    let actionTeamId: UUID?

    /// Layers the field shape, markings, action overlay, both teams' circles,
    /// and the ball.
    var body: some View {
        GeometryReader { geo in
            ZStack {
                fieldShape
                fieldMarkings(in: geo)
                actionOverlay(geo: geo)
                playerCircles(team: homePlayers, isHome: true, geo: geo)
                playerCircles(team: awayPlayers, isHome: false, geo: geo)
                ballView(geo: geo)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .aspectRatio(1.6, contentMode: .fit)
    }

    /// Green gradient background of the pitch.
    private var fieldShape: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.15, green: 0.50, blue: 0.15),
                Color(red: 0.12, green: 0.42, blue: 0.12)
            ]),
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Draws the pitch lines: halfway line, center circle/dot, penalty and goal
    /// areas, and penalty spots for both halves.
    private func fieldMarkings(in geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let lineColor = Color.white.opacity(0.25)
        let lineWidth: CGFloat = 1

        return ZStack {
            Rectangle()
                .fill(lineColor)
                .frame(width: lineWidth, height: h)
                .position(x: w * 0.5, y: h * 0.5)

            // Center circle
            Circle()
                .stroke(lineColor, lineWidth: lineWidth)
                .frame(width: w * 0.12, height: w * 0.12 * (h / w))
                .position(x: w * 0.5, y: h * 0.5)

            // Center dot
            Circle()
                .fill(lineColor)
                .frame(width: 4, height: 4)
                .position(x: w * 0.5, y: h * 0.5)

            // Left penalty area
            RoundedRectangle(cornerRadius: 2)
                .stroke(lineColor, lineWidth: lineWidth)
                .frame(width: w * 0.14, height: h * 0.6)
                .position(x: w * 0.08, y: h * 0.5)

            // Right penalty area
            RoundedRectangle(cornerRadius: 2)
                .stroke(lineColor, lineWidth: lineWidth)
                .frame(width: w * 0.14, height: h * 0.6)
                .position(x: w * 0.92, y: h * 0.5)

            // Left goal area
            RoundedRectangle(cornerRadius: 1)
                .stroke(lineColor, lineWidth: lineWidth)
                .frame(width: w * 0.06, height: h * 0.28)
                .position(x: w * 0.035, y: h * 0.5)

            // Right goal area
            RoundedRectangle(cornerRadius: 1)
                .stroke(lineColor, lineWidth: lineWidth)
                .frame(width: w * 0.06, height: h * 0.28)
                .position(x: w * 0.965, y: h * 0.5)

            // Left penalty spot
            Circle()
                .fill(lineColor)
                .frame(width: 3, height: 3)
                .position(x: w * 0.11, y: h * 0.5)

            // Right penalty spot
            Circle()
                .fill(lineColor)
                .frame(width: 3, height: 3)
                .position(x: w * 0.89, y: h * 0.5)
        }
    }

    /// Draws a transient line for the current action: a dashed pass line, an
    /// arrowed shot toward the goal mouth, a faint dribble trail, or a
    /// restart indicator. Colored by the acting team.
    @ViewBuilder
    private func actionOverlay(geo: GeometryProxy) -> some View {
        switch action {
        case .pass(let from, let to):
            actionLine(from: from, to: to, geo: geo, color: actionColor.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
        case .shot(let from, let to):
            ZStack {
                actionLine(from: from, to: to, geo: geo, color: actionColor.opacity(0.9), style: StrokeStyle(lineWidth: 2))
                arrowHead(from: from, to: to, geo: geo)
            }
        case .dribble(let from, let to):
            actionLine(from: from, to: to, geo: geo, color: actionColor.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [2, 4]))
        case .ballOut(let to):
            actionLine(from: CGPoint(x: ballX, y: ballY), to: to, geo: geo, color: actionColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [1, 5]))
        case .none:
            EmptyView()
        }
    }

    /// The color of the team performing the current action.
    private var actionColor: Color {
        actionTeamId == homeTeam.id ? teamColor(named: homeTeam.name) : teamColor(named: awayTeam.name)
    }

    /// Renders a straight line between two normalized pitch points.
    private func actionLine(from: CGPoint, to: CGPoint, geo: GeometryProxy, color: Color, style: StrokeStyle) -> some View {
        Path { p in
            p.move(to: CGPoint(x: from.x * geo.size.width, y: from.y * geo.size.height))
            p.addLine(to: CGPoint(x: to.x * geo.size.width, y: to.y * geo.size.height))
        }
        .stroke(color, style: style)
        .allowsHitTesting(false)
    }

    /// Renders an arrowhead at the `to` point pointing along the shot direction.
    private func arrowHead(from: CGPoint, to: CGPoint, geo: GeometryProxy) -> some View {
        let start = CGPoint(x: from.x * geo.size.width, y: from.y * geo.size.height)
        let end = CGPoint(x: to.x * geo.size.width, y: to.y * geo.size.height)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let len: CGFloat = 8
        return Path { p in
            p.move(to: CGPoint(x: end.x + len * cos(angle + .pi * 0.8), y: end.y + len * sin(angle + .pi * 0.8)))
            p.addLine(to: end)
            p.addLine(to: CGPoint(x: end.x + len * cos(angle - .pi * 0.8), y: end.y + len * sin(angle - .pi * 0.8)))
            p.closeSubpath()
        }
        .fill(actionColor.opacity(0.9))
        .allowsHitTesting(false)
    }

    /// Renders one team's on-pitch players as numbered circles colored by team.
    /// Injured players get a red ring and yellow-carded players a yellow ring;
    /// players are placed from `playerPositions` with a fallback default layout.
    private func playerCircles(team: [LiveMatchPlayer], isHome: Bool, geo: GeometryProxy) -> some View {
        let onPitch = team.filter { $0.isOnPitch && !$0.redCard }
        let w = geo.size.width
        let h = geo.size.height
        let color = isHome ? teamColor(named: homeTeam.name) : teamColor(named: awayTeam.name)

        return ZStack {
            ForEach(Array(onPitch.enumerated()), id: \.element.id) { idx, player in
                let pos = playerPositions[player.name] ?? {
                    let baseX: CGFloat = 0.5
                    let baseY: CGFloat = 0.3 + CGFloat(idx) * 0.06
                    return CGPoint(x: baseX, y: baseY)
                }()
                let px = pos.x * w
                let py = pos.y * h
                let radius: CGFloat = player.isInjured ? 7 : 8

                ZStack {
                    Circle()
                        .fill(color.opacity(0.85))
                        .frame(width: radius * 2, height: radius * 2)
                    if player.isInjured {
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                            .frame(width: radius * 2, height: radius * 2)
                    }
                    if player.yellowCard {
                        Circle()
                            .stroke(Color.yellow, lineWidth: 2)
                            .frame(width: radius * 2, height: radius * 2)
                    }
                    Text("\(idx + 1)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                }
                .position(x: px, y: py)
                .animation(.easeInOut(duration: 0.5), value: px)
                .animation(.easeInOut(duration: 0.5), value: py)
            }
        }
    }

    /// Generates a simple formation-like grid of normalized pitch positions for
    /// `count` players when no explicit positions are supplied.
    /// - Returns: Array of `count` `(x, y)` points normalized to [0,1].
    private func computeDefaultPositions(count: Int, isHome: Bool) -> [(x: CGFloat, y: CGFloat)] {
        let rows: [[CGFloat]] = [
            [0.5],
            [0.25, 0.75],
            [0.15, 0.5, 0.85],
            [0.15, 0.38, 0.62, 0.85],
        ]
        let colPositions: [CGFloat]
        switch count {
        case 0...1: colPositions = rows[0]
        case 2: colPositions = rows[1]
        case 3: colPositions = rows[2]
        default: colPositions = rows[3]
        }

        var result: [(x: CGFloat, y: CGFloat)] = []
        let rows_ = min(4, (count + 3) / 4 + 1)
        let perRow = max(1, (count + rows_ - 1) / rows_)
        var idx = 0
        for row in 0..<rows_ {
            let n = row == rows_ - 1 ? count - idx : min(perRow, count - idx)
            let cols: [CGFloat] = n <= 2 && n > 1 ? rows[1] : (n == 1 ? rows[0] : colPositions)
            for c in 0..<n {
                let xPos = c < cols.count ? cols[c] : 0.5
                let yPos = CGFloat(row) / CGFloat(max(1, rows_ - 1)) * 0.7 + 0.15
                result.append((xPos, yPos))
                idx += 1
            }
        }
        return result
    }

    /// Renders the white ball at the normalized `ballX`/`ballY` coordinates,
    /// smoothly animating to its current position.
    private func ballView(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        return Circle()
            .fill(Color.white)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 2)
            .position(x: ballX * w, y: ballY * h)
            .animation(.easeInOut(duration: 0.6), value: ballX)
            .animation(.easeInOut(duration: 0.6), value: ballY)
    }
}
