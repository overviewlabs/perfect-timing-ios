import PerfectTimingCore
import SwiftUI

@main
struct PerfectTimingApp: App {
  @StateObject private var coordinator = AppCoordinator.live()
  @Environment(\.scenePhase) private var scenePhase
  var body: some Scene {
    WindowGroup { RootView().environmentObject(coordinator) }
      .onChange(of: scenePhase) { _, phase in coordinator.handleScenePhase(phase) }
  }
}
