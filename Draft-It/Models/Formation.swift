/// Formation.swift
///
/// Defines the `Formation` and `FormationSlot` models that describe a
/// tactical setup and where each starter is placed on the pitch overlay.
import SwiftUI

/// A single placement on the formation diagram. Stores the required
/// position and the normalized field coordinates used for layout.
/// `CGFloat` is encoded as `Double` for stable JSON persistence.
struct FormationSlot: Identifiable, Codable {
    let id: UUID
    let position: Position
    let fieldX: CGFloat
    let fieldY: CGFloat

    enum CodingKeys: String, CodingKey { case id, position, fieldX, fieldY }

    /// Creates a slot at the given normalized coordinates.
    init(id: UUID, position: Position, fieldX: CGFloat, fieldY: CGFloat) {
        self.id = id; self.position = position; self.fieldX = fieldX; self.fieldY = fieldY
    }

    /// Decodes a slot, converting `Double` field coordinates back to `CGFloat`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        position = try c.decode(Position.self, forKey: .position)
        fieldX = CGFloat(try c.decode(Double.self, forKey: .fieldX))
        fieldY = CGFloat(try c.decode(Double.self, forKey: .fieldY))
    }

    /// Encodes a slot, storing `CGFloat` coordinates as `Double`.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(position, forKey: .position)
        try c.encode(Double(fieldX), forKey: .fieldX)
        try c.encode(Double(fieldY), forKey: .fieldY)
    }
}

/// A tactical formation: a name plus the ordered list of slots to fill.
/// Slot order is the order starters are assigned and is stable across saves.
struct Formation: Identifiable, Codable {
    let id: UUID
    let name: String
    let slots: [FormationSlot]

    /// Builds a formation from positional lines running from attack (first)
    /// to goalkeeper (last). Computes normalized field coordinates: the last
    /// line becomes the keeper near the bottom (y = 0.88), and outfielders
    /// are spread vertically and horizontally across the pitch.
    /// - Parameter name: The display name, e.g. "4-4-2".
    /// - Parameter lines: Positional rows, attackers first, keeper last.
    init(name: String, lines: [[Position]]) {
        self.id = UUID()
        self.name = name

        var computed: [FormationSlot] = []
        let totalLines = lines.count
        let gkIndex = totalLines - 1

        for (lineIdx, line) in lines.enumerated() {
            let total = line.count
            let isGK = lineIdx == gkIndex

            for (posIdx, pos) in line.enumerated() {
                let x: CGFloat
                if total == 1 {
                    x = 0.5
                } else if total >= 4 {
                    x = 0.10 + (CGFloat(posIdx) / CGFloat(total - 1)) * 0.80
                } else {
                    x = CGFloat(posIdx + 1) / CGFloat(total + 1)
                }

                let y: CGFloat
                if isGK {
                    y = 0.88
                } else {
                    let nonGkCount = totalLines - 1
                    if nonGkCount <= 1 {
                        y = 0.45
                    } else {
                        let spacing = (0.72 - 0.15) / CGFloat(nonGkCount - 1)
                        y = 0.15 + CGFloat(lineIdx) * spacing
                    }
                }

                computed.append(FormationSlot(id: UUID(), position: pos, fieldX: x, fieldY: y))
            }
        }
        self.slots = computed
    }
}
