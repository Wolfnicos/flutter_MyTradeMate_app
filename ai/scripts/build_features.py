import argparse, json, math, os, sys
from datetime import datetime, timedelta
import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

def load_cfg():
    instruments = os.path.join(REPO, "assets", "config", "instruments.json")
    tfs = os.path.join(REPO, "assets", "config", "timeframes.json")
    with open(instruments, "r") as f:
        ins = json.load(f)
    with open(tfs, "r") as f:
        tcfg = json.load(f)["tfs"]
    return ins["symbols"], tcfg

def tf_to_minutes(tf: str) -> int:
    tf = tf.lower()
    if tf.endswith("m"): return int(tf[:-1])
    if tf.endswith("h"): return int(tf[:-1]) * 60
    if tf in ("1d","1D"): return 24*60
    raise ValueError(f"Unknown timeframe: {tf}")

def synth_ohlcv(n, seed=7):
    rng = np.random.default_rng(seed)
    # random walk close
    steps = rng.normal(0, 0.002, size=n).cumsum()
    base = 100 * np.exp(steps)
    close = base
    open_ = np.concatenate([[base[0]], base[:-1]])
    high = np.maximum(open_, close) * (1 + rng.uniform(0, 0.001, size=n))
    low  = np.minimum(open_, close) * (1 - rng.uniform(0, 0.001, size=n))
    vol  = rng.lognormal(mean=8.0, sigma=0.5, size=n)
    return open_, high, low, close, vol

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO, "ai", "data", "processed"))
    ap.add_argument("--rows", type=int, default=1024)
    args = ap.parse_args()

    symbols, tcfg = load_cfg()
    os.makedirs(args.out, exist_ok=True)

    now = datetime.utcnow().replace(second=0, microsecond=0)
    for sym in symbols:
        for tf, cfg in tcfg.items():
            n = max(args.rows, cfg.get("seq", 256) + 10)
            minutes = tf_to_minutes(tf)
            idx = [now - timedelta(minutes=minutes*i) for i in range(n)][::-1]

            o,h,l,c,v = synth_ohlcv(n, seed=hash(sym+tf) % (2**32))
            df = pd.DataFrame({
                "timestamp": pd.to_datetime(idx),
                "open": o, "high": h, "low": l, "close": c, "volume": v
            })
            # simple features (placeholders) — reale vor fi adăugate ulterior
            df["ret_1"] = df["close"].pct_change().fillna(0.0)
            df["ema9"]  = df["close"].ewm(span=9, adjust=False).mean()
            df["ema21"] = df["close"].ewm(span=21, adjust=False).mean()
            df["atr"]   = (df["high"] - df["low"]).rolling(14).mean().fillna(0.0)

            out_path = os.path.join(args.out, f"{sym}_{tf}_feat.csv")
            df.to_csv(out_path, index=False)
            print(f"✅ wrote {out_path} rows={len(df)}")

    print("✅ build_features.py DONE (synthetic data). Replace later with real OHLCV fetch.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
