import SwiftUI

struct HomeView: View {
    let onStart: (Formation, String, GameMode) -> Void

    @State private var selectedLeague = "All"
    @State private var selectedFormation: Formation = SampleData.formations[0]
    @State private var selectedMode: GameMode = .normal

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Soccer Draft")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 32)

                VStack(alignment: .leading, spacing: 12) {
                    Text("League")
                        .font(.headline)
                        .padding(.leading, 4)

                    Picker("League", selection: $selectedLeague) {
                        ForEach(SampleData.leagues, id: \.self) { league in
                            Text(league).tag(league)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Formation")
                        .font(.headline)
                        .padding(.leading, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(SampleData.formations) { formation in
                                FormationCard(
                                    formation: formation,
                                    isSelected: formation.id == selectedFormation.id,
                                    onTap: { selectedFormation = formation }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Game Mode")
                        .font(.headline)
                        .padding(.leading, 4)

                    Picker("Mode", selection: $selectedMode) {
                        ForEach(GameMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Image(systemName: modeIcon)
                            .foregroundColor(modeColor)
                        Text(modeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }

                Button("Start Draft") {
                    onStart(selectedFormation, selectedLeague, selectedMode)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 16)

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var modeIcon: String {
        switch selectedMode {
        case .easy: return "hare"
        case .normal: return "equal"
        case .hard: return "flame"
        case .mode38: return "dice"
        }
    }

    private var modeColor: Color {
        switch selectedMode {
        case .easy: return .green
        case .normal: return .orange
        case .hard: return .red
        case .mode38: return .purple
        }
    }

    private var modeDescription: String {
        switch selectedMode {
        case .easy: return "3 rerolls per pick"
        case .normal: return "1 reroll per pick"
        case .hard: return "No rerolls, ratings hidden"
        case .mode38: return "Pick from random team's roster"
        }
    }
}

struct FormationCard: View {
    let formation: Formation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(formation.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("\(formation.slots.count) players")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, height: 70)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    HomeView(onStart: { _, _, _ in })
}
