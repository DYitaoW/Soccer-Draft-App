/// SettingsView.swift
///
/// Modal settings sheet for toggling fast mode, appearance, managerial
/// decisions, team name, dynasty mode, playable penalties, and resetting
/// all career stats.
import SwiftUI

/// Modal settings panel. All settings are persisted via `@AppStorage`; the
/// reset button clears career stats after confirmation.
struct SettingsView: View {
    @AppStorage("fastMode") private var fastMode = false
    @AppStorage("colorSchemeMode") private var colorSchemeMode = "system"
    @AppStorage("teamName") private var teamName = "Your Team"
    @AppStorage("expandedManagerialDecisions") private var expandedManagerialDecisions = false
    @AppStorage("dynastyMode") private var dynastyMode = true
    @AppStorage("playablePenalties") private var playablePenalties = false
    @State private var stats: CareerStats = .load()
    @State private var showResetConfirm = false
    @State private var teamNameBuffer = ""
    @FocusState private var teamNameFocused: Bool
    let onDismiss: () -> Void

    /// Saves the current buffer to the persisted team name, applying the
    /// "Your Team" fallback only when the user finishes editing.
    private func commitTeamName() {
        teamName = sanitizeTeamName(teamNameBuffer)
        teamNameBuffer = teamName
    }

    /// Card layout of toggles, pickers, the team-name field, and the reset
    /// button, with a reset confirmation alert.
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
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

            VStack(spacing: 5) {
                HStack {
                    Text("Fast Mode")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $fastMode)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                Text("When enabled, animations and delays are skipped for faster gameplay.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)


                HStack {
                    Text("Appearance")
                        .font(.headline)
                    Spacer()
                    Picker("", selection: $colorSchemeMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                //Divider()
                  //  .padding(.horizontal, 20)
                

                HStack {
                    Text("Midseason Transfers")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $expandedManagerialDecisions)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)
                

                Text("Enable anywhere from 1-3 transfers midseason")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                Divider()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                HStack {
                    Text("Playable Penalties")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $playablePenalties)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                Text("Take penalty shootouts yourself")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                Divider()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                HStack {
                    Text("Team Name")
                        .font(.headline)
                    Spacer()
                    TextField("Enter team name", text: $teamNameBuffer)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 180)
                        .focused($teamNameFocused)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                        )
                        .onChange(of: teamNameBuffer) {
                            let filtered = String(
                                teamNameBuffer.prefix(30).filter {
                                    $0.isLetter || $0.isNumber || $0.isWhitespace || $0 == "-" || $0 == "'" || $0 == "." || $0 == "!"
                                }
                            )
                            if filtered != teamNameBuffer {
                                teamNameBuffer = filtered
                            }
                        }
                        .onSubmit {
                            commitTeamName()
                        }
                        .onChange(of: teamNameFocused) {
                            if !teamNameFocused {
                                commitTeamName()
                            }
                        }
                }
                .padding(.horizontal, 20)

                Button("Reset All Stats", role: .destructive) {
                    showResetConfirm = true
                }
                .font(.headline.weight(.bold))
                .buttonStyle(.borderedProminent)
                //.controlSize(.large)
                .padding(.top, 20)
                .buttonBorderShape(.roundedRectangle(radius: 10))

                Divider()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                HStack(spacing: 12) {
                    Link(destination: URL(string: "https://beyondthestatsapp.com/draftit/privacy")!) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)

                    Link(destination: URL(string: "https://beyondthestatsapp.com/draftit/about")!) {
                        Label("About / Support", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .padding(.bottom, 15)

            Spacer()
        }
        .frame(maxWidth: 340, maxHeight: 550)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(32)
        .onAppear {
            dynastyMode = true
            if teamNameBuffer.isEmpty {
                teamNameBuffer = teamName
            }
        }
        .alert("Reset All Stats", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                CareerStats.reset()
                AchievementStore.reset()
                stats = .load()
            }
        } message: {
            Text("This will permanently erase all career stats, achievements, and past game history.")
        }
    }
}

#Preview {
    SettingsView(onDismiss: {})
}
