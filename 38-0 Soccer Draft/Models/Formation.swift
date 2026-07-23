import SwiftUI

struct FormationSlot: Identifiable {
    let id: UUID
    let position: Position
    let fieldX: CGFloat
    let fieldY: CGFloat
}

struct Formation: Identifiable {
    let id: UUID
    let name: String
    let slots: [FormationSlot]

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
