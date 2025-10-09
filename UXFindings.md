## UX audit vs modern trading apps (HIG + common patterns)

This document highlights UX gaps and proposes targeted fixes aligned with platform Human Interface Guidelines (iOS/macOS HIG, Material 3) and patterns observed in modern trading apps. Each item lists estimated impact on claritate (clarity), viteză (speed), încredere (trust).

### Scope and benchmark
- First‑run/onboarding; permissions friction
- Order flows (confirm/undo), risk and error surfaces
- States quality: empty/error/loading/skeletons
- Feedback: haptics, toasts/snackbars, progress
- Navigation/deeplinks/restoration; RTL/text scaling; a11y
- Model transparency (“Why this signal?”), diagnostics/support

### Findings and targeted fixes

1) Onboarding and first‑run clarity
- Gap: No single first‑run checklist (keys, environment, consent to trade, fixed quote). Users discover settings ad‑hoc.
- Fix: Add a lightweight “Getting started” screen on first launch with 3 steps: Connect (API keys / Testnet), Preferences (fixed quote, paper vs live flag), Consent (explicit trading consent toggle). Persist completion in `TradingPrefs`.
- Impact: claritate: High, viteză: Medium, încredere: High

2) Permissions and privacy prompts
- Gap: Network-only; no camera/storage etc., but privacy stance and logs opt‑in not surfaced early.
- Fix: In Settings “Privacy & Diagnostics”, show telemetry toggle (off by default), link to `Log.md` policy. On first enable, show a brief explainer sheet.
- Impact: claritate: Medium, viteză: Low, încredere: High

3) Order placement confirmations and undo
- Gap: Place actions rely on validators, but no explicit confirmation or undo “grace” window common in trading apps.
- Fix: Add a confirmation bottom sheet (summarized order: side, qty, price, estimated fees). After placement, show a snackbar with “Undo” for N seconds (paper and live where cancellable). Map undo to cancel‑order call or revert in paper broker.
- Impact: claritate: High, viteză: Medium, încredere: High

4) Risk and guardrails surfacing
- Gap: RiskManager blocks with reasons, but UI messaging is inconsistent across screens.
- Fix: Standardize inline `InlineErrorBox` in order forms with specific violation reasons and links to edit preferences (cooldown, max position, loss cap). Add a “Learn more” link to a brief risk explainer.
- Impact: claritate: High, viteză: Medium, încredere: High

5) Empty/error/loading state polish
- Gap: Several screens use spinners only; empty lists lack helpful calls to action.
- Fix: Add skeletons for market chart and lists; descriptive empty states with primary CTA (e.g., “Connect keys” / “Try Testnet”). Ensure all error states use `ErrorMapper` and expose retry + copy diagnostics.
- Impact: claritate: High, viteză: Medium, încredere: Medium

6) Haptics and tactile feedback
- Gap: No platform haptics for success/error/confirm.
- Fix: Add light success haptic on order placed, warning haptic on blockers, selection haptic on toggles (respect system reduce‑motion/disable haptics settings).
- Impact: claritate: Low, viteză: Medium, încredere: Medium

7) Market details responsiveness
- Gap: Reload affordance exists; live region added. Skeleton on first load not present; chart error banner text dense.
- Fix: Add chart and price skeleton shimmer for first contentful paint; simplify chart error copy per `S.chartErrorPrefix`, and provide retry.
- Impact: claritate: Medium, viteză: High, încredere: Medium

8) Navigation, deep links, restoration
- Gap: Restoration tested for TradingModal; deep links basic. No system back behavior doc; no route-level a11y labels.
- Fix: Ensure each primary route has a semantic page label; add deep link examples to README; keep restoration IDs consistent across rebuilds.
- Impact: claritate: Medium, viteză: Medium, încredere: Medium

9) Text scaling, RTL, accessibility parity
- Status: Text-scale and RTL smoke tests added; Settings controls wrapped with Flexible/Wrap; semantics labels in place.
- Fix: Add focused a11y traversal checks on order form; ensure minimum tap targets (48dp), and consistent tooltip ↔ semantics label parity.
- Impact: claritate: Medium, viteză: Low, încredere: Medium

10) Model transparency (“Why this signal?”)
- Status: “Why this signal?” panel, `ExplanationBuilder`, ModelCard link exist.
- Fix: Add concise risk disclaimer inside panel; show staleness banner when features older than threshold; surface calibration status (Identity/Platt/Isotonic) read‑only.
- Impact: claritate: High, viteză: Low, încredere: High

11) Diagnostics & support
- Status: Structured logs and diagnostic bundle implemented; Settings button added with a11y label.
- Fix: Add “Include anonymized settings” checkbox in the bundle dialog; copy a short shareable issue text after create.
- Impact: claritate: Medium, viteză: Medium, încredere: High

12) Performance/feedback loops
- Gap: Some reloads rely on spinners; no batch progress cues for longer tasks.
- Fix: Use inline progress bars for backtests or long sync; keep UI Hz cap for prices; debounce expensive rebuilds with existing throttlers.
- Impact: claritate: Medium, viteză: High, încredere: Medium

13) Settings defaults and guardrails
- Gap: Defaults reasonable but not surfaced; user may not know recommended fixed quote or environment.
- Fix: Add helper texts (already present in part) and a “Recommended” badge for safe defaults; add quick toggle for Paper Trading (if wired).
- Impact: claritate: Medium, viteză: Medium, încredere: Medium

### Quick‑win priorities (next sprint)
1. Order confirm + undo snackbar (High clarity/trust)
2. Market skeletons + friendlier error states (High clarity/speed)
3. Risk violation standard UI with help link (High clarity/trust)
4. Haptics for order success/error (Medium speed/trust)
5. Onboarding “Getting started” first‑run (High clarity/trust)

### Notes on HIG alignment
- Respect system settings (reduce motion/haptics)
- Use clear hierarchy: titles, supporting text, primary action
- Maintain consistent spacing and tap targets
- Provide immediate, reversible feedback for destructive/critical actions





