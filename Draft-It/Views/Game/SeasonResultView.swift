/// SeasonResultView.swift
///
/// Season prediction screen shown after the lineup is complete: expected finish,
/// points, and outcome odds, with actions to play the upcoming season or go home.
import SwiftUI

/// Displays the simulated `SeasonOdds` and buttons to either start the playable season
/// (`onPlaySeason`) or return home (`onRestart`).
struct SeasonResultView: View {
    let odds: SeasonOdds?
    let onRestart: () -> Void
    let onPlaySeason: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var adaptiveGray6: Color {
        Color(.systemGray6)
    }

    /// Renders the prediction header, odds bars, and the play/restart actions.
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                Text("Season Prediction")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 45)

                if let odds = odds {
                    HStack(spacing: 32) {
                        VStack(spacing: 4) {
                            Text("Expected Finish")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ordinal(odds.expectedPosition))
                                .font(.system(size: 40, weight: .bold))
                        }

                        VStack(spacing: 4) {
                            Text("Expected Points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(odds.expectedPoints)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }

                    VStack(spacing: 20) {
                        Text("Season Odds")
                            .font(.title2)
                            .fontWeight(.bold)

                        OutcomeRow(label: "Win Title", pct: odds.winTitle, color: .yellow)
                        OutcomeRow(label: "Top 4 (2-4)", pct: odds.top4, color: .green)
                        OutcomeRow(label: "Top 8 (5-8)", pct: odds.top8, color: .blue)
                        OutcomeRow(label: "Mid Table (9-17)", pct: odds.midTable, color: .orange)
                        OutcomeRow(label: "Relegation (18-20)", pct: odds.relegation, color: .red)
                    }
                    .padding()
                    .background(adaptiveGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                } else {
                    Text("Error calculating season odds.")
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 15) {
                    Button(action: {
                        onPlaySeason()
                    }) {
                        Text("Play Upcoming Season")
                            .frame(maxWidth: .infinity)
                            .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .tint(.green)
                    .padding(.horizontal)

                    Button(action: {
                        onRestart()
                    }) {
                        Text("Back to Home")
                            .frame(maxWidth: .infinity)
                            .font(.headline.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .tint(.gray)
                    .padding(.horizontal)
                }
                .padding(.top, 20)
            }
            .padding()
        }
    }
}

/// A single labeled outcome row: name, percentage, and a filled progress bar.
struct OutcomeRow: View {
    let label: String
    let pct: Int
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    /// Draws the label and percentage with a proportional horizontal bar fill.
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(pct)%")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 15)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(pct) / 100), height: 15)
                }
            }
            .frame(height: 10)
        }
    }
}

#Preview("SeasonResultView") {
    SeasonResultView(
        odds: SeasonOdds(winTitle: 8, top4: 22, top8: 35, midTable: 28, relegation: 7, expectedPoints: 52, expectedPosition: 8),
        onRestart: {},
        onPlaySeason: {}
    )
}

#Preview("OutcomeRow") {
    OutcomeRow(label: "Win Title", pct: 45, color: .yellow)
        .padding()
}
