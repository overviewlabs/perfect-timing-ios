import PerfectTimingCore
import SwiftUI

struct HomeView: View {
  @EnvironmentObject var app: AppCoordinator
  @State private var checkedDailyReward = false
  var body: some View {
    ZStack {
      NeonBackground()
      ScrollView {
        VStack(spacing: 18) {
          HStack {
            Button {
              app.navigate(.profile)
            } label: {
              HStack {
                Image(systemName: "person.crop.circle.fill").font(.title)
                VStack(alignment: .leading) {
                  Text("Level \(app.save.profile.level)").font(.headline)
                  ProgressBar(progress: levelProgress)
                }.frame(width: 110)
              }
            }
            Spacer()
            StatPill(icon: "circle.hexagongrid.fill", value: app.save.economy.balance.formatted())
          }.foregroundStyle(.white)
          VStack(spacing: 5) {
            Text("PERFECT").font(.system(size: 44, weight: .black, design: .rounded))
            Text("TIMING").font(.system(size: 44, weight: .black, design: .rounded))
              .foregroundStyle(.cyan)
          }.padding(.vertical, 22)
          Button("PLAY") { app.start(.classic) }.buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("play-button")
          Button {
            app.navigate(.modes)
          } label: {
            Label("Choose Mode", systemImage: "square.grid.2x2.fill").frame(maxWidth: .infinity)
          }.buttonStyle(.bordered).controlSize(.large)
          DailyCard()
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            menuTile("Missions", "checklist", .missions)
            menuTile("Shop", "bag.fill", .shop)
            menuTile("Inventory", "paintbrush.fill", .inventory)
            menuTile("Achievements", "trophy.fill", .achievements)
            menuTile("Statistics", "chart.bar.fill", .statistics)
            menuTile("Leaderboards", "crown.fill", .leaderboards)
            menuTile("Premium", "sparkles", .premium)
            menuTile("Settings", "gearshape.fill", .settings)
          }
        }.padding(20)
      }
    }.toolbar(.hidden, for: .navigationBar)
      .task {
        guard !checkedDailyReward, !ProcessInfo.processInfo.arguments.contains("--uitesting") else {
          return
        }
        checkedDailyReward = true
        if let last = app.save.dailyReward.lastClaimDate,
          Calendar.current.isDate(last, inSameDayAs: Date())
        {
          return
        }
        app.navigate(.reward)
      }
  }
  private var levelProgress: Double {
    let level = app.save.profile.level
    let start = ProgressionManager.totalXPRequired(for: level)
    let next = ProgressionManager.totalXPRequired(for: min(50, level + 1))
    return next == start ? 1 : Double(app.save.profile.xp - start) / Double(next - start)
  }
  @ViewBuilder private func menuTile(
    _ title: LocalizedStringKey, _ icon: String, _ route: AppCoordinator.Route
  ) -> some View {
    Button {
      app.navigate(route)
    } label: {
      NeonCard {
        VStack(spacing: 10) {
          Image(systemName: icon).font(.title2).foregroundStyle(.cyan)
          Text(title).font(.subheadline.bold())
        }.frame(maxWidth: .infinity)
      }
    }.foregroundStyle(.white)
  }
}
struct DailyCard: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    Button {
      app.navigate(.daily)
    } label: {
      NeonCard {
        HStack {
          Image(systemName: "calendar.badge.clock").font(.largeTitle).foregroundStyle(.cyan)
          VStack(alignment: .leading) {
            Text("Daily Challenge").font(.headline)
            Text("Same challenge. One official score.").font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "chevron.right")
        }
      }
    }.buttonStyle(.plain).foregroundStyle(.white)
  }
}
