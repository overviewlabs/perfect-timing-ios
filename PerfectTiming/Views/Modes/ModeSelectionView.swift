import PerfectTimingCore
import SwiftUI

struct ModeSelectionView: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    ZStack {
      NeonBackground()
      ScrollView {
        VStack(spacing: 14) {
          ForEach(GameMode.allCases, id: \.self) { mode in
            if mode != .daily { ModeCard(mode: mode) }
          }
        }.padding()
      }
    }.navigationTitle("Game Modes")
  }
}
struct ModeCard: View {
  @EnvironmentObject var app: AppCoordinator
  let mode: GameMode
  @State private var practiceDifficulty: DifficultyBand = .normal
  var locked: Bool { mode == .chaos && app.save.profile.level < GameConfiguration.chaosUnlockLevel }
  var body: some View {
    NeonCard {
      HStack(spacing: 16) {
        Image(systemName: icon).font(.title).frame(width: 46, height: 46).background(
          color.opacity(0.18), in: Circle()
        ).foregroundStyle(color)
        VStack(alignment: .leading, spacing: 5) {
          Text(name).font(.title3.bold())
          Text(description).font(.caption).foregroundStyle(.secondary)
          Text("Best: \((app.save.statistics.perMode[mode]?.highScore ?? 0).formatted())").font(
            .caption.bold())
          if locked {
            Text("Unlock at Level \(GameConfiguration.chaosUnlockLevel)").font(.caption)
              .foregroundStyle(.orange)
          }
        }
        Spacer()
        VStack {
          if mode == .practice {
            Picker("Difficulty", selection: $practiceDifficulty) {
              ForEach(DifficultyBand.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.labelsHidden()
          }
          Button(locked ? "Locked" : "Play") {
            if !locked {
              app.start(mode, practiceDifficulty: mode == .practice ? practiceDifficulty : nil)
            }
          }.buttonStyle(.borderedProminent).disabled(locked)
        }
      }
    }
  }
  private var name: String { mode.rawValue.capitalized }
  private var description: String {
    switch mode {
    case .classic: "Endless timing. One miss ends the run."
    case .rush: "Score as much as possible in 60 seconds."
    case .precision: "Tiny targets, three lives, huge rewards."
    case .chaos: "Unpredictable patterns and visual twists."
    case .practice: "Train freely with selectable difficulty."
    case .daily: "Today’s seeded challenge."
    }
  }
  private var icon: String {
    switch mode {
    case .classic: "infinity"
    case .rush: "timer"
    case .precision: "scope"
    case .chaos: "hurricane"
    case .practice: "figure.mind.and.body"
    case .daily: "calendar"
    }
  }
  private var color: Color {
    switch mode {
    case .classic: .cyan
    case .rush: .orange
    case .precision: .green
    case .chaos: .purple
    case .practice: .blue
    case .daily: .pink
    }
  }
}
