/// HomeView.swift
///
/// Main menu screen for configuring a new draft: league databases, past legends,
/// formation, game mode, ratings visibility, cups, managers, and saved games.
/// Also launches resume/dynasty flows and presents settings and career stats.
import SwiftUI

/// Root menu of the app. Persists draft preferences with `@AppStorage`, exposes
/// Start/Resume/Dynasty actions through closures, and overlays the settings,
/// career-stats, and midseason-transfer modals.
struct HomeView: View {
    let onStart: (Formation, GameMode, Bool, Bool, Bool, Bool, Int, Bool, Bool, Bool, Bool, Bool) -> Void
    let onResume: () -> Void
    let onDynastyStart: (GameState) -> Void

    @AppStorage("homeSelectedFormation") private var selectedFormationName: String = GameData.formations[0].name
    @AppStorage("homeSelectedMode") private var selectedModeRaw: String = GameMode.normal.rawValue
    @State private var showCareerStats = false
    @State private var showPlayerPools = false
    @State private var showSpecialModes = false
    @AppStorage("homeTransferBudget") private var transferBudgetAmount: Double = 100
    @AppStorage("homeShowRatings") private var showRatings: Bool = true
    @AppStorage("homeShowOtherLeagues") private var showOtherLeagues: Bool = true
    @AppStorage("homeShowPastLegends") private var showPastLegends: Bool = true
    @AppStorage("homeShowUpgradedPlayers") private var showUpgradedPlayers: Bool = true
    @AppStorage("homeShowCultHeros") private var showCultHeros: Bool = true
    @AppStorage("homeShowFutureSuperstars") private var showFutureSuperstars: Bool = true
    @AppStorage("homeShowWomensStars") private var showWomensStars: Bool = true
    @AppStorage("homeShowRandomBums") private var showRandomBums: Bool = true
    @AppStorage("homeShowManagers") private var showManagers: Bool = true
    @AppStorage("enableCupCompetitions") private var enableCups = false
    @AppStorage("dynastyMode") private var dynastyMode = true

    /// The formation selected by name, falling back to the first available.
    private var selectedFormation: Formation {
        GameData.formations.first { $0.name == selectedFormationName } ?? GameData.formations[0]
    }

    /// The game mode selected by raw value, falling back to normal.
    private var selectedMode: GameMode {
        GameMode(rawValue: selectedModeRaw) ?? .normal
    }

    @State private var hasSavedGame = false
    @State private var showSettings = false
    @State private var showDynastyTransfer = false
    @State private var dynastyTransferCount = 0
    @State private var dynastyTransfersRemaining = 0
    @State private var dynastyGameState: GameState? = nil
    @Environment(\.colorScheme) private var colorScheme

    /// Scrollable menu: header, option toggles, formation grid with preview,
    /// game-mode picker, and start/resume/dynasty buttons, plus modals.
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
                        Text("Draft It!")
                            .font(.largeTitle.weight(.bold))
                            .padding(.top, 0)
                            .padding(.bottom, 10)
                        Spacer()

