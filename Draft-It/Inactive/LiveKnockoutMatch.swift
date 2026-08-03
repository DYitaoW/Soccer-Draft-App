/// LiveKnockoutMatch.swift
///
/// A minute-by-minute, observable match engine that simulates possession,
/// shots, goals, cards, injuries, substitutions, extra time, and penalty
/// shootouts, while also animating ball and player positions on a pitch view.
import Foundation
import Combine
import CoreGraphics

/// A live, minute-by-minute knockout match engine. Each `tick` advances the
/// clock one minute and stochastically simulates possession, shots, goals,
/// cards, injuries, substitutions, penalties, momentum swings, and ball/player
/// movement for a pitch visualization. Publishable state drives SwiftUI views.
///
/// Requires `start()` (or `resume()`) to be called before minutes are ticked.
/// For finals, extra time and a penalty shootout are resolved automatically
/// when the aggregate score is level at 90 and 120 minutes respectively.
class LiveKnockoutMatch: ObservableObject {
    /// The home team for the match.
    let homeTeam: CupTeam
    /// The away team for the match.
    let awayTeam: CupTeam
    /// True when this is a final, enabling extra time and penalties.
    let isFinal: Bool
    /// The home side's tactical mentality, adjustable mid-match.
    var homeMentality: MatchMentality
    /// The away side's tactical mentality, adjustable mid-match.
    var awayMentality: MatchMentality
    /// The home side's half-time team talk, boosting their second half.
    var homeTeamTalk: TeamTalkEffect = .none
    /// The away side's half-time team talk, boosting their second half.
    var awayTeamTalk: TeamTalkEffect = .none

    /// The current match minute (1-90, 91-120 in extra time).
    @Published var currentMinute = 0
    /// Home goals scored in normal time.
    @Published var homeScore = 0
    /// Away goals scored in normal time.
    @Published var awayScore = 0
    /// Home goals scored in extra time.
    @Published var etHomeScore = 0
    /// Away goals scored in extra time.
    @Published var etAwayScore = 0
    /// Home goals scored in the penalty shootout.
    @Published var penaltyHome = 0
    /// Away goals scored in the penalty shootout.
    @Published var penaltyAway = 0
    /// True once the match (and any penalties) has concluded.
    @Published var isFinished = false
    /// True during the half-time break.
    @Published var isHT = false
    /// True during the extra-time half-time break.
    @Published var isETHalf = false
    /// Chronological log of goals, cards, injuries, substitutions, and commentary.
    @Published var events: [LiveMatchEvent] = []
    /// The home squad, including bench players, each tracking live status.
    @Published var homePlayers: [LiveMatchPlayer] = []
    /// The away squad, including bench players, each tracking live status.
    @Published var awayPlayers: [LiveMatchPlayer] = []
    /// Number of substitutions the home side has used.
    @Published var homeSubsUsed = 0
    /// Number of substitutions the away side has used.
    @Published var awaySubsUsed = 0
    /// Maximum substitutions allowed per team per match.
    let maxSubs = 3
    /// True while the engine is actively ticking minutes.
    @Published var isSimulating = false

    /// Total shots taken by the home side.
    @Published var homeShots = 0
    /// Total shots taken by the away side.
    @Published var awayShots = 0
    /// Home shots on target.
    @Published var homeShotsOnTarget = 0
    /// Away shots on target.
    @Published var awayShotsOnTarget = 0
    /// Home possession percentage, smoothed toward a rating-based equilibrium.
    @Published var homePossession: Double = 50
    /// Home yellow cards shown.
    @Published var homeYellowCards = 0
    /// Away yellow cards shown.
    @Published var awayYellowCards = 0
    /// Home red cards shown.
    @Published var homeRedCards = 0
    /// Away red cards shown.
    @Published var awayRedCards = 0
    /// Minutes of stoppage time added at the end of a half.
    @Published var stoppageTimeAdded = 0
    /// True while stoppage time minutes are being ticked.
    @Published var isStoppageTime = false
    /// The minute at which stoppage time ends.
    @Published var stoppageTimeEnd = 0
    /// The penalty shootout results, in kick order.
    @Published var penaltyKicks: [(teamIsHome: Bool, shooter: String, scored: Bool)] = []
    /// Home momentum in [-1, 1], drifting over time and swinging on goals.
    @Published var homeMomentum: Double = 0
    /// The ball's normalized horizontal pitch position (0-1).
    @Published var ballX: CGFloat = 0.5
    /// The ball's normalized vertical pitch position (0-1).
    @Published var ballY: CGFloat = 0.5
    /// The current dribble/pass/shot overlay drawn on the pitch, if any.
    @Published var visualAction: VisualAction = .none
    /// The team performing the current visual action, if any.
    @Published var actionTeamId: UUID?
    /// Multiplier on simulation speed; higher values tick faster.
    @Published var speedMultiplier: Double = 1.0
    /// Current normalized positions of on-pitch players, keyed by name.
    @Published var playerPositions: [String: CGPoint] = [:]
    /// Starting formation positions, used to pull players back to shape.
    private var initialPlayerPositions: [String: CGPoint] = [:]
    /// Formation role per player (0 = GK, 1 = forwards, higher = deeper).
    private var playerRoles: [String: Int] = [:]
    /// The ball's current velocity along the pitch's x-axis.
    private var ballVelocityX: CGFloat = 0
    /// The ball's current velocity along the pitch's y-axis.
    private var ballVelocityY: CGFloat = 0
    /// The phase of play driving ball and player movement between kickoffs,
    /// buildup play, shot flight, goal celebration, and out-of-play restarts.
    private var pitchPhase: Phase = .buildup
    /// Ticks remaining in the current `pitchPhase` (shots/restarts last a few ticks).
    private var phaseTicks = 0
    /// The team currently in possession during buildup play.
    private var possessingTeamId: UUID? = nil
    /// The dribbler's player name (buildup phase).
    private var ballCarrier: String? = nil
    /// The intended pass receiver's player name (buildup phase).
    private var passTarget: String? = nil
    /// True while the ball is flying toward `passTarget`.
    private var passInProgress = false
    /// The goal-mouth point a shot is currently flying toward.
    private var shotTarget = CGPoint(x: 0.98, y: 0.5)
    /// The restart point the ball is moving to after a denied shot.
    private var outTarget = CGPoint(x: 0.5, y: 0.5)
    /// The team that took the current shot.
    private var shotAttackingTeam: UUID? = nil
    /// Whether the current shot was on target (drives restart choice after).
    private var shotOnTarget = false
    /// True when the current shot crossed the line (goal celebration phase).
    private var goalCrossed = false

