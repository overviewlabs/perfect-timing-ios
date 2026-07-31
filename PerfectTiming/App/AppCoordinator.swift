import PerfectTimingCore
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
  enum Route: Hashable {
    case home, modes
    case game(GameMode)
    case daily, reward, missions, achievements, shop, inventory, profile, statistics, leaderboards,
      premium, settings, notifications, legal, debug
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
    let p = JSONPersistenceService()
    return AppCoordinator(
      persistence: p, audio: AudioManager(), haptics: HapticManager(), store: StoreManager(),
      gameCenter: GameCenterManager(), notifications: NotificationManager(), ads: MockAdService())
  }
  func bootstrap() async {
    save = await persistence.load()
    isLoaded = true
    audio.apply(save.settings)
    haptics.enabled = save.settings.haptics
    await store.start { [weak self] ids in
      guard let self else { return }
      self.save.premiumEntitlements.formUnion(ids)
      self.persist()
    }
    await gameCenter.authenticate()
  }
  func navigate(_ route: Route) {
    path.append(route)
    haptics.button()
  }
  func start(_ mode: GameMode, practiceDifficulty: DifficultyBand? = nil) {
    let session = GameSession(
      mode: mode, save: save, practiceDifficulty: practiceDifficulty, audio: audio,
      haptics: haptics, ads: ads)
    session.onFinish = { [weak self] result in self?.finish(result) }
    activeSession = session
    path.append(.game(mode))
  }
  func finish(_ result: RunResult) {
    activeSession = nil
    save.statistics.totalRuns += result.competitive ? 1 : 0
    save.statistics.totalTaps += result.totalTaps
    save.statistics.highestCombo = max(save.statistics.highestCombo, result.highestCombo)
    save.statistics.totalPlayTime += result.duration
    _ = save.economy.grant(result.coins, reason: "Run reward")
    save.profile.xp += result.xp
    save.profile.level = ProgressionManager.level(forXP: save.profile.xp)
    save.adFrequency.completedRuns += result.competitive ? 1 : 0
    var mode = save.statistics.perMode[result.mode] ?? ModeStatistics()
    mode.runs += result.competitive ? 1 : 0
    mode.highScore = max(mode.highScore, result.score)
    mode.totalScore += result.score
    mode.playTime += result.duration
    save.statistics.perMode[result.mode] = mode
    if result.competitive { gameCenter.submit(score: result.score, mode: result.mode) }
    persist()
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
      path = []
    }
  }
}
