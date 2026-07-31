import Foundation

public struct TimingAccuracyEvaluator: Sendable {
  public init() {}
  public func rating(for normalizedDistance: Double) -> AccuracyRating {
    let value = abs(normalizedDistance)
    for (rating, threshold) in GameConfiguration.accuracyThresholds where value <= threshold {
      return rating
    }
    return .miss
  }
}

public enum ScoreManager {
  public static func comboMultiplier(for combo: Int) -> Double {
    GameConfiguration.comboTiers.first(where: { combo >= $0.0 })?.1 ?? 1
  }
  public static func points(
    rating: AccuracyRating, combo: Int, difficulty: Double, speed: Double, mode: GameMode,
    round: Int, perfectStreak: Int
  ) -> Int {
    let base = Double(GameConfiguration.baseScores[rating, default: 0])
    guard base > 0 else { return 0 }
    let scaled =
      base * comboMultiplier(for: combo) * max(1, difficulty) * max(1, speed) * mode.scoreMultiplier
    let roundBonus = max(0, round) * 3
    let streakBonus = rating == .perfect ? max(0, perfectStreak) * 102 : 0
    return Int(scaled.rounded()) + roundBonus + streakBonus
  }
}

public struct ComboManager: Codable, Equatable, Sendable {
  public private(set) var count = 0
  public private(set) var perfectStreak = 0
  public init() {}
  public var multiplier: Double { ScoreManager.comboMultiplier(for: count) }
  public mutating func register(_ rating: AccuracyRating) {
    switch rating {
    case .perfect:
      count += 1
      perfectStreak += 1
    case .excellent, .great:
      count += 1
      perfectStreak = 0
    case .good:
      count = max(0, count - 1)
      perfectStreak = 0
    case .close, .miss:
      count = 0
      perfectStreak = 0
    }
  }
}

public enum DifficultyManager {
  public static func snapshot(score: Int, combo: Int, seconds: TimeInterval, failures: Int)
    -> DifficultySnapshot
  {
    let raw = min(
      1, Double(max(0, score)) / 120_000 + Double(max(0, combo)) / 160 + max(0, seconds) / 600)
    let adaptive = min(0.12, Double(max(0, failures)) * 0.025)
    let d = max(0, raw - adaptive)
    let band = DifficultyBand(rawValue: min(5, Int(d * 6))) ?? .insane
    return DifficultySnapshot(
      band: band, speed: 0.75 + d * 1.9, acceleration: d * 0.18, targetScale: 1 - d * 0.62,
      duration: 3.2 - d * 1.5, targetMovement: max(0, (d - 0.25) * 0.8),
      directionChangeChance: max(0, (d - 0.35) * 0.45), objectCount: d > 0.72 ? 2 : 1,
      fakeTargets: d > 0.58 ? Int(d * 3) : 0, distractionIntensity: max(0, (d - 0.45) * 1.2))
  }
}

public enum ProgressionManager {
  public static func xpRequired(for level: Int) -> Int {
    guard level > 1 else { return 0 }
    return 400 + (level - 2) * 125 + (level - 2) * (level - 2) * 8
  }
  public static func totalXPRequired(for level: Int) -> Int {
    guard level > 1 else { return 0 }
    return (2...min(level, 50)).reduce(0) { $0 + xpRequired(for: $1) }
  }
  public static func level(forXP xp: Int) -> Int {
    for level in 2...50 where xp < totalXPRequired(for: level) { return level - 1 }
    return 50
  }
  public static func rewards(for level: Int) -> (coins: Int, unlock: String?) {
    (100 + level * 25, level == 12 ? "Chaos Mode" : level % 5 == 0 ? "Level \(level) Badge" : nil)
  }
}

public enum DailyChallengeManager {
  public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }
  public static func seed(for date: Date, calendar: Calendar = .current) -> UInt64 {
    dayKey(for: date, calendar: calendar).utf8.reduce(1_469_598_103_934_665_603) {
      ($0 ^ UInt64($1)) &* 1_099_511_628_211
    }
  }
  public static func mode(for date: Date, calendar: Calendar = .current) -> GameMode {
    let modes: [GameMode] = [.classic, .rush, .precision, .chaos]
    return modes[Int(seed(for: date, calendar: calendar) % UInt64(modes.count))]
  }
}

public enum DailyRewardManager {
  public static func claim(state: inout DailyRewardState, now: Date, calendar: Calendar) -> Int? {
    if let last = state.lastClaimDate, calendar.isDate(last, inSameDayAs: now) { return nil }
    if let known = state.lastKnownDate, now < known.addingTimeInterval(-300) {
      state.lastKnownDate = max(known, now)
      return nil
    }
    if let last = state.lastClaimDate,
      let days = calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)
      ).day, days == 1
    {
      state.streak = state.streak % 7 + 1
    } else {
      state.streak = 1
    }
    state.lastClaimDate = now
    state.lastKnownDate = max(state.lastKnownDate ?? now, now)
    return EconomyConfiguration.dailyRewards[state.streak - 1]
  }
}

