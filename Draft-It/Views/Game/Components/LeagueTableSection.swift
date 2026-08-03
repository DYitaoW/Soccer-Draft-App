/// LeagueTableSection.swift
///
/// Reusable league table UI: a data model for one table row plus the section
/// view that renders the standings with position, record, and qualification/
/// relegation highlighting.

import SwiftUI

/// Value type describing a single row in a league standings table.
/// `isPlayer` flags the user's own team for highlighting.
struct LeagueTableRowData: Identifiable {
    let id: AnyHashable
    let teamName: String
    let wins: Int
    let draws: Int
    let losses: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let points: Int
    let isPlayer: Bool

    /// Total matches played (wins + draws + losses).
    var played: Int { wins + draws + losses }
    /// Goal difference (goals for minus goals against).
    var goalDiff: Int { goalsFor - goalsAgainst }

    init(id: AnyHashable, teamName: String, wins: Int, draws: Int, losses: Int, goalsFor: Int, goalsAgainst: Int, points: Int, isPlayer: Bool) {
        self.id = id
        self.teamName = teamName
        self.wins = wins
        self.draws = draws
        self.losses = losses
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.points = points
        self.isPlayer = isPlayer
    }
}

/// Renders a full standings table. Position colors mark the champion,
/// qualification band (`qualStart...qualEnd`), and relegation band
/// (`relStart...`), with the player's row highlighted. Column visibility
/// (GP, GS/GA) is configurable for different competition layouts.
struct LeagueTableSection: View {
    let rows: [LeagueTableRowData]
    let totalTeams: Int
    let showGP: Bool
    let showGSGA: Bool
    let qualStart: Int
    let qualEnd: Int
    let relStart: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                dataRow(row: row, position: idx + 1)
                if idx < rows.count - 1 {
                    Divider().padding(.leading, 8)
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Column headers for the table, matching the column set from the config.
    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 24, alignment: .leading)
            Text("Team").frame(maxWidth: .infinity, alignment: .leading)
            if showGP { Text("GP").frame(width: 22) }
            Text("W").frame(width: 22)
            Text("D").frame(width: 22)
            Text("L").frame(width: 22)
            if showGSGA { Text("GS/GA").frame(width: 44) }
            Text("GD").frame(width: 28)
            Text("Pts").frame(width: 30, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    /// Builds one table row at the given position, color-coding the position
    /// number by champion/qualification/relegation and highlighting the
    /// player's row.
    private func dataRow(row: LeagueTableRowData, position: Int) -> some View {
        let qualColor: Color = position == 1 ? .yellow : (position >= qualStart && position <= qualEnd) ? .green : (position >= relStart) ? .red : .secondary
        let isHighlighted = position <= qualEnd || position >= relStart
        return HStack(spacing: 0) {
            Text("\(position)")
                .frame(width: 24, alignment: .leading)
                .foregroundColor(qualColor)
                .fontWeight(isHighlighted ? .bold : .regular)
            Text(row.teamName)
                .fontWeight(row.isPlayer ? .bold : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showGP { Text("\(row.played)").frame(width: 22) }
            Text("\(row.wins)")
                .foregroundColor(.green)
                .frame(width: 22)
            Text("\(row.draws)").frame(width: 22)
            Text("\(row.losses)")
                .foregroundColor(.red)
                .frame(width: 22)
            if showGSGA { Text("\(row.goalsFor)/\(row.goalsAgainst)").frame(width: 44) }
            Text(gdText(row.goalDiff))
                .foregroundColor(row.goalDiff >= 0 ? .green : .red)
                .frame(width: 28)
            Text("\(row.points)")
                .fontWeight(.bold)
                .frame(width: 30, alignment: .trailing)
        }
        .font(.system(size: 10))
        .foregroundColor(row.isPlayer ? .blue : .primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(row.isPlayer ? Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.08) : Color.clear)
    }
}

