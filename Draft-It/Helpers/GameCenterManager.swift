/// GameCenterManager.swift
///
/// Manages Game Center player authentication, leaderboard score submissions,
/// achievement reporting, and dashboard view controller presentation.
import Foundation
import Combine
import GameKit
import SwiftUI
import UIKit

@MainActor
final class GameCenterManager: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterManager()

    @Published var isAuthenticated: Bool = false
    @Published var localPlayerName: String = ""

    override private init() {
        super.init()
    }

    /// Authenticates the local player with Game Center.
    func authenticateLocalPlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            DispatchQueue.main.async {
                if let vc = vc {
                    Self.presentViewController(vc)
                } else if GKLocalPlayer.local.isAuthenticated {
                    self?.isAuthenticated = true
                    self?.localPlayerName = GKLocalPlayer.local.alias
                    self?.syncCurrentCareerStats()
                } else {
                    self?.isAuthenticated = false
                    if let error = error {
                        print("Game Center auth error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Reports lifetime career stats to Game Center leaderboards and achievements.
    func reportCareerStats(_ stats: CareerStats) {
        guard GKLocalPlayer.local.isAuthenticated else { return }

        let leaderboards: [(String, Int)] = [
            ("draftit.leaderboard.total_wins", stats.bestRecord?.wins ?? 0),
            ("draftit.leaderboard.seasons_played", stats.totalSeasons),
            ("draftit.leaderboard.league_titles", stats.titles),
            ("draftit.leaderboard.most_goals", stats.mostGoalsFor),
            ("draftit.leaderboard.super_league_titles", stats.superLeagueCupsWon)
        ]

        for (id, value) in leaderboards {
            GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id]) { error in
                if let error = error {
                    print("Game Center leaderboard \(id) error: \(error.localizedDescription)")
                }
            }
        }

        syncAchievements(stats: stats)
    }

    /// Helper to sync loaded career stats.
    func syncCurrentCareerStats() {
        let stats = CareerStats.load()
        reportCareerStats(stats)
    }

    /// Syncs unlocked achievements with Game Center.
    private func syncAchievements(stats: CareerStats) {
        var achievements: [GKAchievement] = []

        if stats.titles >= 1 {
            let a = GKAchievement(identifier: "draftit.achievement.champion")
            a.percentComplete = 100.0
            a.showsCompletionBanner = true
            achievements.append(a)
        }
        if stats.perfectSeasons >= 1 {
            let a = GKAchievement(identifier: "draftit.achievement.invincible")
            a.percentComplete = 100.0
            a.showsCompletionBanner = true
            achievements.append(a)
        }
        if stats.superLeagueCupsWon >= 1 {
            let a = GKAchievement(identifier: "draftit.achievement.super_champion")
            a.percentComplete = 100.0
            a.showsCompletionBanner = true
            achievements.append(a)
        }

        if !achievements.isEmpty {
            GKAchievement.report(achievements) { error in
                if let error = error {
                    print("Game Center achievements error: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Reports a single achievement by ID.
    func reportAchievement(id: String, percent: Double = 100.0) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percent
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("Game Center report achievement \(id) error: \(error.localizedDescription)")
            }
        }
    }

    /// Presents the native Game Center dashboard UI.
    func presentDashboard(state: GKGameCenterViewControllerState = .default) {
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticateLocalPlayer()
            return
        }
        let gcVC = GKGameCenterViewController(state: state)
        gcVC.gameCenterDelegate = self
        Self.presentViewController(gcVC)
    }

    // MARK: - GKGameCenterControllerDelegate

    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        DispatchQueue.main.async {
            gameCenterViewController.dismiss(animated: true)
        }
    }

    // MARK: - Presentation Helper

    private static func presentViewController(_ vc: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(vc, animated: true)
    }
}
