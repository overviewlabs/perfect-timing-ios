#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source '/WHOX OS/Apple Developer/environment.sh' 2>/dev/null || true
cd "$ROOT"
swift-format lint --recursive Sources PerfectTiming Tests
swiftc -frontend -parse PerfectTiming/App/*.swift PerfectTiming/Game/*.swift PerfectTiming/Services/*.swift PerfectTiming/Models/*.swift PerfectTiming/Views/*.swift PerfectTiming/Views/Home/*.swift PerfectTiming/Views/Modes/*.swift PerfectTiming/Views/Game/*.swift PerfectTiming/Views/Settings/*.swift Tests/PerfectTimingUITests/*.swift
swift test
python3 -m json.tool PerfectTiming/Resources/Localizable.xcstrings >/dev/null
python3 -m json.tool PerfectTiming/Resources/PerfectTiming.storekit >/dev/null
plutil -lint PerfectTiming/Resources/Info.plist PerfectTiming/Resources/PerfectTiming.entitlements PerfectTiming/Resources/PrivacyInfo.xcprivacy
printf 'Perfect Timing portable verification passed.
'
