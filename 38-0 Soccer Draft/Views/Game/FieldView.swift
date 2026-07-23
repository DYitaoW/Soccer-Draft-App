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
                            isDimmed: isDimmed
                        )

                        if let player = player {
                            Text(playerName(player.name))
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .frame(maxWidth: 70)
                                .offset(y: 34)
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
            Color.green

            // Border
            Rectangle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)

            // Center line
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(height: 1)
                .position(x: w / 2, y: h / 2)

            // Center circle
            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.25)
                .position(x: w / 2, y: h / 2)

            // Left penalty area
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.16, height: h * 0.55)
                .position(x: w * 0.08, y: h / 2)

            // Right penalty area
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.16, height: h * 0.55)
                .position(x: w * 0.92, y: h / 2)

            // Left goal box
            RoundedRectangle(cornerRadius: 1)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.06, height: h * 0.3)
                .position(x: w * 0.03, y: h / 2)

            // Right goal box
            RoundedRectangle(cornerRadius: 1)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: w * 0.06, height: h * 0.3)
                .position(x: w * 0.97, y: h / 2)

            // Corner arcs
            cornerArc(w: w, h: h, x: 0, y: 0)
            cornerArc(w: w, h: h, x: 0, y: 1)
            cornerArc(w: w, h: h, x: 1, y: 0)
            cornerArc(w: w, h: h, x: 1, y: 1)
        }
    }

    private func cornerArc(w: CGFloat, h: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        let cx = x == 0 ? w * 0.025 : w * 0.975
        let cy = y == 0 ? h * 0.025 : h * 0.975
        return Circle()
            .stroke(Color.white.opacity(0.35), lineWidth: 1)
            .frame(width: w * 0.05)
            .position(x: cx, y: cy)
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

    init(position: Position, player: Player?, isHighlighted: Bool = false, isDimmed: Bool = false) {
        self.position = position
        self.player = player
        self.isHighlighted = isHighlighted
        self.isDimmed = isDimmed
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: 56, height: 56)
                .overlay(Circle().stroke(borderColor, lineWidth: borderWidth))

            if let player = player {
                Text("\(player.ovrRating)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text(position.rawValue)
                    .font(.caption.weight(.semibold))
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

#Preview {
    FieldView(
        formation: SampleData.formations[0],
        assignedPlayers: [:],
        onEmptySlotTap: { _, _ in }
    )
    .frame(height: 500)
    .padding()
}
