/// CareerStatsView.swift
///
/// Modal summary of lifetime career stats (league and Super League) with
/// shortcuts to view the achievement catalog and past-season draft history.
import SwiftUI

/// Modal showing the player's career records from `CareerStats`: league and
/// Super League tiles, and buttons opening `AchievementsView`, `DraftHistoryView`,
/// and Game Center dashboard.
struct CareerStatsView: View {
    @State private var stats: CareerStats = .load()
    @State private var showDraftHistory = false
    @State private var showAchievements = false
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    /// Scrim color behind the draft-history overlay, adapted to the color scheme.
    private var adaptiveOverlay: Color { adaptiveOverlayColor(for: colorScheme) }

    /// Returns `true` if either the achievements or draft-history modal is active.
    private var subPopupOpen: Bool {
        showAchievements || showDraftHistory
    }

    /// Card layout with two stat grids and buttons opening the achievements,
    /// draft-history, and Game Center modals. The card content fades out while a sub-popup
    /// is open so only one layer is visible at a time.
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("All Career Stats")
                    .font(.title2.weight(.bold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 10)

            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 12) {
                StatTile(label: "Seasons", value: "\(stats.totalSeasons)", color: .blue)
                StatTile(label: "Most Points", value: stats.totalSeasons > 0 ? "\(stats.mostPoints)" : "-", color: .green)
                StatTile(label: "Best Record", value: stats.bestRecord?.display ?? "-", color: .orange)
                StatTile(label: "Best Win %", value: stats.totalSeasons > 0 ? String(format: "%.0f%%", stats.bestWinPct * 100) : "-", color: .yellow)
                StatTile(label: "Most GF", value: stats.totalSeasons > 0 ? "\(stats.mostGoalsFor)" : "-", color: .red)
                StatTile(label: "Fewest GA", value: stats.totalSeasons > 0 ? stats.displayGoalsAgainst : "-", color: .green)
                StatTile(label: "Highest OVR", value: stats.totalSeasons > 0 ? "\(stats.highestOverall)" : "-", color: .cyan)
                StatTile(label: "Titles", value: "\(stats.titles)", color: .yellow)
                StatTile(label: "38-0 Seas.", value: "\(stats.perfectSeasons)", color: .orange)
            }
            .padding(.horizontal, 16)

            Text("Super League Stats")
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 15)
                .padding(.bottom, 10)

            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 12) {
                StatTile(label: "Seasons", value: "\(stats.superLeagueSeasons)", color: .blue)
                StatTile(label: "Finals App.", value: "\(stats.superLeagueFinalsAppearances)", color: .green)
                StatTile(label: "Best Result", value: stats.displaySuperLeagueResult, color: .orange)
                StatTile(label: "Most GF", value: "\(stats.mostSuperLeagueGoalsFor)", color: .red)
                StatTile(label: "KO Rounds Made", value: "\(stats.superLeagueKnockoutRoundsMade)", color: .green)
                StatTile(label: "Cups Won", value: "\(stats.superLeagueCupsWon)", color: .cyan)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Button(action: {
                    showAchievements = true
                }) {
                    Text("Achievements")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .tint(.orange)

                Button(action: {
                    showDraftHistory = true
                }) {
                    Text("Past Seasons")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .tint(.green)

                Button(action: {
                    GameCenterManager.shared.presentDashboard()
                }) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .tint(.purple)
            }
            .padding(.vertical, 15)
        }
        .opacity(subPopupOpen ? 0 : 1)
        .frame(maxWidth: 340)
        .background(subPopupOpen ? Color.clear : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: subPopupOpen ? .clear : .black.opacity(0.2), radius: 20)
        .padding(.horizontal, 40)
        .overlay {
            if showAchievements {
                adaptiveOverlay
                    .ignoresSafeArea()
                    .onTapGesture { showAchievements = false }

                AchievementsView(onDismiss: { showAchievements = false })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .overlay {
            if showDraftHistory {
                adaptiveOverlay
                    .ignoresSafeArea()
                    .onTapGesture { showDraftHistory = false }

                DraftHistoryView(onDismiss: { showDraftHistory = false })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showAchievements)
        .animation(.easeInOut(duration: 0.2), value: showDraftHistory)
    }
}

/// One grid cell in the career-stats layout: bold colored value above a small
/// centered label.
struct StatTile: View {
    let label: String
    let value: String
    let color: Color

    /// Renders the tile with a rounded gray background.
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("StatTile") {
    StatTile(label: "Seasons", value: "12", color: .blue)
        .padding()
}

#Preview {
    CareerStatsView(onDismiss: {})
}
