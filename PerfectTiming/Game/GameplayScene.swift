import PerfectTimingCore
import SpriteKit

@MainActor final class GameplayScene: SKScene {
  weak var session: GameSession?
  private var challengeID = ""
  private var originTime: TimeInterval = 0
  private let target = SKShapeNode()
  private let marker = SKShapeNode()
  private let dial = SKShapeNode()
  private var lastProgress = 0.0

  convenience init(size: CGSize, session: GameSession) {
    self.init(size: size)
    self.session = session
    scaleMode = .resizeFill
    backgroundColor = UIColor(red: 0.015, green: 0.025, blue: 0.07, alpha: 1)
    isUserInteractionEnabled = true
    setup()
  }
  private func setup() {
    dial.lineWidth = 3
    dial.strokeColor = UIColor.cyan.withAlphaComponent(0.22)
    addChild(dial)
    target.lineWidth = 7
    target.strokeColor = .cyan
    target.glowWidth = 18
    addChild(target)
    marker.fillColor = .white
    marker.strokeColor = .cyan
    marker.glowWidth = 14
    addChild(marker)
  }
  override func update(_ currentTime: TimeInterval) {
    guard let session, session.state == .playing else { return }
    let challenge = session.challenge
    let identifier = "\(challenge.type.rawValue)-\(session.round)"
    if identifier != challengeID {
      challengeID = identifier
      originTime = currentTime
      configure(challenge)
    }
    lastProgress = (currentTime - originTime) / max(0.2, challenge.timeLimit)
    render(challenge, progress: lastProgress)
  }
  private func configure(_ challenge: AnyTimingChallenge) {
    removeChildren(in: children.filter { $0.name == "effect" })
    target.path = nil
    marker.path = nil
    dial.path = nil
    switch challenge.type {
    case .movingBar, .bouncingMarker, .dualMarker:
      target.path = CGPath(
        roundedRect: CGRect(
          x: -size.width * challenge.targetSize / 2, y: -38,
          width: size.width * challenge.targetSize, height: 76), cornerWidth: 18, cornerHeight: 18,
        transform: nil)
      marker.path = CGPath(ellipseIn: CGRect(x: -14, y: -28, width: 28, height: 56), transform: nil)
    case .verticalDrop:
      target.path = CGPath(
        rect: CGRect(x: -size.width / 2, y: -5, width: size.width, height: 10), transform: nil)
      marker.path = CGPath(ellipseIn: CGRect(x: -22, y: -22, width: 44, height: 44), transform: nil)
    case .rotatingNeedle:
      target.path = CGPath(
        ellipseIn: CGRect(x: -118, y: -118, width: 236, height: 236), transform: nil)
      dial.path = target.path
      marker.path = CGPath(
        roundedRect: CGRect(x: -3, y: -105, width: 6, height: 105), cornerWidth: 3, cornerHeight: 3,
        transform: nil)
    case .expandingRing, .contractingRing, .pulseTiming:
      target.path = CGPath(
        ellipseIn: CGRect(x: -92, y: -92, width: 184, height: 184), transform: nil)
      marker.path = CGPath(
        ellipseIn: CGRect(x: -70, y: -70, width: 140, height: 140), transform: nil)
    }
    target.alpha = 0.95
    marker.alpha = 1
  }
  private func render(_ challenge: AnyTimingChallenge, progress: Double) {
    let position = challenge.position(at: progress)
    let center = CGPoint(x: size.width / 2, y: size.height * 0.48)
    switch challenge.type {
    case .movingBar, .bouncingMarker:
      target.position = CGPoint(x: size.width * challenge.targetCenter, y: center.y)
      marker.position = CGPoint(x: size.width * position, y: center.y)
      marker.zRotation = 0
    case .verticalDrop:
      target.position = center
      marker.position = CGPoint(x: center.x, y: size.height * (1 - position))
    case .rotatingNeedle:
      target.position = center
      dial.position = center
      marker.position = center
      marker.zRotation = CGFloat(position * Double.pi * 2)
    case .expandingRing, .contractingRing, .pulseTiming:
      target.position = center
      marker.position = center
      marker.setScale(CGFloat(0.25 + position * 1.25))
    case .dualMarker:
      target.position = CGPoint(x: size.width * challenge.targetCenter, y: center.y)
      marker.position = CGPoint(x: size.width * position, y: center.y)
      if childNode(withName: "dual") == nil {
        let other = marker.copy() as! SKShapeNode
        other.name = "dual"
        addChild(other)
      }
      childNode(withName: "dual")?.position = CGPoint(
        x: size.width * (1 - position), y: center.y + 100)
    }
  }
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first, let session else { return }
    let point = touch.location(in: self)
    impact(at: point, ratingPreview: session.challenge.normalizedDistance(at: lastProgress))
    session.tap(
      progress: lastProgress,
      locationNormalized: CGPoint(x: point.x / size.width, y: point.y / size.height))
  }
  private func impact(at point: CGPoint, ratingPreview: Double) {
    let ring = SKShapeNode(circleOfRadius: 24)
    ring.name = "effect"
    ring.position = point
    ring.strokeColor = ratingPreview <= 0.03 ? .white : .cyan
    ring.lineWidth = 4
    ring.glowWidth = 12
    addChild(ring)
    ring.run(
      .sequence([
        .group([.scale(to: 3, duration: 0.24), .fadeOut(withDuration: 0.24)]), .removeFromParent(),
      ]))
    for index in 0..<10 {
      let dot = SKShapeNode(circleOfRadius: 3)
      dot.name = "effect"
      dot.fillColor = .cyan
      dot.position = point
      addChild(dot)
      let angle = CGFloat(index) * .pi / 5
      dot.run(
        .sequence([
          .group([
            .moveBy(x: cos(angle) * 70, y: sin(angle) * 70, duration: 0.3),
            .fadeOut(withDuration: 0.3),
          ]), .removeFromParent(),
        ]))
    }
  }
}
