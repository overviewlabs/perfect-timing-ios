# Perfect Timing

A polished one-touch timing game for iPhone, built with SwiftUI, SpriteKit, StoreKit 2, GameKit, AVFoundation, UIKit haptics, UserNotifications, Swift Charts, and a versioned Codable save system. The base game has no backend, login, analytics, tracking, or required network connection.

## Product defaults

| Setting | Value |
|---|---|
| Display name | Perfect Timing |
| Temporary bundle ID | `com.whox.perfecttiming` |
| Deployment target | iOS 17+ |
| Devices | iPhone only |
| Orientation | Portrait only |
| Default mode | Classic |
| Default theme | Neon Blue |
| Starting currency | 250 Timing Coins |
| Language | English; String Catalog ready |

## Architecture

- `Sources/PerfectTimingCore`: portable domain models, balancing, persistence, economy, progression, daily systems, missions, achievements, ad cooldowns, and tests.
- `PerfectTiming/App`: lifecycle, navigation, dependency injection, and save orchestration.
- `PerfectTiming/Game`: SpriteKit gameplay, challenge protocol/factory, session state, modes, scoring feedback, pause, revive, and game over.
- `PerfectTiming/Services`: audio, haptics, StoreKit 2, Game Center, notifications, and ad abstraction.
- `PerfectTiming/Views`: all production screens grouped by feature.
- `PerfectTiming/Resources`: assets, localization, StoreKit test configuration, entitlements, privacy manifest, launch configuration.
- `Tests`: deterministic core and UI tests.

See [Architecture](docs/ARCHITECTURE.md), [App Store metadata](docs/APP_STORE_METADATA.md), and [icon specification](docs/APP_ICON.md).

## Folder tree

```text
Perfect Timing/
├── .github/workflows/ios-build.yml
├── PerfectTiming/
│   ├── App/
│   ├── Game/
│   ├── Models/
│   ├── Services/
│   ├── Views/{Home,Modes,Game,Settings}/
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Info.plist
│       ├── Localizable.xcstrings
│       ├── PerfectTiming.entitlements
│       ├── PerfectTiming.storekit
│       └── PrivacyInfo.xcprivacy
├── Sources/PerfectTimingCore/
├── Tests/{PerfectTimingCoreTests,PerfectTimingUITests}/
├── Scripts/
├── docs/
├── Package.swift
└── project.yml
```

## Requirements

- Xcode 16 or newer with an iOS 17+ SDK
- Swift 6 language mode where supported
- XcodeGen (`brew install xcodegen`)
- Active Apple Developer membership only for signed device builds, TestFlight, Game Center, and App Store distribution
- No third-party runtime package is required

## Open and run

```bash
xcodegen generate --spec project.yml
open PerfectTiming.xcodeproj
```

In Xcode, select the **PerfectTiming** scheme and an iPhone simulator, then Run. For local StoreKit testing, choose **Product → Scheme → Edit Scheme → Run → Options** and select `PerfectTiming.storekit`.

## Bundle identifier and signing

