import Foundation
import PerfectTimingCore

protocol TimingChallenge: Sendable {
  var type: ChallengeType { get }
  var speed: Double { get }
  var acceleration: Double { get }
  var direction: Double { get }
  var timeLimit: TimeInterval { get }
  var targetCenter: Double { get }
  var targetSize: Double { get }
  var visualStyle: Int { get }
  var objectCount: Int { get }
  var fakeTargets: Int { get }
  var distractionIntensity: Double { get }
  func position(at progress: Double) -> Double
  func normalizedDistance(at progress: Double) -> Double
}

struct AnyTimingChallenge: TimingChallenge {
  let type: ChallengeType
  let speed: Double
  let acceleration: Double
  let direction: Double
  let timeLimit: TimeInterval
  let targetCenter: Double
  let targetSize: Double
  let visualStyle: Int
  let objectCount: Int
  let fakeTargets: Int
  let distractionIntensity: Double
  private let positionBlock: @Sendable (Double) -> Double
  private let distanceBlock: @Sendable (Double) -> Double

  init<C: TimingChallenge>(_ challenge: C) {
    type = challenge.type
    speed = challenge.speed
    acceleration = challenge.acceleration
    direction = challenge.direction
    timeLimit = challenge.timeLimit
    targetCenter = challenge.targetCenter
    targetSize = challenge.targetSize
    visualStyle = challenge.visualStyle
    objectCount = challenge.objectCount
    fakeTargets = challenge.fakeTargets
    distractionIntensity = challenge.distractionIntensity
    positionBlock = challenge.position
    distanceBlock = challenge.normalizedDistance
  }
  func position(at progress: Double) -> Double { positionBlock(progress) }
  func normalizedDistance(at progress: Double) -> Double { distanceBlock(progress) }
}

struct ParametricChallenge: TimingChallenge {
  let type: ChallengeType
  let speed: Double
  let acceleration: Double
  let direction: Double
  let timeLimit: TimeInterval
  let targetCenter: Double
  let targetSize: Double
  let visualStyle: Int
  let objectCount: Int
  let fakeTargets: Int
  let distractionIntensity: Double

  func position(at progress: Double) -> Double {
    let phase = (progress * speed + 0.5 * acceleration * progress * progress) * direction
    let positivePhase = phase - floor(phase)
    switch type {
    case .movingBar, .verticalDrop, .rotatingNeedle: return positivePhase
    case .expandingRing: return min(1, abs(phase.truncatingRemainder(dividingBy: 2) - 1))
    case .contractingRing: return 1 - min(1, abs(phase.truncatingRemainder(dividingBy: 2) - 1))
    case .bouncingMarker, .dualMarker: return abs(phase.truncatingRemainder(dividingBy: 2) - 1)
    case .pulseTiming: return (sin(phase * Double.pi * 2) + 1) / 2
    }
  }
  func normalizedDistance(at progress: Double) -> Double {
    let position = position(at: progress)
    if type == .dualMarker {
      return max(abs(position - targetCenter), abs((1 - position) - (1 - targetCenter)))
    }
    return abs(position - targetCenter)
  }
}

enum ChallengeFactory {
  static func make(type: ChallengeType, difficulty: DifficultySnapshot, seed: UInt64)
    -> AnyTimingChallenge
  {
    let center = 0.3 + Double(seed % 400) / 1000
    let direction: Double = seed % 2 == 0 ? 1 : -1
    return AnyTimingChallenge(
      ParametricChallenge(
        type: type, speed: difficulty.speed, acceleration: difficulty.acceleration,
        direction: direction, timeLimit: difficulty.duration, targetCenter: center,
        targetSize: max(0.06, 0.28 * difficulty.targetScale), visualStyle: Int(seed % 5),
        objectCount: difficulty.objectCount, fakeTargets: difficulty.fakeTargets,
        distractionIntensity: difficulty.distractionIntensity))
  }
}
