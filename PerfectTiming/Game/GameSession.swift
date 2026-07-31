import Combine
import CoreGraphics
import Foundation
import PerfectTimingCore
import SwiftUI

struct RunResult: Sendable {
  let mode: GameMode
  let score: Int
  let highestCombo: Int
  let ratings: [AccuracyRating: Int]
  let coins: Int
  let xp: Int
  let duration: TimeInterval
  let totalTaps: Int
  let revivesUsed: Int
  let competitive: Bool
}

@MainActor
final class GameSession: ObservableObject {
  enum State { case countdown, playing, paused, reviveOffer, gameOver }

  @Published var state: State = .countdown
  @Published var score = 0
  @Published var round = 1
  @Published var combo = ComboManager()
  @Published var lives = 1
  @Published var timeRemaining: TimeInterval = GameConfiguration.rushDuration
  @Published var lastRating: AccuracyRating?
  @Published var lastPoints = 0
  @Published private(set) var highestCombo = 0

  let mode: GameMode
  let audio: AudioManager
  let haptics: HapticManager
  let ads: any AdService
  let practiceDifficulty: DifficultyBand?
  let settings: AppSettings
  let competitive: Bool
  var onFinish: ((RunResult) -> Void)?
  private(set) var challenge: AnyTimingChallenge
  private(set) var freeRevivesAvailable: Int

  private var ratings: [AccuracyRating: Int] = [:]
  private var started = Date()
  private var revive = ReviveState()
  private var timer: Timer?
  private var countdownTask: Task<Void, Never>?
  private var inputLocked = true
  private var resultCommitted = false
  private var revivesUsed = 0

  init(
    mode: GameMode, save: PlayerSaveData, practiceDifficulty: DifficultyBand? = nil,
    competitive: Bool = true, audio: AudioManager,
    haptics: HapticManager, ads: any AdService
  ) {
    self.mode = mode
    self.audio = audio
    self.haptics = haptics
    self.ads = ads
    self.practiceDifficulty = practiceDifficulty
    self.competitive = competitive && mode != .practice
    settings = save.settings
    freeRevivesAvailable = save.profile.freeRevives
    lives = mode == .precision ? GameConfiguration.precisionLives : 1
    timeRemaining = mode == .rush ? GameConfiguration.rushDuration : 0
    challenge = ChallengeFactory.make(
      type: .movingBar,
      difficulty: DifficultyManager.snapshot(score: 0, combo: 0, seconds: 0, failures: 0),
      seed: mode == .daily ? DailyChallengeManager.seed(for: Date()) : 1)
    countdown()
  }

  isolated deinit {
    timer?.invalidate()
    countdownTask?.cancel()
  }

  var canUseFreeRevive: Bool { !revive.used && freeRevivesAvailable > 0 }
  var canUseRewardedRevive: Bool { !revive.used && ads.rewardedAvailable }
  var rewardCoins: Int { competitive ? max(10, score / 350) : 0 }
  var rewardXP: Int { competitive ? max(20, round * 8) : 0 }

