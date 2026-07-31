import CoreGraphics
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
  private let positionBlock: @Sendable (Double) -> Double
  private let distanceBlock: @Sendable (Double) -> Double
  init<C: TimingChallenge>(_ c: C) {
    type = c.type
    speed = c.speed
    acceleration = c.acceleration
    direction = c.direction
    timeLimit = c.timeLimit
    targetCenter = c.targetCenter
    targetSize = c.targetSize
    visualStyle = c.visualStyle
    positionBlock = c.position
    distanceBlock = c.normalizedDistance
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
  func position(at p: Double) -> Double {
    let phase = (p * speed + 0.5 * acceleration * p * p) * direction
    switch type {
    case .movingBar, .verticalDrop: return phase.truncatingRemainder(dividingBy: 1)
    case .rotatingNeedle: return phase.truncatingRemainder(dividingBy: 1)
    case .expandingRing: return min(1, abs(phase.truncatingRemainder(dividingBy: 2) - 1))
    case .contractingRing: return 1 - min(1, abs(phase.truncatingRemainder(dividingBy: 2) - 1))
    case .bouncingMarker: return abs((phase.truncatingRemainder(dividingBy: 2)) - 1)
    case .dualMarker: return abs((phase.truncatingRemainder(dividingBy: 2)) - 1)
    case .pulseTiming: return (sin(phase * Double.pi * 2) + 1) / 2
    }
  }
  func normalizedDistance(at p: Double) -> Double {
    let pos = position(at: p)
    if type == .dualMarker {
      return max(abs(pos - targetCenter), abs((1 - pos) - (1 - targetCenter)))
    }
    return abs(pos - targetCenter)
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
        targetSize: max(0.06, 0.28 * difficulty.targetScale), visualStyle: Int(seed % 5)))
  }
}
