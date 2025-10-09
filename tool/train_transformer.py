#!/usr/bin/env python3
"""
Training script for TransformerDirectionModel

- Loads candles CSV/JSON, builds 15 canonical features per candle
- Shapes into sequences of length 64, with 3-class labels (BUY/HOLD/SELL)
- Trains a small Transformer encoder classifier in TensorFlow 2
- Exports a TFLite model compatible with Flutter runtime:
  Input:  [1, 64, 15] float32
  Output: [1, 3] logits (softmax to be applied client-side)

Usage:
  python tool/train_transformer.py --data data.json --out assets/models/transformer_direction.tflite
"""

import argparse
import json
import math
import os
from typing import List, Tuple

import numpy as np
import tensorflow as tf


SEQ_LEN = 64
N_FEATURES = 15
N_CLASSES = 3


def _features_from_window(window: List[dict]) -> np.ndarray:
    """Builds [SEQ_LEN, N_FEATURES] features matching app-side ModelUtils.
    Each window element is a dict with keys: time, open, high, low, close, volume
    """
    closes = np.array([w["close"] for w in window], dtype=np.float32)
    opens = np.array([w["open"] for w in window], dtype=np.float32)
    highs = np.array([w["high"] for w in window], dtype=np.float32)
    lows = np.array([w["low"] for w in window], dtype=np.float32)
    vols = np.array([w["volume"] for w in window], dtype=np.float32)

    feats = []
    for i in range(SEQ_LEN):
        f = []
        # Returns
        def ret(p):
            if i < p:
                return 0.0
            prev = closes[i - p]
            return 0.0 if prev == 0 else (closes[i] - prev) / prev

        f.append(ret(1))
        f.append(ret(5))
        f.append(ret(15))

        # HL range normalized by close
        close_i = closes[i]
        hl = (highs[i] - lows[i]) / (close_i if close_i != 0 else 1.0)
        f.append(hl)

        # CO ratio
        f.append(closes[i] / (opens[i] if opens[i] != 0 else 1.0))

        # EMAs (relative)
        def ema(arr, period):
            k = 2.0 / (period + 1)
            e = arr[0]
            for v in arr[1 : i + 1]:
                e = v * k + e * (1 - k)
            return e

        ema12 = ema(closes[: i + 1], 12)
        ema26 = ema(closes[: i + 1], 26)
        f.append(ema12 / (close_i if close_i != 0 else 1.0))
        f.append(ema26 / (close_i if close_i != 0 else 1.0))

        # MACD relative
        f.append((ema12 - ema26) / (close_i if close_i != 0 else 1.0))

        # RSI
        def rsi(period=14):
            if i < period:
                return 50.0
            gains = 0.0
            losses = 0.0
            for j in range(i - period + 1, i + 1):
                diff = closes[j] - closes[j - 1]
                if diff > 0:
                    gains += diff
                else:
                    losses -= diff
            if losses == 0:
                return 100.0
            rs = (gains / period) / (losses / period)
            return 100.0 - (100.0 / (1.0 + rs))

        f.append(rsi(14))

        # ATR (relative)
        def atr(period=14):
            if i < 1:
                return highs[i] - lows[i]
            end = i + 1
            start = max(1, end - period)
            trs = []
            for k in range(start, end):
                high = highs[k]
                low = lows[k]
                prev_close = closes[k - 1]
                tr = max(high - low, abs(high - prev_close), abs(low - prev_close))
                trs.append(tr)
            return np.mean(trs)

        f.append(atr(14) / (close_i if close_i != 0 else 1.0))

        # OBV normalized [0..1]
        obv = 0.0
        for k in range(1, i + 1):
            obv += vols[k] if closes[k] > closes[k - 1] else (-vols[k] if closes[k] < closes[k - 1] else 0.0)
        max_obv = np.sum(vols[: i + 1])
        obv_norm = 0.5 if max_obv == 0 else (obv / max_obv + 1.0) / 2.0
        f.append(obv_norm)

        # Volume rel + z
        avg_vol = np.mean(vols[: i + 1])
        vol_rel = vols[i] / (avg_vol + 1e-10)
        vol_z = (vols[i] - avg_vol) / (avg_vol + 1e-10)
        f.append(vol_rel)
        f.append(vol_z)

        # Rolling std/mean relative
        window_closes = closes[: i + 1]
        rolling_std = np.std(window_closes)
        rolling_mean = np.mean(window_closes)
        f.append(rolling_std / (close_i if close_i != 0 else 1.0))
        f.append(rolling_mean / (close_i if close_i != 0 else 1.0))

        feats.append(f)
    feats = np.array(feats, dtype=np.float32)
    return feats


def _label_from_window(window: List[dict], up=0.003, down=-0.003) -> int:
    """BUY=0, HOLD=1, SELL=2 by next-period return thresholds."""
    last = window[-1]["close"]
    nxt = window[-1].get("next_close", last)
    r = (nxt - last) / (last if last != 0 else 1.0)
    if r >= up:
        return 0
    if r <= down:
        return 2
    return 1


def load_data(path: str) -> List[dict]:
    with open(path, "r") as f:
        if path.endswith(".json"):
            return json.load(f)
        raise ValueError("Only JSON supported in this minimal example")


def make_dataset(rows: List[dict]) -> Tuple[np.ndarray, np.ndarray]:
    X = []
    y = []
    for i in range(SEQ_LEN, len(rows)):
        window = rows[i - SEQ_LEN : i]
        feats = _features_from_window(window)
        X.append(feats)
        y.append(_label_from_window(window))
    X = np.array(X, dtype=np.float32)
    y = np.array(y, dtype=np.int32)
    return X, y


def build_model() -> tf.keras.Model:
    inp = tf.keras.Input(shape=(SEQ_LEN, N_FEATURES), dtype=tf.float32, name="input")
    x = tf.keras.layers.LayerNormalization()(inp)
    # Small transformer encoder
    attn = tf.keras.layers.MultiHeadAttention(num_heads=2, key_dim=32)(x, x)
    x = tf.keras.layers.Add()([x, attn])
    x = tf.keras.layers.LayerNormalization()(x)
    x = tf.keras.layers.Dense(64, activation="relu")(x)
    x = tf.keras.layers.GlobalAveragePooling1D()(x)
    x = tf.keras.layers.Dense(32, activation="relu")(x)
    out = tf.keras.layers.Dense(N_CLASSES, name="logits")(x)
    model = tf.keras.Model(inp, out)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    return model


def export_tflite(model: tf.keras.Model, out_path: str):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(tflite_model)
    print(f"Saved TFLite model to {out_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True, help="Path to JSON candles")
    ap.add_argument("--out", default="assets/models/transformer_direction.tflite")
    args = ap.parse_args()

    rows = load_data(args.data)
    X, y = make_dataset(rows)
    print("Dataset:", X.shape, y.shape)

    model = build_model()
    model.summary()
    model.fit(X, y, epochs=10, batch_size=256, validation_split=0.1)
    export_tflite(model, args.out)


if __name__ == "__main__":
    main()


