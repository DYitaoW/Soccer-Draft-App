/// CupKnockoutModels.swift
///
/// State and models that drive the cup knockout flow: the tournament phase
/// machine, round names, and round matchups.
import Foundation

/// The sequential phases a cup knockout tournament moves through in the UI.
enum CupKnockoutPhase {
    case drawing, intro, simulating, htBreak, legBreak, showingResults, end
}

/// The ordered names of the knockout rounds, playoffs through the final.
let knockoutRoundNames = ["Knockout Playoffs", "Round of 16", "Quarter-finals", "Semi-finals", "Final"]

/// A single knockout pairing showing both leg scores and the aggregate winner.
struct RoundMatchup: Identifiable {
    let id = UUID()
    let teamA: CupTeam
    let teamB: CupTeam
    let leg1ScoreA: Int?
    let leg1ScoreB: Int?
    let leg2ScoreA: Int?
    let leg2ScoreB: Int?
    let winner: CupTeam?
    let isPlayerMatch: Bool

    /// True once the first leg has been played (leg 1 scores are set).
    var isComplete: Bool {
        leg1ScoreA != nil
    }

    /// The total aggregate score as a "home-away" string, treating missing
    /// second-leg scores as zero. Empty string if leg 1 has not been played.
    var aggregateScore: String {
        guard let l1a = leg1ScoreA, let l1b = leg1ScoreB else { return "" }
        let l2a = leg2ScoreA ?? 0
        let l2b = leg2ScoreB ?? 0
        let totalA = l1a + l2a
        let totalB = l1b + l2b
        return "\(totalA)-\(totalB)"
    }
}