                        Button(action: { showCareerStats = true }) {
                            Image(systemName: "chart.bar.fill")
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(10)
                        }
                        .background(adaptiveGray)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.horizontal, 0)
                    .padding(.top, 0)
                    
                    Text("Create the Ultimate 2026/27 Premier League XI")
                        .font(.system(size: 14)).bold()
                        .padding(.bottom, 10)
                    
                    Divider().padding(.horizontal, -16)

                
                // league database settings
                
                sectionHeader("Player Pools")

                Button(action: { showPlayerPools = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Other Players & Leagues")
                                .font(.headline)
                            Text("Enable additional players and leagues")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(adaptiveGray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                .padding(.bottom, 5)
                
                sectionHeader("Additional Options")

                HStack(spacing: 12) {
                    Button(action: { withAnimation(.none) { enableCups.toggle() } }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trophy.fill")
                            Text("Cups")
                                .font(.headline.weight(.bold))
                            Spacer()
                            Image(systemName: enableCups ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(enableCups ? .green : .red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 18)
                        .background(enableCups ? Color.green.opacity(tintOpacity) : Color.red.opacity(tintOpacity))
                        .foregroundColor(.primary)
                        .overlay(enableCups
                            ? RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 2)
                            : RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button(action: { withAnimation(.none) { showManagers.toggle() } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                            Text("Managers")
                                .font(.headline.weight(.bold))
                            Spacer()
                            Image(systemName: showManagers ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(showManagers ? .green : .red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 18)
                        .background(showManagers ? Color.green.opacity(tintOpacity) : Color.red.opacity(tintOpacity))
                        .foregroundColor(.primary)
                        .overlay(showManagers
                            ? RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 2)
                            : RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 0)
                
                // formation view part

                sectionHeader("Formation")

                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 6) {
                    ForEach(GameData.formations) { formation in
                        Button(action: { selectedFormationName = formation.name }) {
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
                    .frame(height: 160)
                    .padding(.top, 12)
                    .padding(.horizontal, 0)

                sectionHeader("Game Mode")

                Button(action: { showSpecialModes = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedMode.displayName)
                                .font(.headline)
                            Text(selectedMode.fullDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(adaptiveGray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                .padding(.bottom, 12)

                if selectedMode == .transferBudget {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Transfer Budget")
                                .font(.headline)
                            Spacer()
                            Text("$\(Int(transferBudgetAmount))M")
                                .font(.headline).fontWeight(.bold)
                                .foregroundColor(.cyan)
                        }
                        Slider(value: $transferBudgetAmount, in: 100...1000, step: 25)
                            .tint(.cyan)
                        HStack {
                            Text("$100M")
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("$1B")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)
                }

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
                            onStart(selectedFormation, selectedMode, showRatings, showOtherLeagues, showPastLegends, showManagers, Int(transferBudgetAmount), showUpgradedPlayers, showCultHeros, showFutureSuperstars, showWomensStars, showRandomBums)
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
                        onStart(selectedFormation, selectedMode, showRatings, showOtherLeagues, showPastLegends, showManagers, Int(transferBudgetAmount), showUpgradedPlayers, showCultHeros, showFutureSuperstars, showWomensStars, showRandomBums)
                    }) {
                        Text("Start New Game")
                            .frame(maxWidth: .infinity)
                            .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .padding(.top, 5)
                    .tint(.green)
                }

                if dynastyMode && UserDefaults.standard.bool(forKey: "dynastyActive") {
                    Button(action: startDynasty) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Continue Dynasty")
                        }
                        .frame(maxWidth: .infinity)
                        .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .padding(.top, 12)
                    .tint(.orange)
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
            if showPlayerPools {
                adaptiveOverlay
                    .ignoresSafeArea()
                    .onTapGesture { showPlayerPools = false }

                PlayerPoolsView(onDismiss: { showPlayerPools = false })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            if showSpecialModes {
                adaptiveOverlay
                    .ignoresSafeArea()
                    .onTapGesture { showSpecialModes = false }

                SpecialModesView(selectedModeRaw: $selectedModeRaw, onDismiss: { showSpecialModes = false })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showSettings)
        .animation(.easeOut(duration: 0.2), value: showCareerStats)
        .animation(.easeOut(duration: 0.2), value: showPlayerPools)
        .animation(.easeOut(duration: 0.2), value: showSpecialModes)
        .overlay {
            if showDynastyTransfer {
                adaptiveOverlay
                    .ignoresSafeArea()
                if let gs = dynastyGameState {
                    MidseasonTransferView(
                        totalTransfers: dynastyTransferCount,
                        transfersRemaining: $dynastyTransfersRemaining,
                        onComplete: {
                            showDynastyTransfer = false
                            DynastySave.clear()
                            if let gs = dynastyGameState {
                                onDynastyStart(gs)
                            }
                        }
                    )
                    .environmentObject(gs)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: showDynastyTransfer)
    }

    /// Updates `hasSavedGame` based on whether a saved game file exists.
    private func checkSavedGame() {
        guard let _ = SavedGame.load() else {
            hasSavedGame = false
            return
        }
        hasSavedGame = true
    }

    /// Resumes the last saved game via the `onResume` callback.
    private func resumeGame() {
        onResume()
    }

    /// Loads the dynasty save, rebuilds its `GameState`, and presents the
    /// midseason transfer modal with a random transfer budget.
    private func startDynasty() {
        guard let save = DynastySave.load() else { return }
        let mode = GameMode(rawValue: save.gameModeRaw ?? "") ?? .normal
        let gs = GameState(formation: save.formation, mode: mode, showRatings: true, showPremierLeague: true, showOtherLeagues: true, showGlobalSuperstars: true, showPastLegends: true, transferBudgetAmount: save.transferBudgetAmount)
        gs.assignedPlayers = save.assignedPlayers
        gs.substitutes = save.substitutes
        gs.selectedManager = save.manager
        if save.manager != nil {
            gs.managerRevealed = true
        }
        dynastyGameState = gs
        dynastyTransferCount = Int.random(in: 1...5)
        dynastyTransfersRemaining = dynastyTransferCount
        showDynastyTransfer = true
    }

    /// Darker/lighter scrim color behind modals, adapted to the color scheme.
    private var adaptiveOverlay: Color { adaptiveOverlayColor(for: colorScheme) }

    /// Neutral gray used for unselected toggle backgrounds.
    private var adaptiveGray: Color {
        Color(.systemGray5)
    }

    /// Opacity used for the tint of active toggle buttons.
    private var tintOpacity: Double {
        colorScheme == .dark ? 0.2 : 0.12
    }

    /// Section heading row with title and leading padding.
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
}

/// Small non-interactive pitch preview showing the selected formation's slot
/// positions as colored circles.
struct MiniFieldPreview: View {
    let formation: Formation

    /// Renders the green field and one colored, position-labeled circle per slot.
    var body: some View {
        GeometryReader { geo in
            let cs = min(geo.size.width, geo.size.height) * 0.11
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Base green
                Color(red: 0.05, green: 0.38, blue: 0.08)

                // Grass cut lines (lighter green horizontal stripes)
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(Color(red: 0.06, green: 0.42, blue: 0.09))
                        .frame(width: w, height: h / 6)
                        .position(x: w / 2, y: h / 12 + h / 6 * CGFloat(i))
                }

                // Border (thicker)
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)

                // Center line (thicker)
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: w, height: 2)
                    .position(x: w / 2, y: h / 2)

                // Center circle
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: w * 0.25, height: h * 0.25)
                    .position(x: w / 2, y: h / 2)

                // Center dot
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .position(x: w / 2, y: h / 2)

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
    HomeView(onStart: { _, _, _, _, _, _, _, _, _, _, _, _ in }, onResume: {}, onDynastyStart: { _ in })
}
