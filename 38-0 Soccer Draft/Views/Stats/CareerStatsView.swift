import SwiftUI

struct CareerStatsView: View {
    @State private var stats: CareerStats = .load()
    @State private var showDraftHistory = false
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var adaptiveOverlay: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.35)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Career Stats")
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
                StatTile(label: "Perfect Seas.", value: "\(stats.perfectSeasons)", color: .orange)
            }
            .padding(.horizontal, 16)

            Text("Super League")
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
                StatTile(label: "Fewest GA", value: stats.displaySuperLeagueGA, color: .green)
                StatTile(label: "Cups Won", value: "\(stats.superLeagueCupsWon)", color: .cyan)
            }
            .padding(.horizontal, 16)

            Button(action: {
                showDraftHistory = true
            }) {
                Text("View Past Seasons")
                    .font(.subheadline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .padding(.bottom, 15)
            .padding(.top, 15)
            .tint(.green)
        }
        .frame(maxWidth: 340)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(.horizontal, 40)
        .overlay {
            if showDraftHistory {
                adaptiveOverlay
                    .ignoresSafeArea()
                    .onTapGesture { showDraftHistory = false }

                DraftHistoryView(onDismiss: { showDraftHistory = false })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showDraftHistory)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let color: Color

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
