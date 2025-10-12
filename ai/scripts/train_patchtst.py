import os, json, math, random, argparse, pandas as pd, numpy as np, torch, torch.nn as nn
from pathlib import Path
from torch.utils.data import Dataset, DataLoader

parser = argparse.ArgumentParser()
parser.add_argument("--symbol", required=True)
parser.add_argument("--tf", required=True)
parser.add_argument("--epochs", type=int, default=12)
parser.add_argument("--seq", type=int, default=96)
parser.add_argument("--batch", type=int, default=256)
parser.add_argument("--lr", type=float, default=3e-4)
parser.add_argument("--out_dir", default="ai/artifacts/ckpts")
args = parser.parse_args()

root = Path.cwd()
csv = root/f"ai/data/processed/{args.symbol}_{args.tf}_dataset.csv"
normp = root/"ai/artifacts/norm.json"
norm = json.loads(normp.read_text()) if normp.exists() else {"feature_order": ["open","high","low","close","volume","ret_1","ema9","ema21","atr"]}

FEAT = norm["feature_order"]
SEQ  = args.seq

df = pd.read_csv(csv, parse_dates=["timestamp"])
df = df.dropna().reset_index(drop=True)

X = df[FEAT].values.astype("float32")
y = df["dir"].astype(int).values
y = np.where(y==-1, 2, y)  # map [-1,0,1] -> [2,0,1]? we want [0,1,2]: use {-1:2,0:1,1:0} or simpler:
# Better: {-1:0,0:1,1:2}
y = df["dir"].map({-1:0,0:1,1:2}).values.astype("int64")

mu = X.mean(axis=0); sd = X.std(axis=0) + 1e-6
X = (X - mu)/sd

class SeqDS(Dataset):
    def __init__(self, X, y, seq):
        self.X=X; self.y=y; self.seq=seq
    def __len__(self): return len(self.X)-self.seq
    def __getitem__(self, i):
        w = self.X[i:i+self.seq]
        t = self.y[i+self.seq-1]
        return torch.from_numpy(w), torch.tensor(t)

N = len(X)-SEQ
split = int(N*0.85)
ds = SeqDS(X,y,SEQ)
tr_idx = list(range(split))
va_idx = list(range(split, N))
train = torch.utils.data.Subset(ds, tr_idx)
valid = torch.utils.data.Subset(ds, va_idx)

dl_tr = DataLoader(train, batch_size=args.batch, shuffle=True, drop_last=True)
dl_va = DataLoader(valid, batch_size=args.batch, shuffle=False, drop_last=False)

# PatchTST-lite style encoder: token proj + TransformerEncoder (dim=128, 4 layers, 8 heads)
class Model(nn.Module):
    def __init__(self, nfeat):
        super().__init__()
        d_model=128; nhead=8; nlayers=4; dim_ff=256
        self.proj = nn.Linear(nfeat, d_model)
        enc_layer = nn.TransformerEncoderLayer(d_model=d_model, nhead=nhead, dim_feedforward=dim_ff, dropout=0.1, batch_first=True, norm_first=True)
        self.enc = nn.TransformerEncoder(enc_layer, num_layers=nlayers)
        self.norm = nn.LayerNorm(d_model)
        self.head = nn.Sequential(nn.Linear(d_model, 128), nn.ReLU(), nn.Linear(128, 3))
    def forward(self, x):          # x [B, seq, feat]
        z = self.proj(x)
        z = self.enc(z)
        z = self.norm(z)
        z = z.mean(dim=1)          # GAP over time
        return self.head(z)

device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
model = Model(len(FEAT)).to(device)
opt = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
crit = nn.CrossEntropyLoss()

best = {"loss": 1e9}

for ep in range(1, args.epochs+1):
    model.train(); tl=0.0; n=0
    for xb,yb in dl_tr:
        xb=xb.to(device); yb=yb.to(device)
        opt.zero_grad()
        out=model(xb)
        loss=crit(out,yb)
        loss.backward(); opt.step()
        tl += loss.item()*len(xb); n+=len(xb)
    model.eval(); vl=0.0; vn=0; correct=0
    with torch.no_grad():
        for xb,yb in dl_va:
            xb=xb.to(device); yb=yb.to(device)
            out=model(xb)
            loss=crit(out,yb)
            vl += loss.item()*len(xb); vn+=len(xb)
            pred=out.argmax(dim=1); correct += (pred==yb).sum().item()
    va_loss=vl/max(1,vn); va_acc=correct/max(1,vn)
    print(f"ep {ep:02d}  tr_loss={tl/max(1,n):.4f}  va_loss={va_loss:.4f}  va_acc={va_acc:.3f}")
    if va_loss < best["loss"]:
        best = {"loss":va_loss,"acc":va_acc}
        Path(args.out_dir).mkdir(parents=True, exist_ok=True)
        torch.save({"state_dict":model.state_dict(),"feat":FEAT,"seq":SEQ}, Path(args.out_dir)/f"{args.symbol}_{args.tf}.pt")
print("saved", str(Path(args.out_dir)/f"{args.symbol}_{args.tf}.pt"))
