#if DEBUG
  import SwiftUI
  import PerfectTimingCore

  struct DebugView: View {
    @EnvironmentObject var app: AppCoordinator
    @State private var difficulty = DifficultyBand.beginner
    @State private var forced = ChallengeType.movingBar
    @State private var slowMotion = false
    @State private var hitboxes = false
    var body: some View {
      Form {
        Section("Progress") {
          Button("Add 10,000 Coins") {
            _ = app.save.economy.grant(10_000, reason: "DEBUG")
            app.persist()
          }
          Button("Add 25,000 XP") {
            app.save.profile.xp += 25_000
            app.save.profile.level = ProgressionManager.level(forXP: app.save.profile.xp)
            app.persist()
          }
          Button("Set Level 50") {
            app.save.profile.xp = ProgressionManager.totalXPRequired(for: 50)
            app.save.profile.level = 50
            app.persist()
          }
          Button("Unlock All Cosmetics") {
            app.save.inventory.owned = Set(CosmeticCatalog.all.map(\.id))
            app.persist()
          }
          Button("Simulate Premium") {
            app.save.premiumEntitlements.insert(StoreConfiguration.premium)
            app.persist()
          }
        }
        Section("Gameplay") {
          Picker("Difficulty", selection: $difficulty) {
            ForEach(DifficultyBand.allCases, id: \.self) { Text("\($0)").tag($0) }
          }
          Picker("Challenge", selection: $forced) {
            ForEach(ChallengeType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
          Toggle("Slow Motion", isOn: $slowMotion)
          Toggle("Show Hitboxes", isOn: $hitboxes)
          ForEach(AccuracyRating.allCases, id: \.self) { rating in
            Button("Trigger \(rating.rawValue.capitalized)") {
              app.audio.play(rating)
              app.haptics.play(rating)
            }
          }
        }
        Section("Retention") {
          Button("Reset Daily Reward") {
            app.save.dailyReward = DailyRewardState()
            app.persist()
          }
          Button("Reset Daily Challenge") {
            app.save.dailyChallenge = DailyChallengeState()
            app.persist()
          }
          Button("Simulate Ad Availability") { app.ads = MockAdService() }
        }
        Section("Data") {
          Text(String(data: (try? JSONEncoder().encode(app.save)) ?? Data(), encoding: .utf8) ?? "")
            .font(.caption2).textSelection(.enabled)
          Button("Clear Save Data", role: .destructive) { app.resetProgress() }
        }
      }.navigationTitle("Developer Panel")
    }
  }
#endif
