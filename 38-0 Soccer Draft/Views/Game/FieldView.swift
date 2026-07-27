import SwiftUI

struct FieldView: View {
    let formation: Formation
    let assignedPlayers: [Int: Player]
    let onEmptySlotTap: (Int, Position) -> Void
    let onFilledSlotTap: ((Int, Position) -> Void)?
    let highlightedIndex: Int?
    let dimmedIndices: Set<Int>?

    init(
        formation: Formation,
        assignedPlayers: [Int: Player],
        onEmptySlotTap: @escaping (Int, Position) -> Void,
        onFilledSlotTap: ((Int, Position) -> Void)? = nil,
        highlightedIndex: Int? = nil,
        dimmedIndices: Set<Int>? = nil
    ) {
        self.formation = formation
        self.assignedPlayers = assignedPlayers
        self.onEmptySlotTap = onEmptySlotTap
        self.onFilledSlotTap = onFilledSlotTap
        self.highlightedIndex = highlightedIndex
        self.dimmedIndices = dimmedIndices
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let circleSize = min(max(min(w, h) / 7.5, 28), 56)
            let nameOffset = circleSize / 2 + 10

            ZStack {
                fieldMarkings(w: w, h: h)

                ForEach(formation.slots.indices, id: \.self) { index in
                    let slot = formation.slots[index]
                    let player = assignedPlayers[index]
                    let isDimmed = dimmedIndices?.contains(index) == true && highlightedIndex != index

                    ZStack {
                        PlayerCircle(
                            position: slot.position,
                            player: player,
                            isHighlighted: index == highlightedIndex,
                            isDimmed: isDimmed,
                            circleSize: circleSize
                        )

                        if let player = player {
                            Text(playerName(player.name))
                                .font(.system(size: max(8, circleSize * 0.16)))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .frame(maxWidth: circleSize * 1.6)
                                .offset(y: nameOffset)
                        }
                    }
                    .position(x: slot.fieldX * w, y: slot.fieldY * h)
                    .opacity(isDimmed ? 0.35 : 1)
                    .onTapGesture {
                        guard !isDimmed else { return }
                        if player == nil {
                            onEmptySlotTap(index, slot.position)
                        } else if let onFilled = onFilledSlotTap {
                            onFilled(index, slot.position)
                        }
                    }
                }
            }
        }
        .aspectRatio(0.7, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func fieldMarkings(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Color(red: 0.05, green: 0.38, blue: 0.08)

            Rectangle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)

            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(height: 1)
                .position(x: w / 2, y: h / 2)

            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.25)
                .position(x: w / 2, y: h / 2)

            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.55, height: h * 0.16)
                .position(x: w / 2, y: h * 0.08)

            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.55, height: h * 0.16)
                .position(x: w / 2, y: h * 0.92)

            RoundedRectangle(cornerRadius: 1)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.3, height: h * 0.06)
                .position(x: w / 2, y: h * 0.03)

            RoundedRectangle(cornerRadius: 1)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.3, height: h * 0.06)
                .position(x: w / 2, y: h * 0.97)

            cornerArc(w: w, h: h, x: 0, y: 0)
            cornerArc(w: w, h: h, x: 0, y: 1)
            cornerArc(w: w, h: h, x: 1, y: 0)
            cornerArc(w: w, h: h, x: 1, y: 1)
        }
    }

    private func cornerArc(w: CGFloat, h: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        let len = min(w, h) * 0.035
        return Path { path in
            path.move(to: CGPoint(x: x == 0 ? 0 : w, y: y == 0 ? 0 : h))
            path.addLine(to: CGPoint(x: x == 0 ? len : w - len, y: y == 0 ? 0 : h))
            path.move(to: CGPoint(x: x == 0 ? 0 : w, y: y == 0 ? 0 : h))
            path.addLine(to: CGPoint(x: x == 0 ? 0 : w, y: y == 0 ? len : h - len))
        }
        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
    }

    private func playerName(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2, let first = parts.first, let last = parts.last {
            let initial = first.first.map { String($0) + ". " } ?? ""
            let maxLast = last.prefix(8)
            return initial + maxLast
        }
        return String(name.prefix(10))
    }
}

struct PlayerCircle: View {
    let position: Position
    let player: Player?
    let isHighlighted: Bool
    let isDimmed: Bool
    let circleSize: CGFloat

    init(position: Position, player: Player?, isHighlighted: Bool = false, isDimmed: Bool = false, circleSize: CGFloat = 56) {
        self.position = position
        self.player = player
        self.isHighlighted = isHighlighted
        self.isDimmed = isDimmed
        self.circleSize = circleSize
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: circleSize, height: circleSize)
                .overlay(Circle().stroke(borderColor, lineWidth: borderWidth))

            if let player = player {
                Text("\(player.ovrRating)")
                    .font(.system(size: max(11, circleSize * 0.3), weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text(position.rawValue)
                    .font(.system(size: max(8, circleSize * 0.22), weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private var fillColor: Color {
        if isHighlighted { return Color.white.opacity(0.6) }
        if player != nil { return position.categoryColor }
        return Color.black.opacity(0.2)
    }

    private var borderColor: Color {
        if isHighlighted { return Color.white }
        if isDimmed { return Color.gray.opacity(0.3) }
        if player != nil { return position.categoryColor }
        return Color.white.opacity(0.4)
    }

    private var borderWidth: CGFloat {
        isHighlighted ? 3 : 2
    }
}

#Preview("Empty Lineup") {
    FieldView(
        formation: GameData.formations[0],
        assignedPlayers: [:],
        onEmptySlotTap: { _, _ in }
    )
    .frame(height: 500)
    .padding()
}

#Preview("Filled Lineup") {
    let formation = GameData.formations[0]
    var assigned: [Int: Player] = [:]
    for (i, slot) in formation.slots.enumerated() {
        assigned[i] = Player(
            name: "Player \(i + 1)",
            ovrRating: 88 - i,
            positions: [slot.position],
            team: "Your Team",
            league: "Premier League"
        )
    }
    return FieldView(
        formation: formation,
        assignedPlayers: assigned,
        onEmptySlotTap: { _, _ in }
    )
    .frame(height: 500)
    .padding()
}
