import PerfectTimingCore
import SwiftUI

struct RootView: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    Group {
      if !app.isLoaded {
        LaunchView()
      } else if !app.save.onboardingComplete {
        OnboardingView()
      } else {
        NavigationStack(path: $app.path) {
          HomeView().navigationDestination(for: AppCoordinator.Route.self) { route in
            destination(route)
          }
        }
      }
    }.tint(.cyan)
  }

  @ViewBuilder private func destination(_ route: AppCoordinator.Route) -> some View {
    switch route {
    case .home: HomeView()
    case .modes: ModeSelectionView()
    case .game: GameplayView()
    case .daily: DailyChallengeView()
    case .reward: DailyRewardView()
    case .missions: MissionsView()
    case .achievements: AchievementsView()
    case .shop: ShopView()
    case .inventory: InventoryView()
    case .profile: ProfileView()
    case .statistics: StatisticsView()
    case .leaderboards: LeaderboardsView()
    case .premium: PremiumView()
    case .settings: SettingsView()
    case .notifications: NotificationExplanationView()
    case .legal: LegalView()
    case .debug:
      #if DEBUG
        DebugView()
      #else
        EmptyView()
      #endif
    }
  }
}

struct LaunchView: View {
  @State private var pulse = false
  var body: some View {
    ZStack {
      NeonBackground()
      VStack(spacing: 22) {
        TargetLogo().scaleEffect(pulse ? 1.08 : 0.9)
        Text("Don’t Tap Yet!").font(.largeTitle.weight(.black))
        ProgressView().tint(.cyan)
      }.onAppear {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
      }
    }.accessibilityElement(children: .combine).accessibilityLabel("Don’t Tap Yet! loading")
  }
}

struct TargetLogo: View {
  var body: some View {
    ZStack {
      Circle().stroke(.cyan.opacity(0.25), lineWidth: 15).frame(width: 120, height: 120)
      Circle().trim(from: 0.68, to: 0.86).stroke(
        .cyan, style: StrokeStyle(lineWidth: 15, lineCap: .round)
      ).frame(width: 120, height: 120).rotationEffect(.degrees(-90)).shadow(
        color: .cyan, radius: 18)
      Capsule().fill(.white).frame(width: 6, height: 56).offset(y: -27)
    }
  }
}
