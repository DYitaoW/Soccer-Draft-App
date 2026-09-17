/// CupFlowView.swift
///
/// Orchestrator for a full cup competition (e.g. Super League): draw, league phase,
/// league-complete recap, playable knockout rounds, and the final end screen.
/// Owns the season-long cup state and reports the player's final outcome back to
/// GameView via `onRestart`.
import SwiftUI

/// Top-level state machine for a cup campaign. Drives CupDrawView -> CupSeasonView ->
/// CupLeagueCompleteView -> CupKnockoutView -> SeasonCompleteView based on `phase`.
struct CupFlowView: View {
    let competitionType: CupCompetitionType
    @Environment(\.colorScheme) private var colorScheme
    let overall: Int
    let attack: Int
    let midfield: Int
    let defense: Int
    let goalkeeper: Int
    let seasonResult: SeasonSimulationResult?
    let userPlayerNames: [String]
    let gameMode: GameMode
    let formation: Formation
    let assignedPlayers: [Int: Player]
    let substitutes: [Player?]
    let manager: Manager?
    let regularDraftId: UUID?
    let onRestart: () -> Void
    var playerGameState: GameState? = nil

    @AppStorage("dynastyMode") private var dynastyMode = true

    @State private var phase: CupPhase = .draw
    @State private var cupTeams: [CupTeam] = []
    @State private var allFixtures: [CupFixture] = []
    @State private var standings: [CupStanding] = []
    @State private var knockoutRounds: [[CupKnockoutMatch]] = []
    @State private var currentRound = "Knockout Playoffs"
    @State private var startingRoundIndex = 0
    @State private var eliminated = false
    @State private var isChampion = false
    @State private var eliminatedIn: String? = nil
    @State private var showEndScreen = false
    @State private var newlyUnlockedAchievements: [Achievement] = []

    private let playerTeamId = UUID()

    /// The cup entry representing the user's squad, looked up by `playerTeamId`.
    private var playerTeam: CupTeam {
        cupTeams.first { $0.id == playerTeamId } ?? CupModels.playerTeam
    }

    /// All scheduled league fixtures that involve the player's team.
    private var playerFixturesFromSchedule: [CupFixture] {
        allFixtures.filter { $0.homeTeam.id == playerTeamId || $0.awayTeam.id == playerTeamId }
    }

    /// Regular-season player stats from the draft history entry, if a `regularDraftId` is set.
    private var regularPlayerStats: [PlayerSeasonStats] {
        guard let id = regularDraftId else { return [] }
        return DraftHistory.loadAll().first { $0.id == id }?.playerStats ?? []
    }

    /// Super-league player stats from the draft history entry, if a `regularDraftId` is set.
    private var superPlayerStats: [PlayerSeasonStats] {
        guard let id = regularDraftId else { return [] }
        return DraftHistory.loadAll().first { $0.id == id }?.superLeaguePlayerStats ?? []
    }

    /// Merged regular + super-league player stats, sorted by goals then assists, for the end screen.
    private var allPlayerStats: [PlayerSeasonStats] {
        let reg = regularPlayerStats
        let sup = superPlayerStats
        var dict: [String: PlayerSeasonStats] = [:]
        for s in reg { dict[s.playerName] = PlayerSeasonStats(playerName: s.playerName, goals: s.goals, assists: s.assists) }
        for s in sup {
            if dict[s.playerName] == nil { dict[s.playerName] = PlayerSeasonStats(playerName: s.playerName) }
            dict[s.playerName]!.goals += s.goals
            dict[s.playerName]!.assists += s.assists
        }
        return dict.values.sorted { $0.goals > $1.goals || ($0.goals == $1.goals && $0.assists > $1.assists) }
    }

    /// Phases of a cup campaign. Transitions: `.draw` -> `.leaguePhase` ->
    /// `.leagueComplete` -> `.knockout` -> `.end`; if the player fails to qualify
    /// from the league phase, flow jumps straight to `.end`.
    enum CupPhase {
        case draw, leaguePhase, leagueComplete, knockout, end
    }

