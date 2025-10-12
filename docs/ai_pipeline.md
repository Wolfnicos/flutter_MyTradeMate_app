
# AI Pipeline Documentation

## Overview

MyTradeMate folosește un pipeline ML modular cu 3 modele independente pentru predicții crypto:
1. **DirectionModel** - Probabilități BUY/HOLD/SELL (multiclass softmax)
2. **ReturnModel** - Randament estimat pentru următoarea perioadă (regresie)
3. **VolatilityModel** - Volatilitate anualizată estimată (regresie)

Fiecare model are **TFLite implementation + rule-based fallback** pentru robustitate.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Input: OHLCV Data                   │
│                     (Candles + Volume)                  │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Feature Engineering                        │
│  - Log returns: ln(close_t / close_{t-1})              │
│  - RSI (14), EMA (12/26), MACD                         │
│  - ATR, OBV, Bollinger Bands                           │
│  - EWMA Volatility (λ=0.94)                            │
│  - Relative Volume vs SMA20                            │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│                  3 ML Models (Parallel)                 │
│                                                         │
│  ┌──────────────┐  ┌─────────────┐  ┌───────────────┐ │
│  │ Direction    │  │   Return    │  │  Volatility   │ │
│  │  Model       │  │   Model     │  │    Model      │ │
│  │              │  │             │  │               │ │
│  │ pBuy,pHold,  │  │ expReturn   │  │  annVol       │ │
│  │ pSell        │  │ (±5%)       │  │  (1-300%)     │ │
│  └──────────────┘  └─────────────┘  └───────────────┘ │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Ensemble Strategies (Vote)                 │
│  - Trend Following                                      │
│  - Mean Reversion                                       │
│  - Momentum                                             │
│  → Majority wins (2/3 or 3/3)                          │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│               Signal Engine (Decision)                  │
│  - Cross-validate action vs target                     │
│  - Apply thresholds (upThresh, downThresh, confThresh) │
│  - Check volatility cap (volCap)                       │
│  - Fix contradictions (SELL + target UP → HOLD)        │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│                Final Prediction                         │
│  action: BUY/HOLD/SELL                                 │
│  confidence: 20-95%                                     │
│  targetPrice: current * (1 + expReturn)                │
│  volatility: LOW/MEDIUM/HIGH                            │
└─────────────────────────────────────────────────────────┘
```

---

## Mathematical Formulas

### 1. Log Return
```
r_t = ln(Close_t / Close_{t-1})
```

### 2. EWMA Volatility (Exponentially Weighted Moving Average)
```
σ_t = sqrt((1-λ) * Σ λ^(i-1) * r_{t-i}^2)

where:
- λ = 0.94 (decay factor, RiskMetrics standard)
- Annualized: σ_annual = σ_daily * sqrt(365)
```

### 3. Relative Volume
```
RV_t = Vol_t / SMA_{Vol,20}

where:
- Vol_t = current volume
- SMA_{Vol,20} = 20-period simple moving average of volume
```

### 4. Confidence Score
```
confidence = maxProb * (1 - min(1, σ/volCap)) * min(1.2, max(0.8, RV_t)) / 1.2

where:
- maxProb = max(pBuy, pHold, pSell)
- σ = annualized volatility
- volCap = 0.85 (85% cap)
- RV_t = relative volume (boosts confidence if high)
```

### 5. Sharpe Ratio (Annualized)
```
Sharpe = (μ * 365) / (σ * sqrt(365))

where:
- μ = mean daily return
- σ = standard deviation of daily returns
- Assumes risk-free rate = 0
```

### 6. Sortino Ratio (Annualized)
```
Sortino = (μ * 365) / (σ_downside * sqrt(365))

where:
- σ_downside = std dev of negative returns only
```

### 7. Maximum Drawdown
```
MDD = min((V_t / peak_t) - 1)

where:
- peak_t = running maximum of equity curve
```

---

## Thresholds & Parameters

### Default StrategySettings:
```dart
upThresh = 0.003      // +0.3% pentru BUY signal
downThresh = -0.003   // -0.3% pentru SELL signal
confThresh = 0.6      // 60% confidence minimum
volCap = 0.85         // 85% annual volatility cap
fee = 0.001           // 0.1% trading fee
slippage = 0.0005     // 0.05% slippage
```

### Decision Rules:

**BUY Signal:**
```
IF:
  expReturn >= upThresh (+0.3%)
  AND pBuy >= confThresh (60%)
  AND confidence >= confThresh (60%)
  AND annVol <= volCap (85%)
THEN:
  action = 'BUY'
```

**SELL Signal:**
```
IF:
  expReturn <= downThresh (-0.3%)
  AND pSell >= confThresh (60%)
  AND confidence >= confThresh (60%)
  AND annVol <= volCap (85%)
THEN:
  action = 'SELL'
```

**HOLD (Default):**
```
IF conditions not met OR high volatility:
  action = 'HOLD'
```

---

## Ensemble Strategies

### 1. Trend Following
```dart
if (trend == 'UP' && probUp >= 0.55) → BUY
if (trend == 'DOWN' && probUp <= 0.45) → SELL
else → HOLD

