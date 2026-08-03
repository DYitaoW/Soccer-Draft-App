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
    let onStart: (Formation, GameMode, Bool, Bool, Bool, Bool) -> Void
    let onResume: () -> Void
    let onDynastyStart: (GameState) -> Void

    @AppStorage("homeSelectedFormation") private var selectedFormationName: String = GameData.formations[0].name
    @AppStorage("homeSelectedMode") private var selectedModeRaw: String = GameMode.normal.rawValue
    @State private var showCareerStats = false
    @AppStorage("homeShowRatings") private var showRatings: Bool = true
    @AppStorage("homeShowOtherLeagues") private var showOtherLeagues: Bool = true
    @AppStorage("homeShowPastLegends") private var showPastLegends: Bool = true
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

                sectionHeader("Past Legends & Upgraded Players")

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
                
                Text("Adds historical legendary players and upgraded versions of today's stars")
                    .font(.system(size: 12).weight(.light))
                
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
                    .frame(height: 180)
                    .padding(.top, 12)
                    .padding(.horizontal, 0)

                sectionHeader("Game Mode")

                HStack(spacing: 8) {
                    ForEach([GameMode.easy, .normal, .hard], id: \.self) { mode in
                        modeButton(mode)
                    }
                }
                .padding(.bottom, 12)

                HStack(spacing: 8) {
                    ForEach([GameMode.mode38, .positionsFirst], id: \.self) { mode in
                        modeButton(mode)
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
                            Image(systemName: "xmark.circle.fill")
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
        }
        .animation(.easeOut(duration: 0.2), value: showSettings)
        .animation(.easeOut(duration: 0.2), value: showCareerStats)
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
        let gs = GameState(formation: save.formation, mode: .normal, showRatings: true, showPremierLeague: true, showOtherLeagues: true, showGlobalSuperstars: true, showPastLegends: true)
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

    /// Returns the accent color used to style a game mode's selection state.
    private func modeColor(_ mode: GameMode) -> Color {
        switch mode {
        case .easy: return .green
        case .normal: return .blue
        case .hard: return .red
        case .mode38: return .purple
        case .positionsFirst: return .orange
        }
    }

    /// Short subtitle describing the reroll rules of a game mode.
    private func modeDescription(for mode: GameMode) -> String {
        switch mode {
        case .easy: return "3 total rerolls"
        case .normal: return "1 total reroll"
        case .hard: return "No rerolls"
        case .mode38: return "Random Teams"
        case .positionsFirst: return "Pick by position"
        }
    }

    /// One selectable game-mode button (difficulty or special mode).
    private func modeButton(_ mode: GameMode) -> some View {
        Button(action: { selectedModeRaw = mode.rawValue }) {
            VStack(spacing: 2) {
                Text(mode.displayName)
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

/// Small non-interactive pitch preview showing the selected formation's slot
/// positions as colored circles.
struct MiniFieldPreview: View {
    let formation: Formation

    /// Renders the green field and one colored, position-labeled circle per slot.
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
    HomeView(onStart: { _, _, _, _, _, _ in }, onResume: {}, onDynastyStart: { _ in })
}
