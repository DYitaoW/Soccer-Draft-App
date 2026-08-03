/// Components.swift
///
/// Small reusable label/value tiles and stat boxes shared across screens
/// (career stats, draft history, match summaries, and the home screen).
import SwiftUI

/// A bordered tile showing a large colored value above a secondary label.
/// Used to summarize season records and match scores in the shared UI.
struct TileView: View {
    let label: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// A compact two-line stat box showing a small secondary label above a bold
/// colored value. Used in tight layouts such as scorer lists and match tables.
struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
        .frame(minWidth: 28)
    }
}

#Preview("TileView") {
    TileView(label: "Finish", value: "8th", color: .blue)
        .padding()
}

#Preview("StatBox") {
    StatBox(label: "Pts", value: "72", color: .yellow)
        .padding()
}
