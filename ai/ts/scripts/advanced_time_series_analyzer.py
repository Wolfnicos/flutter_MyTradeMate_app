import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, MinMaxScaler
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import classification_report, confusion_matrix
import tensorflow as tf
from tensorflow.keras.models import Sequential, Model
from tensorflow.keras.layers import LSTM, Dense, Conv1D, MaxPooling1D, Flatten, Dropout, Input, Attention
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import warnings
warnings.filterwarnings('ignore')


class AdvancedTimeSeriesAnalyzer:
    def __init__(self, sequence_length=100):
        self.sequence_length = sequence_length
        self.scaler = StandardScaler()
        self.models = {}
        self.feature_extractors = {}
        
    def generate_synthetic_patterns(self, n_samples=1000):
        """Generează pattern-uri sintetice similare cu cele din imagini"""
        patterns = []
        labels = []
        
        for i in range(n_samples):
            t = np.linspace(0, 10, self.sequence_length)
            pattern_type = np.random.choice([0, 1, 2, 3])
            
            if pattern_type == 0:  # Trend crescător
                signal = 2 * t + np.random.normal(0, 0.5, len(t))
                label = 'upward_trend'
            elif pattern_type == 1:  # Trend descrescător
                signal = -2 * t + 20 + np.random.normal(0, 0.5, len(t))
                label = 'downward_trend'
            elif pattern_type == 2:  # Signal volatil
                signal = np.random.normal(0, 3, len(t)) + 0.5 * np.sin(5 * t)
                label = 'volatile'
            else:  # Pattern complex
                signal = 5 * np.sin(t) * np.exp(-t/8) + 2 * t + np.random.normal(0, 0.3, len(t))
                label = 'complex'
                
            patterns.append(signal)
            labels.append(label)
            
        return np.array(patterns), np.array(labels)
    
    def extract_advanced_features(self, signals):
        """Extrage feature-uri avansate pentru fiecare signal"""
        features = []
        
        for signal in signals:
            feature_vector = []
            
            # Statistical features
            feature_vector.extend([
                np.mean(signal),
                np.std(signal),
                np.var(signal),
                np.min(signal),
                np.max(signal),
                np.median(signal),
                np.percentile(signal, 25),
                np.percentile(signal, 75)
            ])
            
            # Trend features
            x = np.arange(len(signal))
            slope, intercept = np.polyfit(x, signal, 1)
            feature_vector.extend([slope, intercept])
            
            # Frequency domain features (FFT)
            fft = np.fft.fft(signal)
            fft_magnitude = np.abs(fft)
            feature_vector.extend([
                np.mean(fft_magnitude),
                np.std(fft_magnitude),
                np.argmax(fft_magnitude),  # dominant frequency
            ])
            
            # Volatility and momentum
            diff = np.diff(signal)
            feature_vector.extend([
                np.std(diff),  # volatility
                np.sum(diff > 0) / len(diff),  # momentum ratio
                np.sum(np.abs(diff) > 2 * np.std(diff)) / len(diff)  # spike ratio
            ])
            
            # Shape features
            feature_vector.extend([
                signal[0],  # starting value
                signal[-1],  # ending value
                signal[-1] - signal[0],  # total change
                np.sum(signal > np.mean(signal)) / len(signal)  # above mean ratio
            ])
            
            features.append(feature_vector)
            
        return np.array(features)
    
    def build_transformer_model(self, input_shape, num_classes):
        """Construiește un model Transformer pentru clasificarea pattern-urilor"""
        inputs = Input(shape=input_shape)
        
        # Positional encoding
        x = tf.keras.layers.LayerNormalization()(inputs)
        
        # Multi-head attention
        attention = tf.keras.layers.MultiHeadAttention(
            num_heads=8, key_dim=64
        )(x, x)
        attention = tf.keras.layers.Dropout(0.1)(attention)
        x = tf.keras.layers.Add()([x, attention])
        x = tf.keras.layers.LayerNormalization()(x)
        
        # Feed forward
        ff = tf.keras.layers.Dense(256, activation='relu')(x)
        ff = tf.keras.layers.Dropout(0.1)(ff)
        ff = tf.keras.layers.Dense(input_shape[-1])(ff)
        x = tf.keras.layers.Add()([x, ff])
        x = tf.keras.layers.LayerNormalization()(x)
        
        # Global average pooling and classification
        x = tf.keras.layers.GlobalAveragePooling1D()(x)
        x = tf.keras.layers.Dense(128, activation='relu')(x)
        x = tf.keras.layers.Dropout(0.3)(x)
        outputs = tf.keras.layers.Dense(num_classes, activation='softmax')(x)
        
        model = Model(inputs, outputs)
        return model
    
    def build_cnn_lstm_model(self, input_shape, num_classes):
        """Model hibrid CNN-LSTM pentru pattern recognition"""
        model = Sequential([
            Conv1D(64, 3, activation='relu', input_shape=input_shape),
            Conv1D(64, 3, activation='relu'),
            MaxPooling1D(2),
            Dropout(0.2),
            
            Conv1D(128, 3, activation='relu'),
            Conv1D(128, 3, activation='relu'),
            MaxPooling1D(2),
            Dropout(0.2),
            
            LSTM(100, return_sequences=True),
            Dropout(0.3),
            LSTM(50),
            Dropout(0.3),
            
            Dense(50, activation='relu'),
            Dropout(0.2),
            Dense(num_classes, activation='softmax')
        ])
        
        return model
    
    def diagnose_model_performance(self, X_test, y_test, predictions):
        """Diagnoză detaliată a performanței modelului"""
        print("=== MODEL PERFORMANCE DIAGNOSIS ===\n")
        
        # Classification report
        print("Classification Report:")
        print(classification_report(y_test, predictions))
        
        # Confusion Matrix Analysis
        cm = confusion_matrix(y_test, predictions)
        plt.figure(figsize=(10, 8))
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
        plt.title('Confusion Matrix')
        plt.ylabel('True Label')
        plt.xlabel('Predicted Label')
        plt.show()
        
        # Per-class analysis
        unique_labels = np.unique(y_test)
        for label in unique_labels:
            mask = y_test == label
            accuracy = np.mean(predictions[mask] == label)
            print(f"Accuracy for {label}: {accuracy:.3f}")
            
    def visualize_pattern_differences(self, signals, labels, predictions=None):
        """Vizualizare avansată pentru identificarea diferențelor"""
        fig = make_subplots(
            rows=2, cols=2,
            subplot_titles=['Upward Trend', 'Downward Trend', 'Volatile', 'Complex'],
            vertical_spacing=0.1
        )
        
        unique_labels = ['upward_trend', 'downward_trend', 'volatile', 'complex']
        positions = [(1,1), (1,2), (2,1), (2,2)]
        
        for i, label in enumerate(unique_labels):
            mask = labels == label
            if np.any(mask):
                sample_signals = signals[mask][:5]  # primele 5 exemple
                
                for j, signal in enumerate(sample_signals):
                    row, col = positions[i]
                    color = 'green' if predictions is None or predictions[np.where(mask)[0][j]] == label else 'red'
                    
                    fig.add_trace(
                        go.Scatter(
                            y=signal, 
                            mode='lines',
                            name=f'{label}_{j}',
                            line=dict(color=color, width=2),
                            showlegend=False
                        ),
                        row=row, col=col
                    )
        
        fig.update_layout(
            height=800,
            title_text="Pattern Analysis - Green: Correct, Red: Misclassified"
        )
        fig.show()
        
    def feature_importance_analysis(self, model, feature_names):
        """Analiză importanța feature-urilor"""
        if hasattr(model, 'feature_importances_'):
            importances = model.feature_importances_
            indices = np.argsort(importances)[::-1]
            
            plt.figure(figsize=(12, 8))
            plt.title("Feature Importance Analysis")
            plt.bar(range(len(importances)), importances[indices])
            plt.xticks(range(len(importances)), [feature_names[i] for i in indices], rotation=45)
            plt.tight_layout()
            plt.show()
            
            print("Top 10 Most Important Features:")
            for i in range(min(10, len(indices))):
                print(f"{feature_names[indices[i]]}: {importances[indices[i]]:.4f}")


