import SwiftUI

struct TeamStatsView: View {
    let attack: Double
    let midfield: Double
    let defense: Double
    let gk: Double
    let teamOvr: Double
    let manager: Manager?
    let isMode38: Bool

    init(attack: Double, midfield: Double, defense: Double, gk: Double, teamOvr: Double,
         manager: Manager? = nil, isMode38: Bool = false) {
        self.attack = attack
        self.midfield = midfield
        self.defense = defense
        self.gk = gk
        self.teamOvr = teamOvr
        self.manager = manager
        self.isMode38 = isMode38
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("OVR")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f", teamOvr.rounded()))
                    .font(.title.weight(.bold))

                Spacer()

                if let mgr = manager {
                    Text(mgr.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("(\(mgr.rating))")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 16)

            statBar(label: "Attack", rating: attack, color: .red)
            statBar(label: "Midfield", rating: midfield, color: .blue)
            statBar(label: "Defense", rating: defense, color: .green)
            statBar(label: "GK", rating: gk, color: .purple)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8)
    }

    private func statBar(label: String, rating: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 48, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(
                            width: geo.size.width * CGFloat(min(rating / 99, 1.0)),
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            Text(String(format: "%.0f", rating.rounded()))
                .font(.caption.weight(.bold))
                .frame(width: 24, alignment: .trailing)
        }
    }
}

#Preview {
    TeamStatsView(
        attack: 88,
        midfield: 85,
        defense: 82,
        gk: 90,
        teamOvr: 84
    )
    .padding()
}
