import Foundation

struct SeasonOdds: Codable {
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

        func pAbove(_ threshold: Double) -> Double {
            1.0 / (1.0 + exp(-(strength - threshold) / 3.0))
        }

        let pTitle = pAbove(94)
        let pTop4Cum = pAbove(87)
        let pTop8Cum = pAbove(80)
        let pRel = 1.0 - pAbove(73)

        let pTop4 = max(0, pTop4Cum - pTitle)
        let pTop8 = max(0, pTop8Cum - pTop4Cum)
        let pMid = max(0, 1.0 - pTop8Cum - pRel)

        let totalProb = pTitle + pTop4 + pTop8 + pMid + pRel
        let expPos = totalProb > 0
            ? (pTitle * 1 + pTop4 * 3 + pTop8 * 6 + pMid * 13 + pRel * 19) / totalProb
            : 10
        let expPts = max(15, min(105, Int(round(105 - Double(expPos) * 5))))

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
