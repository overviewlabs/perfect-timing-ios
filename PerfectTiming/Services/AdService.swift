import Foundation

@MainActor protocol AdService: AnyObject {
  var interstitialAvailable: Bool { get }
  var rewardedAvailable: Bool { get }
  func loadInterstitial() async
  func showInterstitial(placement: String) async -> Bool
  func loadRewarded() async
  func showRewarded(placement: String) async -> Bool
}
@MainActor final class MockAdService: AdService {
  var interstitialAvailable = true
  var rewardedAvailable = true
  func loadInterstitial() async { interstitialAvailable = true }
  func showInterstitial(placement: String) async -> Bool {
    guard interstitialAvailable else { return false }
    interstitialAvailable = false
    try? await Task.sleep(for: .milliseconds(350))
    return true
  }
  func loadRewarded() async { rewardedAvailable = true }
  func showRewarded(placement: String) async -> Bool {
    guard rewardedAvailable else { return false }
    try? await Task.sleep(for: .milliseconds(700))
    return true
  }
}
// TODO: Advertising SDK adapter: create a separate target that conforms to AdService. Never import an ad SDK into gameplay code.