  func countdown() {
    countdownTask?.cancel()
    state = .countdown
    inputLocked = true
    audio.play(.countdown)
    countdownTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self, !Task.isCancelled else { return }
      self.state = .playing
      self.inputLocked = false
      self.startTimer()
    }
  }

  func tap(progress: Double, locationNormalized: CGPoint) {
    guard state == .playing, !inputLocked else { return }
    inputLocked = true
    let distance = challenge.normalizedDistance(at: progress)
    register(TimingAccuracyEvaluator().rating(for: distance))
  }

  func expireChallenge() {
    guard state == .playing, !inputLocked else { return }
    inputLocked = true
    register(.miss)
  }

  private func register(_ rating: AccuracyRating) {
    let difficulty = currentDifficulty
    let points = ScoreManager.points(
      rating: rating, combo: combo.count,
      difficulty: 1 + Double(difficulty.band.rawValue) * 0.12,
      speed: max(1, difficulty.speed), mode: mode, round: round,
      perfectStreak: combo.perfectStreak)
    lastRating = rating
    lastPoints = points
    ratings[rating, default: 0] += 1
    score += points
    combo.register(rating)
    highestCombo = max(highestCombo, combo.count)
    if [5, 10, 20, 35, 50].contains(combo.count) {
      audio.play(.milestone)
      haptics.reward()
    } else {
      audio.play(rating)
      haptics.play(rating)
    }

    if mode == .rush {
      if rating == .perfect { timeRemaining += GameConfiguration.perfectBonusTime }
      if rating == .miss {
        timeRemaining = max(0, timeRemaining - GameConfiguration.missTimePenalty)
      }
      round += 1
      if timeRemaining <= 0 { endRun() } else { nextChallenge(after: rating) }
      return
    }

    if rating == .miss {
      handleMiss()
    } else {
      round += 1
      nextChallenge(after: rating)
    }
  }

  private var currentDifficulty: DifficultySnapshot {
    if let practiceDifficulty {
      let baseline = DifficultyManager.snapshot(
        score: practiceDifficulty.rawValue * 8_000, combo: practiceDifficulty.rawValue * 10,
        seconds: Double(practiceDifficulty.rawValue * 35), failures: 0)
      return DifficultySnapshot(
        band: practiceDifficulty, speed: baseline.speed, acceleration: baseline.acceleration,
        targetScale: baseline.targetScale, duration: baseline.duration,
        targetMovement: baseline.targetMovement,
        directionChangeChance: baseline.directionChangeChance, objectCount: baseline.objectCount,
        fakeTargets: baseline.fakeTargets, distractionIntensity: baseline.distractionIntensity)
    }
    return DifficultyManager.snapshot(
      score: score, combo: combo.count, seconds: Date().timeIntervalSince(started), failures: 0)
  }

  private func nextChallenge(after rating: AccuracyRating) {
    var types = ChallengeType.allCases
    if round <= 5 { types = [.movingBar, .verticalDrop, .expandingRing, .rotatingNeedle] }
    let seedBase =
      mode == .daily ? DailyChallengeManager.seed(for: Date()) : UInt64(abs(score &+ round &* 7919))
    let seed = seedBase &+ UInt64(round &* 3571)
    challenge = ChallengeFactory.make(
      type: types[Int(seed % UInt64(types.count))], difficulty: currentDifficulty, seed: seed)
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(rating == .perfect ? 260 : 140))
      self?.inputLocked = false
    }
  }

  private func handleMiss() {
    if mode == .practice {
      round += 1
      nextChallenge(after: .miss)
      return
    }
    if mode == .precision, lives > 1 {
      lives -= 1
      round += 1
      nextChallenge(after: .miss)
      return
    }
    state = .reviveOffer
    inputLocked = true
    timer?.invalidate()
  }

  func canRevive() -> Bool { canUseFreeRevive || canUseRewardedRevive }

  func useFreeRevive() {
    guard canUseFreeRevive else {
      endRun()
      return
    }
    freeRevivesAvailable -= 1
    applyRevive()
  }

  func rewardedRevive() {
    guard canUseRewardedRevive else {
      endRun()
      return
    }
    Task { @MainActor [weak self] in
      guard let self else { return }
      let earned = await self.ads.showRewarded(placement: "revive")
      if earned { self.applyRevive() }
    }
  }

  private func applyRevive() {
    guard !revive.used else { return }
    revive.use()
    revivesUsed += 1
    haptics.revive()
    audio.play(.revive)
    combo = ComboManager()
    countdown()
  }

  func declineRevive() { endRun() }
  func pause() {
    guard state == .playing else { return }
    state = .paused
    timer?.invalidate()
  }
  func resume() {
    guard state == .paused else { return }
    countdown()
  }
  func remainPausedAfterBackground() { if state == .playing { pause() } }

  func restart() {
    completeIfNeeded()
    timer?.invalidate()
    countdownTask?.cancel()
    score = 0
    round = 1
    combo = ComboManager()
    ratings = [:]
    highestCombo = 0
    revive = ReviveState()
    revivesUsed = 0
    resultCommitted = false
    started = Date()
    lives = mode == .precision ? GameConfiguration.precisionLives : 1
    timeRemaining = mode == .rush ? GameConfiguration.rushDuration : 0
    challenge = ChallengeFactory.make(
      type: .movingBar, difficulty: currentDifficulty,
      seed: mode == .daily
        ? DailyChallengeManager.seed(for: Date()) : UInt64(Date().timeIntervalSince1970))
    countdown()
  }

  private func startTimer() {
    timer?.invalidate()
    guard mode == .rush else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.state == .playing else { return }
        self.timeRemaining = max(0, self.timeRemaining - 0.05)
        if self.timeRemaining <= 0 { self.endRun() }
      }
    }
  }

  func endRun() {
    guard state != .gameOver else { return }
    timer?.invalidate()
    state = .gameOver
    inputLocked = true
    audio.play(.gameOver)
    completeIfNeeded()
  }

  func finish() { completeIfNeeded() }

  private func completeIfNeeded() {
    guard !resultCommitted else { return }
    resultCommitted = true
    onFinish?(
      RunResult(
        mode: mode, score: score, highestCombo: highestCombo, ratings: ratings,
        coins: rewardCoins, xp: rewardXP,
        duration: Date().timeIntervalSince(started), totalTaps: ratings.values.reduce(0, +),
        revivesUsed: revivesUsed, competitive: competitive))
  }
}
