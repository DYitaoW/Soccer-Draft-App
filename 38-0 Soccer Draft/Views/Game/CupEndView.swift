import SwiftUI

struct CupEndView: View {
    let competitionType: CupCompetitionType
    let seasonResult: SeasonSimulationResult?
    let cupStandings: [CupStanding]
    let eliminatedIn: String?
    let isChampion: Bool
    let onRestart: () -> Void

    @State private var showCupTable = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Text("Season Complete")
                    .font(.largeTitle.weight(.bold))
                    .padding(.top, 24)

                if isChampion {
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                        Text("\(competitionType.rawValue) Champions!")
                            .font(.title2.weight(.bold))
                    }
                } else if let round = eliminatedIn {
                    VStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Eliminated in \(round)")
                            .font(.title2.weight(.bold))
                    }
                }

                Divider()

                // League Results
                if let sr = seasonResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("League Season")
                            .font(.title2.weight(.bold))

                        if let st = sr.playerStanding {
                            HStack(spacing: 16) {
                                StatBox(label: "Pos", value: "\(sr.playerPosition)", color: .blue)
                                StatBox(label: "W", value: "\(st.wins)", color: .green)
                                StatBox(label: "D", value: "\(st.draws)", color: .gray)
                                StatBox(label: "L", value: "\(st.losses)", color: .red)
                                StatBox(label: "Pts", value: "\(st.points)", color: .yellow)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // League Table
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("#").frame(width: 24, alignment: .leading)
                            Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                            Text("W").frame(width: 24)
                            Text("D").frame(width: 24)
                            Text("L").frame(width: 24)
                            Text("Pts").frame(width: 32, alignment: .trailing)
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        Divider()

                        ForEach(Array(sr.standings.enumerated()), id: \.element.team.id) { idx, st in
                            let isPlayer = st.team.id == sr.playerTeamId
                            HStack(spacing: 0) {
                                Text("\(idx + 1)").frame(width: 24, alignment: .leading)
                                Text(st.team.name)
                                    .fontWeight(isPlayer ? .bold : .regular)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(st.wins)").frame(width: 24)
                                Text("\(st.draws)").frame(width: 24)
                                Text("\(st.losses)").frame(width: 24)
                                Text("\(st.points)").fontWeight(.bold).frame(width: 32, alignment: .trailing)
                            }
                            .font(.system(size: 11))
                            .foregroundColor(isPlayer ? .blue : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(isPlayer ? Color.blue.opacity(0.08) : Color.clear)
                            if idx < sr.standings.count - 1 { Divider().padding(.leading, 12) }
                        }
                    }
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                // Cup Results
                VStack(alignment: .leading, spacing: 8) {
                    Text(competitionType.rawValue)
                        .font(.title2.weight(.bold))

                    if let st = cupStandings.first(where: { $0.team.name == "Your Team" }) {
                        HStack(spacing: 16) {
                            StatBox(label: "W", value: "\(st.wins)", color: .green)
                            StatBox(label: "D", value: "\(st.draws)", color: .gray)
                            StatBox(label: "L", value: "\(st.losses)", color: .red)
                            StatBox(label: "Pts", value: "\(st.points)", color: .yellow)
                        }
                    }
                }
                .padding(.horizontal)

                // Cup Table
                Button(action: { showCupTable.toggle() }) {
                    HStack {
                        Image(systemName: "list.number")
                        Text(showCupTable ? "Hide Cup Table" : "Show Cup Table")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)

                if showCupTable {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("#").frame(width: 24, alignment: .leading)
                            Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                            Text("W").frame(width: 24)
                            Text("D").frame(width: 24)
                            Text("L").frame(width: 24)
                            Text("Pts").frame(width: 32, alignment: .trailing)
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        Divider()

                        ForEach(Array(cupStandings.enumerated()), id: \.element.team.id) { idx, st in
                            let isPlayer = st.team.name == "Your Team"
                            HStack(spacing: 0) {
                                Text("\(idx + 1)").frame(width: 24, alignment: .leading)
                                Text(st.team.name)
                                    .fontWeight(isPlayer ? .bold : .regular)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(st.wins)").frame(width: 24)
                                Text("\(st.draws)").frame(width: 24)
                                Text("\(st.losses)").frame(width: 24)
                                Text("\(st.points)").fontWeight(.bold).frame(width: 32, alignment: .trailing)
                            }
                            .font(.system(size: 11))
                            .foregroundColor(isPlayer ? .blue : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(isPlayer ? Color.blue.opacity(0.08) : Color.clear)
                            if idx < cupStandings.count - 1 { Divider().padding(.leading, 12) }
                        }
                    }
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                Button("Back to Home", action: onRestart)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.vertical, 24)
            }
        }
    }
}

#Preview {
    let team = Team(name: "Your Team", offense: 85, midfield: 83, defense: 82)
    let pid = team.id
    CupEndView(
        competitionType: .superLeague,
        seasonResult: SeasonSimulationResult(
            matches: [],
            standings: [
                LeagueStanding(team: team, wins: 22, draws: 8, losses: 8, goalsFor: 72, goalsAgainst: 41),
                LeagueStanding(team: Team(name: "Arsenal", offense: 88, midfield: 87, defense: 88), wins: 18, draws: 10, losses: 10, goalsFor: 60, goalsAgainst: 45),
            ],
            playerTeamId: pid,
            projectedPosition: 6
        ),
        cupStandings: [
            CupStanding(team: CupTeam(id: pid, name: "Your Team", offense: 85, midfield: 83, defense: 82, pot: 1), wins: 5, draws: 2, losses: 1, goalsFor: 14, goalsAgainst: 6),
        ],
        eliminatedIn: nil,
        isChampion: true,
        onRestart: {}
    )
}
