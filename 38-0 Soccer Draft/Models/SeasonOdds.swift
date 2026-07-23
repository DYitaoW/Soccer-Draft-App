import Foundation

struct SeasonOdds {
    let winTitle: Int
    let top4: Int
    let top8: Int
    let midTable: Int
    let relegation: Int
    let expectedPoints: Int
    let expectedPosition: Int

    static func calculate(players: [Player], manager: Manager) -> SeasonOdds {
        let avg = Double(players.map(\.ovrRating).reduce(0, +)) / Double(players.count)
        let mgrBonus = Double(manager.rating - 80) * 0.3
        let strength = avg + mgrBonus

        func pAbove(_ threshold: Double, scale: Double = 4) -> Double {
            1.0 / (1.0 + exp(-(strength - threshold) / scale))
        }

        let pTitle = pAbove(89, scale: 3)
        let pTop4Cum = pAbove(83, scale: 3.5)
        let pTop8Cum = pAbove(77, scale: 4)
        let pRel = 1.0 - pAbove(72, scale: 4)

        let pTop4 = pTop4Cum - pTitle
        let pTop8 = pTop8Cum - pTop4Cum
        let pMid = 1.0 - pTop8Cum - pRel

        let totalProb = pTitle + pTop4 + pTop8 + pMid + pRel
        let expPos = totalProb > 0
            ? (pTitle * 2 + pTop4 * 5 + pTop8 * 8 + pMid * 14 + pRel * 19) / totalProb
            : 10
        let expPts = max(20, min(100, Int(round(98 - Double(expPos) * 3.5))))

        return SeasonOdds(
            winTitle: Int((pTitle * 100).rounded()),
            top4: Int((pTop4 * 100).rounded()),
            top8: Int((pTop8 * 100).rounded()),
            midTable: Int((pMid * 100).rounded()),
            relegation: Int((pRel * 100).rounded()),
            expectedPoints: expPts,
            expectedPosition: Int(round(expPos))
        )
    }
}
