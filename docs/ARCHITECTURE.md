# Don’t Tap Yet! Architecture

## Runtime layers

1. **PerfectTimingCore** is an Apple-framework-independent Swift module containing balance configuration, accuracy, score, combo, progression, economy, missions, achievements, deterministic daily content, save models, migration, ad cooldowns, and revive policy.
2. **Game** owns `GameSession`, the reusable `TimingChallenge` protocol, `ChallengeFactory`, and `GameplayScene`. SpriteKit renders high-frequency motion; SwiftUI owns menus and overlays.
3. **Services** isolate AVFoundation, UIKit haptics, StoreKit 2, GameKit, notifications, and advertising.
4. **AppCoordinator** injects services, owns navigation and save state, and commits completed runs.
5. **Views** are feature-grouped and do not own economy, scoring, persistence, purchase verification, or challenge generation.

## Challenge extension point

Add a `ChallengeType`, implement `TimingChallenge`, and return it from `ChallengeFactory`. Every challenge reports a normalized distance, so scoring thresholds remain consistent.

## Offline behavior

Gameplay, saves, daily content, missions, achievements, cosmetics, and practice work without network access. StoreKit and Game Center degrade independently. Scores that cannot be submitted can be retained in `pendingScores` for retry.

## Persistence

`JSONPersistenceService` writes a versioned JSON save atomically, maintains a backup, recovers from corruption, and migrates old data. Purchase entitlements survive progress resets and are refreshed from StoreKit's verified transaction history.