1. Change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` if `com.whox.perfecttiming` is not the final identifier.
2. Set `DEVELOPMENT_TEAM` in Xcode or `project.yml`.
3. Regenerate the project.
4. Select the app target under **Signing & Capabilities**.
5. Enable automatic signing or install a matching distribution certificate/profile.
6. Create the matching explicit App ID in Apple Developer and enable Game Center.

Never commit `.p8`, `.p12`, provisioning profiles, passwords, or private keys.

## StoreKit 2 setup

Placeholder product identifiers are centralized in `StoreConfiguration`:

- `com.yourcompany.perfecttiming.premium`
- `com.yourcompany.perfecttiming.cosmeticbundle1`
- `com.yourcompany.perfecttiming.coins.small`
- `com.yourcompany.perfecttiming.coins.medium`
- `com.yourcompany.perfecttiming.coins.large`

Before release:

1. Create the non-consumables and consumables in App Store Connect.
2. Replace placeholder identifiers in both `StoreConfiguration` and `PerfectTiming.storekit` if needed.
3. Add localized display names, descriptions, prices, and review screenshots.
4. Sign the Paid Applications Agreement and complete tax/banking details.
5. Test success, cancellation, pending Ask to Buy, offline launch, restore, and revoked transactions.

`StoreManager` grants only verified StoreKit transactions, listens for updates, restores purchases, refreshes entitlements, and leaves the game usable when product loading fails. Premium is a one-time non-consumable, never described as a subscription.

## Game Center setup

1. Enable Game Center on the App ID and App Store Connect app record.
2. Create Classic, Rush, Precision, Chaos, and Daily leaderboards.
3. Create matching achievements.
4. Replace `com.yourcompany...` values in `GameCenterManager` and achievement configuration.
5. Add the final identifiers to App Store Connect and test with sandbox accounts.

Authentication is optional. Failures do not block gameplay. Scores can be retained in `pendingScores` for a production retry policy.

## Audio

The included `AudioManager` generates lightweight procedural tones and uses the ambient audio category with `mixWithOthers`, so missing files cannot crash the app and other music is respected. To use mastered sounds, add files to an asset or resource folder, preload them, and map these cues: menu, round start, Perfect, Excellent, Great, Good, Close, Miss, combo increase, combo milestone, coin, reward, purchase, game over, revive, countdown, and daily completion. Keep SFX and music volume controls separate.

## Advertising SDK integration

The base project intentionally has no ad SDK. `AdService` owns loading, availability, display, and rewarded completion. `MockAdService` makes development fully functional.

To integrate a provider:

1. Add its package/SDK to a separate adapter target.
2. Implement `AdService` without importing the SDK into gameplay or SwiftUI screens.
3. Inject the adapter in `AppCoordinator.live()`.
4. Update the privacy manifest, App Store privacy labels, consent flow, age-rating answers, and ATT behavior based on the SDK's actual data use.
5. Show ATT only if the configured SDK tracks users across apps/websites.
6. Verify premium suppression and configured run/time cooldowns.

Interstitials must never appear during gameplay, onboarding, every run, practice, or for Premium owners. Rewarded opportunities remain voluntary.

## Icons and launch assets

The included artwork is original and programmatically generated:

```bash
python3 Scripts/generate-assets.py
```

Replace `AppIcon-1024.png` with an opaque 1024 × 1024 production icon. Do not add text or pre-rounded corners. See `docs/APP_ICON.md`.

## Privacy and legal URLs

Update `ExternalLinks` and publish final routes before submission. The base app collects no personal data and uses no tracking. Any advertising SDK may change privacy disclosures and manifest requirements.

## Tests and verification

Portable verification on Linux or macOS:

```bash
./Scripts/verify.sh
```

This formats/lints, parses all Swift source, runs deterministic Swift tests, validates JSON, and lints property lists. Full iOS type checking requires Apple hardware/Xcode:

```bash
xcodegen generate --spec project.yml
xcodebuild -project PerfectTiming.xcodeproj -scheme PerfectTiming \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO clean build test
```

Core tests cover accuracy thresholds, scoring, combo behavior, difficulty, XP/levels, safe spending, duplicate rewards, daily rewards/seeds, missions, achievements, save migration, ad cooldowns, and revive eligibility. UI tests cover first launch/onboarding, Classic gameplay, tapping, ending/restarting, shop, inventory, settings, and restore purchases.

## Archive and TestFlight

1. Replace all external TODO values.
2. Create the App Store Connect app and IAP/Game Center records.
3. Confirm signing and capabilities.
4. Increment version/build.
5. Run all tests on a current iPhone simulator and physical iPhone.
6. In Xcode select **Any iOS Device (arm64)**, then **Product → Archive**.
7. Validate the archive and inspect bundle ID, version, privacy manifest, entitlements, icon, and embedded profile.
8. Distribute to App Store Connect.
9. Wait for Apple processing to become valid.
10. Add the build to an internal TestFlight group and verify installation/launch before external testing.

The checked-in GitHub workflow performs an unsigned simulator build/test on hosted Apple hardware. Signed TestFlight upload remains blocked until the final App Store record, product IDs, Game Center identifiers, team/signing assets, App Store Connect key, and tester group are supplied.

## App Store submission checklist

- [ ] Final bundle ID and Apple team
- [ ] App Store Connect app record
- [ ] Game Center leaderboards and achievements
- [ ] StoreKit product identifiers and approved metadata
- [ ] Advertising provider identifiers, SDK privacy details, and consent policy if ads are enabled
- [ ] Published privacy, terms, support, and marketing URLs
- [ ] Final icon and screenshots on current iPhone sizes
- [ ] Age rating and privacy questionnaire
- [ ] Accessibility checks with VoiceOver, Dynamic Type, high contrast, and reduced motion
- [ ] Offline, interruption, background, purchase restore, and corrupted-save tests
- [ ] Signed archive and TestFlight installation

## External TODO values

Search the repository for `TODO:`. Only Apple signing/team information, App Store Connect configuration, product/Game Center identifiers, advertising provider configuration, external URLs, and final production art/audio are intentionally external.