    /// Visual overlay shown on the pitch for the current action.
    enum VisualAction: Equatable {
        case none
        case dribble(from: CGPoint, to: CGPoint)
        case pass(from: CGPoint, to: CGPoint)
        case shot(from: CGPoint, to: CGPoint)
        case ballOut(to: CGPoint)
    }

    /// Internal phase machine driving ball and player motion: normal buildup
    /// (dribble/pass), shot flight toward a goal mouth, goal celebration,
    /// kickoff restart, and out-of-play restart.
    private enum Phase {
        case buildup
        case shot
        case goal
        case kickoff
        case ballOut
    }

    /// The home side's starting XI (and substitutes) names.
    let homePlayerNames: [String]
    /// The away side's starting XI (and substitutes) names.
    let awayPlayerNames: [String]

    /// Random per-match home form multiplier, fixed for the duration.
    private let homeForm: Double
    /// Random per-match away form multiplier, fixed for the duration.
    private let awayForm: Double
    /// Random home shot conversion probability, fixed for the duration.
    private let homeConversion: Double
    /// Random away shot conversion probability, fixed for the duration.
    private let awayConversion: Double
    /// Team currently applying sustained pressure, if any.
    private var pressureTeamId: UUID?
    /// Minute at which the current pressure period ends.
    private var pressureEnd = 0

    /// True once the engine has been paused or the match finished.
    private var cancelled = false
    /// Count of simulated minutes, used for possession tracking.
    private var possessionTicks = 0

    /// Sets up the match: rolls per-match form and conversion rates, builds
    /// both squads from player names (falling back to numbered players when
    /// empty), and lays out starting formation positions and roles.
    /// - Parameters:
    ///   - isFinal: True for finals, which can go to extra time and penalties.
    ///   - homePlayerNames: Home player names; empty builds a generic squad.
    ///   - awayPlayerNames: Away player names; empty builds a generic squad.
    init(homeTeam: CupTeam, awayTeam: CupTeam, isFinal: Bool, homePlayerNames: [String], awayPlayerNames: [String], homeMentality: MatchMentality = .balanced, awayMentality: MatchMentality = .balanced) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.isFinal = isFinal
        self.homeMentality = homeMentality
        self.awayMentality = awayMentality
        self.homePlayerNames = homePlayerNames
        self.awayPlayerNames = awayPlayerNames
        self.homeForm = Double.random(in: 0.88...1.12)
        self.awayForm = Double.random(in: 0.88...1.12)
        self.homeConversion = Double.random(in: 0.30...0.50)
        self.awayConversion = Double.random(in: 0.30...0.50)

        func makeSquad(_ names: [String]) -> [LiveMatchPlayer] {
            let ratings: [String: Int] = Dictionary(GameData.players.map { ($0.name, $0.ovrRating) }, uniquingKeysWith: { max($0, $1) })
            if names.isEmpty {
                return (1...23).map { LiveMatchPlayer(name: "Player \($0)", isOnPitch: $0 <= 11) }
            }
            var result: [LiveMatchPlayer] = []
            for (idx, name) in names.enumerated() {
                let rating = ratings[name] ?? 80
                result.append(LiveMatchPlayer(name: name, isOnPitch: idx < 11, rating: rating))
            }
            return result
        }
        homePlayers = makeSquad(homePlayerNames)
        awayPlayers = makeSquad(awayPlayerNames)

