import json, torch, torch.nn as nn
from pathlib import Path
import argparse

parser=argparse.ArgumentParser()
parser.add_argument("--symbol", required=True)
parser.add_argument("--tf", required=True)
args=parser.parse_args()

root=Path.cwd()
ckpt_p=root/f"ai/artifacts/ckpts/{args.symbol}_{args.tf}.pt"
ckpt=torch.load(ckpt_p, map_location="cpu")
FEAT=ckpt.get("feat", ["open","high","low","close","volume","ret_1","ema9","ema21","atr"])
SEQ =ckpt.get("seq",96)

class Model(nn.Module):
    def __init__(self, nfeat):
        super().__init__()
        d_model=128; nhead=8; nlayers=4; dim_ff=256
        self.proj = nn.Linear(nfeat, d_model)
        enc_layer = nn.TransformerEncoderLayer(d_model=d_model, nhead=nhead, dim_feedforward=dim_ff, dropout=0.1, batch_first=True, norm_first=True)
        self.enc = nn.TransformerEncoder(enc_layer, num_layers=4)
        self.norm = nn.LayerNorm(d_model)
        self.head = nn.Sequential(nn.Linear(d_model, 128), nn.ReLU(), nn.Linear(128, 3))
    def forward(self,x):
        z=self.proj(x); z=self.enc(z); z=self.norm(z); z=z.mean(1); return self.head(z)

m=Model(len(FEAT)).eval()
m.load_state_dict(ckpt["state_dict"])
dummy=torch.randn(1, SEQ, len(FEAT))
onnx_path=root/f"ai/artifacts/patchtst_{args.symbol}_{args.tf}.onnx"
torch.onnx.export(m, dummy, onnx_path, input_names=["window"], output_names=["logits"], opset_version=17, dynamic_axes={"window":{0:"B"}})
print("wrote", onnx_path)
