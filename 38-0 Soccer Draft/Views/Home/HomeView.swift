import SwiftUI

struct HomeView: View {
    let onStart: (Formation, GameMode, Bool, Bool, Bool, Bool) -> Void
    let onResume: () -> Void

    @State private var selectedFormation: Formation = GameData.formations[0]
    @State private var selectedMode: GameMode = .normal
    @State private var showCareerStats = false
    @AppStorage("homeShowRatings") private var showRatings: Bool = true
    @AppStorage("homeShowOtherLeagues") private var showOtherLeagues: Bool = true
    @AppStorage("homeShowPastLegends") private var showPastLegends: Bool = true
    @AppStorage("homeShowManagers") private var showManagers: Bool = true
    @AppStorage("enableCupCompetitions") private var enableCups = false

    @State private var hasSavedGame = false
    @State private var showSettings = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 0)
                        .onAppear { checkSavedGame() }

                    // top row of the app
                    HStack {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(10)
                                .background(adaptiveGray)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        Spacer()
                        Text("Soccer Draft")
                            .font(.largeTitle.weight(.bold))
                            .padding(.top, 0)
                            .padding(.bottom, 10)
                        Spacer()

                        Button(action: { showCareerStats = true }) {
                            Image(systemName: "chart.bar.fill")
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(10)
                                .foregroundColor(.primary)
                        }.background(adaptiveGray)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.horizontal, 0)
                    .padding(.top, 0)
                    
                    Text("Create the Ultimate 2026/27 Premier League XI")
                        .font(.system(size: 14,)).bold()
                        .padding(.bottom, 10)
                    
                    Divider().padding(.horizontal, -16)

                
                // league database settings
                
                sectionHeader("Other Leagues & Players")

                HStack(spacing: 8) {
                    Button(action: { showOtherLeagues = true }) {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("On")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(showOtherLeagues ? Color.green.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(showOtherLeagues ? RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button(action: { showOtherLeagues = false }) {
                      
                        HStack(spacing: 2) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Off")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(!showOtherLeagues ? Color.red.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(!showOtherLeagues ? RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 5)
                
                Text("Adds other famous teams & players outside England")
                    .font(.system(size: 12).weight(.light))

                sectionHeader("Past Legends")

                HStack(spacing: 8) {
                    Button(action: { showPastLegends = true }) {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("On")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(showPastLegends ? Color.green.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(showPastLegends ? RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button(action: { showPastLegends = false }) {
                        HStack(spacing: 2) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Off")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(!showPastLegends ? Color.red.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(!showPastLegends ? RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 5)
                
                Text("Adds other historical legendary players")
                    .font(.system(size: 12).weight(.light))
                
                // formation view part

                sectionHeader("Formation")

                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 6) {
                    ForEach(GameData.formations) { formation in
                        Button(action: { selectedFormation = formation }) {
                            Text(formation.name)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(formation.id == selectedFormation.id ? Color.green.opacity(tintOpacity) : adaptiveGray)
                                .foregroundColor(.primary)
                                .overlay(formation.id == selectedFormation.id ? RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 2) : nil)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                MiniFieldPreview(formation: selectedFormation)
                    .frame(height: 180)
                    .padding(.top, 12)
                    .padding(.horizontal, 0)

                sectionHeader("Game Mode")

                HStack(spacing: 8) {
                    ForEach(GameMode.allCases, id: \.self) { mode in
                        Button(action: { selectedMode = mode }) {
                            VStack(spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.headline.weight(.bold))
                                Text(modeDescription(for: mode))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedMode == mode ? modeColor(mode).opacity(tintOpacity) : adaptiveGray)
                            .foregroundColor(.primary)
                            .overlay(selectedMode == mode ? RoundedRectangle(cornerRadius: 8).stroke(modeColor(mode), lineWidth: 2) : nil)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Color.clear.frame(height: 4)

                sectionHeader("Show Ratings")

                HStack(spacing: 8) {
                    Button(action: { showRatings = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                            Text("On")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(showRatings ? Color.green.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(showRatings ? RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button(action: { showRatings = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.slash")
                            Text("Off")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(!showRatings ? Color.red.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(!showRatings ? RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 4)

                sectionHeader("Cups")

                HStack(spacing: 8) {
                    Button(action: { enableCups = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                            Text("On")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(enableCups ? Color.green.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(enableCups ? RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button(action: { enableCups = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.slash")
                            Text("Off")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(!enableCups ? Color.red.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(!enableCups ? RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 4)

                sectionHeader("Managers")

                HStack(spacing: 8) {
                    Button(action: { showManagers = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                            Text("On")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(showManagers ? Color.green.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(showManagers ? RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button(action: { showManagers = false }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.slash")
                            Text("Off")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(!showManagers ? Color.red.opacity(tintOpacity) : adaptiveGray)
                        .foregroundColor(.primary)
                        .overlay(!showManagers ? RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 2) : nil)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 4)

                if hasSavedGame {
                    HStack(spacing: 12) {
                        Button(action: {
                            resumeGame()
                        }) {
                            Text("Resume Game")
                                .frame(maxWidth: .infinity)
                                .font(.headline.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                        .controlSize(.large)
                        .padding(.top, 25)
                        .tint(.green)

                        Button(action: {
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
                        .tint(.gray)
                    }
                    .padding(.top, 25)
                } else {
                    Button(action: {
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
                    .tint(.green)
                }

                Spacer().id("settingsBottom")
                }
                .padding(.horizontal, 16)
            }
        }
        .overlay {
            if showSettings {
                adaptiveOverlay
                    .ignoresSafeArea()
                    .onTapGesture { showSettings = false }

                SettingsView(onDismiss: { showSettings = false })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            if showCareerStats {
                adaptiveOverlay
                    .ignoresSafeArea()
                    .onTapGesture { showCareerStats = false }

                CareerStatsView(onDismiss: { showCareerStats = false })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showSettings)
        .animation(.easeOut(duration: 0.2), value: showCareerStats)
    }

    private func checkSavedGame() {
        guard let _ = SavedGame.load() else {
            hasSavedGame = false
            return
        }
        hasSavedGame = true
    }

    private func resumeGame() {
        onResume()
    }

    private var adaptiveOverlay: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.35)
    }

    private var adaptiveGray: Color {
        Color(.systemGray5)
    }

    private var tintOpacity: Double {
        colorScheme == .dark ? 0.2 : 0.12
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .padding(.leading, 2)
    }

    private func modeColor(_ mode: GameMode) -> Color {
        switch mode {
        case .easy: return .green
        case .normal: return .blue
        case .hard: return .red
        case .mode38: return .purple
        }
    }

    private func modeDescription(for mode: GameMode) -> String {
        switch mode {
        case .easy: return "3 total rerolls"
        case .normal: return "1 total reroll"
        case .hard: return "No rerolls"
        case .mode38: return "Random Teams"
        }
    }
}

struct MiniFieldPreview: View {
    let formation: Formation

    var body: some View {
        GeometryReader { geo in
            let cs = min(geo.size.width, geo.size.height) * 0.11
            ZStack {
                Color(red: 0.05, green: 0.38, blue: 0.08)

                Rectangle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 1)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                ForEach(formation.slots.indices, id: \.self) { i in
                    let slot = formation.slots[i]
                    ZStack {
                        Circle()
                            .fill(slot.position.categoryColor)
                            .frame(width: cs, height: cs)
                        Text(slot.position.rawValue)
                            .font(.system(size: max(6, cs * 0.3), weight: .bold))
                            .foregroundColor(.white)
                    }
                    .position(x: CGFloat(slot.fieldX) * geo.size.width, y: CGFloat(slot.fieldY) * geo.size.height)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview("MiniFieldPreview") {
    MiniFieldPreview(formation: GameData.formations[0])
        .frame(height: 200)
        .padding()
}

#Preview {
    HomeView(onStart: { _, _, _, _, _, _ in }, onResume: {})
}
