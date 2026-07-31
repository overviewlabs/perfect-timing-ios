import AVFoundation
import PerfectTimingCore

enum SoundCue {
  case menu, roundStart, perfect, excellent, great, good, close, miss, combo, milestone, coin,
    reward, purchase, gameOver, revive, countdown, daily
}
@MainActor final class AudioManager {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private var volume: Float = 0.8
  private var muted = false
  init() {
    engine.attach(player)
    let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    engine.connect(player, to: engine.mainMixerNode, format: format)
    try? AVAudioSession.sharedInstance().setCategory(
      .ambient, mode: .default, options: [.mixWithOthers])
    try? engine.start()
  }
  func apply(_ settings: AppSettings) {
    volume = Float(settings.effectsVolume)
    muted = settings.muteAll
  }
  func play(_ cue: SoundCue) {
    guard !muted, volume > 0 else { return }
    let hz: Double
    let duration: Double
    switch cue {
    case .perfect:
      hz = 880
      duration = 0.13
    case .excellent:
      hz = 740
      duration = 0.11
    case .great:
      hz = 660
      duration = 0.1
    case .good:
      hz = 520
      duration = 0.09
    case .close:
      hz = 360
      duration = 0.1
    case .miss:
      hz = 130
      duration = 0.22
    case .gameOver:
      hz = 110
      duration = 0.35
    case .revive:
      hz = 990
      duration = 0.22
    case .countdown:
      hz = 440
      duration = 0.08
    case .coin, .reward, .purchase:
      hz = 1040
      duration = 0.16
    default:
      hz = 600
      duration = 0.06
    }
    tone(hz: hz, duration: duration)
  }
  func play(_ rating: AccuracyRating) {
    switch rating {
    case .perfect: play(.perfect)
    case .excellent: play(.excellent)
    case .great: play(.great)
    case .good: play(.good)
    case .close: play(.close)
    case .miss: play(.miss)
    }
  }
  private func tone(hz: Double, duration: Double) {
    let rate = 44_100.0
    let count = AVAudioFrameCount(rate * duration)
    guard let f = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
      let b = AVAudioPCMBuffer(pcmFormat: f, frameCapacity: count),
      let samples = b.floatChannelData?[0]
    else { return }
    b.frameLength = count
    for i in 0..<Int(count) {
      let envelope = Float(1 - Double(i) / Double(count))
      samples[i] = sin(Float(Double(i) * 2*.pi * hz / rate)) * envelope * 0.22 * volume
    }
    player.scheduleBuffer(b)
    if !player.isPlaying { player.play() }
  }
}
