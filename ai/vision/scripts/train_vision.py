import os, json, math, random, tensorflow as tf
from pathlib import Path
AUTOTUNE = tf.data.AUTOTUNE
ROOT = Path(__file__).resolve().parents[2]
IMGS = ROOT / "vision" / "images"
LABS = ROOT / "vision" / "labels"
OUT  = ROOT / "artifacts"
OUT.mkdir(parents=True, exist_ok=True)

IMG_SIZE = (224,224)
BATCH = 16
EPOCHS = 5
SEED = 42

def load_table():
  rows = []
  for csv in sorted(LABS.glob("*.csv")):
    with csv.open() as f:
      next(f)  # header
      for line in f:
        p,l = line.strip().split(",")
        rows.append((str(IMGS/p), int(l)))
  random.Random(SEED).shuffle(rows)
  n = len(rows)
  split = int(0.85*n)
  return rows[:split], rows[split:]

def decode(path, label):
  img = tf.io.read_file(path)
  img = tf.io.decode_png(img, channels=3)
  img = tf.image.resize(img, IMG_SIZE)
  img = tf.image.convert_image_dtype(img, tf.float32)
  return img, tf.cast(label+1, tf.int32)  # map {-1,0,1} -> {0,1,2}

def augment(img, label):
  img = tf.image.random_flip_left_right(img, seed=SEED)
  img = tf.image.random_brightness(img, 0.05, seed=SEED)
  return img, label

def make_ds(rows, train=True):
  paths = tf.constant([r[0] for r in rows])
  labels= tf.constant([r[1] for r in rows])
  ds = tf.data.Dataset.from_tensor_slices((paths, labels))
  ds = ds.map(decode, num_parallel_calls=AUTOTUNE)
  if train: ds = ds.map(augment, num_parallel_calls=AUTOTUNE)
  ds = ds.shuffle(1024, seed=SEED) if train else ds
  return ds.batch(BATCH).prefetch(AUTOTUNE)

def build_model():
  base = tf.keras.applications.EfficientNetB0(include_top=False, input_shape=(*IMG_SIZE,3), weights=None)
  x = tf.keras.layers.GlobalAveragePooling2D()(base.output)
  x = tf.keras.layers.Dropout(0.2)(x)
  out = tf.keras.layers.Dense(3, activation='softmax')(x)
  m = tf.keras.Model(base.input, out)
  m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
            loss='sparse_categorical_crossentropy',
            metrics=['accuracy'])
  return m

def main():
  train_rows, val_rows = load_table()
  train_ds = make_ds(train_rows, True)
  val_ds   = make_ds(val_rows, False)
  model = build_model()
  model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS, verbose=2)
  # export TFLite FP16
  conv = tf.lite.TFLiteConverter.from_keras_model(model)
  conv.optimizations = [tf.lite.Optimize.DEFAULT]
  conv.target_spec.supported_types = [tf.float16]
  tflite_model = conv.convert()
  tfl_path = ROOT / "assets" / "models" / "vision_fp16.tflite"
  tfl_path.parent.mkdir(parents=True, exist_ok=True)
  with open(tfl_path, "wb") as f:
    f.write(tflite_model)
  print(f"wrote {tfl_path} size={tfl_path.stat().st_size/1024/1024:.2f}MB")

if __name__ == "__main__":
  main()
