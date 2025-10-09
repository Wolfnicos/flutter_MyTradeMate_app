## Release Checklist

Privacy & Telemetry
- Telemetry opt-in only (default off). Toggle present in Settings and persisted in `TradingPrefs`.
- Privacy policy mentions opt-in diagnostics only; no PII, API keys masked.
- First-run disclaimer and trading consent present and tested.

Model Disclosure
- `ModelCard.md` filled with features, training splits, limitations, and calibration notice.

Diagnostics
- `createDiagnosticBundle()` includes logs and anonymized config; secrets masked.
- Manual validation: open produced zip and confirm `[REDACTED]` masking.

Store Assets
- App icons, screenshots, feature graphics ready.
- App descriptions and contact/support links updated.

iOS
- Provisioning profiles set. `tool/release_ios.sh` builds and signs.
- Usage descriptions set where needed; App Privacy answers align with telemetry opt-in.

Android
- AAB packaging via `tool/release_android.sh`.
- Target SDK current; permissions minimal.

Security
- No secrets in repo. CI uses GitHub Secrets only.
- Dependency audit reviewed; no blocking CVEs.

CI Gates
- Full test suite green with concurrency=1.
- Cleaned-core coverage ≥ 60%.
- Red-team WS flaps test stable.





