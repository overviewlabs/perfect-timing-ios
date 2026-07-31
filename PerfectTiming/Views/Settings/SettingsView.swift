import PerfectTimingCore
import StoreKit
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var app: AppCoordinator
  @State private var showReset = false
  var body: some View {
    ZStack {
      NeonBackground()
      Form {
        Section("Audio") {
          LabeledContent("Music") { Slider(value: $app.save.settings.musicVolume, in: 0...1) }
          LabeledContent("Sound Effects") {
            Slider(value: $app.save.settings.effectsVolume, in: 0...1)
          }
          Toggle("Mute All", isOn: $app.save.settings.muteAll)
          Toggle("Haptics", isOn: $app.save.settings.haptics)
        }
        Section("Accessibility") {
          Toggle("Reduced Motion", isOn: $app.save.settings.reducedMotion)
          Toggle("High Contrast", isOn: $app.save.settings.highContrast)
          Toggle("Screen Shake", isOn: $app.save.settings.screenShake)
          LabeledContent("Particles") {
            Slider(value: $app.save.settings.particleIntensity, in: 0...1)
          }
          Toggle("Show Accuracy Percentage", isOn: $app.save.settings.showAccuracyPercentage)
        }
        Section("Services") {
          Button("Notifications") { app.navigate(.notifications) }
          Button("Game Center Dashboard") { app.gameCenter.showDashboard() }
          Button("Restore Purchases") { Task { await app.store.restore() } }
        }
        Section("About") {
          Button("Privacy, Terms & Support") { app.navigate(.legal) }
          Button("Rate Perfect Timing") { requestReview() }
          LabeledContent("Version", value: version)
        }
        Section("Progress") {
          Button("Replay Onboarding") {
            app.save.onboardingComplete = false
            app.persist()
          }
          Button("Reset Progress", role: .destructive) { showReset = true }
        }
        #if DEBUG
          Section("Developer") { Button("Open Debug Panel") { app.navigate(.debug) } }
        #endif
      }.scrollContentBackground(.hidden)
    }.navigationTitle("Settings")
      .onChange(of: app.save.settings) { _, value in
        app.audio.apply(value)
        app.haptics.enabled = value.haptics
        app.persist()
      }
      .confirmationDialog(
        "Reset all gameplay progress? Purchases will be preserved.", isPresented: $showReset,
        titleVisibility: .visible
      ) {
        Button("Reset Everything", role: .destructive) { app.resetProgress() }
        Button("Cancel", role: .cancel) {}
      }
  }
  private var version: String {
    "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
  }
  private func requestReview() {
    guard
      let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
    else { return }
    SKStoreReviewController.requestReview(in: scene)
  }
}

struct NotificationExplanationView: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    ZStack {
      NeonBackground()
      VStack(spacing: 24) {
        Image(systemName: "bell.badge.fill").font(.system(size: 72)).foregroundStyle(.cyan)
        Text("A gentle timing reminder").font(.largeTitle.black).multilineTextAlignment(.center)
        Text(
          "Get an optional reminder for daily challenges and unclaimed rewards. You can turn this off anytime."
        ).multilineTextAlignment(.center).foregroundStyle(.secondary)
        Button(app.notifications.authorized ? "Reminders Enabled" : "Enable Reminders") {
          Task {
            let allowed = await app.notifications.request()
            app.save.settings.notificationsEnabled = allowed
            app.persist()
          }
        }.buttonStyle(PrimaryButtonStyle())
        if app.notifications.authorized {
          Button("Disable Reminders", role: .destructive) {
            app.notifications.disable()
            app.save.settings.notificationsEnabled = false
            app.persist()
          }
        }
      }.padding()
    }.navigationTitle("Notifications")
  }
}
struct LegalView: View {
  var body: some View {
    ZStack {
      NeonBackground()
      List {
        Link("Privacy Policy", destination: URL(string: ExternalLinks.privacy)!)
        Link("Terms of Use", destination: URL(string: ExternalLinks.terms)!)
        Link("Support", destination: URL(string: ExternalLinks.support)!)
        Section("Privacy") {
          Text(
            "The base game collects no personal data, includes no analytics, and performs no cross-app tracking. A future advertising SDK may require updated privacy labels, consent, privacy manifests, and App Tracking Transparency disclosures."
          )
        }
      }.scrollContentBackground(.hidden)
    }.navigationTitle("Privacy & Legal")
  }
}
