import PerfectTimingCore
import SpriteKit
import SwiftUI

struct GameplayView: View {
  @EnvironmentObject var app: AppCoordinator
  @Environment(\.dismiss) var dismiss
  var body: some View {
    if let session = app.activeSession {
      GameContainer(session: session) {
        app.closeActiveSession()
        dismiss()
      }
    } else {
      EmptyState(
        icon: "gamecontroller", title: "Run finished", detail: "Return to the menu to play again.")
    }
  }
}

private struct GameContainer: View {
  @ObservedObject var session: GameSession
  let onExit: () -> Void
  @State private var scene: GameplayScene?
  var body: some View {
    GeometryReader { proxy in
      ZStack {
        if let scene {
          SpriteView(scene: scene, options: [.ignoresSiblingOrder]).ignoresSafeArea()
        } else {
          Color.black.onAppear { scene = GameplayScene(size: proxy.size, session: session) }
        }
        VStack {
          HUD(session: session)
          Spacer()
        }.padding()
        if session.state == .countdown {
          Text("READY").font(.system(size: 54, weight: .black)).foregroundStyle(.white).shadow(
            color: .cyan, radius: 22)
        }
        if let rating = session.lastRating, session.state == .playing {
          VStack {
            Text(rating.rawValue.uppercased()).font(.system(size: 36, weight: .black))
              .foregroundStyle(ratingColor(rating))
            Text("+\(session.lastPoints.formatted())").font(.headline)
          }.allowsHitTesting(false)
        }
        if session.state == .paused { PauseOverlay(session: session, onExit: onExit) }
        if session.state == .reviveOffer { ReviveOverlay(session: session) }
        if session.state == .gameOver { GameOverOverlay(session: session, onExit: onExit) }
      }
    }.navigationBarBackButtonHidden().statusBarHidden()
  }
  private func ratingColor(_ rating: AccuracyRating) -> Color {
    switch rating {
    case .perfect: .white
    case .excellent: .cyan
    case .great: .green
    case .good: .yellow
    case .close: .orange
    case .miss: .red
    }
  }
}

private struct HUD: View {
  @ObservedObject var session: GameSession
  var body: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading) {
        Text(session.score.formatted()).font(.system(size: 30, weight: .black, design: .rounded))
        Text("ROUND \(session.round)").font(.caption.bold()).foregroundStyle(.secondary)
      }
      Spacer()
      VStack {
        Text("×\(session.combo.multiplier.formatted(.number.precision(.fractionLength(1))))").font(
          .title3.bold()
        ).foregroundStyle(.cyan)
        Text("COMBO \(session.combo.count)").font(.caption.bold())
      }
      Spacer()
      if session.mode == .rush {
        Text(session.timeRemaining.formatted(.number.precision(.fractionLength(1))))
          .monospacedDigit().font(.title2.bold())
      } else if session.mode == .precision {
        Label("\(session.lives)", systemImage: "heart.fill").foregroundStyle(.pink)
      }
      Button {
        session.pause()
      } label: {
        Image(systemName: "pause.fill").frame(width: 44, height: 44).background(
          .black.opacity(0.3), in: Circle())
      }.accessibilityLabel("Pause")
    }.foregroundStyle(.white)
  }
}

private struct PauseOverlay: View {
  @ObservedObject var session: GameSession
  let onExit: () -> Void
  var body: some View {
    Color.black.opacity(0.75).ignoresSafeArea().overlay {
      NeonCard {
        VStack(spacing: 16) {
          Text("PAUSED").font(.largeTitle.weight(.black))
          Button("Resume") { session.resume() }.buttonStyle(PrimaryButtonStyle())
          Button("Restart") { session.restart() }.buttonStyle(.bordered)
          Button("Quit to Menu", role: .destructive) { onExit() }.buttonStyle(.bordered)
        }
      }.padding(28)
    }
  }
}
private struct ReviveOverlay: View {
  @ObservedObject var session: GameSession
  var body: some View {
    Color.black.opacity(0.82).ignoresSafeArea().overlay {
      VStack(spacing: 18) {
        Image(systemName: "bolt.heart.fill").font(.system(size: 65)).foregroundStyle(.cyan)
        Text("One more chance?").font(.largeTitle.weight(.black))
        if session.canUseFreeRevive {
          Button("Use Free Revive") { session.useFreeRevive() }.buttonStyle(PrimaryButtonStyle())
        }
        if session.canUseRewardedRevive {
          Button("Watch to Revive") { session.rewardedRevive() }.buttonStyle(.borderedProminent)
        }
        Button("End Run") { session.declineRevive() }.foregroundStyle(.secondary)
      }.padding(30)
    }
  }
}
private struct GameOverOverlay: View {
  @ObservedObject var session: GameSession
  let onExit: () -> Void
  @State private var shareItem: ShareCardItem?
  var body: some View {
    Color.black.opacity(0.88).ignoresSafeArea().overlay {
      ScrollView {
        VStack(spacing: 15) {
          Text("RUN COMPLETE").font(.caption.bold()).foregroundStyle(.cyan)
          Text(session.score.formatted()).font(.system(size: 54, weight: .black, design: .rounded))
          Text("Best Combo \(session.highestCombo)").foregroundStyle(.secondary)
          HStack {
            StatPill(icon: "circle.hexagongrid.fill", value: "+\(session.rewardCoins)")
            StatPill(icon: "sparkles", value: "+\(session.rewardXP) XP")
          }
          Button("PLAY AGAIN") { session.restart() }.buttonStyle(PrimaryButtonStyle())
          Button("Share Score") {
            shareItem = ShareCardItem(
              image: ShareCardRenderer.render(
                score: session.score, mode: session.mode, combo: session.combo.count, accuracy: 0.92
              ))
          }.buttonStyle(.bordered)
          Button("Main Menu") { onExit() }.foregroundStyle(.secondary)
        }.padding(28)
      }
    }.sheet(item: $shareItem) { ShareSheet(items: [$0.image]) }
  }
}
struct ShareCardItem: Identifiable {
  let id = UUID()
  let image: UIImage
}
@MainActor enum ShareCardRenderer {
  static func render(score: Int, mode: GameMode, combo: Int, accuracy: Double) -> UIImage {
    let view = ZStack {
      LinearGradient(
        colors: [Color.black, Color.cyan.opacity(0.5)], startPoint: .top, endPoint: .bottom)
      VStack(spacing: 22) {
        TargetLogo()
        Text("PERFECT TIMING").font(.title.weight(.black))
        Text(score.formatted()).font(.system(size: 64, weight: .black))
        Text(
          "\(mode.rawValue.capitalized) • \(combo) Combo • \(accuracy.formatted(.percent.precision(.fractionLength(1))))"
        )
        Text("Can you beat my score?").font(.title3.bold())
      }.foregroundStyle(.white)
    }.frame(width: 1080, height: 1350)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    return renderer.uiImage ?? UIImage()
  }
}
struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
