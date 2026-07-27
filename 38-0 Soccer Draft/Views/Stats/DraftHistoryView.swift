import SwiftUI

struct DraftHistoryView: View {
    @State private var history: [DraftHistory] = DraftHistory.loadAll()
    @State private var selectedDraft: DraftHistory?
    let onDismiss: () -> Void

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

struct DraftHistoryRow: View {
    let draft: DraftHistory

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(draft.gameMode.rawValue)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(width: 80, alignment: .leading)

            VStack(spacing: 1) {
                Text("OVR")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text("\(draft.teamOverall)")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.blue)
            }
            .frame(width: 44)

            VStack(spacing: 1) {
                Text("REC")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text(draft.record.display)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(width: 70)

            VStack(spacing: 1) {
                Text("POS")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text(ordinal(draft.position))
                    .font(.headline.weight(.bold))
                    .foregroundColor(draft.position == 1 ? .yellow : .green)
            }
            .frame(width: 44)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        if (11...13).contains(n % 100) { suffix = "th" }
        else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

#Preview("DraftHistoryRow") {
    let p = Player(name: "Test", ovrRating: 88, positions: [.ST], team: "Arsenal", league: "EPL")
    let draft = DraftHistory(id: UUID(), date: Date(), gameMode: .normal, teamOverall: 84, record: SeasonRecord(wins: 22, draws: 8, losses: 8), position: 4, formation: GameData.formations[0], assignedPlayers: [0: p], substitutes: [], manager: nil)
    DraftHistoryRow(draft: draft)
        .padding()
}

struct DraftDetailView: View {
    let draft: DraftHistory
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
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

            FieldView(
                formation: draft.formation,
                assignedPlayers: draft.assignedPlayers,
                onEmptySlotTap: { _, _ in },
                onFilledSlotTap: nil
            )
            .frame(height: 280)
            .padding(.horizontal, 16)

            if draft.substitutes.contains(where: { $0 != nil }) {
                VStack(spacing: 4) {
                    Text("Substitutes")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(draft.substitutes.enumerated()), id: \.offset) { pair in
                                if let player = pair.element {
                                    VStack(spacing: 2) {
                                        ZStack {
                                            Circle()
                                                .fill(player.positions.first!.categoryColor)
                                                .frame(width: 44, height: 44)
                                            Text("\(player.ovrRating)")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        Text(player.name)
                                            .font(.system(size: 7))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .frame(width: 52)
                                    }
                                    .frame(width: 52)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 80)
                }
            }

            Spacer()
        }
        .frame(maxWidth: 360, maxHeight: 560)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        if (11...13).contains(n % 100) { suffix = "th" }
        else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

#Preview("DraftDetailView") {
    let p = Player(name: "Test", ovrRating: 88, positions: [.ST], team: "Arsenal", league: "EPL")
    let draft = DraftHistory(id: UUID(), date: Date(), gameMode: .normal, teamOverall: 84, record: SeasonRecord(wins: 22, draws: 8, losses: 8), position: 4, formation: GameData.formations[0], assignedPlayers: [0: p], substitutes: [nil, nil, nil, nil, nil], manager: GameData.managers[0])
    DraftDetailView(draft: draft, onDismiss: {})
}

#Preview {
    DraftHistoryView(onDismiss: {})
}
