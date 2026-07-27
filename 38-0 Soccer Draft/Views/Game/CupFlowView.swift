import SwiftUI

struct CupFlowView: View {
    let competitionType: CupCompetitionType
    @Environment(\.colorScheme) private var colorScheme
    let overall: Int
    let attack: Int
    let midfield: Int
    let defense: Int
    let seasonResult: SeasonSimulationResult?
    let userPlayerNames: [String]
    let onRestart: () -> Void

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

    private let playerTeamId = UUID()

    private var playerTeam: CupTeam {
        cupTeams.first { $0.id == playerTeamId } ?? CupModels.playerTeam
    }

    enum CupPhase {
        case draw, leaguePhase, knockout, end
    }

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
                onStart: { drawnFixtures, _ in
                    mergeDrawFixtures(drawnFixtures)
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
                onComplete: { updatedStandings, playerPosition in
                    standings = updatedStandings
                    proceedToKnockout()
                }
            )
        case .knockout:
            CupKnockoutView(
                competitionType: competitionType,
                playerTeamId: playerTeamId,
                cupTeams: cupTeams,
                standings: standings,
                knockoutRounds: knockoutRounds,
                userPlayerNames: userPlayerNames,
                startingRoundIndex: startingRoundIndex,
                onComplete: { eliminated, eliminatedInRound, champion in
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
                    }
                    withAnimation { phase = .end }
                }
            )
        case .end:
            CupEndView(
                competitionType: competitionType,
                seasonResult: seasonResult,
                cupStandings: standings,
                eliminatedIn: eliminatedIn,
                isChampion: isChampion,
                onRestart: onRestart
            )
            }
        }
    }

    private func setupCup() {
        var teams = CupModels.teams(for: competitionType)
        let pots = Set(teams.map { $0.pot }).sorted()
        guard let randomPot = pots.randomElement() else { cupTeams = teams; return }
        let potIndices = teams.indices.filter { teams[$0].pot == randomPot }
        guard !potIndices.isEmpty else { cupTeams = teams; return }
        let replaceIdx = potIndices.randomElement()!
        let replaced = teams[replaceIdx]
        let playerTeam = CupTeam(id: playerTeamId, name: "Your Team",
                                 offense: attack, midfield: midfield, defense: defense, pot: replaced.pot)
        teams[replaceIdx] = playerTeam
        cupTeams = teams

        let fixtures = CupModels.generateFullSchedule(teams: teams)
        allFixtures = fixtures
        standings = CupModels.computeStandings(from: fixtures, allTeams: teams)
    }

    private func twoLegMatch(teamA: CupTeam, teamB: CupTeam, round: String) -> CupKnockoutMatch {
        let (s1a, s1b) = CupModels.simulateCupMatch(home: teamA, away: teamB)
        let (s2a, s2b) = CupModels.simulateCupMatch(home: teamB, away: teamA)
        return CupKnockoutMatch(
            id: UUID(), round: round,
            teamA: teamA, teamB: teamB,
            leg1Home: teamA, leg1ScoreA: s1a, leg1ScoreB: s1b,
            leg2ScoreA: s2a, leg2ScoreB: s2b
        )
    }

    private func nextRoundWinners(from matches: [CupKnockoutMatch]) -> [CupTeam] {
        matches.map {
            if $0.teamA.id == playerTeamId || $0.teamB.id == playerTeamId {
                return playerTeam
            }
            return $0.winner ?? $0.teamA
        }
    }

    private func generateKnockoutBracket() -> [[CupKnockoutMatch]] {
        let totalTeams = cupTeams.count
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

    private func mergeDrawFixtures(_ drawn: [CupFixture]) {
        guard !drawn.isEmpty else { return }
        var updated = allFixtures
        updated.removeAll { $0.homeTeam.id == playerTeamId || $0.awayTeam.id == playerTeamId }
        for var f in drawn {
            let (h, a) = CupModels.simulateCupMatch(home: f.homeTeam, away: f.awayTeam)
            f.homeScore = h; f.awayScore = a
            updated.append(f)
        }
        allFixtures = updated
        standings = CupModels.computeStandings(from: allFixtures, allTeams: cupTeams)
    }

    private func proceedToKnockout() {
        guard let playerPos = standings.firstIndex(where: { $0.team.id == playerTeamId }) else { return }
        let position = playerPos + 1

        let totalTeams = cupTeams.count
        let qualifiedCutoff = min(totalTeams, 24)
        guard position <= qualifiedCutoff else {
            eliminated = true
            eliminatedIn = "Group Stage (finished \(position) of \(totalTeams))"
            withAnimation { phase = .end }
            return
        }

        knockoutRounds = generateKnockoutBracket()

        startingRoundIndex = position <= 8 ? 1 : 0

        currentRound = ["Knockout Playoffs", "Round of 16", "Quarter-finals", "Semi-finals", "Final"][startingRoundIndex]
        withAnimation { phase = .knockout }
    }
}

#Preview {
    CupFlowView(
        competitionType: .superLeague,
        overall: 84,
        attack: 85,
        midfield: 83,
        defense: 82,
        seasonResult: SeasonSimulationResult(
            matches: [],
            standings: [],
            playerTeamId: UUID(),
            projectedPosition: 8
        ),
        userPlayerNames: [],
        onRestart: {}
    )
}
