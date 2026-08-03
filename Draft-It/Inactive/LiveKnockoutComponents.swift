/// LiveKnockoutComponents.swift
///
/// Live match UI for knockout games: momentum bar, scoreboard, stats row,
/// scrolling event feed, substitution overlay, speed controls, and the
/// half-time/extra-time break screen.

import SwiftUI

/// Live match scoreboard: both team columns with current scores plus the
/// match clock, stoppage time, extra time, and substitution counters.
struct LiveMatchScoreboard: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    let match: LiveKnockoutMatch

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                LiveMatchTeamColumn(name: homeTeam.name, score: match.homeScore, isPlayer: true)
                Text("vs").font(.caption).foregroundColor(.secondary)
                LiveMatchTeamColumn(name: awayTeam.name, score: match.awayScore, isPlayer: false)
            }
            HStack(spacing: 6) {
                Text(match.isStoppageTime ? "\(match.currentMinute)+\(match.stoppageTimeEnd - 45 > 0 && match.currentMinute <= 45 ? match.stoppageTimeEnd - 45 : match.stoppageTimeEnd - 90)'" : "\(match.currentMinute)'")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(match.currentMinute > 90 ? .orange : .primary)
                if match.currentMinute > 90 {
                    Text("ET").font(.caption.weight(.bold)).foregroundColor(.orange)
                }
                if match.isStoppageTime {
                    Text("+\(match.stoppageTimeAdded)").font(.caption2.weight(.bold)).foregroundColor(.orange)
                }
                if match.homeSubsUsed > 0 || match.awaySubsUsed > 0 {
                    Text("Subs \(match.homeSubsUsed)/\(match.awaySubsUsed)")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

/// One team's name and score column in the live scoreboard, with an animated
/// numeric transition on the score. `isPlayer` bolds the team name.
struct LiveMatchTeamColumn: View {
    let name: String
    let score: Int
    let isPlayer: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(name).font(.caption.weight(isPlayer ? .bold : .semibold)).lineLimit(1)
                .foregroundColor(teamColor(named: name))
            Text("\(score)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(teamColor(named: name))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }
}

/// Row of live stat boxes comparing shots, shots on target, possession, and
/// card counts between the two teams.
struct LiveMatchStatsRow: View {
    let match: LiveKnockoutMatch

    var body: some View {
        HStack(spacing: 0) {
            StatBox(label: "Shots", value: "\(match.homeShots)-\(match.awayShots)", color: .primary)
            StatBox(label: "SOT", value: "\(match.homeShotsOnTarget)-\(match.awayShotsOnTarget)", color: .primary)
            StatBox(label: "Poss", value: "\(Int(match.homePossession))%-\(100 - Int(match.homePossession))%", color: .primary)
            StatBox(label: "Cards", value: "\(match.homeYellowCards + match.homeRedCards)-\(match.awayYellowCards + match.awayRedCards)", color: match.homeRedCards + match.awayRedCards > 0 ? .red : .yellow)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

/// Scrolling, reverse-chronological feed of live match events, auto-scrolling
/// to the newest event as events are appended. Shows a placeholder when the
/// match has not kicked off yet.
struct LiveMatchFeed: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    @ObservedObject var match: LiveKnockoutMatch

    var body: some View {
        VStack(spacing: 4) {
            Text("Match Feed")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.top, 4)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(match.events.enumerated().reversed()), id: \.offset) { idx, ev in
                            LiveMatchEventRow(event: ev, homeTeam: homeTeam, awayTeam: awayTeam).id(idx)
                        }
                        if match.events.isEmpty {
                            Text("Kick off coming soon...")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(4)
                        }
                    }
                }
                .onChange(of: match.events.count) {
                    withAnimation { proxy.scrollTo(0, anchor: .bottom) }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

/// Renders a single feed event (goal, card, injury, substitution, or
/// commentary) as a styled row with minute stamp and team-colored accents.
struct LiveMatchEventRow: View {
    let event: LiveMatchEvent
    let homeTeam: CupTeam
    let awayTeam: CupTeam

    @ViewBuilder
    var body: some View {
        switch event {
        case .goal(let g):
            HStack(spacing: 4) {
                Text("\(g.minute)'")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
                Text("GOAL! \(g.scorer)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(g.teamId == homeTeam.id ? teamColor(named: homeTeam.name) : teamColor(named: awayTeam.name))
                if g.isPenalty { Text("(P)").font(.system(size: 8)).foregroundColor(.orange) }
                if let a = g.assist { Text("(\(a))").font(.system(size: 8)).foregroundColor(.secondary) }
                Spacer()
            }
            .padding(.vertical, 3).padding(.horizontal, 4)
            .background(Color.yellow.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        case .card(let c):
            HStack(spacing: 4) {
                Text("\(c.minute)'")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
                Text(c.isSecondYellow ? "RED" : "YELLOW")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(c.isSecondYellow ? .red : .yellow)
                Text(c.playerName).font(.system(size: 10))
                Spacer()
            }
            .padding(.vertical, 2).padding(.horizontal, 4)
        case .injury(let minute, let player, _):
            HStack(spacing: 4) {
                Text("\(minute)'")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
                Image(systemName: "cross.circle.fill").font(.system(size: 9)).foregroundColor(.red)
                Text("\(player) injured").font(.system(size: 10)).foregroundColor(.red)
                Spacer()
            }
            .padding(.vertical, 2).padding(.horizontal, 4)
        case .substitution(let minute, let off, let on, _):
            HStack(spacing: 4) {
                Text("\(minute)'")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 9)).foregroundColor(.green)
                Text("\u{2191}\(on) \u{2193}\(off)").font(.system(size: 10))
                Spacer()
            }
            .padding(.vertical, 2).padding(.horizontal, 4)
        case .commentary(let minute, let text):
            HStack(spacing: 4) {
                Text("\(minute)'")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
                Text(text).font(.system(size: 9)).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 2).padding(.horizontal, 4)
        }
    }
}

/// Bottom control bar during a live match: a Subs button (via `onSubs`) and
/// playback speed toggles (1x/2x/4x).
struct LiveMatchControlBar: View {
    @ObservedObject var match: LiveKnockoutMatch
    let onSubs: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSubs) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                    Text("Subs")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 4) {
                LiveMatchSpeedButton(match: match, label: "1x", multiplier: 1.0)
                LiveMatchSpeedButton(match: match, label: "2x", multiplier: 2.0)
                LiveMatchSpeedButton(match: match, label: "4x", multiplier: 4.0)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }
}

/// Speed control button that sets the match's simulation speed multiplier and
/// highlights itself when it is the active speed.
struct LiveMatchSpeedButton: View {
    @ObservedObject var match: LiveKnockoutMatch
    let label: String
    let multiplier: Double

    var body: some View {
        Button(action: {
            match.speedMultiplier = multiplier
        }) {
            Text(label)
                .font(.system(size: 10, weight: match.speedMultiplier == multiplier ? .bold : .regular))
                .foregroundColor(match.speedMultiplier == multiplier ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(match.speedMultiplier == multiplier ? Color.blue : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

/// Modal overlay for making substitutions during a live match. Shows the
/// player team's on-pitch and bench players; tapping a bench player swaps
/// them in for an injured starter (or the last starter). Dismissed via
/// `onClose` or by tapping the dimmed background.
struct LiveMatchSubOverlay: View {
    let homeTeam: CupTeam
    @ObservedObject var match: LiveKnockoutMatch
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 12) {
                Text("Substitutions")
                    .font(.title2.weight(.bold))

                VStack(spacing: 0) {
                    Text("On Pitch")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(match.onPitchPlayers(match.homeTeam.id)) { player in
                                LiveMatchPlayerSubRow(player: player, teamId: match.homeTeam.id, match: match)
                            }
                        }
                    }
                    .frame(maxHeight: 140)

                    Divider().padding(.vertical, 4)

                    Text("Bench")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(match.benchPlayers(match.homeTeam.id)) { player in
                                Button(action: {
                                    let onPitch = match.onPitchPlayers(match.homeTeam.id)
                                    let target = onPitch.first { $0.isInjured } ?? onPitch.last
                                    if let target = target {
                                        match.substitute(playerOff: target.name, playerOn: player.name, teamId: match.homeTeam.id)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Text(player.name)
                                            .font(.system(size: 12, weight: .medium))
                                        Spacer()
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(teamColor(named: homeTeam.name))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(teamColor(named: homeTeam.name).opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                            if match.benchPlayers(match.homeTeam.id).isEmpty {
                                Text("No substitutes available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .frame(maxHeight: 140)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Button(action: onClose) {
                    Text("Close")
                        .frame(maxWidth: .infinity)
                        .font(.headline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .tint(.blue)
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)
        }
    }
}

/// One row in the substitution overlay's on-pitch list, showing the player's
/// fitness dot and any injury, yellow card, or goal markers.
struct LiveMatchPlayerSubRow: View {
    let player: LiveMatchPlayer
    let teamId: UUID
    @ObservedObject var match: LiveKnockoutMatch

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(player.isInjured ? Color.red : Color.green)
                .frame(width: 8, height: 8)
            Text(player.name)
                .font(.system(size: 11, weight: .medium))
            Spacer()
            HStack(spacing: 4) {
                if player.isInjured { Text("INJ").font(.system(size: 8, weight: .bold)).foregroundColor(.red) }
                if player.yellowCard { Text("YC").font(.system(size: 8, weight: .bold)).foregroundColor(.yellow) }
                if player.goals > 0 { Text("G\(player.goals)").font(.system(size: 8, weight: .bold)).foregroundColor(.green) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(.systemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// Break screen between halves (or at extra-time half time) of a live match.
/// Shows the current score, the mentality picker for the player's team, a
/// half-time team talk choice, and a Continue button to resume play.
struct LiveMatchBreakView: View {
    let homeTeam: CupTeam
    let awayTeam: CupTeam
    @ObservedObject var match: LiveKnockoutMatch
    @Binding var mentality: MatchMentality
    @Binding var teamTalk: TeamTalkEffect
    @Binding var teamTalkChosen: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 12) {
                Text(match.isHT ? "Half Time" : "Extra Time Half Time")
                    .font(.largeTitle.weight(.bold))
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text(homeTeam.name).font(.headline.weight(.bold)).foregroundColor(teamColor(named: homeTeam.name))
                        Text("\(match.homeScore)").font(.system(size: 44, weight: .bold))
                    }.frame(maxWidth: .infinity)
                    Text("-").font(.system(size: 32, weight: .bold)).foregroundColor(.secondary)
                    VStack(spacing: 2) {
                        Text(awayTeam.name).font(.headline.weight(.bold)).foregroundColor(teamColor(named: awayTeam.name))
                        Text("\(match.awayScore)").font(.system(size: 44, weight: .bold))
                    }.frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)

            VStack(spacing: 8) {
                Text(match.isET ? "Extra Time Mentality" : "Second Half Mentality")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                LiveMatchMentalityRow(selection: $mentality)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            KnockoutTeamTalkPicker(selection: $teamTalk, chosen: $teamTalkChosen)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

            Button(action: onContinue) {
                Text(match.isET ? "Continue Extra Time" : "Continue to Second Half")
                    .frame(maxWidth: .infinity).font(.headline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal, 16)
            Spacer()
        }
    }
}

/// Horizontal row of mentality buttons for a live match, binding to the
/// current selection and highlighting the active option.
struct LiveMatchMentalityRow: View {
    @Binding var selection: MatchMentality

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MatchMentality.allCases, id: \.self) { m in
                Button(action: { selection = m }) {
                    Text(mentalityLabel(m))
                        .font(.system(size: 11, weight: selection == m ? .bold : .regular))
                        .lineLimit(1).frame(maxWidth: .infinity).padding(.vertical, 6).padding(.horizontal, 4)
                        .background(selection == m ? mentalityColor(m).opacity(0.25) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection == m ? mentalityColor(m) : Color(.separator), lineWidth: selection == m ? 2 : 1))
                        .foregroundColor(selection == m ? mentalityColor(m) : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

