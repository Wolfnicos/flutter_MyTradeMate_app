import sys, csv
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "processed"
IMGS = ROOT / "vision" / "images"
OUT  = ROOT / "vision" / "labels"
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
    return df

def main():
    total = 0
    for s in SYMS:
        rows = []
        for tf in TFS:
            csv_path = DATA / f"{s}_{tf}_dataset.csv"
            if not csv_path.exists(): 
                continue
            df = load_df(csv_path)
            if df is None or len(df) < WIN+1: 
                continue
            idx = list(range(len(df)-WIN, WIN, -STRIDE))[:MAX_IMG_PER_SET]
            for i, end in enumerate(idx):
                # label = dir at last candle of the window
                label = int(df.iloc[end-1]["dir"]) if "dir" in df.columns else 0
                img = IMGS / f"{s}_{tf}" / f"{s}_{tf}_{i:03d}.png"
                if img.exists():
                    rows.append([f"{s}_{tf}/{img.name}", label])
                    total += 1
        out_csv = OUT / f"{s}.csv"
        with out_csv.open("w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["image","label"])
            w.writerows(rows)
        print(f"wrote {out_csv} rows={len(rows)}")
    print(f"TOTAL labeled images: {total}")

if __name__ == "__main__":
    sys.exit(main() or 0)
