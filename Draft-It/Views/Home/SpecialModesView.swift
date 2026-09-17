/// SpecialModesView.swift
///
/// Popup for selecting a game mode.
import SwiftUI

/// Modal popup that displays all available game modes for selection,
/// grouped by category with 2-per-row layout.
struct SpecialModesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedModeRaw: String
    let onDismiss: () -> Void

    private var selectedMode: GameMode {
        GameMode(rawValue: selectedModeRaw) ?? .normal
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Game Mode")
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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Standard Draft modes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Standard Draft")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)

                        HStack(spacing: 10) {
                            modeButton(.easy)
                            modeButton(.normal)
                        }
                        .padding(.horizontal, 20)

                        HStack(spacing: 10) {
                            modeButton(.hard)
                            modeButton(.extreme)
                        }
                        .padding(.horizontal, 20)
                    }

                    // 38-0 Modes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("38-0 Modes")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)

                        HStack(spacing: 10) {
                            modeButton(.mode38)
                            modeButton(.positionsFirst)
                        }
                        .padding(.horizontal, 20)

                        modeButton(.onePerClub)
                            .padding(.horizontal, 20)
                    }

                    // Special Modes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Special Modes")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)

                        VStack(spacing: 10) {
                            modeButton(.transferBudget)
                            modeButton(.noPremierLeague)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: 360)
        .frame(minHeight: 440, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(32)
    }

    @ViewBuilder
    private func modeButton(_ mode: GameMode) -> some View {
        Button(action: {
            selectedModeRaw = mode.rawValue
            onDismiss()
        }) {
            VStack(spacing: 4) {
                Image(systemName: iconFor(mode))
                    .font(.title3)
                    .foregroundColor(colorFor(mode))

                Text(mode.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.primary)

                Text(mode.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(mode == selectedMode ? colorFor(mode).opacity(0.15) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                mode == selectedMode
                    ? RoundedRectangle(cornerRadius: 12).stroke(colorFor(mode), lineWidth: 2)
                    : nil
            )
        }
        .buttonStyle(.plain)
    }

    private func iconFor(_ mode: GameMode) -> String {
        switch mode {
        case .easy: return "sun.max.fill"
        case .normal: return "equal.circle.fill"
        case .hard: return "flame.fill"
        case .extreme: return "bolt.fill"
        case .mode38: return "list.number"
        case .positionsFirst: return "arrow.up.arrow.down"
        case .transferBudget: return "banknotes"
        case .onePerClub: return "person.2.fill"
        case .noPremierLeague: return "o"
        }
    }

    private func colorFor(_ mode: GameMode) -> Color {
        switch mode {
        case .easy: return .green
        case .normal: return .blue
        case .hard: return .red
        case .extreme: return .purple
        case .mode38: return .orange
        case .positionsFirst: return .cyan
        case .transferBudget: return .yellow
        case .onePerClub: return .indigo
        case .noPremierLeague: return .mint
        }
    }
}

#Preview {
    SpecialModesView(selectedModeRaw: .constant(GameMode.normal.rawValue), onDismiss: {})
}
