import subprocess, sys, tensorflow as tf
from pathlib import Path
onnx_path = Path(sys.argv[sys.argv.index("--onnx")+1]) if "--onnx" in sys.argv else Path("ai/artifacts/patchtst_BTCUSDT_15m.onnx")
saved = Path("/tmp/onnx2tf_saved_model"); saved.mkdir(parents=True, exist_ok=True)
cmd = ["onnx2tf","-i",str(onnx_path),"-o",str(saved),"--output_signaturedefs","-b","1","-ois","1,96,9"]
print("+"," ".join(cmd)); subprocess.check_call(cmd)
converter = tf.lite.TFLiteConverter.from_saved_model(str(saved))
converter.optimizations=[tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types=[tf.float16]
tfl = converter.convert()
out = Path(f"assets/models/{onnx_path.stem}_fp16.tflite")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(tfl)
print(f"✅ {out} ({out.stat().st_size} bytes)")
