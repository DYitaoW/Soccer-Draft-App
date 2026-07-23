import SwiftUI

struct ContentView: View {
    @State private var gameState: GameState?

    var body: some View {
        if let gs = gameState {
            GameView(onRestart: { gameState = nil })
                .environmentObject(gs)
        } else {
            HomeView { formation, league, mode in
                gameState = GameState(formation: formation, league: league, mode: mode)
            }
        }
    }
}

#Preview {
    ContentView()
}
