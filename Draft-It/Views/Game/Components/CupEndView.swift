/// CupEndView.swift
///
/// End-of-season summary screen for cup competitions: championship or
/// elimination banner, league and cup tables, top scorer lists, and a
/// button back to the home screen.

import SwiftUI

/// Full-screen end-of-season summary shown after a cup tournament concludes.
///
/// Requires the competition type, optional league season result, cup
/// standings, elimination info, player stats, and a restart callback.
/// Renders a champion/eliminated banner, the league table, a toggleable
/// cup table, top scorer lists, and a "Back to Home" button.
struct CupEndView: View {
    let competitionType: CupCompetitionType
    let seasonResult: SeasonSimulationResult?
    let cupStandings: [CupStanding]
    let eliminatedIn: String?
    let isChampion: Bool
    let regularPlayerStats: [PlayerSeasonStats]
    let superPlayerStats: [PlayerSeasonStats]
    let onRestart: () -> Void

    @State private var showCupTable = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Text("Season Complete")
                    .font(.largeTitle.weight(.bold))
                    .padding(.top, 24)

                if isChampion {
                    VStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                        Text("\(competitionType.rawValue) Champions!")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color.yellow.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                } else if let round = eliminatedIn {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Eliminated in \(round)")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                Divider()

                // League Results
                if let sr = seasonResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("League Season")
                            .font(.title2.weight(.bold))
                            .padding(.horizontal)

                        if let st = sr.playerStanding {
                            HStack(spacing: 8) {
                                TileView(label: "Pos", value: "\(sr.playerPosition)", color: .blue)
                                TileView(label: "W", value: "\(st.wins)", color: .green)
                                TileView(label: "D", value: "\(st.draws)", color: .gray)
                                TileView(label: "L", value: "\(st.losses)", color: .red)
                                TileView(label: "Pts", value: "\(st.points)", color: .yellow)
                            }
                            .padding(.horizontal)
                        }
                    }

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
                        .padding(.horizontal)

                    if let st = cupStandings.first(where: { $0.team.name == customTeamName() }) {
                        HStack(spacing: 8) {
                            TileView(label: "W", value: "\(st.wins)", color: .green)
                            TileView(label: "D", value: "\(st.draws)", color: .gray)
                            TileView(label: "L", value: "\(st.losses)", color: .red)
                            TileView(label: "Pts", value: "\(st.points)", color: .yellow)
                        }
                        .padding(.horizontal)
                    }
                }

                // Cup Table
                Button(action: { showCupTable.toggle() }) {
                    HStack {
                        Image(systemName: "list.number")
                        Text(showCupTable ? "Hide Cup Table" : "Show Cup Table")
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(.primary)
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
                            let isPlayer = st.team.name == customTeamName()
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

                // Top Scorers
                Divider()

                VStack(spacing: 12) {
                    if !regularPlayerStats.isEmpty {
                        scorerTable(title: "Regular Season", stats: regularPlayerStats)
                    }
                    if !superPlayerStats.isEmpty {
                        scorerTable(title: "Super League", stats: superPlayerStats)
                    }
                    if !superPlayerStats.isEmpty {
                        scorerTable(title: "Total Stats", stats: totalStats)
                    }
                }
                .padding(.horizontal)

                Button(action: onRestart) {
                    HStack(spacing: 6) {
                        Image(systemName: "house.fill")
                            .font(.subheadline)
                        Text("Back to Home")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .tint(.primary)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 15)
            }
        }
    }

    /// Combines regular season and Super League player stats for players
    /// appearing in both, merging goals/assists and sorting by goals.
    private var totalStats: [PlayerSeasonStats] {
        var dict: [String: PlayerSeasonStats] = [:]
        let superNames = Set(superPlayerStats.map(\.playerName))
        for s in regularPlayerStats where superNames.contains(s.playerName) {
            dict[s.playerName] = PlayerSeasonStats(playerName: s.playerName, goals: s.goals, assists: s.assists)
        }
        for s in superPlayerStats {
            if dict[s.playerName] == nil {
                dict[s.playerName] = PlayerSeasonStats(playerName: s.playerName)
            }
            dict[s.playerName]!.goals += s.goals
            dict[s.playerName]!.assists += s.assists
        }
        return dict.values.sorted { $0.goals > $1.goals || ($0.goals == $1.goals && $0.assists > $1.assists) }
    }

    /// Builds a compact top-scorer table: player names with goal and assist
    /// tallies for the given stat list, headed by `title`.
    private func scorerTable(title: String, stats: [PlayerSeasonStats]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.bold))
                .padding(.top, 4)

            ForEach(stats) { stat in
                HStack(spacing: 0) {
                    Text(stat.playerName)
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: "soccerball")
                                .font(.system(size: 9))
                                .foregroundColor(.yellow)
                            Text("\(stat.goals)")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(width: 40)
                        HStack(spacing: 3) {
                            Image(systemName: "shoe.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text("\(stat.assists)")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(width: 40)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(8)
        .background(Color(.systemGray5).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        regularPlayerStats: [
            PlayerSeasonStats(playerName: "Harry Kane", goals: 28, assists: 8),
            PlayerSeasonStats(playerName: "Bukayo Saka", goals: 14, assists: 12),
            PlayerSeasonStats(playerName: "Martin Odegaard", goals: 8, assists: 16),
        ],
        superPlayerStats: [
            PlayerSeasonStats(playerName: "Harry Kane", goals: 10, assists: 3),
            PlayerSeasonStats(playerName: "Bukayo Saka", goals: 5, assists: 7),
        ],
        onRestart: {}
    )
}