    /// Routes between the cup sub-views based on `phase` and records results (standings,
    /// super-league stats, dynasty saves) when phases complete.
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()
            switch phase {
        case .draw:
            CupDrawView(
                competitionType: competitionType,
                cupTeams: cupTeams,
                playerTeamId: playerTeamId,
                playerFixtures: playerFixturesFromSchedule,
                onStart: { drawnFixtures, _ in
                    withAnimation { phase = .leaguePhase }
                }
            )
            .onAppear { setupCup() }
        case .leaguePhase:
            CupSeasonView(
                competitionType: competitionType,
                allFixtures: allFixtures,
                standings: standings,
                playerTeamId: playerTeamId,
                cupTeams: cupTeams,
                userPlayerNames: userPlayerNames,
                assignedPlayers: assignedPlayers,
                onComplete: { updatedStandings, playerPosition in
                    standings = updatedStandings
                    let playerFixtures = allFixtures.filter { fixture in
                        fixture.homeTeam.id == playerTeamId || fixture.awayTeam.id == playerTeamId
                    }
                    let scores: [Int] = playerFixtures.map { fixture in
                        if fixture.homeTeam.id == playerTeamId {
                            return fixture.homeScore
                        } else {
                            return fixture.awayScore
                        }
                    }
                    let totalGF = scores.reduce(0, +)
                    let statDict = CupGoalDistributor.distribute(totalGoals: totalGF, userPlayerNames: userPlayerNames, assignedPlayers: assignedPlayers)
                    if let draftId = self.regularDraftId {
                        let statValues = Array(statDict.values)
                        let sortedStats: [PlayerSeasonStats]
                        sortedStats = statValues.sorted { lhs, rhs in
                            if lhs.goals > rhs.goals { return true }
                            if lhs.goals < rhs.goals { return false }
                            return lhs.assists > rhs.assists
                        }
                        DraftHistory.update(draftId) { entry in
                            entry.superLeaguePlayerStats = sortedStats
                        }
                    }
                    withAnimation { phase = .leagueComplete }
                }
            )
        case .leagueComplete:
            CupLeagueCompleteView(
                cupTeams: cupTeams,
                standings: standings,
                playerTeamId: playerTeamId,
                onContinue: { proceedToKnockout() }
            )
        case .knockout:
            CupKnockoutView(
                competitionType: competitionType,
                playerTeamId: playerTeamId,
                cupTeams: cupTeams,
                standings: standings,
                knockoutRounds: knockoutRounds,
                userPlayerNames: userPlayerNames,
                userSubstituteNames: [],
                startingRoundIndex: startingRoundIndex,
                onComplete: { eliminated, eliminatedInRound, champion, playerStats in
                    self.eliminated = eliminated
                    self.eliminatedIn = eliminatedInRound
                    self.isChampion = champion
                    if let ps = self.standings.first(where: { $0.team.id == self.playerTeamId }) {
                        var stats = CareerStats.load()
                        let position = self.standings.firstIndex { $0.team.id == self.playerTeamId }.map { $0 + 1 } ?? 0
                        let round = SuperLeagueRound.from(eliminatedIn: eliminatedInRound, isChampion: champion, leaguePosition: position)
                        stats.recordSuperLeagueSeason(
                            wins: ps.wins,
                            points: ps.points,
                            goalsFor: ps.goalsFor,
                            goalsAgainst: ps.goalsAgainst,
                            round: round
                        )
                        stats.save()
                        if let draftId = self.regularDraftId {
                            DraftHistory.update(draftId) { entry in
                                let groupStats = entry.superLeaguePlayerStats
                                let merged = Self.mergePlayerStats(group: groupStats, knockout: playerStats)
                                entry.superLeagueRound = round
                                entry.superLeagueRecord = SeasonRecord(wins: ps.wins, draws: ps.draws, losses: ps.losses)
                                entry.superLeaguePlayerStats = merged
                            }
                        }
                        if self.dynastyMode && champion {
                            let seasonCount = UserDefaults.standard.integer(forKey: "dynastySeasonCount") + 1
                            UserDefaults.standard.set(seasonCount, forKey: "dynastySeasonCount")
                            DynastySave.save(
                                assignedPlayers: self.assignedPlayers,
                                substitutes: self.substitutes,
                                formation: self.formation,
                                manager: self.manager,
                                seasonCount: seasonCount,
                                gameMode: self.gameMode,
                                transferBudgetAmount: self.playerGameState?.transferBudget ?? 100
                            )
                        }
                        let leagueStandings = self.seasonResult?.standings ?? []
                        let draftedPlayers = self.assignedPlayers.values.map { $0 } + self.substitutes.compactMap { $0 }
                        let context = SeasonAchievementContext(
                            teamOverall: DraftHistory.loadAll().first { $0.id == self.regularDraftId }?.teamOverall ?? self.overall,
                            bestDraftedPlayerRating: self.assignedPlayers.values.map(\.ovrRating).max() ?? 0,
                            managerRating: self.manager?.rating ?? 0,
                            leaguePosition: self.seasonResult?.playerPosition ?? 0,
                            leagueRecord: self.seasonResult?.playerStanding.map { SeasonRecord(wins: $0.wins, draws: $0.draws, losses: $0.losses) },
                            leagueGoalsFor: self.seasonResult?.playerStanding?.goalsFor ?? 0,
                            leagueGoalsAgainst: self.seasonResult?.playerStanding?.goalsAgainst ?? 0,
                            leagueTeamCount: leagueStandings.count,
                            leagueMaxGoalsFor: leagueStandings.map(\.goalsFor).max() ?? 0,
                            leagueMinGoalsFor: leagueStandings.map(\.goalsFor).min() ?? 0,
                            leagueMaxGoalsAgainst: leagueStandings.map(\.goalsAgainst).max() ?? 0,
                            leagueMinGoalsAgainst: leagueStandings.map(\.goalsAgainst).min() ?? 0,
                            leagueTopScorerGoals: self.regularPlayerStats.map(\.goals).max() ?? 0,
                            leagueTopAssists: self.regularPlayerStats.map(\.assists).max() ?? 0,
                            superLeagueRound: round,
                            superLeagueChampion: champion,
                            backToBackChampion: AchievementStore.backToBackChampion(position: self.seasonResult?.playerPosition ?? 0),
                            draftedPlayers: draftedPlayers,
                            starterLeagues: self.assignedPlayers.values.map(\.league)
                        )
                        self.newlyUnlockedAchievements = AchievementStore.evaluateSeason(context)
                    }
                    withAnimation { phase = .end }
                }
            )
        case .end:
            SeasonCompleteView(
                seasonResult: seasonResult,
                cupStandings: standings,
                competitionType: competitionType,
                eliminatedIn: eliminatedIn,
                isChampion: isChampion,
                playerStats: allPlayerStats,
                regularPlayerStats: regularPlayerStats,
                superPlayerStats: superPlayerStats,
                onRestart: { SavedGame.clear(); onRestart() },
                onContinueDynasty: dynastyMode && isChampion ? { SavedGame.clear(); onRestart() } : nil,
                newlyUnlocked: newlyUnlockedAchievements
            )
            }
        }
    }

    /// Combines league-phase and knockout player stats, summing goals/assists per player
    /// and sorting by goals then assists.
    /// - Parameters:
    ///   - group: Stats accumulated during the league phase.
    ///   - knockout: Stats accumulated during the knockout rounds.
    /// - Returns: Merged, sorted player stats.
    private static func mergePlayerStats(group: [PlayerSeasonStats], knockout: [PlayerSeasonStats]) -> [PlayerSeasonStats] {
        var dict: [String: PlayerSeasonStats] = [:]
        for s in group { dict[s.playerName] = s }
        for s in knockout {
            if var existing = dict[s.playerName] {
                existing.goals += s.goals
                existing.assists += s.assists
                dict[s.playerName] = existing
            } else {
                dict[s.playerName] = s
            }
        }
        return dict.values.sorted { $0.goals > $1.goals || ($0.goals == $1.goals && $0.assists > $1.assists) }
    }

    /// Builds the cup team list by swapping one random AI pot team for the player's
    /// custom team, then generates the full league schedule and initial standings.
    private func setupCup() {
        var teams = CupModels.teams(for: competitionType)
        let pots = Set(teams.map { $0.pot }).sorted()
        guard let randomPot = pots.randomElement() else { cupTeams = teams; return }
        let potIndices = teams.indices.filter { teams[$0].pot == randomPot }
        guard !potIndices.isEmpty else { cupTeams = teams; return }
        let replaceIdx = potIndices.randomElement()!
        let replaced = teams[replaceIdx]

        // Apply player OVR boost/penalty based on selected game mode
        let playerBoost = gameMode.playerBoost
        let playerTeam = CupTeam(id: playerTeamId, name: customTeamName(),
                                 offense: max(1, attack + playerBoost),
                                 midfield: max(1, midfield + playerBoost),
                                 defense: max(1, defense + playerBoost),
                                 goalkeeper: max(1, goalkeeper + playerBoost),
                                 pot: replaced.pot)
        teams[replaceIdx] = playerTeam

        // Apply OVR boost to all AI teams based on game mode (Super League is slightly harder)
        // plus Dynasty mode progress boost if active.
        let baseBoost = gameMode.opponentBoost
        let cupOpponentBoost = baseBoost >= 0 ? baseBoost + 1 : baseBoost - 1
        let dynastyBoost = dynastyMode ? min(6, UserDefaults.standard.integer(forKey: "dynastySeasonCount")) : 0
        let totalOpponentBoost = cupOpponentBoost + dynastyBoost
        if totalOpponentBoost != 0 {
            teams = teams.map { team in
                if team.id == playerTeamId { return team }
                return CupTeam(id: team.id, name: team.name,
                               offense: max(1, team.offense + totalOpponentBoost),
                               midfield: max(1, team.midfield + totalOpponentBoost),
                               defense: max(1, team.defense + totalOpponentBoost),
                               goalkeeper: max(1, team.goalkeeper + totalOpponentBoost),
                               pot: team.pot)
            }
        }

        cupTeams = teams

        let fixtures = CupModels.generateFullSchedule(teams: teams, playerBonus: 1.15)
        allFixtures = fixtures
        standings = CupModels.computeStandings(from: fixtures, allTeams: teams)
    }

    /// Simulates a two-legged knockout tie between two teams and returns the match record.
    private func twoLegMatch(teamA: CupTeam, teamB: CupTeam, round: String) -> CupKnockoutMatch {
        var homeWL1: (attack: Double, midfield: Double, defense: Double) = (0, 0, 0)
        var awayWL1: (attack: Double, midfield: Double, defense: Double) = (0, 0, 0)
        var homeWL2: (attack: Double, midfield: Double, defense: Double) = (0, 0, 0)
        var awayWL2: (attack: Double, midfield: Double, defense: Double) = (0, 0, 0)
        if let gs = playerGameState {
            if teamA.id == playerTeamId { homeWL1 = gs.weakLinkPenalties(vs: teamB) }
            if teamB.id == playerTeamId { awayWL1 = gs.weakLinkPenalties(vs: teamA) }
            if teamB.id == playerTeamId { homeWL2 = gs.weakLinkPenalties(vs: teamA) }
            if teamA.id == playerTeamId { awayWL2 = gs.weakLinkPenalties(vs: teamB) }
        }
        let (s1a, s1b) = CupModels.simulateCupMatch(home: teamA, away: teamB, homeWeakLinkPenalties: homeWL1, awayWeakLinkPenalties: awayWL1)
        let (s2a, s2b) = CupModels.simulateCupMatch(home: teamB, away: teamA, homeWeakLinkPenalties: homeWL2, awayWeakLinkPenalties: awayWL2)
        return CupKnockoutMatch(
            id: UUID(), round: round,
            teamA: teamA, teamB: teamB,
            leg1Home: teamA, leg1ScoreA: s1a, leg1ScoreB: s1b,
            leg2ScoreA: s2a, leg2ScoreB: s2b
        )
    }

    /// Resolves the winners of a round, always advancing the player's team when it
    /// is involved in a tie.
    private func nextRoundWinners(from matches: [CupKnockoutMatch]) -> [CupTeam] {
        matches.map {
            if $0.teamA.id == playerTeamId || $0.teamB.id == playerTeamId {
                return playerTeam
            }
            return $0.winner ?? $0.teamA
        }
    }

    /// Builds the full knockout bracket from league standings: top-8 teams seeded,
    /// next 8-16 teams in a knockout playoff, then Round of 16 through the Final.
    /// - Returns: Rounds of two-legged matches, or an empty array for small leagues.
    private func generateKnockoutBracket() -> [[CupKnockoutMatch]] {
        let totalTeams = cupTeams.count
        guard totalTeams > 8 else { return [] }
        let qualifiedCutoff = min(totalTeams, 24)

        let top8Teams = Array(standings.prefix(8).map { $0.team })
        let playoffTeams = standings[8..<qualifiedCutoff].map { $0.team }

        var rounds: [[CupKnockoutMatch]] = []

        if playoffTeams.count >= 16 {
            let seeded = Array(playoffTeams.prefix(8))
            let unseeded = Array(playoffTeams.suffix(8))
            let playoff: [CupKnockoutMatch] = (0..<8).map { i in
                twoLegMatch(teamA: seeded[i], teamB: unseeded[i], round: "Knockout Playoffs")
            }
            rounds.append(playoff)
        }

        var prevWinners: [CupTeam]
        if !rounds.isEmpty {
            prevWinners = nextRoundWinners(from: rounds[0])
        } else {
            prevWinners = []
        }

        if !top8Teams.isEmpty && !prevWinners.isEmpty {
            let r16: [CupKnockoutMatch] = (0..<8).map { i in
                twoLegMatch(teamA: top8Teams[i], teamB: prevWinners[i], round: "Round of 16")
            }
            rounds.append(r16)
            prevWinners = nextRoundWinners(from: r16)
        } else if !top8Teams.isEmpty {
            prevWinners = top8Teams
        }

        if prevWinners.count >= 8 {
            let qf: [CupKnockoutMatch] = stride(from: 0, to: 8, by: 2).map { i in
                twoLegMatch(teamA: prevWinners[i], teamB: prevWinners[i + 1], round: "Quarter-finals")
            }
            rounds.append(qf)
            prevWinners = nextRoundWinners(from: qf)
        }

        if prevWinners.count >= 4 {
            let sf: [CupKnockoutMatch] = stride(from: 0, to: 4, by: 2).map { i in
                twoLegMatch(teamA: prevWinners[i], teamB: prevWinners[i + 1], round: "Semi-finals")
            }
            rounds.append(sf)
            prevWinners = nextRoundWinners(from: sf)
        }

        if prevWinners.count >= 2 {
            let finalMatch = CupKnockoutMatch(
                id: UUID(), round: "Final",
                teamA: prevWinners[0], teamB: prevWinners[1],
                leg1Home: prevWinners[0], leg1ScoreA: 0, leg1ScoreB: 0,
                leg2ScoreA: 0, leg2ScoreB: 0
            )
            rounds.append([finalMatch])
        }

        return rounds
    }

    /// Determines the player's knockout starting point from their league position:
    /// top-8 enter the Round of 16, positions 9-24 enter the knockout playoff, and
    /// everyone else is eliminated immediately.
    private func proceedToKnockout() {
        guard let playerPos = standings.firstIndex(where: { $0.team.id == playerTeamId }) else { return }
        let position = playerPos + 1

        let totalTeams = cupTeams.count
        let qualifiedCutoff = min(totalTeams, 24)
        guard position <= qualifiedCutoff else {
            eliminated = true
            eliminatedIn = "Group Stage (finished \(position) of \(totalTeams))"
            recordSuperLeagueFailure()
            withAnimation { phase = .end }
            return
        }

        knockoutRounds = generateKnockoutBracket()

        startingRoundIndex = position <= 8 ? 1 : 0

        currentRound = ["Knockout Playoffs", "Round of 16", "Quarter-finals", "Semi-finals", "Final"][startingRoundIndex]
        withAnimation { phase = .knockout }
    }

    /// Distributes the player team's total league goals across the user's players.
    private func computeSuperPlayerStats(totalGoals: Int) -> [String: PlayerSeasonStats] {
        CupGoalDistributor.distribute(totalGoals: totalGoals, userPlayerNames: userPlayerNames, assignedPlayers: assignedPlayers)
    }

    /// Records the career/history entry when the player is eliminated in the group
    /// phase of the Super League, so the season records as a "League"/group finish
    /// rather than being left unset and displayed as "DNQ".
    private func recordSuperLeagueFailure() {
        guard let ps = standings.first(where: { $0.team.id == playerTeamId }) else { return }
        let position = standings.firstIndex { $0.team.id == playerTeamId }.map { $0 + 1 } ?? 0
        let round = SuperLeagueRound.from(eliminatedIn: eliminatedIn, isChampion: false, leaguePosition: position)
        var stats = CareerStats.load()
        stats.recordSuperLeagueSeason(
            wins: ps.wins, points: ps.points,
            goalsFor: ps.goalsFor, goalsAgainst: ps.goalsAgainst, round: round
        )
        stats.save()
        if let draftId = regularDraftId {
            DraftHistory.update(draftId) { entry in
                entry.superLeagueRound = round
                entry.superLeagueRecord = SeasonRecord(wins: ps.wins, draws: ps.draws, losses: ps.losses)
            }
        }
    }

}

#Preview {
    CupFlowView(
        competitionType: .superLeague,
        overall: 84,
        attack: 85,
        midfield: 83,
        defense: 82,
        goalkeeper: 82,
        seasonResult: SeasonSimulationResult(
            matches: [],
            standings: [],
            playerTeamId: UUID(),
            projectedPosition: 8
        ),
        userPlayerNames: [],
        gameMode: .normal,
        formation: GameData.formations[0],
        assignedPlayers: [:],
        substitutes: [],
        manager: nil,
        regularDraftId: nil,
        onRestart: {}
    )
}
