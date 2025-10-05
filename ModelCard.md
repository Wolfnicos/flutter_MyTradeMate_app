## ModelCard – MyTradeMate

**Task:** 1-step ahead direction (probUp)

**Targets:** next Δprice > 0 over horizon H (e.g., 5m)

**Features:** OHLCV-derived (RSI/EMA/etc.), recent momentum, spreads

**Data:** Symbols: BTCUSDT, ETHUSDT; Window: 2025-06..2025-09

**Splits:** chronological (train → calibrate → validate)

**Calibration:** {identity|platt|isotonic}; ECE=…; Brier=…; ROC-AUC=…

**Limits:** volatile regimes, latency lags, potential non-stationarity

**Safety:** no auto-trade without consent; policy guards (cooldown, caps)

**Versioning:** calibration.json v1; reproducible with seed & commit id

—

This file is auto-updatable alongside `assets/models/calibration.json` and `artifacts/calibration_report.json` from the backtest tooling.

