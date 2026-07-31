import Foundation

public enum GameConfiguration {
  public static let accuracyThresholds: [(AccuracyRating, Double)] = [
    (.perfect, 0.03), (.excellent, 0.07), (.great, 0.13), (.good, 0.20), (.close, 0.30),
  ]
  public static let baseScores: [AccuracyRating: Int] = [
    .perfect: 1000, .excellent: 750, .great: 500, .good: 300, .close: 100, .miss: 0,
  ]
  public static let comboTiers: [(Int, Double)] = [
    (50, 3.0), (35, 2.5), (20, 2.0), (10, 1.5), (5, 1.2), (0, 1.0),
  ]
  public static let chaosUnlockLevel = 12
  public static let rushDuration: TimeInterval = 60
  public static let precisionLives = 3
  public static let perfectBonusTime = 0.35
  public static let missTimePenalty = 3.0
  public static let animationDuration = 0.22
}
public enum EconomyConfiguration {
  public static let initialCoins = 250
  public static let dailyRewards = [100, 150, 200, 250, 300, 400, 750]
  public static let premiumCoinBonus = 2_500
}
public enum StoreConfiguration {
  public static let premium = "com.yourcompany.perfecttiming.premium"
  public static let cosmeticBundle = "com.yourcompany.perfecttiming.cosmeticbundle1"
  public static let smallCoins = "com.yourcompany.perfecttiming.coins.small"
  public static let mediumCoins = "com.yourcompany.perfecttiming.coins.medium"
  public static let largeCoins = "com.yourcompany.perfecttiming.coins.large"
  public static let productIDs: Set<String> = [
    premium, cosmeticBundle, smallCoins, mediumCoins, largeCoins,
  ]
  public static let coinAmounts: [String: Int] = [
    smallCoins: 1_000, mediumCoins: 3_500, largeCoins: 8_000,
  ]
}
public enum AdConfiguration {
  public static let minimumRuns = 3
  public static let runsBetweenInterstitials = 4
  public static let secondsBetweenInterstitials: TimeInterval = 120
}
public enum ExternalLinks {
  // TODO: Publish the final privacy policy at this URL.
  public static let privacy = "https://whox.ai/perfect-timing/privacy"
  public static let terms = "https://whox.ai/perfect-timing/terms"  // TODO: Publish final terms.
  public static let support = "https://whox.ai/support"  // TODO: Confirm support route.
}
