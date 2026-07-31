import GameKit
import PerfectTimingCore
import SwiftUI

@MainActor final class GameCenterManager: ObservableObject {
  @Published private(set) var authenticated = false
  @Published var errorMessage: String?
  static let leaderboards: [GameMode: String] = [
    .classic: "com.yourcompany.perfecttiming.classic", .rush: "com.yourcompany.perfecttiming.rush",
    .precision: "com.yourcompany.perfecttiming.precision",
    .chaos: "com.yourcompany.perfecttiming.chaos", .daily: "com.yourcompany.perfecttiming.daily",
  ]  // TODO: Replace in App Store Connect.
  func authenticate() async {
    GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
      Task { @MainActor in
        if let controller,
          let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first, let root = scene.keyWindow?.rootViewController
        {
          root.present(controller, animated: true)
        }
        self?.authenticated = GKLocalPlayer.local.isAuthenticated
        self?.errorMessage = error?.localizedDescription
      }
    }
  }
  func submit(score: Int, mode: GameMode) {
    guard authenticated, let id = Self.leaderboards[mode] else { return }
    Task {
      do {
        try await GKLeaderboard.submitScore(
          score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id])
      } catch { errorMessage = error.localizedDescription }
    }
  }
  func report(_ achievement: Achievement) {
    guard authenticated, let id = achievement.gameCenterID else { return }
    let a = GKAchievement(identifier: id)
    a.percentComplete = min(100, Double(achievement.progress) / Double(achievement.target) * 100)
    a.showsCompletionBanner = true
    GKAchievement.report([a])
  }
  func showDashboard() {
    guard authenticated else { return }
    let vc = GKGameCenterViewController(state: .dashboard)
    vc.gameCenterDelegate = GameCenterDismissDelegate.shared
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?
      .rootViewController?.present(vc, animated: true)
  }
}
@MainActor final class GameCenterDismissDelegate: NSObject, GKGameCenterControllerDelegate {
  @MainActor static let shared = GameCenterDismissDelegate()
  func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
    gameCenterViewController.dismiss(animated: true)
  }
}
