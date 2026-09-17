/// ContentView.swift
///
/// The app's root navigation view. Switches between the home screen
/// (with options to start, resume, or continue a dynasty) and the in-game
/// view once a `GameState` has been created.
import SwiftUI

/// Root container view. Requires no data itself; it presents `HomeView`
/// until a `GameState` exists, then presents `GameView` and injects the
/// state as an environment object. Instantiated by `Soccer_DraftApp`.
struct ContentView: View {
    /// The active game session, or `nil` when showing the home screen.
    @State private var gameState: GameState? = nil

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            if let gs = gameState {
                GameView(onRestart: {
                    SavedGame.clear()
                    gameState = nil
                })
                .environmentObject(gs)
            } else {
                HomeView(
                    onStart: { formation, mode, showRatings, showOther, showLegends, showManagers, budgetAmount, showUpgraded, showCult, showFuture, showWomens, showBums in
                        SavedGame.clear()
                        DynastySave.clear()
                        let gs = GameState(formation: formation, mode: mode, showRatings: showRatings, showPremierLeague: true, showOtherLeagues: showOther, showGlobalSuperstars: showOther, showPastLegends: showLegends, showUpgradedPlayers: showUpgraded, showCultHeros: showCult, showFutureSuperstars: showFuture, showWomensStars: showWomens, showRandomBums: showBums, transferBudgetAmount: budgetAmount)
                        if !showManagers {
                            gs.selectedManager = nil
                            gs.managerRevealed = true
                        }
                        gameState = gs
                    },
                    onResume: {
                        gameState = SavedGame.load()
                    },
                    onDynastyStart: { gs in
                        SavedGame.clear()
                        gameState = gs
                    }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
