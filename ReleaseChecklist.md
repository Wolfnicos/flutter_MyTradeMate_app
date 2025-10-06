## Store submission checklist (paper trading only)

This checklist prepares the app for App Store / Play Store submission with paper-trading functionality only (no real-money execution).

### Product and compliance
- App name, subtitle, keywords, description reviewed (no claims of financial advice)
- In-app disclaimer: “Educational use only. Paper trading — no real-money execution.”
- Terms & Conditions and Privacy Policy linked in Settings
- Support email reachable and monitored
- Privacy labels/manifests filled (no PII beyond preferences; opt-in telemetry off by default)

### Assets and branding
- App icons generated for iOS/Android (adaptive where applicable)
- Splash screen configured (light/dark); no timeouts; fast fade
- Screenshots for required storefront sizes (light/dark; small/large text scale)

### Platform manifests
- iOS: Info.plist contains required descriptions; PrivacyInfo.xcprivacy (if using iOS 17+ privacy manifests)
- Android: targetSdk/compileSdk updated; queries/permissions minimal; network security config if needed

### Build and versioning
- Semantic version bump (e.g., 1.0.0+1 → 1.0.1+2)
- Changelog prepared
- CI green: analyze, tests, cleaned-core coverage gate
- Release tracks prepared: TestFlight (iOS), Internal/Closed testing (Android)

### Stability and crash-free targets
- Crash-free session target: ≥ 99% (paper features)
- Basic smoke tests run on real/simulator devices

### Paper-only guardrails
- PAPER_TRADING flag enforced; no API key input required for release variant (or guarded behind testnet mode)
- Error messages avoid financial advice; show paper-only notices where relevant

### Store metadata
- Age rating questionnaire complete
- Category/subcategory correct (Finance/Education)
- Contact and links tested (support, T&C, privacy)

### Submissions
- iOS: Archive, upload via Transporter/Xcode; set release notes; submit for review
- Android: Upload AAB to Play Console; content rating; privacy; release notes; roll out to track

### Post-submit
- Monitoring dashboards ready (crash logs, anonymized diagnostics)
- Hotfix plan documented

---

## Commands and CI

### Android (local)
```
flutter clean && flutter pub get
flutter build appbundle --release
flutter build apk --release
```

### iOS (local, no codesign archive)
```
flutter clean && flutter pub get
flutter build ios --release --no-codesign
```

### CI hooks
- Ensure jobs run: analyze, test (–j 1), coverage gate, release build artifacts (AAB/APK, iOS archive)
- Artifacts uploaded with build number and commit SHA

### Verification before tag
- All epics/story tasks ticked & tested: see `docs/ProjectBoard.md`
- Coverage gate met and module breakdown: see `TestCoverage.md`


