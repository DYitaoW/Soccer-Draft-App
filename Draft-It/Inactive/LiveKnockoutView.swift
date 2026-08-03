/// LiveKnockoutView.swift
///
/// Animated, real-time knockout match using the advanced match engine: animated pitch,
/// momentum, half-time/extra-time breaks with managerial decisions, live stats and feed,
/// and in-game substitutions. Reports the final `SimulatedKnockoutLeg` via `onComplete`.
import SwiftUI

/// Hosts a single live match (`LiveKnockoutMatch`) between two cup teams, driving the
/// animated field, breaks, and subs overlay, and calling `onComplete` with the finished
/// leg so the parent can continue the two-legged tie. Requires both teams and their
/// player name lists up front.
struct LiveKnockoutView: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    let isFinal: Bool
    let homePlayerNames: [String]
    let awayPlayerNames: [String]
    let homeMentality: MatchMentality
    let awayMentality: MatchMentality
    let playerIsHome: Bool
    let onComplete: (SimulatedKnockoutLeg) -> Void

    @StateObject private var match: LiveKnockoutMatch
    @State private var htMentality: MatchMentality
    @State private var etMentality: MatchMentality
    @State private var htTeamTalk: TeamTalkEffect = .none
    @State private var etTeamTalk: TeamTalkEffect = .none
    @State private var showSubView = false

    /// Wires the owned `LiveKnockoutMatch` and the half-time / extra-time mentality states.
    init(homeTeam: CupTeam, awayTeam: CupTeam, isFinal: Bool, homePlayerNames: [String], awayPlayerNames: [String], homeMentality: MatchMentality = .balanced, awayMentality: MatchMentality = .balanced, playerIsHome: Bool = true, onComplete: @escaping (SimulatedKnockoutLeg) -> Void) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.isFinal = isFinal
        self.homePlayerNames = homePlayerNames
        self.awayPlayerNames = awayPlayerNames
        self.homeMentality = homeMentality
        self.awayMentality = awayMentality
        self.playerIsHome = playerIsHome
        self.onComplete = onComplete
        _match = StateObject(wrappedValue: LiveKnockoutMatch(homeTeam: homeTeam, awayTeam: awayTeam, isFinal: isFinal, homePlayerNames: homePlayerNames, awayPlayerNames: awayPlayerNames, homeMentality: homeMentality, awayMentality: awayMentality))
        _htMentality = State(initialValue: playerIsHome ? homeMentality : awayMentality)
        _etMentality = State(initialValue: playerIsHome ? homeMentality : awayMentality)
    }

    /// Renders the scoreboard and, depending on match state, the finished view, the
    /// half-time/extra-time break, or the live pitch with control bar, stats, and feed.
    /// Starts the match clock on appear.
    var body: some View {
        VStack(spacing: 0) {
            LiveMatchScoreboard(homeTeam: homeTeam, awayTeam: awayTeam, match: match)
            if match.isFinished {
                LiveKnockoutFinishedView(homeTeam: homeTeam, awayTeam: awayTeam, match: match, onComplete: { onComplete(match.toSimulatedKnockoutLeg()) })
            } else if match.isHT || match.isETHalf {
                LiveMatchBreakView(
                    homeTeam: homeTeam,
                    awayTeam: awayTeam,
                    match: match,
                    mentality: Binding(get: { mentalityForCurrentHalf }, set: { mentalityForCurrentHalf = $0 }),
                    teamTalk: Binding(get: { teamTalkForCurrentHalf }, set: { teamTalkForCurrentHalf = $0 }),
                    teamTalkChosen: Binding(get: { teamTalkChosenForCurrentHalf }, set: { teamTalkChosenForCurrentHalf = $0 }),
                    onContinue: {
                        if playerIsHome {
                            match.homeMentality = mentalityForCurrentHalf
                            match.homeTeamTalk = teamTalkForCurrentHalf
                        } else {
                            match.awayMentality = mentalityForCurrentHalf
                            match.awayTeamTalk = teamTalkForCurrentHalf
                        }
                        if match.isHT { match.isHT = false }
                        if match.isETHalf { match.isETHalf = false }
                        match.resume()
                    }
                )
            } else {
                MomentumBar(homeName: homeTeam.name, awayName: awayTeam.name, momentum: match.homeMomentum)
                MatchFieldView(
                    homeTeam: homeTeam, awayTeam: awayTeam,
                    homeMentality: match.homeMentality, awayMentality: match.awayMentality,
                    ballX: match.ballX, ballY: match.ballY,
                    homePlayers: match.homePlayers, awayPlayers: match.awayPlayers,
                    playerPositions: match.playerPositions,
                    action: match.visualAction, actionTeamId: match.actionTeamId
                )
                .padding(.horizontal, 12)
                .padding(.top, 4)
                LiveMatchControlBar(match: match, onSubs: {
                    match.pause()
                    showSubView = true
                })
                LiveMatchStatsRow(match: match)
                LiveMatchFeed(homeTeam: homeTeam, awayTeam: awayTeam, match: match)
            }
        }
        .overlay {
            if showSubView {
                LiveMatchSubOverlay(homeTeam: homeTeam, match: match, onClose: {
                    showSubView = false
                    match.resume()
                })
            }
        }
        .onAppear { match.start() }
    }

    /// The mentality the player currently edits, selected from the extra-time or
    /// half-time state depending on which break is showing.
    private var mentalityForCurrentHalf: MatchMentality {
        get { match.isET ? etMentality : htMentality }
        nonmutating set {
            if match.isET { etMentality = newValue } else { htMentality = newValue }
        }
    }

    /// The team talk the player currently edits, from the extra-time or half-time
    /// state depending on which break is showing.
    private var teamTalkForCurrentHalf: TeamTalkEffect {
        get { match.isET ? etTeamTalk : htTeamTalk }
        nonmutating set {
            if match.isET { etTeamTalk = newValue } else { htTeamTalk = newValue }
        }
    }

    /// Whether a team talk has been chosen for the current break. The picker
    /// writes `true` after a choice; the selection itself is stored in `teamTalk`.
    private var teamTalkChosenForCurrentHalf: Bool {
        get { teamTalkForCurrentHalf != .none }
        nonmutating set { }
    }
}

#Preview {
    LiveKnockoutView(
        homeTeam: CupTeam(name: "Your Team", offense: 85, midfield: 83, defense: 82, pot: 1),
        awayTeam: CupTeam(name: "Barcelona", offense: 94, midfield: 90, defense: 85, pot: 1),
        isFinal: true,
        homePlayerNames: ["Player 1", "Player 2", "Player 3", "Player 4", "Player 5", "Player 6"],
        awayPlayerNames: ["A 1", "A 2", "A 3", "A 4", "A 5", "A 6"],
        onComplete: { _ in }
    )
}
