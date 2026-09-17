/// KnockoutFlowViews.swift
///
/// Transitional screens for the knockout tournament flow: the opponent draw,
/// pre-match intro with managerial decisions, half-time and between-leg
/// breaks, and the elimination/championship end screen.

import SwiftUI

/// Full-screen "drawing opponent" screen shown before a knockout tie.
///
/// While the opponent is being selected, cycles through a spinner and lists
/// the pool of possible opponents; once locked in, displays the opponent
/// name. Requires the player team name and ID, the lock state, and the
/// opponent pool.
struct KnockoutDrawView: View {
    let displayName: String
    let lockedOpponent: Bool
    let opponentName: String?
    let opponentPool: [CupTeam]
    let playerTeamId: UUID

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(lockedOpponent ? opponentName ?? "???" : displayName)
                .font(.system(size: 36, weight: .bold))
                .padding(.horizontal)
            Text(lockedOpponent ? "Your opponent is set!" : "Drawing opponent...")
                .foregroundColor(.secondary)
if lockedOpponent {
                ProgressView().padding(.top, 8)
            }
            Spacer()
        }
    }
}

/// Pre-match introduction screen showing the player team vs the opponent,
/// a Final/First Leg/Second Leg badge, and a "Play Match" button. Used at the
/// start of every knockout match.
struct KnockoutIntroView: View {
    let playerTeam: CupTeam
    let opponent: CupTeam?
    let isFinal: Bool
    let legs: Int
    let currentLegIndex: Int
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(spacing: 4) {
                Text(customTeamName())
                    .font(.headline)
                Text(playerTeam.name)
                    .font(.title2.weight(.bold))
                    .foregroundColor(teamColor(named: playerTeam.name))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(teamColor(named: playerTeam.name).opacity(0.3))
                    .frame(width: 4),
                alignment: .leading
            )

            Text("vs")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(.systemGray3))
                .clipShape(Circle())

            VStack(spacing: 4) {
                Text("Opponent")
                    .font(.headline)
                Text(opponent?.name ?? "???")
                    .font(.title2.weight(.bold))
                    .foregroundColor(teamColor(named: opponent?.name ?? ""))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(teamColor(named: opponent?.name ?? "").opacity(0.3))
                    .frame(width: 4),
                alignment: .leading
            )

            if isFinal {
                Text("Final")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.yellow)
                    .clipShape(Capsule())
            } else if legs > 1 {
                Text(currentLegIndex == 0 ? "First Leg" : "Second Leg")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }

            Spacer()
            Button(action: onPlay) {
                Text("Play Match")
                    .frame(maxWidth: .infinity)
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .padding()
    }
}

/// Half-time interlude during a knockout match. Shows the current score
/// (from goals scored up to the current minute, swapped by leg index) and a
/// Continue button to start the second half.
struct KnockoutHTBreakView: View {
    let playerTeam: CupTeam
    let opponent: CupTeam?
    let currentLegIndex: Int
    let currentGoals: [GoalEvent]
    let currentMinute: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 8) {
                Text("Half Time")
                    .font(.largeTitle.weight(.bold))
                let hScore = currentGoals.filter { $0.teamId == (currentLegIndex == 0 ? playerTeam : opponent ?? playerTeam).id && $0.minute <= currentMinute }.count
                let aScore = currentGoals.filter { $0.teamId == (currentLegIndex == 0 ? opponent ?? playerTeam : playerTeam).id && $0.minute <= currentMinute }.count

                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text(currentLegIndex == 0 ? playerTeam.name : opponent?.name ?? "")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(teamColor(named: currentLegIndex == 0 ? playerTeam.name : opponent?.name ?? ""))
                        Text("\(hScore)")
                            .font(.system(size: 44, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)

                    Text("-")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 2) {
                        Text(currentLegIndex == 0 ? opponent?.name ?? "" : playerTeam.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(teamColor(named: currentLegIndex == 0 ? opponent?.name ?? "" : playerTeam.name))
                        Text("\(aScore)")
                            .font(.system(size: 44, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Second half starting soon...")
                .foregroundColor(.secondary)
            Button(action: onContinue) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal)
            Spacer()
        }
    }
}

/// Screen shown between the two legs of a tie (or after the final). Displays
/// the first-leg full-time result, a "Second Leg coming up" hint for
/// non-finals, and a Continue button to advance.
struct KnockoutLegBreakView: View {
    let playerTeam: CupTeam
    let opponent: CupTeam?
    let isFinal: Bool
    let leg1: SimulatedKnockoutLeg?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            if let l1 = leg1 {
                VStack(spacing: 10) {
                    Text(isFinal ? "Full Time Result" : "First Leg Result")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        VStack(spacing: 2) {
                            Text(playerTeam.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(teamColor(named: playerTeam.name))
                            Text("\(l1.totalHomeScore)")
                                .font(.system(size: 44, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)

                        Text("-")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 2) {
                            Text(opponent?.name ?? "")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(teamColor(named: opponent?.name ?? ""))
                            Text("\(l1.totalAwayScore)")
                                .font(.system(size: 44, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if !isFinal {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                        Text("Second Leg coming up...")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            Spacer()
            if !isFinal, let _ = leg1 {
                Button(action: onContinue) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .font(.headline.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.large)
                .tint(.green)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .padding()
    }
}

/// Final screen of the knockout tournament: a trophy banner if the player
/// won, an elimination banner otherwise, plus a "View Full Results" button.
struct KnockoutEndView: View {
    let competitionType: CupCompetitionType
    let isChampion: Bool
    let eliminated: Bool
    let eliminatedIn: String?
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if isChampion {
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    Text("Champions!")
                        .font(.largeTitle.weight(.bold))
                    Text("\(competitionType.rawValue) Winners")
                        .font(.title2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.yellow.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            } else if eliminated {
                VStack(spacing: 12) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    Text("Eliminated")
                        .font(.largeTitle.weight(.bold))
                    Text(eliminatedIn ?? "")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            Spacer()
        }
    }
}
