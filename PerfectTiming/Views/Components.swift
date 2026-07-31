import PerfectTimingCore
import SwiftUI

extension Color {
  init(hex: String) {
    let value = UInt64(hex, radix: 16) ?? 0
    self.init(
      red: Double((value >> 16) & 255) / 255,
      green: Double((value >> 8) & 255) / 255,
      blue: Double(value & 255) / 255)
  }
}

struct NeonBackground: View {
  var body: some View {
    ZStack {
      Color(red: 0.01, green: 0.02, blue: 0.07)
      RadialGradient(
        colors: [.cyan.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 380)
      Canvas { context, size in
        for index in 0..<26 {
          let x = CGFloat((index * 73) % 101) / 100 * size.width
          let y = CGFloat((index * 47) % 103) / 102 * size.height
          context.fill(
            Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
            with: .color(.white.opacity(0.24)))
        }
      }
    }.ignoresSafeArea()
  }
}

struct NeonCard<Content: View>: View {
  let content: Content
  init(@ViewBuilder content: () -> Content) { self.content = content() }
  var body: some View {
    content.padding(18)
      .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 24))
      .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12)))
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.headline.bold()).frame(maxWidth: .infinity, minHeight: 58)
      .foregroundStyle(.black)
      .background(
        LinearGradient(
          colors: [.white, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 20)
      )
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.spring(response: 0.2), value: configuration.isPressed)
  }
}

struct StatPill: View {
  let icon: String
  let value: String
  var body: some View {
    Label(value, systemImage: icon).font(.subheadline.bold()).padding(.horizontal, 12).padding(
      .vertical, 8
    ).background(.white.opacity(0.08), in: Capsule())
  }
}

struct ProgressBar: View {
  let progress: Double
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.12))
        Capsule().fill(
          LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
        ).frame(width: geometry.size.width * max(0, min(1, progress)))
      }
    }.frame(height: 8)
  }
}

struct EmptyState: View {
  let icon: String
  let title: LocalizedStringKey
  let detail: LocalizedStringKey
  var body: some View {
    ContentUnavailableView(title, systemImage: icon, description: Text(detail))
  }
}