        func initPositions(_ players: [LiveMatchPlayer], isHome: Bool) {
            let rows: [[CGFloat]] = [[0.5], [0.25, 0.75], [0.15, 0.5, 0.85], [0.15, 0.38, 0.62, 0.85]]
            let onPitch = players.filter { $0.isOnPitch }
            let outfield = onPitch.filter { !$0.name.contains("GK") }
            let gk = onPitch.first { $0.name.contains("GK") }
            if let gk = gk {
                let gx: CGFloat = isHome ? 0.06 : 0.94
                let gy: CGFloat = 0.5
                let pos = CGPoint(x: gx, y: gy)
                playerPositions[gk.name] = pos
                initialPlayerPositions[gk.name] = pos
                playerRoles[gk.name] = 0
            }
            let count = outfield.count
            let rowCount = min(4, (count + 2) / 3)
            let baseY: CGFloat = 0.18
            for (i, player) in outfield.enumerated() {
                let rowIdx = min(i / 4, rowCount - 1)
                let rowPositions = rows[min(rowIdx, rows.count - 1)]
                let colIdx = i % rowPositions.count
                let xPos = rowPositions[colIdx]
                let px: CGFloat = isHome ? xPos * 0.42 + 0.08 : 0.5 + (1.0 - xPos) * 0.42
                let py = baseY + CGFloat(rowIdx) * 0.18
                let pos = CGPoint(x: px, y: py)
                playerPositions[player.name] = pos
                initialPlayerPositions[player.name] = pos
                let role: Int
                if rowIdx <= 0 { role = 1 }
                else if rowIdx == 1 { role = count > 6 ? 2 : 1 }
                else if rowIdx <= 2 { role = 2 }
                else { role = 3 }
                playerRoles[player.name] = role
            }
        }
        initPositions(homePlayers, isHome: true)
        initPositions(awayPlayers, isHome: false)
        possessingTeamId = homeTeam.id
        pickCarrier()
    }

    /// The final minute of the match: 120 for finals, otherwise 90.
    var maxMinute: Int { isFinal ? 120 : 90 }

    /// True during extra time, i.e. a final that is level at 90 minutes.
    var isET: Bool { isFinal && homeScore == awayScore && currentMinute >= 90 }

    /// Total goals for each side, combining normal and extra time.
    var aggregateScore: (home: Int, away: Int) {
        (homeScore + etHomeScore, awayScore + etAwayScore)
    }

    /// Begins the match. Must be called before minutes are ticked.
    func start() {
        cancelled = false
        isSimulating = true
        tick()
    }

    /// Pauses minute-by-minute simulation. Idempotent.
    func pause() { cancelled = true; isSimulating = false }
    /// Resumes a paused match unless it has already finished.
    func resume() {
        guard !isFinished else { return }
        cancelled = false
        isSimulating = true
        tick()
    }

    /// Schedules the next tick on the main queue, honoring speed multiplier
    /// and the user's fast-mode preference. No-ops once cancelled.
    private func scheduleNext() {
        guard !cancelled else { return }
        let fast = UserDefaults.standard.bool(forKey: "fastMode")
        let base = fast ? 5 : 120
        let delay = max(5, Int(Double(base) / speedMultiplier))
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            self?.tick()
        }
    }

    /// Advances the match by one minute, handling half-time/stoppage-time
    /// boundaries and finishing the match (resolving penalties in finals).
    private func tick() {
        guard !cancelled, !isFinished else { return }

        if (isHT || isETHalf) && !isStoppageTime {
            return
        }

        if isStoppageTime {
            currentMinute += 1
            if currentMinute > stoppageTimeEnd {
                isStoppageTime = false
                if currentMinute >= 90 && currentMinute < 120 && homeScore == awayScore && isFinal {
                    events.append(.commentary(minute: 90, text: "Extra time begins"))
                    scheduleNext()
                    return
                }
                if currentMinute >= 120 && aggregateScore.home == aggregateScore.away {
                    resolvePenalties()
                }
                if currentMinute >= 90 {
                    isFinished = true
                    isSimulating = false
                    events.append(.commentary(minute: currentMinute, text: "Full time"))
                }
                return
            }
            if currentMinute == stoppageTimeEnd { isHT = true }
            simulateMinute()
            scheduleNext()
            return
        }

        if currentMinute >= 120 && isFinal {
            if aggregateScore.home == aggregateScore.away {
                resolvePenalties()
            }
            isFinished = true
            isSimulating = false
            events.append(.commentary(minute: 120, text: "Full time"))
            return
        }

        if !isFinal && currentMinute >= 90 {
            stoppageTimeAdded = Int.random(in: 2...5)
            stoppageTimeEnd = 90 + stoppageTimeAdded
            isStoppageTime = true
            events.append(.commentary(minute: 90, text: "\(stoppageTimeAdded) minutes added"))
            scheduleNext()
            return
        }

        if isFinal && currentMinute >= 90 && homeScore != awayScore {
            stoppageTimeAdded = Int.random(in: 2...5)
            stoppageTimeEnd = 90 + stoppageTimeAdded
            isStoppageTime = true
            events.append(.commentary(minute: 90, text: "\(stoppageTimeAdded) minutes added"))
            scheduleNext()
            return
        }

        if isFinal && currentMinute == 90 && homeScore == awayScore && !events.contains(where: { ev in
            if case .commentary(_, let t) = ev { return t.contains("Extra time") }
            return false
        }) {
            events.append(.commentary(minute: 90, text: "Extra time begins"))
        }

        currentMinute += 1

        if currentMinute == 45 {
            stoppageTimeAdded = Int.random(in: 1...4)
            stoppageTimeEnd = 45 + stoppageTimeAdded
            isStoppageTime = true
            events.append(.commentary(minute: 45, text: "\(stoppageTimeAdded) minutes added"))
            scheduleNext()
            return
        }

        if currentMinute == 105 {
            isETHalf = true
            events.append(.commentary(minute: 105, text: "Half time in extra time"))
            scheduleNext()
            return
        }

        simulateMinute()
        scheduleNext()
    }

    /// Simulates one minute of play: computes expected goals from ratings and
    /// mentalities, resolves shots/goals, cards, injuries, momentum shifts,
    /// and the ball's and players' movement on the pitch.
    private func simulateMinute() {
        let isETPeriod = currentMinute > 90

        let hOffMul = homeMentality.offensiveMultiplier
        let hDefMul = homeMentality.defensiveMultiplier
        let aOffMul = awayMentality.offensiveMultiplier
        let aDefMul = awayMentality.defensiveMultiplier

        let bHO = (Double(homeTeam.offense) * 0.50 + Double(homeTeam.midfield) * 0.30 + Double(homeTeam.defense) * 0.20) * homeForm
        let bHD = (Double(homeTeam.defense) * 0.50 + Double(homeTeam.midfield) * 0.30 + Double(homeTeam.offense) * 0.20) * homeForm
        let bAO = (Double(awayTeam.offense) * 0.50 + Double(awayTeam.midfield) * 0.30 + Double(awayTeam.defense) * 0.20) * awayForm
        let bAD = (Double(awayTeam.defense) * 0.50 + Double(awayTeam.midfield) * 0.30 + Double(awayTeam.offense) * 0.20) * awayForm

        let hO = bHO * hOffMul
        let hD = bHD * hDefMul
        let aO = bAO * aOffMul
        let aD = bAD * aDefMul

        let hExp: Double
        let aExp: Double
        if isETPeriod {
            hExp = max(0.06, hO / 38 - aD / 44 + 0.06) + 0.05
            aExp = max(0.03, aO / 44 - hD / 56 + 0.01) + 0.05
        } else {
            hExp = max(0.10, hO / 36 - aD / 42 + 0.16)
            aExp = max(0.04, aO / 42 - hD / 52 + 0.01)
        }

        let hGP = min(1.0, hExp / 90.0)
        let aGP = min(1.0, aExp / 90.0)

        // Momentum pulls toward the stronger side instead of drifting around zero,
        // so the bar visibly favors whichever team is on top.
        let hOffDominance = hO / (hO + aO + 0.001)
        let dominanceTarget = (hOffDominance - 0.5) * 2.0
        homeMomentum = min(1, max(-1, homeMomentum * 0.85 + dominanceTarget * 0.08 + Double.random(in: -0.03...0.03)))
        let momentumBoost = homeMomentum * 0.5

        let inSecondHalf = currentMinute > 45
        let homeTalkMultiplier = inSecondHalf ? homeTeamTalk.secondHalfShotMultiplier : 1.0
        let homeOpponentTalkMultiplier = inSecondHalf ? awayTeamTalk.secondHalfOpponentShotMultiplier : 1.0
        let awayTalkMultiplier = inSecondHalf ? awayTeamTalk.secondHalfShotMultiplier : 1.0
        let awayOpponentTalkMultiplier = inSecondHalf ? homeTeamTalk.secondHalfOpponentShotMultiplier : 1.0
        let effectiveHomeConversion = homeConversion * homeTalkMultiplier * homeOpponentTalkMultiplier
        let effectiveAwayConversion = awayConversion * awayTalkMultiplier * awayOpponentTalkMultiplier

        if currentMinute > pressureEnd {
            pressureTeamId = nil
        }
        if pressureTeamId == nil && Double.random(in: 0...1) < 0.02 {
            pressureTeamId = Bool.random() ? homeTeam.id : awayTeam.id
            pressureEnd = currentMinute + Int.random(in: 3...6)
            let pressureName = pressureTeamId == homeTeam.id ? homeTeam.name : awayTeam.name
            events.append(.commentary(minute: currentMinute, text: "\(pressureName) pile on the pressure"))
        }
        let homePressure = pressureTeamId == homeTeam.id
        homeMomentum += homePressure ? 0.02 : (pressureTeamId == awayTeam.id ? -0.02 : 0)

        possessionTicks += 1
        let hDom = hO / (hO + aO + 0.001)
        homePossession = homePossession * 0.95 + hDom * 100 * 0.05

        let hShotChance = min(0.30, hGP * 5.0 * (1 + momentumBoost) * (homePressure ? 1.6 : 1.0))
        let aShotChance = min(0.30, aGP * 5.0 * (1 - momentumBoost) * (homePressure ? 1.0 : 1.6))

        if pitchPhase == .buildup, Double.random(in: 0...1) < hShotChance {
            homeShots += 1
            let shooter = onPitchPlayers(homeTeam.id).randomElement()
            let isPenalty = !isETPeriod && Double.random(in: 0...1) < 0.08
            let onTarget = Double.random(in: 0...1) < 0.45
            if onTarget {
                homeShotsOnTarget += 1
                homeMomentum = min(1, homeMomentum + 0.02)
                if Double.random(in: 0...1) < effectiveHomeConversion {
                    let onPitch = onPitchPlayers(homeTeam.id)
                    if let scorer = weightedRandomElement(from: onPitch) {
                        let others = onPitch.filter { $0.name != scorer.name }
                        let assist = Bool.random() && !others.isEmpty ? others.randomElement()!.name : nil
                        let g = GoalEvent(id: UUID(), minute: currentMinute, scorer: scorer.name, teamId: homeTeam.id, isExtraTime: isETPeriod, isPenalty: isPenalty, assist: assist)
                        if isETPeriod { etHomeScore += 1 } else { homeScore += 1 }
                        scorer.goals += 1
                        homeMomentum = min(1, homeMomentum + 0.28)
                        events.append(.goal(g))
                        beginShot(attackingTeamId: homeTeam.id, shooter: shooter?.name, onTarget: true, scored: true, isPenalty: isPenalty)
                    } else {
                        beginShot(attackingTeamId: homeTeam.id, shooter: shooter?.name, onTarget: true, scored: false)
                    }
                } else if let shooter = shooter {
                    homeMomentum = max(-1, homeMomentum - 0.03)
                    if Double.random(in: 0...1) < 0.3 {
                        events.append(.commentary(minute: currentMinute, text: "\(homeTeam.name) - \(shooter.name) rattles the woodwork"))
                    } else {
                        events.append(.commentary(minute: currentMinute, text: "\(homeTeam.name) - \(shooter.name) forces a save"))
                    }
                    beginShot(attackingTeamId: homeTeam.id, shooter: shooter.name, onTarget: true, scored: false)
                }
            } else if let shooter = shooter {
                if Double.random(in: 0...1) < 0.3 {
                    events.append(.commentary(minute: currentMinute, text: "\(homeTeam.name) - \(shooter.name) hits the post"))
                } else if Bool.random() {
                    events.append(.commentary(minute: currentMinute, text: "\(homeTeam.name) - \(shooter.name) shoots just wide"))
                }
                beginShot(attackingTeamId: homeTeam.id, shooter: shooter.name, onTarget: false, scored: false)
            } else {
                beginShot(attackingTeamId: homeTeam.id, shooter: nil, onTarget: false, scored: false)
            }
        }

        if pitchPhase == .buildup, Double.random(in: 0...1) < aShotChance {
            awayShots += 1
            let shooter = onPitchPlayers(awayTeam.id).randomElement()
            let isPenalty = !isETPeriod && Double.random(in: 0...1) < 0.08
            let onTarget = Double.random(in: 0...1) < 0.45
            if onTarget {
                awayShotsOnTarget += 1
                homeMomentum = max(-1, homeMomentum - 0.02)
                if Double.random(in: 0...1) < effectiveAwayConversion {
                    let onPitch = onPitchPlayers(awayTeam.id)
                    if let scorer = weightedRandomElement(from: onPitch) {
                        let others = onPitch.filter { $0.name != scorer.name }
                        let assist = Bool.random() && !others.isEmpty ? others.randomElement()!.name : nil
                        let g = GoalEvent(id: UUID(), minute: currentMinute, scorer: scorer.name, teamId: awayTeam.id, isExtraTime: isETPeriod, isPenalty: isPenalty, assist: assist)
                        if isETPeriod { etAwayScore += 1 } else { awayScore += 1 }
                        scorer.goals += 1
                        homeMomentum = max(-1, homeMomentum - 0.28)
                        events.append(.goal(g))
                        beginShot(attackingTeamId: awayTeam.id, shooter: shooter?.name, onTarget: true, scored: true, isPenalty: isPenalty)
                    } else {
                        beginShot(attackingTeamId: awayTeam.id, shooter: shooter?.name, onTarget: true, scored: false)
                    }
                } else if let shooter = shooter {
                    homeMomentum = min(1, homeMomentum + 0.03)
                    if Double.random(in: 0...1) < 0.3 {
                        events.append(.commentary(minute: currentMinute, text: "\(awayTeam.name) - \(shooter.name) rattles the woodwork"))
                    } else {
                        events.append(.commentary(minute: currentMinute, text: "\(awayTeam.name) - \(shooter.name) forces a save"))
                    }
                    beginShot(attackingTeamId: awayTeam.id, shooter: shooter.name, onTarget: true, scored: false)
                }
            } else if let shooter = shooter {
                if Double.random(in: 0...1) < 0.3 {
                    events.append(.commentary(minute: currentMinute, text: "\(awayTeam.name) - \(shooter.name) hits the post"))
                } else if Bool.random() {
                    events.append(.commentary(minute: currentMinute, text: "\(awayTeam.name) - \(shooter.name) shoots just wide"))
                }
                beginShot(attackingTeamId: awayTeam.id, shooter: shooter.name, onTarget: false, scored: false)
            } else {
                beginShot(attackingTeamId: awayTeam.id, shooter: nil, onTarget: false, scored: false)
            }
        }

        let yellowProb = isETPeriod ? 0.0009 : 0.0013
        let directRedProb = isETPeriod ? 0.0002 : 0.0004

        for teamId in [homeTeam.id, awayTeam.id] {
            for player in onPitchPlayers(teamId) where !player.redCard {
                if Double.random(in: 0...1) < yellowProb {
                    if player.yellowCard && Double.random(in: 0...1) < 0.25 {
                        player.redCard = true
                        player.isOnPitch = false
                        if teamId == homeTeam.id { homeRedCards += 1; homeMomentum = max(-1, homeMomentum - 0.2) } else { awayRedCards += 1; homeMomentum = min(1, homeMomentum + 0.2) }
                        events.append(.card(CardEvent(id: UUID(), minute: currentMinute, playerName: player.name, teamId: teamId, isSecondYellow: true, isExtraTime: isETPeriod)))
                    } else {
                        player.yellowCard = true
                        if teamId == homeTeam.id { homeYellowCards += 1; homeMomentum = max(-1, homeMomentum - 0.08) } else { awayYellowCards += 1; homeMomentum = min(1, homeMomentum + 0.08) }
                        events.append(.card(CardEvent(id: UUID(), minute: currentMinute, playerName: player.name, teamId: teamId, isSecondYellow: false, isExtraTime: isETPeriod)))
                    }
                }
                if Double.random(in: 0...1) < directRedProb && !player.yellowCard {
                    player.redCard = true
                    player.isOnPitch = false
                    if teamId == homeTeam.id { homeRedCards += 1; homeMomentum = max(-1, homeMomentum - 0.2) } else { awayRedCards += 1; homeMomentum = min(1, homeMomentum + 0.2) }
                    events.append(.card(CardEvent(id: UUID(), minute: currentMinute, playerName: player.name, teamId: teamId, isSecondYellow: false, isExtraTime: isETPeriod)))
                }
            }
        }

        for teamId in [homeTeam.id, awayTeam.id] {
            let players = onPitchPlayers(teamId)
            if let victim = players.filter({ !$0.isInjured }).randomElement(), Double.random(in: 0...1) < 0.005 {
                victim.isInjured = true
                events.append(.injury(minute: currentMinute, player: victim.name, teamId: teamId))
            }
        }

        moveBall()
        movePlayers()

        if currentMinute % 4 == 0 {
            let team = Bool.random() ? homeTeam : awayTeam
            let onPitch = onPitchPlayers(team.id)
            guard !onPitch.isEmpty, let p1 = onPitch.randomElement() else { return }
            let others = onPitch.filter { $0.name != p1.name }
            let text: String
            let roll = Double.random(in: 0...1)
            if roll < 0.12, let p2 = others.randomElement() {
                let pt = ["\(p1.name) finds \(p2.name) with a through ball", "\(p1.name) slips the ball to \(p2.name)", "\(p1.name) and \(p2.name) exchange passes", "\(p1.name) picks out \(p2.name) with a lofted cross"]
                text = "\(team.name) - \(pt.randomElement()!)"
            } else if roll < 0.22 {
                text = "\(team.name) win a corner as \(p1.name)'s cross is deflected"
            } else if roll < 0.30 {
                text = "\(team.name) - \(p1.name) is flagged offside as the ball rolls through"
            } else {
                let actions = ["drives forward", "wins possession", "shoots from distance", "cuts inside", "delivers a cross", "charges down the wing", "plays a long ball", "spins his marker and runs at goal", "breaks into the box", "screens the ball and shields it out", "thumps a clearance away", "switches play with a raking pass"]
                text = "\(team.name) - \(p1.name) \(actions.randomElement()!)"
            }
            events.append(.commentary(minute: currentMinute, text: text))
        }
    }

    /// Advances the ball one tick according to the current pitch phase:
    /// dribbling toward the carrier, a flying pass to a teammate, shot flight
    /// to the goal mouth, a goal-celebration pause, a kickoff reset, or an
    /// out-of-play restart. Publishes `visualAction` for the pitch overlay.
    private func moveBall() {
        let prev = CGPoint(x: ballX, y: ballY)
        switch pitchPhase {
        case .shot:
            let dx = shotTarget.x - ballX
            let dy = shotTarget.y - ballY
            let dist = max(hypot(dx, dy), 0.001)
            let step = dist / max(1, CGFloat(phaseTicks))
            ballX += (dx / dist) * step
            ballY += (dy / dist) * step
            phaseTicks -= 1
            visualAction = .shot(from: prev, to: shotTarget)
            actionTeamId = shotAttackingTeam
            if phaseTicks <= 0 {
                if goalCrossed {
                    pitchPhase = .goal
                    phaseTicks = 2
                    visualAction = .none
                    actionTeamId = nil
                } else {
                    beginBallOut(onTarget: shotOnTarget, attackingTeamId: shotAttackingTeam)
                }
            }
        case .goal:
            phaseTicks -= 1
            visualAction = .none
            actionTeamId = nil
            if phaseTicks <= 0 {
                resetForKickoff()
            }
        case .ballOut:
            let dx = outTarget.x - ballX
            let dy = outTarget.y - ballY
            let dist = max(hypot(dx, dy), 0.001)
            let step = dist / max(1, CGFloat(phaseTicks))
            ballX += (dx / dist) * step
            ballY += (dy / dist) * step
            phaseTicks -= 1
            visualAction = .ballOut(to: outTarget)
            actionTeamId = possessingTeamId
            if phaseTicks <= 0 {
                pitchPhase = .buildup
                phaseTicks = 0
                ballCarrier = nil
                passTarget = nil
                passInProgress = false
                visualAction = .none
                actionTeamId = nil
            }
        case .kickoff:
            phaseTicks -= 1
            visualAction = .none
            actionTeamId = nil
            if phaseTicks <= 0 {
                pitchPhase = .buildup
                phaseTicks = 0
            }
        case .buildup:
            if !passInProgress, let carrier = ballCarrier, onPitchPlayers(possessingTeamId ?? homeTeam.id).contains(where: { $0.name == carrier }), Double.random(in: 0...1) < 0.18 {
                let teammates = onPitchPlayers(possessingTeamId ?? homeTeam.id).filter { $0.name != carrier }
                if let receiver = teammates.randomElement() {
                    passTarget = receiver.name
                    passInProgress = true
                }
            }
            if passInProgress, let target = passTarget, let tpos = playerPositions[target] {
                let dx = tpos.x - ballX
                let dy = tpos.y - ballY
                let dist = max(hypot(dx, dy), 0.001)
                let step = min(0.15, dist)
                ballX += (dx / dist) * step
                ballY += (dy / dist) * step
                visualAction = .pass(from: prev, to: tpos)
                if dist < 0.045 {
                    passInProgress = false
                    ballCarrier = target
                }
            } else if let carrier = ballCarrier, onPitchPlayers(possessingTeamId ?? homeTeam.id).contains(where: { $0.name == carrier }), let cpos = playerPositions[carrier] {
                let dx = cpos.x - ballX
                let dy = cpos.y - ballY
                let dist = max(hypot(dx, dy), 0.001)
                let step = min(0.06, dist)
                ballX += (dx / dist) * step
                ballY += (dy / dist) * step
                visualAction = .dribble(from: prev, to: CGPoint(x: ballX, y: ballY))
            } else {
                pickCarrier()
                visualAction = .none
            }
            actionTeamId = possessingTeamId
        }
        ballX = max(0.02, min(0.98, ballX))
        ballY = max(0.10, min(0.90, ballY))
    }

    /// Starts a shot sequence: points the ball at the attacking goal mouth and
    /// sets a multi-tick flight phase so the ball visibly travels to the goal.
    /// A penalty first places the ball on the spot. On a goal the ball stops at
    /// the line for a celebration phase before the kickoff reset.
    /// - Parameters:
    ///   - attackingTeamId: The team shooting at the opponent's goal.
    ///   - shooter: The shooter's name, used as the shot's starting point.
    ///   - onTarget: Whether the shot was on target (chooses the restart after).
    ///   - scored: Whether the shot crossed the line (goal celebration).
    ///   - isPenalty: Places the ball on the penalty spot before the flight.
    private func beginShot(attackingTeamId: UUID, shooter: String?, onTarget: Bool, scored: Bool, isPenalty: Bool = false) {
        let isHome = attackingTeamId == homeTeam.id
        pitchPhase = .shot
        shotAttackingTeam = attackingTeamId
        shotOnTarget = onTarget
        goalCrossed = scored
        ballCarrier = shooter
        passTarget = nil
        passInProgress = false
        let mouthY: CGFloat = 0.5 + CGFloat(Double.random(in: -0.16...0.16))
        shotTarget = CGPoint(x: isHome ? 0.98 : 0.02, y: mouthY)
        if isPenalty {
            ballX = isHome ? 0.89 : 0.11
            ballY = 0.5
            phaseTicks = 1
        } else {
            if let shooter = shooter, let spos = playerPositions[shooter] {
                ballX = spos.x
                ballY = spos.y
            }
            let dist = max(hypot(shotTarget.x - ballX, shotTarget.y - ballY), 0.001)
            phaseTicks = min(6, max(2, Int(dist / 0.15)))
        }
        ballVelocityX = 0
        ballVelocityY = 0
        visualAction = .shot(from: CGPoint(x: ballX, y: ballY), to: shotTarget)
        actionTeamId = attackingTeamId
    }

    /// Sends the ball to a restart position after a denied shot: a corner
    /// (attacking team keeps possession) or a goal kick/keeper distribution
    /// (defending team takes possession). Runs for a couple of ticks.
    private func beginBallOut(onTarget: Bool, attackingTeamId: UUID?) {
        let defendingIsHome = attackingTeamId != homeTeam.id
        pitchPhase = .ballOut
        phaseTicks = 2
        if onTarget {
            possessingTeamId = defendingIsHome ? homeTeam.id : awayTeam.id
            outTarget = CGPoint(x: defendingIsHome ? 0.12 : 0.88, y: 0.5 + CGFloat(Double.random(in: -0.10...0.10)))
        } else if Double.random(in: 0...1) < 0.6 {
            possessingTeamId = attackingTeamId
            outTarget = CGPoint(x: defendingIsHome ? 0.04 : 0.96, y: Bool.random() ? 0.10 : 0.90)
        } else {
            possessingTeamId = defendingIsHome ? homeTeam.id : awayTeam.id
            outTarget = CGPoint(x: defendingIsHome ? 0.12 : 0.88, y: 0.5)
        }
        ballCarrier = nil
        passTarget = nil
        passInProgress = false
        visualAction = .ballOut(to: outTarget)
        actionTeamId = possessingTeamId
    }

    /// Centers the ball after a goal so the conceding team kicks off, briefly
    /// pausing in a kickoff phase before resuming normal buildup play.
    private func resetForKickoff() {
        ballX = 0.5
        ballY = 0.5
        ballVelocityX = 0
        ballVelocityY = 0
        possessingTeamId = (shotAttackingTeam == homeTeam.id) ? awayTeam.id : homeTeam.id
        pitchPhase = .kickoff
        phaseTicks = 2
        ballCarrier = nil
        passTarget = nil
        passInProgress = false
        visualAction = .none
        actionTeamId = nil
    }

    /// Selects the player of the possessing team nearest the ball as the dribbler.
    private func pickCarrier() {
        guard let teamId = possessingTeamId else { return }
        let candidates = onPitchPlayers(teamId)
        guard !candidates.isEmpty else { return }
        ballCarrier = candidates.min { distanceFromBall($0.name) < distanceFromBall($1.name) }?.name
    }

    /// Distance from the ball to the given player's current position.
    private func distanceFromBall(_ name: String) -> CGFloat {
        guard let pos = playerPositions[name] else { return .greatestFiniteMagnitude }
        return hypot(ballX - pos.x, ballY - pos.y)
    }

    /// Moves every on-pitch player toward a role- and phase-dependent target:
    /// the whole team slides forward when attacking and drops back when
    /// defending, the ball carrier drives forward, the nearest defender presses
    /// the ball, keepers hold their line, and same-team circles are pushed
    /// apart so players never clump on the ball.
    private func movePlayers() {
        let homeAttacking = possessingTeamId == homeTeam.id
        let defendingTeamId = homeAttacking ? awayTeam.id : homeTeam.id
        let pressingName = onPitchPlayers(defendingTeamId).min { distanceFromBall($0.name) < distanceFromBall($1.name) }?.name

        for player in (homePlayers + awayPlayers).filter(\.isOnPitch) {
            guard var pos = playerPositions[player.name] else { continue }
            let initial = initialPlayerPositions[player.name] ?? pos
            let role = playerRoles[player.name] ?? 2
            let isHomeTeam = homePlayers.contains { $0.name == player.name }
            let teamAttacking = isHomeTeam == homeAttacking
            let attackingDir: CGFloat = isHomeTeam ? 1 : -1

            var target = initial

            if role == 0 {
                let gkX: CGFloat = isHomeTeam ? 0.05 : 0.95
                target.x = gkX
                target.y = 0.5 + (ballY - 0.5) * 0.28
                if (ballX < 0.5) == isHomeTeam {
                    target.y += (ballY - target.y) * 0.2
                }
            } else {
                let push: CGFloat = teamAttacking ? 0.12 : 0.10
                let depth: CGFloat
                switch role { case 1: depth = 1.0; case 2: depth = 0.55; default: depth = 0.25 }
                target.x += attackingDir * push * depth
                target.x += (ballX - 0.5) * 0.10
                target.y += (ballY - 0.5) * 0.12
                if pitchPhase == .shot {
                    if teamAttacking {
                        target.x += attackingDir * (role == 1 ? 0.10 : role == 2 ? 0.06 : 0.03)
                    } else {
                        target.x += -attackingDir * (role == 3 ? 0.08 : role == 2 ? 0.05 : 0.02)
                    }
                }
            }

            if role == 0 {
                if player.name == ballCarrier || distanceFromBall(player.name) < 0.12 {
                    target.x += (ballX - target.x) * 0.3
                    target.y += (ballY - target.y) * 0.3
                }
            } else if player.name == ballCarrier {
                let drive = CGPoint(x: ballX + attackingDir * 0.12, y: ballY + CGFloat(Double.random(in: -0.05...0.05)))
                target = CGPoint(x: pos.x + (drive.x - pos.x) * 0.30, y: pos.y + (drive.y - pos.y) * 0.30)
            } else if player.name == pressingName {
                target.x += (ballX - pos.x) * 0.16
                target.y += (ballY - pos.y) * 0.16
            }

            let pull: CGFloat = role == 0 ? 0.28 : 0.20
            pos.x += (target.x - pos.x) * pull
            pos.y += (target.y - pos.y) * pull

            pos.x += CGFloat(Double.random(in: -0.004...0.004))
            pos.y += CGFloat(Double.random(in: -0.003...0.003))
            pos.x = max(0.02, min(0.98, pos.x))
            pos.y = max(0.02, min(0.98, pos.y))
            playerPositions[player.name] = pos
        }

        applySeparation()
    }

    /// Pushes same-team players apart when they are closer than a minimum
    /// distance, preventing circles from piling up on the ball.
    private func applySeparation() {
        for teamId in [homeTeam.id, awayTeam.id] {
            let names = onPitchPlayers(teamId).map { $0.name }
            for i in 0..<names.count {
                guard var pi = playerPositions[names[i]] else { continue }
                for j in (i + 1)..<names.count {
                    guard var pj = playerPositions[names[j]] else { continue }
                    let dx = pj.x - pi.x
                    let dy = pj.y - pi.y
                    let d = hypot(dx, dy)
                    let minDist: CGFloat = 0.06
                    if d < minDist && d > 0.0001 {
                        let push = (minDist - d) / 2
                        let nx = dx / d
                        let ny = dy / d
                        pi.x -= nx * push
                        pi.y -= ny * push
                        pj.x += nx * push
                        pj.y += ny * push
                    }
                }
                playerPositions[names[i]] = pi
            }
        }
    }

    /// Runs a penalty shootout when the final is still level after extra time,
    /// recording the result and per-kick commentary.
    private func resolvePenalties() {
        let shootout = SimulatedKnockoutLeg.generatePenaltyShootout(homePlayers: homePlayerNames, awayPlayers: awayPlayerNames)
        penaltyHome = shootout.home
        penaltyAway = shootout.away
        penaltyKicks = shootout.kicks.map { (teamIsHome: $0.teamIsHome, shooter: $0.shooter, scored: $0.scored) }
        events.append(.commentary(minute: 120, text: "Penalties: \(penaltyHome)-\(penaltyAway)"))
        for kick in shootout.kicks {
            let teamName = kick.teamIsHome ? homeTeam.name : awayTeam.name
            events.append(.commentary(minute: 120, text: "\(teamName) - \(kick.shooter): \(kick.scored ? "SCORED" : "MISSED")"))
        }
    }

    /// Substitutes a player on for another on the given team, guarding against
    /// invalid swaps (off-pitch players, injured/sent-off players, overusing subs).
    /// - Parameters:
    ///   - playerOff: Name of the player leaving the pitch.
    ///   - playerOn: Name of the player coming on.
    ///   - teamId: The team making the change.
    func substitute(playerOff: String, playerOn: String, teamId: UUID) {
        guard let off = player(by: playerOff), let on = player(by: playerOn) else { return }
        guard off.isOnPitch, !on.isOnPitch, !on.isInjured, !on.redCard else { return }
        off.isOnPitch = false
        off.isSubbedOff = true
        on.isOnPitch = true
        if teamId == homeTeam.id { homeSubsUsed += 1 } else { awaySubsUsed += 1 }
        events.append(.substitution(minute: currentMinute, playerOff: playerOff, playerOn: playerOn, teamId: teamId))
    }

    /// Returns the players of a team who are currently on the pitch and not
    /// sent off (used for shot taking, pass targets, and event assignment).
    func onPitchPlayers(_ teamId: UUID) -> [LiveMatchPlayer] {
        (teamId == homeTeam.id ? homePlayers : awayPlayers).filter { $0.isOnPitch && !$0.redCard }
    }

    /// Returns the players of a team who are available to come on as subs:
    /// on the bench, not injured, not already subbed off, and not sent off.
    func benchPlayers(_ teamId: UUID) -> [LiveMatchPlayer] {
        (teamId == homeTeam.id ? homePlayers : awayPlayers).filter { !$0.isOnPitch && !$0.isInjured && !$0.isSubbedOff && !$0.redCard }
    }

    /// Finds a player by name across both squads.
    private func player(by name: String) -> LiveMatchPlayer? {
        (homePlayers + awayPlayers).first { $0.name == name }
    }

    /// Picks a player from the given list, weighted by their rating.
    private func weightedRandomElement(from players: [LiveMatchPlayer]) -> LiveMatchPlayer? {
        guard !players.isEmpty else { return nil }
        let totalRating = players.reduce(0) { $0 + $1.rating }
        guard totalRating > 0 else { return players.randomElement() }
        var running = 0
        let target = Int.random(in: 0..<totalRating)
        for player in players {
            running += player.rating
            if target < running {
                return player
            }
        }
        return players.last
    }

    /// Converts the live match's score, events, and penalties into a static
    /// `SimulatedKnockoutLeg`, splitting goals/cards into normal and extra time.
    func toSimulatedKnockoutLeg() -> SimulatedKnockoutLeg {
        var normalG: [GoalEvent] = []
        var etG: [GoalEvent] = []
        var normalC: [CardEvent] = []
        var etC: [CardEvent] = []
        for ev in events {
            switch ev {
            case .goal(let g):
                if g.isExtraTime { etG.append(g) } else { normalG.append(g) }
            case .card(let c):
                if c.isExtraTime { etC.append(c) } else { normalC.append(c) }
            default: break
            }
        }
        return SimulatedKnockoutLeg(
            homeTeam: homeTeam, awayTeam: awayTeam,
            homeScore: homeScore, awayScore: awayScore,
            goals: normalG, cards: normalC,
            etHomeScore: etHomeScore, etAwayScore: etAwayScore,
            etGoals: etG, etCards: etC,
            penaltyHome: penaltyHome, penaltyAway: penaltyAway,
            penaltyKicks: penaltyKicks.enumerated().map { PenaltyKick(teamIsHome: $0.element.teamIsHome, shooter: $0.element.shooter, scored: $0.element.scored, round: $0.offset / 2 + 1) }
        )
    }
}

