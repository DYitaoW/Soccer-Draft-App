/// PlayerPoolsView.swift
///
/// Popup for toggling which player pools are included in the draft.
import SwiftUI

/// Modal popup that lets the user toggle which player pools are included
/// in the draft. Uses full-width buttons styled like the game mode selector.
struct PlayerPoolsView: View {
    @AppStorage("homeShowOtherLeagues") private var showOtherLeagues: Bool = true
    @AppStorage("homeShowPastLegends") private var showPastLegends: Bool = true
    @AppStorage("homeShowUpgradedPlayers") private var showUpgradedPlayers: Bool = true
    @AppStorage("homeShowCultHeros") private var showCultHeros: Bool = true
    @AppStorage("homeShowFutureSuperstars") private var showFutureSuperstars: Bool = true
    @AppStorage("homeShowWomensStars") private var showWomensStars: Bool = true
    @AppStorage("homeShowRandomBums") private var showRandomBums: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Player Pools")
                    .font(.title2.weight(.bold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            VStack(spacing: 8) {
                poolButton(title: "Other Leagues & Players", subtitle: "Adds other famous teams & players outside England", isOn: $showOtherLeagues)
                poolButton(title: "Past Legends", subtitle: "Adds historical legendary players from past eras", isOn: $showPastLegends)
                poolButton(title: "Upgraded Players", subtitle: "Adds upgraded versions of today's stars", isOn: $showUpgradedPlayers)
                poolButton(title: "Cult Heros", subtitle: "Adds fan favorite players", isOn: $showCultHeros)
                poolButton(title: "Future Superstars", subtitle: "Adds young players upgraded to their max potential", isOn: $showFutureSuperstars)
                poolButton(title: "Womens Stars", subtitle: "Adds some top players from womens football", isOn: $showWomensStars)
                poolButton(title: "Random Bums", subtitle: "Adds some randoms", isOn: $showRandomBums)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: 340)
        //.fixedSize()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(32)
    }

    @ViewBuilder
    private func poolButton(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Button(action: {
            isOn.wrappedValue.toggle()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isOn.wrappedValue ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isOn.wrappedValue ? Color.green : Color.red, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PlayerPoolsView(onDismiss: {})
}
