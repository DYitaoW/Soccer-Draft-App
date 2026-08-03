/// PlayerCircle.swift
///
/// A reusable player dot shown on tactical field layouts across the draft,
/// game, and history screens.
import SwiftUI

/// Reusable player dot shown on tactical field layouts.
/// Displays the player's OVR rating when filled, otherwise the position's
/// abbreviation. Supports highlight, dim, and category-colored states.
struct PlayerCircle: View {
    let position: Position
    let player: Player?
    let isHighlighted: Bool
    let isDimmed: Bool
    let circleSize: CGFloat

    /// Creates the circle.
    /// - Parameters:
    ///   - position: The slot position; drives the color when filled.
    ///   - player: The assigned player, or `nil` for an empty slot.
    ///   - isHighlighted: Renders the circle in a strong highlight state.
    ///   - isDimmed: Renders the circle faded to show it is not a valid target.
    ///   - circleSize: Diameter of the circle in points.
    init(position: Position, player: Player?, isHighlighted: Bool = false, isDimmed: Bool = false, circleSize: CGFloat = 56) {
        self.position = position
        self.player = player
        self.isHighlighted = isHighlighted
        self.isDimmed = isDimmed
        self.circleSize = circleSize
    }

    /// Lays out the circle and its label (rating or position abbreviation).
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

    /// Fill color: highlight state first, then position color when filled,
    /// otherwise a dark translucent empty-slot color.
    private var fillColor: Color {
        if isHighlighted { return Color.white.opacity(0.6) }
        if player != nil { return position.categoryColor }
        return Color.black.opacity(0.2)
    }

    /// Border color for the circle, based on highlight, dim, filled, or empty state.
    private var borderColor: Color {
        if isHighlighted { return Color.white }
        if isDimmed { return Color.gray.opacity(0.3) }
        if player != nil { return position.categoryColor }
        return Color.white.opacity(0.4)
    }

    /// Border width: thicker when highlighted.
    private var borderWidth: CGFloat {
        isHighlighted ? 3 : 2
    }
}
