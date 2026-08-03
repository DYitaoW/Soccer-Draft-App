/// Formatting.swift
///
/// Shared formatting and styling helpers used across screens: ordinal text,
/// goal-difference text, and adaptive scrim colors for modal overlays.

import SwiftUI

/// Formats an integer as an ordinal string (1 -> "1st", 2 -> "2nd", ...).
/// - Parameter n: The number to format.
/// - Returns: The number with its English ordinal suffix.
func ordinal(_ n: Int) -> String {
    let suffix: String
    if (11...13).contains(n % 100) { suffix = "th" } else {
        switch n % 10 {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
    }
    return "\(n)\(suffix)"
}

/// Formats a goal-difference value with an explicit "+" prefix for
/// non-negative values (e.g. "+3", "0", "-2").
/// - Parameter gd: The goal difference to format.
/// - Returns: The formatted goal-difference string.
func gdText(_ gd: Int) -> String {
    gd >= 0 ? "+\(gd)" : "\(gd)"
}

/// Returns the scrim color used behind modal overlays, adapted to the color
/// scheme (darker in dark mode for more separation).
/// - Parameter scheme: The current color scheme.
/// - Returns: The overlay scrim color.
func adaptiveOverlayColor(for scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.35)
}
