Structured logging and diagnostics

Goals
- Unified structured logs across services and UI
- Correlation ID per app session
- Opt-in telemetry only; privacy-safe; no PII

Log format
- JSON Lines (one JSON per line)
- Fields: ts (UTC ISO), level, session, msg, ctx{}
- Levels: trace, debug, info, warn, error
- Context: sanitized recursively; keys containing secret/apiKey/key are redacted; long strings masked

Correlation IDs
- A session ID is generated at startup and attached to all records (field: session)
- For workflows (e.g., placing orders), add logical sub-ids in ctx, e.g. { flow: 'placeOrder', step: 'validated' }

Telemetry (opt-in)
- Disabled by default
- When enabled, only aggregate counters/timings are recorded; never raw symbols, keys or timestamps tied to identity

Privacy / PII
- Never log raw API keys or secrets
- Mask long strings (keep head/tail)
- Prefer coarse-grained timings and anonymized labels

Diagnostic bundle
- Settings → Advanced → "Send diagnostic bundle"
- Creates a ZIP with:
  - logs: mytrademate.log.jsonl
  - config (anonymized): selected prefs with secrets redacted
  - app info: version, platform
- Prompts user to review before sharing

How to read
- Use jq: jq -r '.level + " " + .ts + " " + .msg' mytrademate.log.jsonl
- Filter by session: jq 'select(.session=="<id>")' mytrademate.log.jsonl








