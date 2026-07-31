import SwiftUI

struct OnboardingView: View {
  @EnvironmentObject var app: AppCoordinator
  @State private var page = 0
  @State private var marker: CGFloat = 0
  @State private var feedback = ""

  var body: some View {
    ZStack {
      NeonBackground()
      VStack(spacing: 28) {
        Spacer()
        TargetLogo()
        Text("Perfect Timing").font(.largeTitle.weight(.black))
        Text(headline).font(.title.bold()).multilineTextAlignment(.center)
        if page == 0 {
          timingDemo
        } else {
          Image(systemName: page == 1 ? "flame.fill" : "sparkles").font(.system(size: 70))
            .foregroundStyle(.cyan).symbolEffect(.pulse)
        }
        Spacer()
        Button(page < 2 ? "Continue" : "Play your first run") {
          if page < 2 {
            page += 1
          } else {
            app.save.onboardingComplete = true
            app.persist()
            app.start(.classic)
          }
        }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 24)
        Button("Skip") {
          app.save.onboardingComplete = true
          app.persist()
        }.foregroundStyle(.secondary).opacity(page == 0 ? 1 : 0)
        Spacer().frame(height: 24)
      }
    }.animation(.snappy, value: page)
  }

  private var headline: String {
    page == 0
      ? "Tap at the perfect moment"
      : page == 1 ? "Build combos. Score bigger." : "Coins unlock your style."
  }
  private var timingDemo: some View {
    VStack {
      ZStack {
        Capsule().fill(.cyan.opacity(0.25)).frame(width: 85, height: 70)
        Circle().fill(.white).frame(width: 28, height: 28).offset(x: marker).shadow(
          color: .cyan, radius: 12)
      }.frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture {
        feedback = abs(marker) < 24 ? "PERFECT" : "GREAT"
        app.haptics.reward()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { page = 1 }
      }.onAppear {
        withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: true)) { marker = 130 }
      }
      Text(feedback).font(.title2.weight(.black)).foregroundStyle(.cyan)
    }
  }
}
