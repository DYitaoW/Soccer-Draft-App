/// SeasonOdds.swift
///
/// Monte-Carlo season prediction: runs many simulated seasons to estimate
/// a player team's title, top-4, top-8, mid-table, and relegation probabilities.
import Foundation

/// Probability percentages (0-100) and expected outcome for a player team,
/// derived from Monte-Carlo season simulations and Codable for persistence.
struct SeasonOdds: Codable {
    /// Estimated chance of winning the league, as a percentage.
    let winTitle: Int
    /// Estimated chance of finishing top 4, as a percentage.
    let top4: Int
    /// Estimated chance of finishing top 8, as a percentage.
    let top8: Int
    /// Estimated chance of finishing in the mid-table band, as a percentage.
    let midTable: Int
    /// Estimated chance of being relegated, as a percentage.
    let relegation: Int
    /// Expected points total across simulated seasons.
    let expectedPoints: Int
    /// Median final league position across simulated seasons.
    let expectedPosition: Int

    init(
        winTitle: Int, top4: Int, top8: Int, midTable: Int, relegation: Int,
        expectedPoints: Int, expectedPosition: Int
    ) {
        self.winTitle = winTitle
        self.top4 = top4
        self.top8 = top8
        self.midTable = midTable
        self.relegation = relegation
        self.expectedPoints = expectedPoints
        self.expectedPosition = expectedPosition
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        winTitle = try c.decode(Int.self, forKey: .winTitle)
        top4 = try c.decode(Int.self, forKey: .top4)
        top8 = try c.decode(Int.self, forKey: .top8)
        midTable = try c.decode(Int.self, forKey: .midTable)
        relegation = try c.decode(Int.self, forKey: .relegation)
        expectedPoints = try c.decode(Int.self, forKey: .expectedPoints)
        expectedPosition = try c.decode(Int.self, forKey: .expectedPosition)
    }

    /// Estimates a team's season odds by simulating the league 150 times, each
    /// time drawing a fresh random set of 19 opponents. Percentages are the
    /// rounded share of iterations falling into each outcome band.
    /// - Parameters:
    ///   - playerTeam: The team whose odds are being estimated.
    ///   - opponents: The pool of teams opponents are drawn from.
    /// - Returns: Computed probabilities and expected points/position.
    static func calculate(playerTeam: Team, opponents: [Team], difficulty: Double = 0) -> SeasonOdds {
        let iterations = 150
        var positions: [Int] = []
        var points: [Int] = []
        positions.reserveCapacity(iterations)
        points.reserveCapacity(iterations)
        var title = 0, top4 = 0, top8 = 0, mid = 0, rel = 0

        for _ in 0..<iterations {
            let seasonOpponents = Array(opponents.shuffled().prefix(19))
            let sim = SeasonSimulator.simulateSeason(
                playerTeam: playerTeam,
                opponents: seasonOpponents,
                projectedPosition: 0,
                difficulty: difficulty
            )
            let pos = sim.playerPosition
            positions.append(pos)
            points.append(sim.playerStanding?.points ?? 0)
            switch pos {
            case 1: title += 1
            case 2...4: top4 += 1
            case 5...8: top8 += 1
            case 9...17: mid += 1
            default: rel += 1
            }
        }

        positions.sort()
        points.sort()
        let expPosition = positions[iterations / 2]
        let expPoints = Int((Double(points.reduce(0, +)) / Double(iterations)).rounded())

        return SeasonOdds(
            winTitle: Int((Double(title) / Double(iterations) * 100).rounded()),
            top4: Int((Double(top4) / Double(iterations) * 100).rounded()),
            top8: Int((Double(top8) / Double(iterations) * 100).rounded()),
            midTable: Int((Double(mid) / Double(iterations) * 100).rounded()),
            relegation: Int((Double(rel) / Double(iterations) * 100).rounded()),
            expectedPoints: expPoints,
            expectedPosition: expPosition
        )
    }
}
