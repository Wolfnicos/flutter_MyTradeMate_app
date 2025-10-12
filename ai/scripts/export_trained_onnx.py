import argparse, torch, torch.nn as nn, pathlib
parser = argparse.ArgumentParser()
parser.add_argument("--ckpt", required=True)
parser.add_argument("--onnx", required=True)
args = parser.parse_args()

class Tiny1D(nn.Module):
    def __init__(self, feat=9, hid=32, classes=3):
        super().__init__()
        self.proj = nn.Conv1d(feat, hid, kernel_size=1, bias=True)
        self.relu = nn.ReLU(inplace=True)
        self.pool = nn.AdaptiveAvgPool1d(1)
        self.head_cls = nn.Linear(hid, classes)
        self.head_reg = nn.Linear(hid, 1)
    def forward(self, x):
        x = x.transpose(1,2)
        h = self.pool(self.relu(self.proj(x))).squeeze(-1)
        return self.head_cls(h), self.head_reg(h).squeeze(-1)

ckpt = torch.load(args.ckpt, map_location="cpu")
m = Tiny1D(); m.load_state_dict(ckpt["model"]); m.eval()
dummy = torch.randn(1,64,9)
pathlib.Path(args.onnx).parent.mkdir(parents=True, exist_ok=True)
torch.onnx.export(
    m, dummy, args.onnx,
    input_names=["window"], output_names=["logits","ret"],
    opset_version=17, dynamic_axes={"window":{0:"B"}, "logits":{0:"B"}, "ret":{0:"B"}}
)
print("wrote", args.onnx)
