import SwiftUI

struct TeamStatsView: View {
    let attack: Double
    let midfield: Double
    let defense: Double
    let gk: Double
    let teamOvr: Double
    let chemistryModifier: Int
    let chemistry: Int

    init(attack: Double, midfield: Double, defense: Double, gk: Double, teamOvr: Double,
         chemistryModifier: Int = 0, chemistry: Int = 0) {
        self.attack = attack
        self.midfield = midfield
        self.defense = defense
        self.gk = gk
        self.teamOvr = teamOvr
        self.chemistryModifier = chemistryModifier
        self.chemistry = chemistry
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("OVR")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f", teamOvr.rounded()))
                    .font(.title.weight(.bold))
                Text(chemModText)
                    .font(.title3.weight(.bold))
                    .foregroundColor(chemModColor)
                Spacer()
            }
            .padding(.horizontal, 16)

            statBar(label: "Attack", rating: attack, color: .red)
            statBar(label: "Midfield", rating: midfield, color: .blue)
            statBar(label: "Defense", rating: defense, color: .green)
            statBar(label: "GK", rating: gk, color: .purple)
            chemBar
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8)
    }

    private var chemModText: String {
        chemistryModifier >= 0 ? "+\(chemistryModifier)" : "\(chemistryModifier)"
    }

    private var chemModColor: Color {
        if chemistryModifier >= 3 { return .green }
        if chemistryModifier >= 1 { return .green }
        if chemistryModifier == 0 { return .gray }
        if chemistryModifier >= -5 { return .orange }
        return .red
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

    private var chemBar: some View {
        HStack(spacing: 8) {
            Text("Chem")
                .font(.caption)
                .frame(width: 48, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(chemColor)
                        .frame(
                            width: geo.size.width * CGFloat(chemistry) / 100,
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            Text("\(chemistry)")
                .font(.caption.weight(.bold))
                .foregroundColor(chemColor)
                .frame(width: 24, alignment: .trailing)
        }
    }

    private var chemColor: Color {
        if chemistry >= 80 { return .green }
        if chemistry >= 60 { return .yellow }
        if chemistry >= 40 { return .orange }
        return .red
    }
}

#Preview {
    TeamStatsView(
        attack: 88,
        midfield: 85,
        defense: 82,
        gk: 90,
        teamOvr: 84,
        chemistryModifier: 3,
        chemistry: 75
    )
    .padding()
}
