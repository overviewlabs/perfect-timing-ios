import Foundation
import Testing

@testable import PerfectTimingCore

@Test func accuracyThresholdBoundaries() {
  let evaluator = TimingAccuracyEvaluator()
  #expect(evaluator.rating(for: 0.03) == .perfect)
  #expect(evaluator.rating(for: 0.07) == .excellent)
  #expect(evaluator.rating(for: 0.13) == .great)
  #expect(evaluator.rating(for: 0.20) == .good)
  #expect(evaluator.rating(for: 0.30) == .close)
  #expect(evaluator.rating(for: 0.301) == .miss)
}

@Test func scoreIncludesConfiguredMultipliers() {
  let score = ScoreManager.points(
    rating: .perfect, combo: 20, difficulty: 1.2, speed: 1.1, mode: .classic, round: 10,
    perfectStreak: 3)
  #expect(score == 2_976)
}

@Test func comboRules() {
  var combo = ComboManager()
  combo.register(.perfect)
  combo.register(.excellent)
  combo.register(.great)
  #expect(combo.count == 3)
  combo.register(.good)
  #expect(combo.count == 2)
  combo.register(.close)
  #expect(combo.count == 0)
}

@Test func difficultyProgressesSmoothly() {
  let early = DifficultyManager.snapshot(score: 0, combo: 0, seconds: 0, failures: 0)
  let late = DifficultyManager.snapshot(score: 100_000, combo: 30, seconds: 180, failures: 0)
  #expect(early.band == .beginner)
  #expect(late.speed > early.speed)
  #expect(late.targetScale < early.targetScale)
  #expect(late.band.rawValue >= DifficultyBand.expert.rawValue)
}

@Test func levelCalculationReachesFifty() {
  #expect(ProgressionManager.level(forXP: 0) == 1)
  #expect(ProgressionManager.level(forXP: ProgressionManager.totalXPRequired(for: 50)) == 50)
  #expect(ProgressionManager.level(forXP: Int.max) == 50)
}

@Test func economyRejectsOverspendAndDuplicateReward() {
  var economy = EconomyState(balance: 250)
  let spent = economy.spend(100, reason: "theme")
  let overspent = economy.spend(1_000, reason: "invalid")
  let granted = economy.grant(100, reason: "daily", rewardID: "daily-1")
  let duplicated = economy.grant(100, reason: "daily", rewardID: "daily-1")
  #expect(spent)
  #expect(!overspent)
  #expect(granted)
  #expect(!duplicated)
  #expect(economy.balance == 250)
}

@Test func dailyChallengeSeedIsStable() {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0)!
  let date = Date(timeIntervalSince1970: 1_767_225_600)
  #expect(
    DailyChallengeManager.seed(for: date, calendar: calendar)
      == DailyChallengeManager.seed(for: date, calendar: calendar))
  #expect(
    DailyChallengeManager.seed(for: date, calendar: calendar)
      != DailyChallengeManager.seed(for: date.addingTimeInterval(86_400), calendar: calendar))
}

@Test func dailyRewardCannotBeClaimedTwice() {
  var state = DailyRewardState()
  let now = Date(timeIntervalSince1970: 1_767_225_600)
  let first = DailyRewardManager.claim(
    state: &state, now: now, calendar: Calendar(identifier: .gregorian))
  let second = DailyRewardManager.claim(
    state: &state, now: now, calendar: Calendar(identifier: .gregorian))
  #expect(first != nil)
  #expect(second == nil)
}

@Test func missionProgressCompletesAndClaimsOnce() {
  var mission = Mission(
    id: "p10", title: "Perfect 10", detail: "Get 10 Perfect taps", metric: .perfectTaps, target: 10,
    rewardCoins: 100, expiration: .daily)
  mission.addProgress(10)
  #expect(mission.isComplete)
  let firstClaim = mission.claim()
  let secondClaim = mission.claim()
  #expect(firstClaim)
  #expect(!secondClaim)
}

@Test func achievementProgressCompletes() {
  var achievement = Achievement(
    id: "first", title: "First Tap", detail: "Tap once", metric: .totalTaps, target: 1,
    rewardCoins: 25)
  achievement.update(to: 1)
  #expect(achievement.isComplete)
}

@Test func saveMigrationPreservesPremium() throws {
  let legacy = PlayerSaveData(
    version: 1, profile: .default, economy: EconomyState(balance: 42),
    premiumEntitlements: ["premium"])
  let migrated = SaveMigrator.migrate(legacy)
  #expect(migrated.version == PlayerSaveData.currentVersion)
  #expect(migrated.premiumEntitlements.contains("premium"))
  #expect(migrated.economy.balance == 42)
}

@Test func adCooldownRequiresRunsAndTime() {
  let now = Date(timeIntervalSince1970: 1_000)
  var state = AdFrequencyState(completedRuns: 2)
  #expect(!AdCooldownPolicy.isInterstitialEligible(state: state, premium: false, now: now))
  state.completedRuns = 4
  state.lastInterstitialAt = Date(timeIntervalSince1970: 950)
  #expect(!AdCooldownPolicy.isInterstitialEligible(state: state, premium: false, now: now))
  state.lastInterstitialAt = Date(timeIntervalSince1970: 800)
  #expect(AdCooldownPolicy.isInterstitialEligible(state: state, premium: false, now: now))
  #expect(!AdCooldownPolicy.isInterstitialEligible(state: state, premium: true, now: now))
}

@Test func reviveEligibilityIsOncePerRun() {
  var revive = ReviveState()
  #expect(revive.canRevive(hasFreeRevive: true, rewardedAdAvailable: false))
  revive.use()
  #expect(!revive.canRevive(hasFreeRevive: true, rewardedAdAvailable: true))
}
