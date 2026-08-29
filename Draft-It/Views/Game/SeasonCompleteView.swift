/// SeasonCompleteView.swift
///
/// End-of-campaign summary: champion/elimination banner, season awards, league table,
/// optional cup table and scorer breakdown, and the actions to continue the dynasty
/// or return home.
import SwiftUI

/// Renders the full season recap for both the regular season and the cup campaign.
/// Requires the season result and player stats; when a cup was played it also receives
/// `cupStandings` and the competition type. Reports restart / dynasty continuation
/// through `onRestart` and `onContinueDynasty`, and shows an unlock popup for any
/// achievements earned this campaign.
struct SeasonCompleteView: View {
    @Environment(\.colorScheme) private var colorScheme

    let seasonResult: SeasonSimulationResult?
    let cupStandings: [CupStanding]?
    let competitionType: CupCompetitionType?
    let eliminatedIn: String?
    let isChampion: Bool
    let playerStats: [PlayerSeasonStats]
    let regularPlayerStats: [PlayerSeasonStats]
    let superPlayerStats: [PlayerSeasonStats]
    let onRestart: () -> Void
    let onContinueDynasty: (() -> Void)?

    /// Achievements unlocked by this campaign, shown once in a popup.
    var newlyUnlocked: [Achievement] = []

    @State private var showCupTable = false
    @State private var showScorerBreakdown = false
    @State private var showUnlockPopup = false

    /// Top scorer from the provided player stats (most goals, then assists).
    private var goldenBoot: PlayerSeasonStats? {
        playerStats.max(by: { $0.goals < $1.goals || ($0.goals == $1.goals && $0.assists < $1.assists) })
    }

    /// Top assister from the provided player stats (most assists, then goals).
    private var mostAssists: PlayerSeasonStats? {
        playerStats.max(by: { $0.assists < $1.assists || ($0.assists == $1.assists && $0.goals < $1.goals) })
    }

    /// Player with the most combined goals + assists.
    private var mvp: PlayerSeasonStats? {
        playerStats.max(by: { ($0.goals + $0.assists) < ($1.goals + $1.assists) })
    }

    /// Assembles the full scrollable summary: title, awards, season summary, player
    /// stats, league table, cup section, scorers, and the home/dynasty actions.
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                titleSection
                awardsSection
                seasonSummarySection
                leagueTableSection
                if cupStandings != nil {
                    cupSection
                }
                scorersSection
               /* if let onContinue = onContinueDynasty {
                    Button("Continue Dynasty") {
                        onContinue()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                    .padding(.horizontal)
                } */
                Button(action: onRestart) {
                    HStack(spacing: 6) {
                        Image(systemName: "house.fill")
                            .font(.subheadline)
                        Text("Back to Home")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !newlyUnlocked.isEmpty {
                showUnlockPopup = true
            }
        }
        .overlay {
            if showUnlockPopup {
                adaptiveOverlay
                    .ignoresSafeArea()
                    .onTapGesture { showUnlockPopup = false }

                AchievementUnlockPopup(
                    achievements: newlyUnlocked,
                    onDismiss: { showUnlockPopup = false }
                )
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showUnlockPopup)
    }

    /// Scrim color behind the unlock popup, adapted to the color scheme.
    private var adaptiveOverlay: Color { adaptiveOverlayColor(for: colorScheme) }

    /// "Season Complete" heading with the regular-season result banner
    /// (champion trophy or final league position).
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Season Complete")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 24)

            if let sr = seasonResult {
                if sr.playerPosition == 1 {
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                        Text("League Champions!")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.yellow.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("Finished \(ordinal(sr.playerPosition)) in the League")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
            }
        }
    }

