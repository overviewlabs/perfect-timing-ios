import PerfectTimingCore
import UIKit

@MainActor final class HapticManager {
  var enabled = true
  func play(_ rating: AccuracyRating) {
    guard enabled else { return }
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    switch rating {
    case .perfect: style = .rigid
    case .excellent, .great: style = .medium
    case .good, .close: style = .light
    case .miss:
      UINotificationFeedbackGenerator().notificationOccurred(.error)
      return
    }
    UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: rating == .perfect ? 1 : 0.7)
  }
  func button() {
    guard enabled else { return }
    UISelectionFeedbackGenerator().selectionChanged()
  }
  func revive() {
    guard enabled else { return }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }
  func reward() { revive() }
  func purchase() { revive() }
}
