import Foundation
import PerfectTimingCore

struct RunResult: Sendable {
  let mode: GameMode
  let score: Int
  let highestCombo: Int
  let ratings: [AccuracyRating: Int]
  let coins: Int
  let xp: Int
  let duration: TimeInterval
  let totalTaps: Int
  let competitive: Bool
}

@MainActor final class GameSession: ObservableObject {
  enum State { case countdown, playing, paused, reviveOffer, gameOver }
  @Published var state: State = .countdown
  @Published var score = 0
  @Published var round = 1
  @Published var combo = ComboManager()
  @Published var lives = 1
  @Published var timeRemaining: TimeInterval = 60
  @Published var lastRating: AccuracyRating?
  @Published var lastPoints = 0
  @Published var showGameOver = false
  let mode: GameMode
  let audio: AudioManager
  let haptics: HapticManager
  let ads: any AdService
  let practiceDifficulty: DifficultyBand?
  var onFinish: ((RunResult) -> Void)?
  private(set) var challenge: AnyTimingChallenge
  private var ratings: [AccuracyRating: Int] = [:]
  private var started = Date()
  private var highestCombo = 0
  private var revive = ReviveState()
  private var timer: Timer?
  private var inputLocked = true
  init(
    mode: GameMode, save: PlayerSaveData, practiceDifficulty: DifficultyBand?, audio: AudioManager,
    haptics: HapticManager, ads: any AdService
  ) {
    self.mode = mode
    self.audio = audio
    self.haptics = haptics
    self.ads = ads
    self.practiceDifficulty = practiceDifficulty
    self.lives = mode == .precision ? GameConfiguration.precisionLives : 1
    self.timeRemaining = mode == .rush ? GameConfiguration.rushDuration : 0
    self.challenge = ChallengeFactory.make(
      type: .movingBar,
      difficulty: DifficultyManager.snapshot(score: 0, combo: 0, seconds: 0, failures: 0), seed: 1)
    countdown()
  }
  func countdown() {
    state = .countdown
    inputLocked = true
    audio.play(.countdown)
    Task {
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      state = .playing
      inputLocked = false
      startTimer()
    }
  }
  func tap(progress: Double, locationNormalized: CGPoint) {
    guard state == .playing, !inputLocked else { return }
    inputLocked = true
    let distance = challenge.normalizedDistance(at: progress)
    let rating = TimingAccuracyEvaluator().rating(for: distance)
    let difficulty = DifficultyManager.snapshot(
      score: score, combo: combo.count, seconds: Date().timeIntervalSince(started), failures: 0)
    let points = ScoreManager.points(
      rating: rating, combo: combo.count, difficulty: 1 + Double(difficulty.band.rawValue) * 0.12,
      speed: max(1, difficulty.speed), mode: mode, round: round, perfectStreak: combo.perfectStreak)
    lastRating = rating
    lastPoints = points
    ratings[rating, default: 0] += 1
    score += points
    combo.register(rating)
    highestCombo = max(highestCombo, combo.count)
    audio.play(rating)
    haptics.play(rating)
    if mode == .rush {
      if rating == .perfect { timeRemaining += GameConfiguration.perfectBonusTime }
      if rating == .miss {
        timeRemaining = max(0, timeRemaining - GameConfiguration.missTimePenalty)
      }
    }
    if rating == .miss {
      handleMiss()
    } else {
      round += 1
      nextChallenge(after: rating)
    }
  }
  private func nextChallenge(after rating: AccuracyRating) {
    let d = DifficultyManager.snapshot(
      score: score, combo: combo.count, seconds: Date().timeIntervalSince(started), failures: 0)
    var types = ChallengeType.allCases
    if round <= 5 { types = [.movingBar, .verticalDrop, .expandingRing, .rotatingNeedle] }
    if mode == .chaos { types = ChallengeType.allCases }
    let seed = UInt64(abs(score &+ round &* 7919))
    challenge = ChallengeFactory.make(
      type: types[Int(seed % UInt64(types.count))], difficulty: d, seed: seed)
    Task {
      try? await Task.sleep(for: .milliseconds(rating == .perfect ? 260 : 140))
      inputLocked = false
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
  func canRevive() -> Bool {
    revive.canRevive(hasFreeRevive: true, rewardedAdAvailable: ads.rewardedAvailable)
  }
  func useRevive() {
    guard canRevive() else {
      endRun()
      return
    }
    revive.use()
    haptics.revive()
    audio.play(.revive)
    combo = ComboManager()
    countdown()
  }
  func rewardedRevive() {
    Task {
      let earned = await ads.showRewarded(placement: "revive")
      if earned { useRevive() }
    }
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
    timer?.invalidate()
    score = 0
    round = 1
    combo = ComboManager()
    ratings = [:]
    highestCombo = 0
    revive = ReviveState()
    started = Date()
    lives = mode == .precision ? 3 : 1
    timeRemaining = mode == .rush ? 60 : 0
    countdown()
  }
  func quit() { finish() }
  private func startTimer() {
    timer?.invalidate()
    guard mode == .rush else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
      Task { @MainActor in
        guard let self, self.state == .playing else {
          t.invalidate()
          return
        }
        self.timeRemaining = max(0, self.timeRemaining - 0.05)
        if self.timeRemaining <= 0 { self.endRun() }
      }
    }
  }
  func endRun() {
    timer?.invalidate()
    state = .gameOver
    showGameOver = true
    audio.play(.gameOver)
  }
  func finish() {
    let result = RunResult(
      mode: mode, score: score, highestCombo: highestCombo, ratings: ratings,
      coins: mode == .practice ? 0 : max(10, score / 350),
      xp: mode == .practice ? 0 : max(20, round * 8), duration: Date().timeIntervalSince(started),
      totalTaps: ratings.values.reduce(0, +), competitive: mode != .practice)
    onFinish?(result)
  }
}
