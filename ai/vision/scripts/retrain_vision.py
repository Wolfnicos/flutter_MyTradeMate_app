import os
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, Model
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
from sklearn.model_selection import train_test_split

# Ensure import works when running from scripts folder
try:
    from generate_dataset import ChartPatternGenerator
except ImportError:
    from ai.vision.scripts.generate_dataset import ChartPatternGenerator


class VisionModelTrainer {
    def __init__(self):
        self.model = None
        self.history = None

    def build_improved_model(self, input_shape=(200, 320, 3)):
        inputs = layers.Input(shape=input_shape)

        x = layers.Conv2D(32, 3, activation='relu', padding='same')(inputs)
        x = layers.BatchNormalization()(x)
        x = layers.MaxPooling2D(2)(x)
        x = layers.Dropout(0.2)(x)

        x = layers.Conv2D(64, 3, activation='relu', padding='same')(x)
        x = layers.BatchNormalization()(x)
        x = layers.MaxPooling2D(2)(x)
        x = layers.Dropout(0.3)(x)

        x = layers.Conv2D(128, 3, activation='relu', padding='same')(x)
        x = layers.BatchNormalization()(x)
        x = layers.MaxPooling2D(2)(x)
        x = layers.Dropout(0.4)(x)

        x = layers.GlobalAveragePooling2D()(x)

        x = layers.Dense(256, activation='relu')(x)
        x = layers.BatchNormalization()(x)
        x = layers.Dropout(0.5)(x)

        x = layers.Dense(128, activation='relu')(x)
        x = layers.Dropout(0.3)(x)

        outputs = layers.Dense(3, activation='softmax', name='predictions')(x)
        model = Model(inputs, outputs)
        return model

    def create_augmentation_pipeline(self):
        return tf.keras.Sequential([
            layers.RandomBrightness(0.1),
            layers.RandomContrast(0.1),
            layers.GaussianNoise(0.01),
        ])

    def train_model(self, X_train, y_train, X_val, y_val):
        self.model = self.build_improved_model()
        self.model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
            loss='categorical_crossentropy',
            metrics=['accuracy']
        )

        callbacks = [
            EarlyStopping(patience=10, restore_best_weights=True),
            ReduceLROnPlateau(patience=5, factor=0.5, min_lr=0.0001),
        ]

        aug = self.create_augmentation_pipeline()
        X_train_aug = aug(X_train, training=True)

        self.history = self.model.fit(
            X_train_aug, y_train,
            validation_data=(X_val, y_val),
            epochs=100,
            batch_size=32,
            callbacks=callbacks,
            verbose=1,
        )
        return self.model

    def evaluate_model(self, X_test, y_test):
        results = self.model.evaluate(X_test, y_test, verbose=0)
        preds = self.model.predict(X_test, verbose=0)
        pred_cls = np.argmax(preds, axis=1)
        true_cls = np.argmax(y_test, axis=1)
        classes = ['buy', 'hold', 'sell']
        for i, name in enumerate(classes):
            mask = true_cls == i
            if np.sum(mask) > 0:
                acc = np.mean(pred_cls[mask] == i)
                print(f'{name} accuracy: {acc:.3f}')
        return results

    def export_to_tflite(self, output_path='assets/models/vision_fp16.tflite'):
        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        tflite_model = converter.convert()
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        print(f'Model exported to {output_path}')
        self.verify_tflite_model(output_path)

    def verify_tflite_model(self, model_path):
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()
        inp = interpreter.get_input_details()
        out = interpreter.get_output_details()
        print(f'Input shape: {inp[0]["shape"]}')
        print(f'Output shape: {out[0]["shape"]}')
        test_input = np.random.rand(1, 200, 320, 3).astype(np.float32)
        interpreter.set_tensor(inp[0]['index'], test_input)
        interpreter.invoke()
        output = interpreter.get_tensor(out[0]['index'])
        print(f'Test output: {output[0]}')
        print(f'Output sum: {np.sum(output[0])} (should be ~1.0)')


def main():
    gen = ChartPatternGenerator()
    X, y = gen.generate_dataset(samples_per_pattern=800, width=320, height=200)
    print(f'Class distribution: {np.bincount(np.argmax(y, axis=1))}')
    X_train, X_temp, y_train, y_temp = train_test_split(
        X, y, test_size=0.4, random_state=42, stratify=np.argmax(y, axis=1)
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp, test_size=0.5, random_state=42, stratify=np.argmax(y_temp, axis=1)
    )
    trainer = VisionModelTrainer()
    trainer.train_model(X_train, y_train, X_val, y_val)
    results = trainer.evaluate_model(X_test, y_test)
    print(f'Test results: {results}')
    trainer.export_to_tflite()


if __name__ == '__main__':
    main()


