import os, json, argparse, sys
import pandas as pd
import numpy as np

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def load_tf_cfg():
    with open(os.path.join(REPO, "assets", "config", "timeframes.json"), "r") as f:
        return json.load(f)["tfs"]

def label_frame(df: pd.DataFrame, horizon: int, flat_band_bps: float):
    df = df.copy()
    df["ret_fut"] = df["close"].shift(-horizon) / df["close"] - 1.0
    df["vol_proxy"] = df["close"].pct_change().rolling(32).std().fillna(0.0)
    band = flat_band_bps / 10000.0
    cls = np.where(df["ret_fut"] >  band,  1,
          np.where(df["ret_fut"] < -band, -1, 0))
    df["dir"] = cls
    if horizon > 0:
        df = df.iloc[:-horizon]
    return df

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in_dir",  default=os.path.join(REPO, "ai", "data", "processed"))
    ap.add_argument("--out_dir", default=os.path.join(REPO, "ai", "data", "processed"))
    args = ap.parse_args()

    tf_cfg = load_tf_cfg()
    if not os.path.isdir(args.in_dir):
        print(f"in_dir not found: {args.in_dir}", file=sys.stderr); return 2

    feats = [f for f in os.listdir(args.in_dir) if f.endswith("_feat.csv")]
    if not feats:
        print("No *_feat.csv files found.", file=sys.stderr); return 3

    for fname in sorted(feats):
        base = fname[:-9]
        try:
            sym, tf = base.rsplit("_", 1)
        except ValueError:
            continue
        cfg = tf_cfg.get(tf)
        if not cfg:
            continue
        horizon = int(cfg.get("horizon", 1))
        flat_bps = float(cfg.get("flat_band_bps", 10.0))

        df = pd.read_csv(os.path.join(args.in_dir, fname))
        required = {"timestamp","open","high","low","close","volume"}
        if not required.issubset(df.columns):
            continue

        labeled = label_frame(df, horizon=horizon, flat_band_bps=flat_bps)
        out = os.path.join(args.out_dir, f"{sym}_{tf}_dataset.csv")
        labeled.to_csv(out, index=False)
        print(f"labeled {out} rows={len(labeled)} horizon={horizon} band_bps={flat_bps}")

    print("make_labels.py DONE")
    return 0

if __name__ == "__main__":
    sys.exit(main())
