/// AchievementsView.swift
///
/// Modal grid of all achievements: unlocked ones are colored, locked hidden
/// ones show as "???", and locked visible ones show a dimmed preview.
import SwiftUI

/// Modal showing the full achievement catalog in a tile grid. Unlocked
/// achievements are highlighted by tier; hidden achievements stay masked as
/// "???" until they are earned.
struct AchievementsView: View {
    @State private var unlocked: Set<String> = AchievementStore.unlockedIds()
    let onDismiss: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    /// Header, scrollable achievement grid, and a progress footer.
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Achievements")
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
            .padding(.bottom, 8)

            Text("\(unlocked.count) of \(AchievementStore.all.count) unlocked")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    if let meta = AchievementStore.all.first(where: { $0.id == "legendOfTheGame" }) {
                        AchievementTile(
                            achievement: meta,
                            unlocked: unlocked.contains(meta.id),
                            fullWidth: true
                        )
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(AchievementStore.all.filter { $0.id != "legendOfTheGame" }) { achievement in
                            AchievementTile(achievement: achievement, unlocked: unlocked.contains(achievement.id))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: 380, maxHeight: 700)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(32)
    }
}

/// One achievement cell: icon, title, and detail. Hidden locked achievements
/// are masked with "???"; locked visible ones show dimmed text.
struct AchievementTile: View {
    let achievement: Achievement
    let unlocked: Bool
    var fullWidth: Bool = false

    /// Tier color for unlocked gold/silver/bronze achievements.
    private var tierColor: Color {
        switch achievement.tier {
        case .gold: return .yellow
        case .silver: return .gray
        case .bronze: return .brown
        }
    }

    /// Icon, title, and detail for unlocked achievements. Every tile uses the
    /// same fixed height so all achievements render as identical-size boxes;
    /// the full-width Legend of the Game tile keeps that same height.
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: unlocked ? achievement.icon : "lock.fill")
                .font(fullWidth ? .title2 : .title2)
                .foregroundColor(unlocked ? tierColor : .secondary.opacity(0.4))
                .frame(height: 24)

            Text(displayTitle)
                .font(fullWidth ? .headline.weight(.bold) : .subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(unlocked ? .primary : .secondary.opacity(0.7))

            Text(displayDetail)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

          /*  Text(unlocked ? achievement.tier.rawValue.uppercased() : (achievement.isHidden ? "Hidden" : "Locked"))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(unlocked ? tierColor : .secondary.opacity(0.5)) */
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .background(unlocked ? tierColor.opacity(0.12) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Masked title for locked hidden achievements.
    private var displayTitle: String {
        unlocked || !achievement.isHidden ? achievement.title : "???"
    }

    /// Masked detail for locked hidden achievements.
    private var displayDetail: String {
        unlocked || !achievement.isHidden ? achievement.detail : "???"
    }
}

#Preview {
    AchievementsView(onDismiss: {})
}
