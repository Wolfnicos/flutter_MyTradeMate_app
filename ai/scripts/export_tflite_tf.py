import os, shutil, tempfile, json, numpy as np
from pathlib import Path
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers as L

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "models"
ASSETS.mkdir(parents=True, exist_ok=True)

# input [batch, 64, 9] — aceleași 9 feature-uri din norm.json
inp = keras.Input(shape=(64, 9), name="inputs")
x = L.GlobalAveragePooling1D()(inp)
x = L.Dense(64, activation="relu")(x)
logits3 = L.Dense(3, name="logits3")(x)     # p(BUY/HOLD/SELL) (ne-softmax-uit)
reg2    = L.Dense(2, name="reg2")(x)        # [exp_return, ann_vol]
model = keras.Model(inp, [logits3, reg2])
model.summary()

# salvează ca SavedModel
tmp = Path(tempfile.mkdtemp(prefix="tf_saved_"))
saved_dir = tmp / "saved_model"
model.save(saved_dir, include_optimizer=False)

# TFLite FP16
conv = tf.lite.TFLiteConverter.from_saved_model(saved_dir.as_posix())
conv.optimizations = [tf.lite.Optimize.DEFAULT]
conv.target_spec.supported_types = [tf.float16]
tflite_fp16 = conv.convert()
(ASSETS / "patchtst_dummy_fp16.tflite").write_bytes(tflite_fp16)

# Copiem pe TF-urile tale ca să poată fi încărcate din app
for tf_name in ["5m","15m","1h","4h","1d"]:
    shutil.copyfile(ASSETS / "patchtst_dummy_fp16.tflite", ASSETS / f"patchtst_{tf_name}_fp16.tflite")

print("✅ TFLite FP16 scris în:", ASSETS)