def main_analysis():
    """Pipeline principal de analiză"""
    print("🔍 Inițializare Advanced Time Series Analyzer...")
    analyzer = AdvancedTimeSeriesAnalyzer(sequence_length=100)
    
    # Generate data
    print("📊 Generare date sintetice...")
    X, y = analyzer.generate_synthetic_patterns(n_samples=2000)
    
    # Extract features
    print("🔧 Extragere feature-uri avansate...")
    features = analyzer.extract_advanced_features(X)
    
    # Prepare data
    print("⚙️ Pregătire date pentru training...")
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    features_train, features_test, _, _ = train_test_split(features, y, test_size=0.2, random_state=42, stratify=y)
    
    # Scale features
    features_train_scaled = analyzer.scaler.fit_transform(features_train)
    features_test_scaled = analyzer.scaler.transform(features_test)
    
    # Train multiple models
    print("🤖 Training modele multiple...")
    
    # 1. Random Forest on extracted features
    rf_model = RandomForestClassifier(n_estimators=200, random_state=42)
    rf_model.fit(features_train_scaled, y_train)
    rf_predictions = rf_model.predict(features_test_scaled)
    
    print("\n=== RANDOM FOREST RESULTS ===")
    analyzer.diagnose_model_performance(y_test, y_test, rf_predictions)
    
    # 2. CNN-LSTM Model
    X_train_reshaped = X_train.reshape(X_train.shape[0], X_train.shape[1], 1)
    X_test_reshaped = X_test.reshape(X_test.shape[0], X_test.shape[1], 1)
    
    # Convert labels to categorical
    from sklearn.preprocessing import LabelEncoder
    le = LabelEncoder()
    y_train_encoded = le.fit_transform(y_train)
    y_test_encoded = le.transform(y_test)
    y_train_categorical = tf.keras.utils.to_categorical(y_train_encoded, 4)
    y_test_categorical = tf.keras.utils.to_categorical(y_test_encoded, 4)
    
    cnn_lstm_model = analyzer.build_cnn_lstm_model((X_train.shape[1], 1), 4)
    cnn_lstm_model.compile(
        optimizer=Adam(learning_rate=0.001),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    callbacks = [
        EarlyStopping(patience=10, restore_best_weights=True),
        ReduceLROnPlateau(patience=5, factor=0.5)
    ]
    
    history = cnn_lstm_model.fit(
        X_train_reshaped, y_train_categorical,
        validation_data=(X_test_reshaped, y_test_categorical),
        epochs=50,
        batch_size=32,
        callbacks=callbacks,
        verbose=1
    )
    
    # Predict with CNN-LSTM
    cnn_predictions = cnn_lstm_model.predict(X_test_reshaped)
    cnn_predictions_labels = le.inverse_transform(np.argmax(cnn_predictions, axis=1))
    
    print("\n=== CNN-LSTM RESULTS ===")
    analyzer.diagnose_model_performance(y_test, y_test, cnn_predictions_labels)
    
    # 3. Transformer Model
    transformer_model = analyzer.build_transformer_model((X_train.shape[1], 1), 4)
    transformer_model.compile(
        optimizer=Adam(learning_rate=0.0005),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    transformer_history = transformer_model.fit(
        X_train_reshaped, y_train_categorical,
        validation_data=(X_test_reshaped, y_test_categorical),
        epochs=30,
        batch_size=32,
        callbacks=callbacks,
        verbose=1
    )
    
    transformer_predictions = transformer_model.predict(X_test_reshaped)
    transformer_predictions_labels = le.inverse_transform(np.argmax(transformer_predictions, axis=1))
    
    print("\n=== TRANSFORMER RESULTS ===")
    analyzer.diagnose_model_performance(y_test, y_test, transformer_predictions_labels)
    
    # Visualization
    print("📈 Generare vizualizări...")
    analyzer.visualize_pattern_differences(X_test[:20], y_test[:20], cnn_predictions_labels[:20])
    
    # Feature importance for Random Forest
    feature_names = ['mean', 'std', 'var', 'min', 'max', 'median', 'q25', 'q75', 
                     'slope', 'intercept', 'fft_mean', 'fft_std', 'dom_freq',
                     'volatility', 'momentum_ratio', 'spike_ratio', 'start_val', 
                     'end_val', 'total_change', 'above_mean_ratio']
    
    analyzer.feature_importance_analysis(rf_model, feature_names)
    
    return analyzer, {
        'rf_model': rf_model,
        'cnn_lstm_model': cnn_lstm_model,
        'transformer_model': transformer_model
    }


# Troubleshooting function pentru problemele comune
def troubleshoot_identical_predictions():
    """Ghid pentru rezolvarea predicțiilor identice"""
    print("""
    🚨 TROUBLESHOOTING: Predicții Identice
    
    CAUZE POSIBILE:
    1. ⚠️  Model Underfitting:
       - Learning rate prea mare/mic
       - Arhitectură prea simplă
       - Training time insuficient
       
    2. ⚠️  Date Preprocessing Greșit:
       - Normalizarea elimină diferențele importante
       - Feature extraction inadecvat
       - Labels corupte/greșite
       
    3. ⚠️  Class Imbalance:
       - Modelul preferă clasa majoritară
       - Lipsa weight balancing
       
    SOLUȚII:
    ✅ Folosește Multiple Models Ensemble
    ✅ Feature Engineering Avansat
    ✅ Data Augmentation
    ✅ Learning Rate Scheduling
    ✅ Cross-Validation cu Stratification
    ✅ SMOTE pentru Class Balancing
    
    """)


if __name__ == "__main__":
    troubleshoot_identical_predictions()
    analyzer, models = main_analysis()


