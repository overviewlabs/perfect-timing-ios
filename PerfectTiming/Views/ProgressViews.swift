import Charts
import GameKit
import PerfectTimingCore
import SwiftUI

struct DailyChallengeView: View {
  @EnvironmentObject var app: AppCoordinator
  var mode: GameMode { DailyChallengeManager.mode(for: Date()) }
  var body: some View {
    ZStack {
      NeonBackground()
      VStack(spacing: 22) {
        Image(systemName: "calendar.badge.clock").font(.system(size: 72)).foregroundStyle(.cyan)
        Text("Today’s Challenge").font(.largeTitle.black)
        Text(mode.rawValue.capitalized).font(.title2.bold)
        Text("A deterministic challenge shared by every player today.").multilineTextAlignment(
          .center
        ).foregroundStyle(.secondary)
        NeonCard {
          VStack {
            Text("Local Best").font(.caption)
            Text(app.save.dailyChallenge.bestScore.formatted()).font(.largeTitle.black)
          }
        }
        Button(
          app.save.dailyChallenge.officialAttemptUsed
            ? "Practice Today’s Seed" : "Start Official Attempt"
        ) {
          if !app.save.dailyChallenge.officialAttemptUsed {
            app.save.dailyChallenge.officialAttemptUsed = true
            app.persist()
          }
          app.start(.daily)
        }.buttonStyle(PrimaryButtonStyle())
        Text("Seed \(DailyChallengeManager.seed(for:Date()))").font(.caption2).foregroundStyle(
          .secondary)
      }.padding()
    }.navigationTitle("Daily Challenge")
  }
}
struct DailyRewardView: View {
  @EnvironmentObject var app: AppCoordinator
  @State private var claimed: Int?
  var body: some View {
    ZStack {
      NeonBackground()
      VStack(spacing: 22) {
        Text("Daily Rewards").font(.largeTitle.black)
        HStack {
          ForEach(0..<7) { i in
            VStack {
              Text("Day \(i+1)").font(.caption2)
              Image(systemName: i == 6 ? "gift.fill" : "circle.hexagongrid.fill")
              Text(EconomyConfiguration.dailyRewards[i].formatted()).font(.caption.bold())
            }.foregroundStyle(i + 1 == app.save.dailyReward.streak ? .cyan : .white).padding(7)
              .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
          }
        }.minimumScaleFactor(0.65)
        if let claimed {
          Text("+\(claimed) Timing Coins").font(.title.bold()).foregroundStyle(.cyan)
        }
        Button("Claim Today’s Reward") {
          var state = app.save.dailyReward
          if let reward = DailyRewardManager.claim(state: &state, now: Date(), calendar: .current) {
            app.save.dailyReward = state
            _ = app.save.economy.grant(
              reward, reason: "Daily reward",
              rewardID: "daily-\(DailyChallengeManager.dayKey(for:Date()))")
            claimed = reward
            app.persist()
            app.haptics.reward()
          }
        }.buttonStyle(PrimaryButtonStyle())
      }.padding()
    }.navigationTitle("Daily Reward")
  }
}
struct MissionsView: View {
  @EnvironmentObject var app: AppCoordinator
  var missions: [Mission] {
    app.save.missions.isEmpty
      ? MissionManager.generated(for: Date(), weekly: false) : app.save.missions
  }
  var body: some View {
    ZStack {
      NeonBackground()
      List(missions) { m in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(m.title).font(.headline)
            Spacer()
            Text("+\(m.rewardCoins) ◉").foregroundStyle(.cyan)
          }
          Text(m.detail).font(.caption).foregroundStyle(.secondary)
          ProgressView(value: Double(m.progress), total: Double(m.target))
          Text("\(m.progress)/\(m.target)").font(.caption2)
        }
      }.scrollContentBackground(.hidden)
    }.navigationTitle("Missions")
  }
}
struct AchievementsView: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    ZStack {
      NeonBackground()
      List(app.save.achievements) { a in
        HStack {
          Image(systemName: a.isComplete ? "trophy.fill" : "lock.circle").foregroundStyle(
            a.isComplete ? .yellow : .secondary)
          VStack(alignment: .leading) {
            Text(a.hidden && !a.isComplete ? "Hidden Achievement" : a.title).font(.headline)
            Text(a.hidden && !a.isComplete ? "Keep playing to discover it." : a.detail).font(
              .caption
            ).foregroundStyle(.secondary)
            ProgressView(value: Double(a.progress), total: Double(a.target))
          }
          Spacer()
          Text("+\(a.rewardCoins)").font(.caption).foregroundStyle(.cyan)
        }
      }.scrollContentBackground(.hidden)
    }.navigationTitle("Achievements")
  }
}
struct StatisticsView: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    ZStack {
      NeonBackground()
      ScrollView {
        VStack(spacing: 14) {
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
            stat("Total Taps", app.save.statistics.totalTaps)
            stat("Runs", app.save.statistics.totalRuns)
            stat("Best Combo", app.save.statistics.highestCombo)
            stat("Play Time", Int(app.save.statistics.totalPlayTime))
          }
          NeonCard {
            Chart(AccuracyRating.allCases, id: \.self) { r in
              BarMark(
                x: .value("Rating", r.rawValue.capitalized),
                y: .value("Count", app.save.statistics.ratings[r, default: 0])
              ).foregroundStyle(.cyan.gradient)
            }.frame(height: 240)
          }
          NeonCard {
            Chart(GameMode.allCases, id: \.self) { m in
              SectorMark(
                angle: .value("Runs", app.save.statistics.perMode[m]?.runs ?? 0),
                innerRadius: .ratio(0.55)
              ).foregroundStyle(by: .value("Mode", m.rawValue))
            }.frame(height: 220)
          }
        }.padding()
      }
    }.navigationTitle("Statistics")
  }
  @ViewBuilder private func stat(_ title: String, _ value: Int) -> some View {
    NeonCard {
      VStack {
        Text(value.formatted()).font(.title.bold())
        Text(title).font(.caption).foregroundStyle(.secondary)
      }.frame(maxWidth: .infinity)
    }
  }
}
struct LeaderboardsView: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    ZStack {
      NeonBackground()
      VStack(spacing: 22) {
        Image(systemName: "crown.fill").font(.system(size: 70)).foregroundStyle(.yellow)
        Text(app.gameCenter.authenticated ? "Game Center Connected" : "Game Center Offline").font(
          .title.bold)
        Text("Perfect Timing remains fully playable offline.").foregroundStyle(.secondary)
        Button("Open Game Center") { app.gameCenter.showDashboard() }.buttonStyle(
          PrimaryButtonStyle()
        ).disabled(!app.gameCenter.authenticated)
      }.padding()
    }.navigationTitle("Leaderboards")
  }
}
struct ProfileView: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    ZStack {
      NeonBackground()
      VStack(spacing: 22) {
        Image(systemName: "person.crop.circle.fill").font(.system(size: 90)).foregroundStyle(.cyan)
        Text("Level \(app.save.profile.level)").font(.largeTitle.black)
        Text(app.save.profile.title).foregroundStyle(.secondary)
        NeonCard {
          VStack {
            HStack {
              Text("XP")
              Spacer()
              Text(app.save.profile.xp.formatted())
            }
            ProgressBar(
              progress: Double(
                app.save.profile.xp
                  - ProgressionManager.totalXPRequired(for: app.save.profile.level))
                / Double(
                  max(
                    1,
                    ProgressionManager.totalXPRequired(for: min(50, app.save.profile.level + 1))
                      - ProgressionManager.totalXPRequired(for: app.save.profile.level))))
          }.frame(height: 40)
        }
        StatPill(icon: "circle.hexagongrid.fill", value: app.save.economy.balance.formatted())
        Spacer()
      }.padding()
    }.navigationTitle("Player Profile")
  }
}