where:
trend = priceChange > +1% ? 'UP' : (< -1% ? 'DOWN' : 'FLAT')
```

### 2. Mean Reversion
```dart
deviation = (currentPrice - avgPrice) / avgPrice

if (deviation < -3% && probUp > 0.50) → BUY  (oversold)
if (deviation > +3% && probUp < 0.50) → SELL (overbought)
else → HOLD
```

### 3. Momentum
```dart
if (nextReturn > +2% && probUp >= 0.60) → BUY
if (nextReturn < -2% && probUp <= 0.40) → SELL
if (volatility > 15%) → HOLD (too risky)
else → HOLD
```

### Voting:
```
Majority wins (≥2/3 votes)
Confidence boost:
  - All 3 agree: +15%
  - 2 of 3 agree: +0%
  - No majority: -30%
```

---

## Cross-Validation

Purpose: **Eliminate contradictions** between action și target price.

```dart
if (action == 'SELL' && targetPrice > currentPrice) {
  debugPrint('⚠️ Contradiction: SELL but target UP → HOLD');
  action = 'HOLD';  // Auto-fix!
}

if (action == 'BUY' && targetPrice < currentPrice) {
  debugPrint('⚠️ Contradiction: BUY but target DOWN → HOLD');
  action = 'HOLD';  // Auto-fix!
}
```

**Example:**
```
Price: 105,435 EUR
Target: 110,707 EUR (+5%)
Initial Action: SELL

Cross-validation: SELL + target UP → CONTRADICTION!
Fixed Action: HOLD ✅
```

---

## Backtesting

### Inputs:
- `symbol`: ex 'BTCUSDT'
- `data`: List<Candle> (OHLCV historical)
- `initial`: Starting capital (default: 10,000)
- `position`: Position size fraction (default: 0.1 = 10%)
- `windowSize`: Lookback period (default: 50 candles)

### Execution:
```dart
for each candle in history:
  1. Get window of last 50 candles
  2. Predict with SignalEngine
  3. Decide action (BUY/HOLD/SELL)
  4. Execute if conditions met:
     - BUY: spend = cash * position
           qty += (spend * (1 - fee)) / (price * (1 + slippage))
     - SELL: proceeds = qty * (price * (1 - slippage))
             cash += proceeds * (1 - fee)
  5. Mark to market: equity = cash + qty * price
```

### Metrics Calculated:
- **Total Return**: (final / initial) - 1
- **CAGR**: (final / initial)^(1/years) - 1
- **Sharpe Ratio**: risk-adjusted return
- **Sortino Ratio**: downside risk-adjusted
- **Max Drawdown**: worst peak-to-trough loss
- **Win Rate**: % of profitable periods

---

## TFLite Models

### Model Files (in assets/models/):
- `direction_f32_builtin.tflite` - Direction (multiclass)
- `return_f32_builtin.tflite` - Return (regression)
- `volatility_f32_builtin.tflite` - Volatility (regression)

### Fallback Behavior:
If TFLite model fails to load:
- **DirectionModel**: RSI + EMA cross + MACD rules
- **ReturnModel**: Momentum-based estimation
- **VolatilityModel**: EWMA calculation (λ=0.94)

### Feature Engineering:
```dart
features = [
  logReturn,                    // ln(close_t / close_{t-1})
  (rsi14 - 50) / 50,           // RSI normalized to [-1, 1]
  (ema12 / ema26) - 1,         // EMA ratio deviation
  macdHistogram / close,        // MACD normalized
  min(1.0, volatility),         // Volatility capped
  min(2.0, relVolume) / 2.0,   // Relative volume [0, 1]
]
```

---

## Tuning Parameters

### Pentru piețe mai volatile (crypto meme coins):
```dart
settings = StrategySettings(
  upThresh: 0.005,     // +0.5% (mai conservator)
  downThresh: -0.005,  // -0.5%
  confThresh: 0.70,    // 70% (mai strict)
  volCap: 1.20,        // 120% (permite volatilitate mare)
)
```

### Pentru piețe mai stabile (BTC, ETH):
```dart
settings = StrategySettings(
  upThresh: 0.002,     // +0.2% (mai agresiv)
  downThresh: -0.002,
  confThresh: 0.55,    // 55% (mai permisiv)
  volCap: 0.60,        // 60% (strict pe vol)
)
```

### Pentru day trading:
```dart
settings = StrategySettings(
  upThresh: 0.001,     // +0.1% (scalping)
  downThresh: -0.001,
  confThresh: 0.65,
  volCap: 0.70,
  fee: 0.0015,         // 0.15% (mai mare pentru trading frecvent)
)
```

---

## iOS Optimization (Xcode 15/16/26)

### Podfile Settings:
```ruby
platform :ios, '13.0'  # Wide compatibility
use_frameworks! :linkage => :static
inhibit_all_warnings!
pod 'TensorFlowLiteSwift', '~> 2.12.0'

