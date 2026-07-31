import PerfectTimingCore
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
  enum Route: Hashable {
    case home, modes
    case game(GameMode)
    case daily, reward, missions, achievements, shop, inventory, profile, statistics, leaderboards
    case premium, settings, notifications, legal, debug
  }

  @Published var path: [Route] = []
  @Published var save = PlayerSaveData(achievements: AchievementManager.defaults)
  @Published var isLoaded = false
  @Published var activeSession: GameSession?

  let persistence: any PersistenceService
  let audio: AudioManager
  let haptics: HapticManager
  let store: StoreManager
  let gameCenter: GameCenterManager
  let notifications: NotificationManager
  var ads: any AdService

  init(
    persistence: any PersistenceService, audio: AudioManager, haptics: HapticManager,
    store: StoreManager, gameCenter: GameCenterManager, notifications: NotificationManager,
    ads: any AdService
  ) {
    self.persistence = persistence
    self.audio = audio
    self.haptics = haptics
    self.store = store
    self.gameCenter = gameCenter
    self.notifications = notifications
    self.ads = ads
    Task { await bootstrap() }
  }

  static func live() -> AppCoordinator {
    AppCoordinator(
      persistence: JSONPersistenceService(), audio: AudioManager(), haptics: HapticManager(),
      store: StoreManager(), gameCenter: GameCenterManager(), notifications: NotificationManager(),
      ads: MockAdService())
  }

  func bootstrap() async {
    save = await persistence.load()
    applyLaunchArguments()
    refreshDailyContent()
    audio.apply(save.settings)
    haptics.enabled = save.settings.haptics
    isLoaded = true
    await store.start { [weak self] identifiers in
      guard let self else { return }
      self.save.premiumEntitlements = identifiers
      self.applyPremiumUnlocksIfNeeded()
      self.persist()
    }
    await ads.loadInterstitial()
    await ads.loadRewarded()
    await gameCenter.authenticate()
  }

  private func applyLaunchArguments() {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--uitesting") {
      save = PlayerSaveData(achievements: AchievementManager.defaults)
      if arguments.contains("--skip-onboarding") { save.onboardingComplete = true }
      if arguments.contains("--reset-onboarding") { save.onboardingComplete = false }
    }
  }

  private func refreshDailyContent(now: Date = Date()) {
    let key = DailyChallengeManager.dayKey(for: now)
    if save.dailyChallenge.dayKey != key {
      save.dailyChallenge = DailyChallengeState()
      save.dailyChallenge.dayKey = key
    }
    let hasCurrentMissions = save.missions.contains { $0.id.contains(key) }
    if !hasCurrentMissions {
      save.missions =
        MissionManager.generated(for: now, weekly: false)
        + Array(MissionManager.generated(for: now, weekly: true).prefix(2))
    }
  }

  func navigate(_ route: Route) {
    path.append(route)
    haptics.button()
  }

  func start(
    _ mode: GameMode, practiceDifficulty: DifficultyBand? = nil, competitive: Bool = true
  ) {
    let session = GameSession(
      mode: mode, save: save, practiceDifficulty: practiceDifficulty, competitive: competitive,
      audio: audio,
      haptics: haptics, ads: ads)
    session.onFinish = { [weak self] result in self?.finish(result) }
    activeSession = session
    path.append(.game(mode))
  }

  func closeActiveSession() {
    activeSession?.finish()
    activeSession = nil
  }

  private func finish(_ result: RunResult) {
    guard result.competitive else { return }
    save.statistics.totalRuns += result.competitive ? 1 : 0
    save.statistics.totalTaps += result.totalTaps
    save.statistics.highestCombo = max(save.statistics.highestCombo, result.highestCombo)
    save.statistics.totalPlayTime += result.duration
    for (rating, count) in result.ratings { save.statistics.ratings[rating, default: 0] += count }
    save.statistics.revivesUsed += result.revivesUsed
    save.profile.freeRevives = max(0, save.profile.freeRevives - result.revivesUsed)

    if save.economy.grant(result.coins, reason: "Run reward") {
      save.statistics.coinsEarned += result.coins
    }
    save.profile.xp += result.xp
    save.profile.level = ProgressionManager.level(forXP: save.profile.xp)
    save.adFrequency.completedRuns += result.competitive ? 1 : 0

    var modeStatistics = save.statistics.perMode[result.mode] ?? ModeStatistics()
    modeStatistics.runs += result.competitive ? 1 : 0
    modeStatistics.highScore = max(modeStatistics.highScore, result.score)
    modeStatistics.totalScore += result.score
    modeStatistics.playTime += result.duration
    save.statistics.perMode[result.mode] = modeStatistics

    if result.mode == .daily, result.competitive {
      save.dailyChallenge.bestScore = max(save.dailyChallenge.bestScore, result.score)
      save.statistics.dailyChallengesCompleted += 1
    }
    updateProgress(with: result)
    if result.competitive { gameCenter.submit(score: result.score, mode: result.mode) }
    persist()
    showInterstitialIfEligible()
  }

  private func updateProgress(with result: RunResult) {
    let values: [MissionMetric: Int] = [
      .perfectTaps: result.ratings[.perfect, default: 0], .combo: result.highestCombo,
      .runs: result.competitive ? 1 : 0, .score: result.score,
      .dailyChallenge: result.mode == .daily ? 1 : 0, .coinsEarned: result.coins,
      .level: save.profile.level,
      .themesUnlocked: save.inventory.owned.filter { $0.hasPrefix("theme.") }.count,
      .roundsSurvived: max(0, result.totalTaps),
      .cleanRounds: result.ratings[.miss, default: 0] == 0 ? 1 : 0,
      .totalTaps: result.totalTaps,
    ]

    for index in save.missions.indices {
      guard let value = values[save.missions[index].metric] else { continue }
      switch save.missions[index].metric {
      case .combo, .level, .themesUnlocked, .roundsSurvived:
        save.missions[index].progress = max(save.missions[index].progress, value)
      default:
        save.missions[index].addProgress(value)
      }
    }

    for index in save.achievements.indices {
      let achievement = save.achievements[index]
      let wasComplete = achievement.isComplete
      let lifetime = lifetimeValue(for: achievement.metric, latest: result)
      save.achievements[index].update(to: lifetime)
      if !wasComplete, save.achievements[index].isComplete {
        _ = save.economy.grant(
          save.achievements[index].rewardCoins, reason: "Achievement: \(achievement.title)",
          rewardID: "achievement-\(achievement.id)")
        gameCenter.report(save.achievements[index])
      }
    }
  }

  private func lifetimeValue(for metric: MissionMetric, latest result: RunResult) -> Int {
    switch metric {
    case .perfectTaps: return save.statistics.ratings[.perfect, default: 0]
    case .combo: return save.statistics.highestCombo
    case .runs: return save.statistics.totalRuns
    case .score: return save.statistics.perMode.values.map(\.totalScore).reduce(0, +)
    case .dailyChallenge: return save.statistics.dailyChallengesCompleted
    case .coinsEarned: return save.statistics.coinsEarned
    case .level: return save.profile.level
    case .themesUnlocked: return save.inventory.owned.filter { $0.hasPrefix("theme.") }.count
    case .roundsSurvived: return result.totalTaps
    case .cleanRounds: return result.ratings[.miss, default: 0] == 0 ? result.totalTaps : 0
    case .totalTaps: return save.statistics.totalTaps
    }
  }

  func claimMission(_ identifier: String) {
    guard let index = save.missions.firstIndex(where: { $0.id == identifier }),
      save.missions[index].claim()
    else { return }
    _ = save.economy.grant(
      save.missions[index].rewardCoins, reason: "Mission reward",
      rewardID: "mission-\(identifier)")
    haptics.reward()
    persist()
  }

  private func showInterstitialIfEligible() {
    let premium = save.premiumEntitlements.contains(StoreConfiguration.premium)
    guard
      AdCooldownPolicy.isInterstitialEligible(
        state: save.adFrequency, premium: premium, now: Date()), ads.interstitialAvailable
    else { return }
    Task { @MainActor [weak self] in
      guard let self, await self.ads.showInterstitial(placement: "post-run") else { return }
      self.save.adFrequency.runsAtLastInterstitial = self.save.adFrequency.completedRuns
      self.save.adFrequency.lastInterstitialAt = Date()
      self.persist()
      await self.ads.loadInterstitial()
    }
  }

  func applyPremiumUnlocksIfNeeded() {
    if save.premiumEntitlements.contains(StoreConfiguration.premium) {
      save.inventory.owned.formUnion([
        "theme.void", "marker.premium", "trail.premium", "badge.premium",
      ])
      _ = save.economy.grant(
        EconomyConfiguration.premiumCoinBonus, reason: "Premium bonus",
        rewardID: "premium-bonus")
    }
    if save.premiumEntitlements.contains(StoreConfiguration.cosmeticBundle) {
      save.inventory.owned.formUnion([
        "theme.sunset", "theme.cyberPurple", "marker.prism", "trail.echo", "tap.portal",
        "particle.stars", "badge.combo", "gameover.fade",
      ])
    }
  }

  func persist() {
    let snapshot = save
    Task { try? await persistence.save(snapshot) }
  }

  func handleScenePhase(_ phase: ScenePhase) {
    if phase != .active {
      activeSession?.pause()
      persist()
    } else {
      activeSession?.remainPausedAfterBackground()
    }
  }

  func resetProgress() {
    let entitlements = save.premiumEntitlements
    Task {
      try? await persistence.resetPreservingEntitlements(entitlements)
      save = await persistence.load()
      applyPremiumUnlocksIfNeeded()
      refreshDailyContent()
      path = []
    }
  }
}
