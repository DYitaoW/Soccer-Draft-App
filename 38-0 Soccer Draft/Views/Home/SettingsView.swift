import SwiftUI

struct SettingsView: View {
    @AppStorage("fastMode") private var fastMode = false
    @AppStorage("colorSchemeMode") private var colorSchemeMode = "system"
    @State private var stats: CareerStats = .load()
    @State private var showResetConfirm = false
    let onDismiss: () -> Void

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

                Divider()
                    .padding(.horizontal, 20)
                
           /*    Button(action: {
                    onStart(selectedFormation, selectedMode, showRatings, showOtherLeagues, showPastLegends, showManagers)
                }) {
                    Text("Start New Game")
                        .frame(maxWidth: .infinity)
                        .font(.headline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.large)
                .padding(.top, 25)
                .tint(.green) */

                Button("Reset All Stats", role: .destructive) {
                    showResetConfirm = true
                }
                .font(.headline.weight(.bold))
                .buttonStyle(.borderedProminent)
                //.controlSize(.large)
                .padding(.top, 20)
                .buttonBorderShape(.roundedRectangle(radius: 10))
            }
            .padding(.bottom, 20)

            Spacer()
        }
        .frame(maxWidth: 340, maxHeight: 360)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(32)
        .alert("Reset All Stats", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                CareerStats.reset()
                stats = .load()
            }
        } message: {
            Text("This will permanently erase all career stats and past game history.")
        }
    }
}

#Preview {
    SettingsView(onDismiss: {})
}
