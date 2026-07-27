import SwiftUI

struct ContentView: View {
    @State private var gameState: GameState? = nil
    @State private var navigateToGame = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if let gs = gameState {
                GameView(onRestart: {
                    SavedGame.clear()
                    gameState = nil
                })
                .environmentObject(gs)
            } else {
                HomeView(
                    onStart: { formation, mode, showRatings, showOther, showLegends, showManagers in
                        SavedGame.clear()
                        let gs = GameState(formation: formation, mode: mode, showRatings: showRatings, showPremierLeague: true, showOtherLeagues: showOther, showGlobalSuperstars: showOther, showPastLegends: showLegends)
                        if !showManagers {
                            gs.selectedManager = nil
                            gs.managerRevealed = true
                        }
                        gameState = gs
                    },
                    onResume: {
                        gameState = SavedGame.load()
                    }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
