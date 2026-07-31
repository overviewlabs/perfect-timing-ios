import Foundation

public enum GameMode: String, Codable, CaseIterable, Sendable {
  case classic, rush, precision, chaos, daily, practice
  public var scoreMultiplier: Double {
    switch self {
    case .classic, .daily, .practice: 1
    case .rush: 0.9
    case .precision: 1.35
    case .chaos: 1.5
    }
  }
}

public enum ChallengeType: String, Codable, CaseIterable, Sendable {
  case movingBar, verticalDrop, rotatingNeedle, expandingRing, contractingRing, bouncingMarker,
    dualMarker, pulseTiming
}

public enum AccuracyRating: String, Codable, CaseIterable, Sendable {
  case perfect, excellent, great, good, close, miss
}

public enum DifficultyBand: Int, Codable, CaseIterable, Comparable, Sendable {
  case beginner, easy, normal, hard, expert, insane
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct DifficultySnapshot: Codable, Equatable, Sendable {
  public var band: DifficultyBand
  public var speed: Double
  public var acceleration: Double
  public var targetScale: Double
  public var duration: Double
  public var targetMovement: Double
  public var directionChangeChance: Double
  public var objectCount: Int
  public var fakeTargets: Int
  public var distractionIntensity: Double
  public init(
    band: DifficultyBand, speed: Double, acceleration: Double, targetScale: Double,
    duration: Double, targetMovement: Double, directionChangeChance: Double,
    objectCount: Int, fakeTargets: Int, distractionIntensity: Double
  ) {
    self.band = band
    self.speed = speed
    self.acceleration = acceleration
    self.targetScale = targetScale
    self.duration = duration
    self.targetMovement = targetMovement
    self.directionChangeChance = directionChangeChance
    self.objectCount = objectCount
    self.fakeTargets = fakeTargets
    self.distractionIntensity = distractionIntensity
  }
}

public struct PlayerProfile: Codable, Equatable, Sendable {
  public var level: Int
  public var xp: Int
  public var title: String
  public var freeRevives: Int
  public static let `default` = PlayerProfile(
    level: 1, xp: 0, title: "Perfect Rookie", freeRevives: 1)
}

public struct AppSettings: Codable, Equatable, Sendable {
  public var musicVolume: Double = 0.35
  public var effectsVolume: Double = 0.8
  public var haptics = true
  public var muteAll = false
  public var reducedMotion = false
  public var highContrast = false
  public var screenShake = true
  public var particleIntensity: Double = 1
  public var showAccuracyPercentage = true
  public var notificationsEnabled = false
  public init() {}
}

public struct ModeStatistics: Codable, Equatable, Sendable {
  public var runs = 0
  public var highScore = 0
  public var totalScore = 0
  public var playTime: TimeInterval = 0
  public init() {}
}

public struct LifetimeStatistics: Codable, Equatable, Sendable {
  public var totalTaps = 0
  public var totalRuns = 0
  public var ratings: [AccuracyRating: Int] = [:]
  public var highestCombo = 0
  public var totalPlayTime: TimeInterval = 0
  public var dailyChallengesCompleted = 0
  public var coinsEarned = 0
  public var coinsSpent = 0
  public var revivesUsed = 0
  public var longestDailyStreak = 0
  public var perMode: [GameMode: ModeStatistics] = [:]
  public init() {}
}

public struct TransactionRecord: Codable, Equatable, Sendable, Identifiable {
  public let id: UUID
  public let amount: Int
  public let reason: String
  public let date: Date
  public init(id: UUID = UUID(), amount: Int, reason: String, date: Date = Date()) {
    self.id = id
    self.amount = amount
    self.reason = reason
    self.date = date
  }
}

public struct EconomyState: Codable, Equatable, Sendable {
  public private(set) var balance: Int
  public private(set) var transactions: [TransactionRecord]
  public private(set) var claimedRewardIDs: Set<String>
  public init(
    balance: Int = EconomyConfiguration.initialCoins, transactions: [TransactionRecord] = [],
    claimedRewardIDs: Set<String> = []
  ) {
    self.balance = max(0, balance)
    self.transactions = transactions
    self.claimedRewardIDs = claimedRewardIDs
  }
  @discardableResult public mutating func grant(
    _ amount: Int, reason: String, rewardID: String? = nil
  ) -> Bool {
    guard amount > 0 else { return false }
    if let rewardID {
      guard !claimedRewardIDs.contains(rewardID) else { return false }
      claimedRewardIDs.insert(rewardID)
    }
    balance = min(Int.max - amount, balance) + amount
    transactions.append(TransactionRecord(amount: amount, reason: reason))
    return true
  }
  @discardableResult public mutating func spend(_ amount: Int, reason: String) -> Bool {
    guard amount > 0, balance >= amount else { return false }
    balance -= amount
    transactions.append(TransactionRecord(amount: -amount, reason: reason))
    return true
  }
}

public enum MissionMetric: String, Codable, Sendable {
  case perfectTaps, combo, runs, score, dailyChallenge, coinsEarned, level, themesUnlocked,
    roundsSurvived, cleanRounds, totalTaps
}
public enum MissionExpiration: String, Codable, Sendable { case daily, weekly, lifetime }
public struct Mission: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var title: String
  public var detail: String
  public var metric: MissionMetric
  public var target: Int
  public var progress = 0
  public var rewardCoins: Int
  public var expiration: MissionExpiration
  public var claimed = false
  public var isComplete: Bool { progress >= target }
  public init(
    id: String, title: String, detail: String, metric: MissionMetric, target: Int, rewardCoins: Int,
    expiration: MissionExpiration
  ) {
    self.id = id
    self.title = title
    self.detail = detail
    self.metric = metric
    self.target = target
    self.rewardCoins = rewardCoins
    self.expiration = expiration
  }
  public mutating func addProgress(_ amount: Int) {
    progress = min(target, max(0, progress + amount))
  }
  @discardableResult public mutating func claim() -> Bool {
    guard isComplete, !claimed else { return false }
    claimed = true
    return true
  }
}

