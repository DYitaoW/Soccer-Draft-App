/// KnockoutCommentary.swift
///
/// Reusable text generation for knockout match commentary: random match
/// updates, goal build-up descriptions, and formatted goal/card summaries.
import Foundation

/// Builds human-readable commentary strings for simulated knockout matches.
enum KnockoutCommentary {
    /// Produces a random neutral commentary line for one team using its
    /// players' names. Player lists fall back to generated squad names when
    /// empty. Returns an empty string if no players are available.
    /// - Parameters:
    ///   - isHome: True to commentate on the home team, false for the away team.
    static func generateRandom(minute: Int, home: CupTeam, away: CupTeam, hPlayers: [String], aPlayers: [String], isHome: Bool) -> String {
        let teamName = isHome ? home.name : away.name
        let players = isHome ? (hPlayers.isEmpty ? SimulatedKnockoutLeg.squadNames(for: teamName, count: 11) : hPlayers) : (aPlayers.isEmpty ? SimulatedKnockoutLeg.squadNames(for: teamName, count: 11) : aPlayers)
        guard let p1 = players.randomElement() else { return "" }

        let templates: [String] = [
            "\(p1) drives forward with pace",
            "\(p1) sprays a long ball out wide",
            "\(p1) cuts inside and shoots - just over!",
            "\(p1) wins a header in midfield",
            "\(p1) with a sharp turn, beats his marker",
            "\(p1) slides in to break up the attack",
            "\(p1) whips in a dangerous cross - cleared!",
            "\(p1) takes a shot from distance - wide!",
            "\(p1) holds up the play, waiting for support",
            "\(p1) with a clever backheel",
            "\(p1) launches a counter-attack",
            "\(p1) rises highest to head clear",
            "\(p1) charges down the wing",
            "\(p1) plays a quick one-two",
            "\(p1) with a crunching tackle!",
            "\(p1) curls a free kick - just past the post!",
            "\(p1) with a lofted pass over the defense",
            "\(p1) nutmegs his marker and surges forward",
            "\(p1) shields the ball well, drawing a foul",
            "\(p1) with a last-ditch sliding challenge",
            "\(p1) steps up and intercepts the pass",
            "\(p1) rattles the crossbar from 25 yards!",
            "\(p1) with a perfectly timed run, but the pass is overcooked",
            "\(p1) backheels it into the path of a teammate",
            "\(p1) goes down under pressure - no penalty says the ref",
            "\(p1) drills a low shot - saved by the keeper!",
            "\(p1) with a towering header from the corner - wide!",
            "\(p1) reads the game superbly and cuts out the danger",
            "\(p1) with a mazy dribble past two defenders",
            "\(p1) tries his luck from distance - straight at the keeper",
            "\(p1) robs the defender and bursts into the box",
            "\(p1) with a raking pass to switch the play",
            "\(p1) floats in a delightful cross - headed clear",
            "\(p1) turns his man inside out on the wing",
            "\(p1) unleashes a thunderous volley - just wide!",
            "\(p1) with a tactical foul to stop the counter",
            "\(p1) clips the ball first time to a runner",
        ]

        if let p2 = players.filter({ $0 != p1 }).randomElement(), Bool.random() {
            let passTemplates: [String] = [
                "\(p1) slips the ball through to \(p2)",
                "\(p1) finds \(p2) with a pinpoint pass",
                "\(p1) flicks it on to \(p2)",
                "\(p2) collects \(p1)'s pass and drives forward",
                "\(p1) picks out \(p2) in space",
                "\(p1) releases \(p2) with a perfectly weighted through ball",
                "\(p1) and \(p2) exchange a sharp one-two",
                "\(p1) dinks the ball over the top for \(p2) to chase",
                "\(p1) cuts it back to \(p2) on the edge of the box",
                "\(p1) drills a low cross to \(p2)",
                "\(p1) squares it to \(p2) first time",
                "\(p1) lobs it forward to \(p2), who brings it down well",
            ]
            return "\(teamName) - \(passTemplates.randomElement()!)"
        }

        return "\(teamName) - \(templates.randomElement()!)"
    }

    /// Describes the move that led to a goal, naming a passer and the scorer.
    /// - Parameter goal: The goal event being described.
    /// - Returns: A commentary string, or an empty string if no passer exists.
    static func generateBuildUp(minute: Int, goal: GoalEvent, home: CupTeam, away: CupTeam, hPlayers: [String], aPlayers: [String]) -> String {
        let isHomeGoal = goal.teamId == home.id
        let teamName = isHomeGoal ? home.name : away.name
        let players = isHomeGoal ? (hPlayers.isEmpty ? SimulatedKnockoutLeg.squadNames(for: teamName, count: 11) : hPlayers) : (aPlayers.isEmpty ? SimulatedKnockoutLeg.squadNames(for: teamName, count: 11) : aPlayers)
        let others = players.filter { $0 != goal.scorer }
        guard let passer = others.randomElement() else { return "" }

        let templates: [String] = [
            "\(passer) threads a brilliant ball through to \(goal.scorer)",
            "\(passer) dribbles into the box and pulls it back to \(goal.scorer)",
            "\(goal.scorer) bursts into the box to meet \(passer)'s cross",
            "\(passer) lifts a perfectly weighted pass to \(goal.scorer)",
            "\(passer) slips it through the gap - \(goal.scorer) is onto it!",
            "\(goal.scorer) makes a clever run - \(passer) finds him!",
            "\(passer) clips the ball over the top to \(goal.scorer)",
            "\(goal.scorer) peels off his marker - \(passer) delivers!",
            "\(passer) swings in a corner - \(goal.scorer) rises!",
            "\(goal.scorer) spins his defender - \(passer) plays him in!",
            "\(passer) slides a perfectly weighted through ball - \(goal.scorer) finishes!",
            "\(goal.scorer) holds off his man and \(passer) picks him out",
            "\(passer) with a clever dummy - \(goal.scorer) is through on goal!",
            "\(passer) picks up the loose ball and feeds \(goal.scorer)",
            "\(goal.scorer) drifts into space - \(passer) finds him and he scores!",
        ]
        return "\(teamName) - \(templates.randomElement()!)"
    }

    /// Formats a goal as a one-line match report, annotating penalties, own
    /// goals, assists, and extra-time goals.
    static func goalDescription(_ g: GoalEvent) -> String {
        var text = "GOAL! \(g.scorer)"
        if g.isPenalty { text += " (P)" }
        if g.isOwnGoal { text += " (OG)" }
        if let a = g.assist { text += " - assist \(a)" }
        if g.isExtraTime { text += " [ET]" }
        return text
    }

    /// Formats a card as a one-line report, distinguishing a second yellow
    /// (dismissal) from an ordinary yellow card.
    static func cardDescription(_ c: CardEvent) -> String {
        if c.isSecondYellow { return "\(c.playerName) sent off (second yellow)" }
        return "\(c.playerName) shown a yellow card"
    }
}