/// One player in a live match, publishing their on-pitch status, cards,
/// injury state, substitution state, and goal tally for UI observation.
class LiveMatchPlayer: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    /// Whether the player is currently on the pitch.
    @Published var isOnPitch: Bool
    /// Whether the player is currently injured.
    @Published var isInjured = false
    /// Whether the player has been booked.
    @Published var yellowCard = false
    /// Whether the player has been sent off.
    @Published var redCard = false
    /// Goals scored by the player this match.
    @Published var goals = 0
    /// Whether the player has been substituted off.
    @Published var isSubbedOff = false

    /// The player's overall rating, used for weighted shot/sim choices.
    let rating: Int

    /// - Parameters:
    ///   - isOnPitch: Whether the player starts on the pitch.
    ///   - rating: The player's overall rating (default 80).
    init(name: String, isOnPitch: Bool = false, rating: Int = 80) {
        self.name = name
        self.isOnPitch = isOnPitch
        self.rating = rating
    }
}

/// A single event in a live match's timeline.
enum LiveMatchEvent {
    case goal(GoalEvent)
    case card(CardEvent)
    case injury(minute: Int, player: String, teamId: UUID)
    case substitution(minute: Int, playerOff: String, playerOn: String, teamId: UUID)
    case commentary(minute: Int, text: String)
}