public struct Achievement: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var title: String
  public var detail: String
  public var metric: MissionMetric
  public var target: Int
  public var progress = 0
  public var rewardCoins: Int
  public var hidden = false
  public var gameCenterID: String?
  public var isComplete: Bool { progress >= target }
  public init(
    id: String, title: String, detail: String, metric: MissionMetric, target: Int, rewardCoins: Int,
    hidden: Bool = false, gameCenterID: String? = nil
  ) {
    self.id = id
    self.title = title
    self.detail = detail
    self.metric = metric
    self.target = target
    self.rewardCoins = rewardCoins
    self.hidden = hidden
    self.gameCenterID = gameCenterID
  }
  public mutating func update(to value: Int) { progress = min(target, max(progress, value)) }
}

public struct DailyRewardState: Codable, Equatable, Sendable {
  public var lastClaimDate: Date?
  public var streak = 0
  public var lastKnownDate: Date?
  public init() {}
}
public struct DailyChallengeState: Codable, Equatable, Sendable {
  public var dayKey = ""
  public var officialAttemptUsed = false
  public var rewardClaimed = false
  public var bestScore = 0
  public init() {}
}
public struct AdFrequencyState: Codable, Equatable, Sendable {
  public var completedRuns: Int
  public var runsAtLastInterstitial: Int
  public var lastInterstitialAt: Date?
  public init(
    completedRuns: Int = 0, runsAtLastInterstitial: Int = 0, lastInterstitialAt: Date? = nil
  ) {
    self.completedRuns = completedRuns
    self.runsAtLastInterstitial = runsAtLastInterstitial
    self.lastInterstitialAt = lastInterstitialAt
  }
}
public struct ReviveState: Codable, Equatable, Sendable {
  public private(set) var used = false
  public init() {}
  public func canRevive(hasFreeRevive: Bool, rewardedAdAvailable: Bool) -> Bool {
    !used && (hasFreeRevive || rewardedAdAvailable)
  }
  public mutating func use() { used = true }
}

public enum CosmeticCategory: String, Codable, CaseIterable, Sendable {
  case theme, marker, trail, tapEffect, particle, badge, gameOver
}
public enum CosmeticRarity: String, Codable, Sendable {
  case common, rare, epic, legendary, premium
}
public struct CosmeticItem: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let name: String
  public let detail: String
  public let category: CosmeticCategory
  public let rarity: CosmeticRarity
  public let coinPrice: Int
  public let premium: Bool
  public let unlockLevel: Int
  public let previewHex: String
  public init(
    id: String, name: String, detail: String, category: CosmeticCategory,
    rarity: CosmeticRarity, coinPrice: Int, premium: Bool, unlockLevel: Int,
    previewHex: String
  ) {
    self.id = id
    self.name = name
    self.detail = detail
    self.category = category
    self.rarity = rarity
    self.coinPrice = coinPrice
    self.premium = premium
    self.unlockLevel = unlockLevel
    self.previewHex = previewHex
  }
}
public struct CosmeticInventory: Codable, Equatable, Sendable {
  public var owned: Set<String> = ["theme.neonBlue", "marker.orb", "trail.spark"]
  public var equipped: [CosmeticCategory: String] = [
    .theme: "theme.neonBlue", .marker: "marker.orb", .trail: "trail.spark",
  ]
  public init() {}
}

public struct PendingScore: Codable, Equatable, Sendable, Identifiable {
  public var id = UUID()
  public var leaderboardID: String
  public var score: Int
  public var date = Date()
}

public struct PlayerSaveData: Codable, Equatable, Sendable {
  public static let currentVersion = 3
  public var version: Int
  public var profile: PlayerProfile
  public var economy: EconomyState
  public var settings: AppSettings
  public var statistics: LifetimeStatistics
  public var inventory: CosmeticInventory
  public var missions: [Mission]
  public var achievements: [Achievement]
  public var dailyReward: DailyRewardState
  public var dailyChallenge: DailyChallengeState
  public var premiumEntitlements: Set<String>
  public var pendingScores: [PendingScore]
  public var onboardingComplete: Bool
  public var adFrequency: AdFrequencyState
  public init(
    version: Int = currentVersion, profile: PlayerProfile = .default,
    economy: EconomyState = EconomyState(), settings: AppSettings = AppSettings(),
    statistics: LifetimeStatistics = LifetimeStatistics(),
    inventory: CosmeticInventory = CosmeticInventory(), missions: [Mission] = [],
    achievements: [Achievement] = [], dailyReward: DailyRewardState = DailyRewardState(),
    dailyChallenge: DailyChallengeState = DailyChallengeState(),
    premiumEntitlements: Set<String> = [], pendingScores: [PendingScore] = [],
    onboardingComplete: Bool = false, adFrequency: AdFrequencyState = AdFrequencyState()
  ) {
    self.version = version
    self.profile = profile
    self.economy = economy
    self.settings = settings
    self.statistics = statistics
    self.inventory = inventory
    self.missions = missions
    self.achievements = achievements
    self.dailyReward = dailyReward
    self.dailyChallenge = dailyChallenge
    self.premiumEntitlements = premiumEntitlements
    self.pendingScores = pendingScores
    self.onboardingComplete = onboardingComplete
    self.adFrequency = adFrequency
  }
}