public enum MissionManager {
  public static func generated(for date: Date, weekly: Bool, calendar: Calendar = .current)
    -> [Mission]
  {
    let seed = DailyChallengeManager.seed(for: date, calendar: calendar) ^ (weekly ? 0xABCDEF : 0)
    let templates: [Mission] = [
      Mission(
        id: "perfect", title: "Perfect Rhythm", detail: "Get Perfect taps", metric: .perfectTaps,
        target: weekly ? 75 : 10, rewardCoins: weekly ? 500 : 100,
        expiration: weekly ? .weekly : .daily),
      Mission(
        id: "combo", title: "Keep It Going", detail: "Reach a combo", metric: .combo,
        target: weekly ? 35 : 15, rewardCoins: weekly ? 600 : 150,
        expiration: weekly ? .weekly : .daily),
      Mission(
        id: "runs", title: "One More Try", detail: "Complete runs", metric: .runs,
        target: weekly ? 20 : 3, rewardCoins: weekly ? 450 : 100,
        expiration: weekly ? .weekly : .daily),
      Mission(
        id: "score", title: "Score Hunter", detail: "Earn score", metric: .score,
        target: weekly ? 150_000 : 25_000, rewardCoins: weekly ? 700 : 200,
        expiration: weekly ? .weekly : .daily),
    ]
    let offset = Int(seed % UInt64(templates.count))
    return (0..<3).map {
      var m = templates[($0 + offset) % templates.count]
      m.id +=
        "-" + DailyChallengeManager.dayKey(for: date, calendar: calendar) + (weekly ? "-w" : "")
      return m
    }
  }
}

public enum AchievementManager {
  public static let defaults: [Achievement] = {
    let specs: [(String, String, MissionMetric, Int, Int)] = [
      ("firstTap", "First Tap", .totalTaps, 1, 25),
      ("firstPerfect", "Perfect Start", .perfectTaps, 1, 50),
      ("perfect10", "Ten Perfects", .perfectTaps, 10, 100),
      ("perfect100", "Century of Precision", .perfectTaps, 100, 300),
      ("combo5", "Combo Apprentice", .combo, 5, 50), ("combo20", "Combo Master", .combo, 20, 200),
      ("combo50", "Combo Legend", .combo, 50, 750),
      ("score10k", "Five Digits", .score, 10_000, 100),
      ("score100k", "Six Digits", .score, 100_000, 500),
      ("level10", "Rising Star", .level, 10, 250), ("level25", "Timing Pro", .level, 25, 750),
      ("level50", "Perfect Legend", .level, 50, 2_000),
      ("themes5", "Style Collector", .themesUnlocked, 5, 300),
      ("daily1", "Daily Challenger", .dailyChallenge, 1, 100),
      ("daily30", "Daily Devotee", .dailyChallenge, 30, 1_000),
      ("streak7", "Seven-Day Streak", .runs, 7, 250),
      ("precision", "Precision Expert", .score, 40_000, 400),
      ("chaos", "Chaos Survivor", .roundsSurvived, 30, 500),
      ("rush", "Rush Champion", .score, 50_000, 500), ("runs100", "Persistent", .runs, 100, 600),
      ("runs1000", "Unstoppable", .runs, 1_000, 2_000),
      ("taps1000", "Tap Machine", .totalTaps, 1_000, 500),
      ("taps10000", "Tap Titan", .totalTaps, 10_000, 2_000),
      ("coins", "Coin Collector", .coinsEarned, 10_000, 750),
      ("clean", "Flawless Five", .cleanRounds, 5, 300),
    ]
    return specs.map {
      Achievement(
        id: $0.0, title: $0.1, detail: "Reach \($0.3)", metric: $0.2, target: $0.3,
        rewardCoins: $0.4, gameCenterID: "com.yourcompany.perfecttiming.achievement.\($0.0)")
    }
  }()
}

public enum AdCooldownPolicy {
  public static func isInterstitialEligible(state: AdFrequencyState, premium: Bool, now: Date)
    -> Bool
  {
    guard !premium, state.completedRuns >= AdConfiguration.minimumRuns,
      state.completedRuns - state.runsAtLastInterstitial >= AdConfiguration.runsBetweenInterstitials
    else { return false }
    guard let last = state.lastInterstitialAt else { return true }
    return now.timeIntervalSince(last) >= AdConfiguration.secondsBetweenInterstitials
  }
}
