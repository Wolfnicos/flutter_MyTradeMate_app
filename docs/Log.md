## Logging & Diagnostics

Policy
- Telemetry is opt-in only (default off). Toggle in Settings under "Share anonymous diagnostics".
- No PII or API keys are stored; masking enforced by `AppLogger`.

Implementation
- `AppLogger` writes JSONL to a temp file with session ID.
- Context sanitization masks keys containing `key`/`secret` and long strings.
- Diagnostic bundle (`createDiagnosticBundle`) zips logs and anonymized config.

Retention
- Logs live in temp; users can export via diagnostics button. No background uploads.

Verification
- Manually run diagnostics and inspect zip: ensure `apiKeyMasked`/`apiSecretMasked` and `[REDACTED]` appear.