    /// Golden Boot, Most Assists, and MVP tiles derived from the player stats.
    @ViewBuilder
    private var awardsSection: some View {
        if !playerStats.isEmpty {
            VStack(spacing: 10) {
                Text("Season Awards")
                    .font(.title2.weight(.bold))

                HStack(spacing: 8) {
                    if let boot = goldenBoot, boot.goals > 0 {
                        awardTile(
                            icon: "soccerball",
                            iconColor: .yellow,
                            label: "Golden Boot",
                            value: "\(boot.goals) goals",
                            name: boot.playerName
                        )
                    }
                    if let assists = mostAssists, assists.assists > 0 {
                        awardTile(
                            icon: "shoe.fill",
                            iconColor: .green,
                            label: "Most Assists",
                            value: "\(assists.assists) assists",
                            name: assists.playerName
                        )
                    }
                    if let top = mvp, (top.goals + top.assists) > 0 {
                        awardTile(
                            icon: "star.fill",
                            iconColor: .yellow,
                            label: "MVP",
                            value: "\(top.goals)G / \(top.assists)A",
                            name: top.playerName
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    /// A single award tile: icon, label, recipient name, and value. All tiles share
    /// the same fixed height, reserving two lines for the player name.
    private func awardTile(icon: String, iconColor: Color, label: String, value: String, name: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(height: 22)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(name)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 36)
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 118)
        .padding(.vertical, 8)
        .background(Color(.systemGray5).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// League season record tiles (position, W-D-L, points, goal difference).
    @ViewBuilder
    private var seasonSummarySection: some View {
        if let sr = seasonResult, let st = sr.playerStanding {
            VStack(spacing: 8) {
                Text("League Season")
                    .font(.title2.weight(.bold))

                HStack(spacing: 8) {
                    TileView(label: "Pos", value: "\(sr.playerPosition)", color: .blue)
                    TileView(label: "W", value: "\(st.wins)", color: .green)
                    TileView(label: "D", value: "\(st.draws)", color: .gray)
                    TileView(label: "L", value: "\(st.losses)", color: .red)
                    TileView(label: "Pts", value: "\(st.points)", color: .yellow)
                    TileView(label: "GD", value: gdText(st.goalDiff), color: st.goalDiff >= 0 ? .green : .red)
                }
                .padding(.horizontal)
            }
        }
    }

    /// Final league table from the season result.
    @ViewBuilder
    private var leagueTableSection: some View {
        if let sr = seasonResult {
            VStack(alignment: .leading, spacing: 6) {
                Text("League Table")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal)

                let rows = sr.standings.enumerated().map { idx, st in
                    LeagueTableRowData(
                        id: st.team.id as AnyHashable,
                        teamName: st.team.name,
                        wins: st.wins,
                        draws: st.draws,
                        losses: st.losses,
                        goalsFor: st.goalsFor,
                        goalsAgainst: st.goalsAgainst,
                        points: st.points,
                        isPlayer: st.team.id == sr.playerTeamId
                    )
                }
                LeagueTableSection(
                    rows: rows,
                    totalTeams: sr.standings.count,
                    showGP: true,
                    showGSGA: true,
                    qualStart: 1,
                    qualEnd: 5,
                    relStart: sr.standings.count - 2
                )
                .padding(.horizontal)
            }
        }
    }

    /// Cup campaign section: Super League result banner, the player's cup record
    /// tiles and an expandable full table, shown only when the player competed in a cup.
    @ViewBuilder
    private var cupSection: some View {
        if let standings = cupStandings {
            Divider()

            if isChampion {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    Text("\(competitionType?.rawValue ?? "Cup") Champions!")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.yellow.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            } else if let round = eliminatedIn {
                VStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    Text("Eliminated in the \(round)")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(competitionType?.rawValue ?? "Cup")
                    .font(.title2.weight(.bold))
                    .padding(.horizontal)

                if let st = standings.first(where: { $0.team.name == customTeamName() }) {
                    HStack(spacing: 8) {
                        TileView(label: "W", value: "\(st.wins)", color: .green)
                        TileView(label: "D", value: "\(st.draws)", color: .gray)
                        TileView(label: "L", value: "\(st.losses)", color: .red)
                        TileView(label: "Pts", value: "\(st.points)", color: .yellow)
                    }
                    .padding(.horizontal)
                }
            }

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
                let cutoff = min(standings.count, 24)
                let rows = standings.enumerated().map { idx, st in
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
                    totalTeams: standings.count,
                    showGP: false,
                    showGSGA: true,
                    qualStart: 1,
                    qualEnd: 8,
                    relStart: cutoff + 1
                )
                .padding(.horizontal)
            }
        }
    }

    /// Combined totals shown by default; the regular-season and Super League tables
    /// are revealed behind a toggle button.
    @ViewBuilder
    private var scorersSection: some View {
        if !regularPlayerStats.isEmpty || !superPlayerStats.isEmpty {
            Divider()
            VStack(spacing: 12) {
                scorerTable(title: "Total Stats", stats: totalStats)

                if !superPlayerStats.isEmpty {
                    Button(action: { withAnimation { showScorerBreakdown.toggle() } }) {
                        HStack(spacing: 6) {
                            Image(systemName: showScorerBreakdown ? "chevron.up" : "chevron.down")
                                .font(.caption)
                            Text(showScorerBreakdown ? "Hide League & Super League" : "Show League & Super League")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    if showScorerBreakdown {
                        if !regularPlayerStats.isEmpty {
                            scorerTable(title: "Regular Season", stats: regularPlayerStats)
                        }
                        if !superPlayerStats.isEmpty {
                            scorerTable(title: "Super League", stats: superPlayerStats)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    /// Merges regular-season and Super League stats into combined per-player totals,
    /// summing goals/assists for players who featured in both competitions.
    private var totalStats: [PlayerSeasonStats] {
        var dict: [String: PlayerSeasonStats] = [:]
        for s in regularPlayerStats {
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

    /// A titled goals/assists table for a given set of player stats.
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

/// Popup shown at season end listing the achievements unlocked this campaign,
/// with a "View Achievements" shortcut and a dismiss action.
struct AchievementUnlockPopup: View {
    let achievements: [Achievement]
    let onDismiss: () -> Void
    @State private var showAll = false

    /// Tier color for an achievement.
    private func tierColor(_ achievement: Achievement) -> Color {
        switch achievement.tier {
        case .gold: return .yellow
        case .silver: return .gray
        case .bronze: return .brown
        }
    }

    /// Centered card: headline, unlock rows, and action buttons.
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundColor(.yellow)

            Text("Achievement\(achievements.count > 1 ? "s" : "") Unlocked!")
                .font(.title3.weight(.bold))

            VStack(spacing: 10) {
                ForEach(achievements) { achievement in
                    if achievement.id == "legendOfTheGame" {
                        VStack(spacing: 6) {
                            Image(systemName: achievement.icon)
                                .font(.system(size: 30))
                                .foregroundColor(tierColor(achievement))
                            Text(achievement.title)
                                .font(.headline.weight(.bold))
                            Text(achievement.detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: achievement.icon)
                                .font(.title3)
                                .foregroundColor(tierColor(achievement))
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.subheadline.weight(.bold))
                                Text(achievement.detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            Button(action: {
                showAll = true
            }) {
                Text("View Achievements")
                    .font(.subheadline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .tint(.orange)

            Button(action: onDismiss) {
                Text("Continue")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .overlay {
            if showAll {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { showAll = false }
                AchievementsView(onDismiss: { showAll = false })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showAll)
    }
}

#Preview {
    AchievementUnlockPopup(
        achievements: [
            Achievement(id: "firstTitle", title: "Champions", detail: "Win the league title.", icon: "trophy.fill", tier: .silver),
            Achievement(id: "starCatcher", title: "Star Catcher", detail: "Draft a player rated 95+.", icon: "star.fill", tier: .gold)
        ],
        onDismiss: {}
    )
}
