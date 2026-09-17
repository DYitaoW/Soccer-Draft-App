/// DraftHistoryView.swift
///
/// Modal list of all past saved drafts with season results, opening a detailed
/// view per draft (league table, scorers, lineup, and substitutes).
import SwiftUI

/// Modal listing saved `DraftHistory` entries. Tapping a row opens a
/// `DraftDetailView`; shows an empty state when no history exists.
struct DraftHistoryView: View {
    @State private var history: [DraftHistory] = DraftHistory.loadAll()
    @State private var selectedDraft: DraftHistory?
    let onDismiss: () -> Void

    /// Header, scrollable row list (or empty state), and detail overlay.
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Draft History")
                    .font(.title2.weight(.bold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            if history.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No draft history yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(history) { draft in
                            Button(action: { selectedDraft = draft }) {
                                DraftHistoryRow(draft: draft)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: 380, maxHeight: 520)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(32)
        .overlay {
            if let draft = selectedDraft {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { selectedDraft = nil }
                DraftDetailView(draft: draft, onDismiss: { selectedDraft = nil })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: selectedDraft != nil)
    }
}

/// One compact row summarizing a past draft: date, mode, team OVR, record,
/// finishing position, and Super League cup result.
struct DraftHistoryRow: View {
    let draft: DraftHistory

    /// Lays out the summary columns with a trailing chevron.
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(draft.gameMode.rawValue)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(width: 72, alignment: .leading)

            VStack(spacing: 1) {
                Text("OVR")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text("\(draft.teamOverall)")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.blue)
            }
            .frame(width: 38)

            VStack(spacing: 1) {
                Text("REC")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text(draft.record.display)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(width: 60)

            VStack(spacing: 1) {
                Text("POS")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text(ordinal(draft.position))
                    .font(.headline.weight(.bold))
                    .foregroundColor(draft.position == 1 ? .yellow : .green)
            }
            .frame(width: 36)

            VStack(spacing: 1) {
                Text("CUP")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text(draft.superLeagueDisplay)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(cupColor)
            }
            .frame(width: 40)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Color for the cup result based on the Super League round reached.
    private var cupColor: Color {
        guard let round = draft.superLeagueRound else { return .secondary }
        switch round {
        case .winner: return .yellow
        case .final: return .orange
        case .semiFinal, .quarterFinal: return .green
        default: return .secondary
        }
    }

}

#Preview("DraftHistoryRow") {
    let p = Player(name: "Test", ovrRating: 88, positions: [.ST], team: "Arsenal", league: "EPL")
    let draft = DraftHistory(id: UUID(), date: Date(), gameMode: .normal, teamOverall: 84, record: SeasonRecord(wins: 22, draws: 8, losses: 8), position: 4, formation: GameData.formations[0], assignedPlayers: [0: p], substitutes: [], manager: nil)
    DraftHistoryRow(draft: draft)
        .padding()
}

/// Modal showing the full details of one saved draft: game mode/date, OVR,
/// record, finish, manager, Super League result, expandable league table and
/// scorer sections, the final lineup pitch, and substitutes.
struct DraftDetailView: View {
    let draft: DraftHistory
    let onDismiss: () -> Void

    @State private var showLeagueTable = false
    @State private var showScorers = false

    /// Scrollable detail card with header and collapsible sections.
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Draft Details")
                    .font(.title2.weight(.bold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: true) {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text(draft.gameMode.rawValue)
                                .font(.headline)
                            Text(draft.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("OVR \(draft.teamOverall)")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text(draft.record.display)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack(spacing: 2) {
                            Text("Finish")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ordinal(draft.position))
                                .font(.headline.weight(.bold))
                                .foregroundColor(draft.position == 1 ? .yellow : .green)
                        }
                    }
                    .padding(.horizontal, 20)

                    if let mgr = draft.manager {
                        HStack(spacing: 4) {
                            Text("Manager:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(mgr.name)
                                .font(.caption.weight(.semibold))
                            Text("(\(mgr.rating))")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }

                    if draft.superLeagueRound != nil, let slRecord = draft.superLeagueRecord {
                        VStack(spacing: 4) {
                            Text("Super League")
                                .font(.subheadline.weight(.bold))
                            HStack(spacing: 8) {
                                TileView(label: "CUP", value: draft.superLeagueDisplay, color: .orange)
                                TileView(label: "W", value: "\(slRecord.wins)", color: .green)
                                TileView(label: "D", value: "\(slRecord.draws)", color: .gray)
                                TileView(label: "L", value: "\(slRecord.losses)", color: .red)
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if !draft.standings.isEmpty {
                        VStack(spacing: 4) {
                            Button(action: { withAnimation { showLeagueTable.toggle() } }) {
                                HStack {
                                    Text("League Table")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: showLeagueTable ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                            }
                            if showLeagueTable {
                                let rows = draft.standings.enumerated().map { idx, st in
                                    LeagueTableRowData(
                                        id: st.team.id as AnyHashable,
                                        teamName: st.team.name,
                                        wins: st.wins,
                                        draws: st.draws,
                                        losses: st.losses,
                                        goalsFor: st.goalsFor,
                                        goalsAgainst: st.goalsAgainst,
                                        points: st.points,
                                        isPlayer: st.team.name == customTeamName()
                                    )
                                }
                                LeagueTableSection(
                                    rows: rows,
                                    totalTeams: draft.standings.count,
                                    showGP: true,
                                    showGSGA: true,
                                    qualStart: 1,
                                    qualEnd: 5,
                                    relStart: draft.standings.count - 2
                                )
                                .padding(.horizontal)
                            }
                        }
                    }

                    if !draft.playerStats.isEmpty || !draft.superLeaguePlayerStats.isEmpty {
                        VStack(spacing: 4) {
                            Button(action: { withAnimation { showScorers.toggle() } }) {
                                HStack {
                                    Text("Scorers")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: showScorers ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                            }
                            if showScorers {
                                scorerTable(title: "Regular Season", stats: draft.playerStats)
                                if !draft.superLeaguePlayerStats.isEmpty {
                                    scorerTable(title: "Super League", stats: draft.superLeaguePlayerStats)
                                }
                            }
                        }
                    }

                    FieldView(
                        formation: draft.formation,
                        assignedPlayers: draft.assignedPlayers,
                        onEmptySlotTap: { _, _ in },
                        onFilledSlotTap: nil
                    )
                    .frame(height: 240)
                    .padding(.horizontal, 16)

                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: 380, maxHeight: 600)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
    }

    /// Horizontally scrollable scorer table with goals/assists per player,
    /// only rendered when the stats array is non-empty.
    @ViewBuilder
    private func scorerTable(title: String, stats: [PlayerSeasonStats]) -> some View {
        if !stats.isEmpty {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stats) { stat in
                            VStack(spacing: 2) {
                                Text(stat.playerName)
                                    .font(.system(size: 8, weight: .semibold))
                                    .lineLimit(1)
                                    .frame(width: 50)
                                HStack(spacing: 6) {
                                    Label("\(stat.goals)", systemImage: "soccerball")
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue)
                                    Label("\(stat.assists)", systemImage: "shoe.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 60)
            }
        }
    }

}

#Preview("DraftDetailView") {
    let p = Player(name: "Test", ovrRating: 88, positions: [.ST], team: "Arsenal", league: "EPL")
    let draft = DraftHistory(id: UUID(), date: Date(), gameMode: .normal, teamOverall: 84, record: SeasonRecord(wins: 22, draws: 8, losses: 8), position: 4, formation: GameData.formations[0], assignedPlayers: [0: p], substitutes: [nil, nil, nil, nil, nil], manager: GameData.managers[0], playerStats: [PlayerSeasonStats(playerName: "Salah", goals: 22, assists: 8), PlayerSeasonStats(playerName: "Mane", goals: 18, assists: 6)])
    DraftDetailView(draft: draft, onDismiss: {})
}

#Preview {
    DraftHistoryView(onDismiss: {})
}