post_install:
  ENABLE_BITCODE = NO               # Deprecated in Xcode 14+
  DEAD_CODE_STRIPPING = YES
  SWIFT_VERSION = 5.0
  SWIFT_OPTIMIZATION_LEVEL = -Osize  # Size optimization (Release)
  GCC_OPTIMIZATION_LEVEL = s
  ONLY_ACTIVE_ARCH = NO (Release)    # Build all architectures
  ARCHS = arm64
```

### Key Points:
- **Bitcode OFF**: Deprecated, reduces build time
- **Size Optimization**: -Osize reduces app size
- **Static Linking**: Faster startup
- **ARM64 only**: Modern devices only

---

## Testing

### Unit Tests:
```bash
flutter test test/ai/
```

**Tests include:**
- Indicators calculation (RSI, EMA, MACD, etc.)
- Signal engine logic
- Backtester execution
- Metrics calculation
- Bounds validation

### Integration Test:
```bash
flutter test test/ai_helper_live_test.dart
```

### Backtest Demo:
```bash
# From Flutter test (not dart directly)
flutter test test/ai/backtest_test.dart
```

---

## Usage Examples

### 1. Get Prediction:
```dart
final engine = SignalEngine.full();
final candles = await fetchCandles('BTCUSDT', limit: 60);
final prediction = await engine.predict('BTCUSDT', candles);

print('Action: ${prediction.action}');
print('Confidence: ${prediction.confidencePercent.toStringAsFixed(1)}%');
print('Target: ${prediction.targetPrice(candles.last.close)}');
print('Volatility: ${prediction.annVolPercent.toStringAsFixed(1)}%');
```

### 2. Run Backtest:
```dart
final backtester = Backtester(engine, engine.settings);
final historical = await loadHistoricalData('BTCUSDT', days: 30);
final result = await backtester.run('BTCUSDT', historical);

print(result.metrics.toString());
print('Final Equity: \$${result.finalCapital}');
```

### 3. Custom Settings:
```dart
final customSettings = StrategySettings(
  upThresh: 0.005,
  confThresh: 0.70,
  volCap: 1.0,
);

final engine = SignalEngine.full(settings: customSettings);
```

---

## Performance Expectations

### DirectionModel:
- **Accuracy**: 55-65% (better than random 33%)
- **Precision (BUY)**: 60-70%
- **Recall (BUY)**: 50-60%

### ReturnModel:
- **MAE**: <2% (mean absolute error)
- **R²**: 0.15-0.30 (typical for financial data)

### VolatilityModel:
- **MAE**: <5% annual
- **Correlation**: 0.70-0.85 with realized vol

### Backtesting (BTCUSDT 30 days):
- **Sharpe Ratio**: 0.5-1.5 (good for crypto)
- **Max Drawdown**: 10-25%
- **Win Rate**: 50-60%

---

## Troubleshooting

### Issue: "TFLite model not found"
**Solution:** Models fall back to rule-based. Add .tflite files to `assets/models/` if you have trained models.

### Issue: "Confidence always low"
**Cause:** High volatility or weak signals.
**Solution:** Adjust `volCap` higher or `confThresh` lower.

### Issue: "Too many HOLD actions"
**Cause:** Thresholds too strict.
**Solution:** Reduce `upThresh`, `downThresh`, `confThresh`.

### Issue: "Contradictions in logs"
**Cause:** Model outputs don't align.
**Solution:** Cross-validation auto-fixes this. Check logs for "⚠️ Contradiction" messages.

---

## File Structure

```
lib/ai/
├── entities.dart              # Candle, Prediction, StrategySettings, Indicators
├── indicators.dart            # RSI, EMA, MACD, ATR, OBV, EWMA
├── signal_engine.dart         # Core decision engine
├── models/
│   ├── direction_model.dart   # BUY/HOLD/SELL probabilities
│   ├── return_model.dart      # Expected return
│   └── volatility_model.dart  # Annualized volatility
└── backtest/
    ├── backtester.dart        # Backtest simulation
    └── metrics.dart           # Sharpe, Sortino, MaxDD, WinRate

assets/models/
├── direction_f32_builtin.tflite
├── return_f32_builtin.tflite
└── volatility_f32_builtin.tflite

test/ai/
├── indicators_test.dart
├── signal_engine_test.dart
└── backtest_test.dart
```

---

## Best Practices

### 1. Always Validate Inputs:
- Clamp probability: 0.1 - 0.9
- Clamp returns: ±5%
- Clamp volatility: 1% - 300%

### 2. Use Ensemble for Robustness:
- Don't rely on single strategy
- Voting reduces errors
- Check agreement for confidence

### 3. Cross-Validate Outputs:
- Action must match target direction
- Auto-fix contradictions
- Log warnings for review

### 4. Realistic Bounds:
- Target price: ±10% max daily move
- Confidence: 20-95% (never overconfident)
- Returns: Conservative estimates

### 5. Test Thoroughly:
- Unit tests for all components
- Backtest on historical data
- Monitor contradiction warnings

---

## Future Enhancements

- [ ] Add Volume Model (4th model)
- [ ] Implement Platt calibration
- [ ] Add more ensemble strategies
- [ ] Real-time model retraining
- [ ] A/B testing framework
- [ ] Risk management layer
- [ ] Position sizing optimization

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-08  
**Author:** MyTradeMate Team





