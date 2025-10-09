## Model Card

Overview
- Task: Directional move probability and volatility estimate for liquid spot pairs.
- Inputs: features from ticker/klines; no user data.

Training
- Split: time-ordered 80% train / 20% validation.
- Calibration: Platt or Isotonic (see assets/models/calibration.json).

Metrics (validation)
- ECE, Brier, LogLoss, ROC-AUC reported in `artifacts/calibration_report.json`.
- Seed and commit recorded for reproducibility.

Limitations
- Not designed for illiquid assets; assumes continuous pricing.
- No guarantees; for educational purposes, not financial advice.

Calibration Notice
- Probabilities are post-calibration; fallback to identity if file missing or invalid.





