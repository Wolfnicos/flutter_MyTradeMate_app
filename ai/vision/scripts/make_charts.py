import sys
from pathlib import Path
import pandas as pd
import mplfinance as mpf

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "processed"
OUT  = ROOT / "vision" / "images"
OUT.mkdir(parents=True, exist_ok=True)

SYMS = ["BTCUSDT","ETHUSDT","BNBUSDT","TRUMPUSDT","WLFIUSDT"]
TFS  = ["5m","15m","1h","4h","1d"]

WIN = 128
STRIDE = 32
MAX_IMG_PER_SET = 64

def load_df(path: Path):
    df = pd.read_csv(path)
    if "timestamp" not in df.columns: return None
    df["timestamp"] = pd.to_datetime(df["timestamp"])
    df = df.set_index("timestamp", drop=True)
    rename = {"open":"Open","high":"High","low":"Low","close":"Close","volume":"Volume"}
    for k,v in rename.items():
        if k in df.columns: df[v] = df[k]
    need = ["Open","High","Low","Close","Volume"]
    if not all(c in df.columns for c in need): return None
    return df

def gen_images(sym, tf):
    csv = DATA / f"{sym}_{tf}_dataset.csv"
    if not csv.exists(): 
        print(f"skip (missing): {csv}")
        return 0
    df = load_df(csv)
    if df is None or len(df) < WIN+1:
        print(f"skip (short): {csv}")
        return 0

    out_dir = OUT / f"{sym}_{tf}"
    out_dir.mkdir(parents=True, exist_ok=True)

    style = mpf.make_mpf_style(base_mpf_style='nightclouds', gridstyle=':', y_on_right=False)
    saved = 0
    idx = list(range(len(df)-WIN, WIN, -STRIDE))
    for i, end in enumerate(idx[:MAX_IMG_PER_SET]):
        start = end - WIN
        win = df.iloc[start:end].copy()

        addplots = []
        for ema in ("ema9","ema21"):
            if ema in win.columns:
                addplots.append(mpf.make_addplot(win[ema], panel=0, width=1))
        if "vol_proxy" in win.columns:
            addplots.append(mpf.make_addplot(win["vol_proxy"], panel=1, width=1))

        fname = out_dir / f"{sym}_{tf}_{i:03d}.png"
        mpf.plot(
            win,
            type='candle',
            volume=True,
            addplot=addplots if addplots else None,
            style=style,
            mav=(9,21),
            figsize=(12,7),
            tight_layout=True,
            xrotation=0,
            savefig=dict(fname=str(fname), dpi=160, bbox_inches='tight')
        )
        saved += 1
    print(f"[{sym} {tf}] saved={saved} -> {out_dir}")
    return saved

def main():
    total = 0
    for s in SYMS:
        for tf in TFS:
            total += gen_images(s, tf)
    print(f"TOTAL images: {total}")

if __name__ == "__main__":
    sys.exit(main() or 0)
