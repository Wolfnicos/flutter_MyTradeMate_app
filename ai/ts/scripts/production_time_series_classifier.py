"""
NEXT LEVEL IMPROVEMENTS - De la 100% pe Date Sintetice la Date Reale
====================================================================
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import cross_val_score, GridSearchCV, StratifiedKFold
from sklearn.ensemble import RandomForestClassifier, VotingClassifier
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.preprocessing import StandardScaler
import warnings
warnings.filterwarnings('ignore')


class ProductionTimeSeriesClassifier:
    """
    Classifier pentru production - cu validare riguroasă și robustețe
    """
    
    def __init__(self):
        self.scaler = StandardScaler()
        self.best_model = None
        self.feature_names = None
        
    def extract_production_features(self, signals):
        """
        Features robuste pentru date reale (cu noise, missing values, etc.)
        """
        features = []
        feature_names = []
        
        for signal in signals:
            # Handle missing values
            signal = np.array(signal)
            if np.any(np.isnan(signal)):
                signal = np.nan_to_num(signal, nan=np.nanmean(signal))
            
            feature_vector = []
            
            # 1. ROBUST STATISTICAL FEATURES
            feature_vector.extend([
                np.mean(signal),
                np.std(signal),
                np.median(signal),
                np.percentile(signal, 25),
                np.percentile(signal, 75),
                np.percentile(signal, 10),
                np.percentile(signal, 90),
                np.ptp(signal),  # Range
                np.mean(np.abs(signal - np.mean(signal))),  # Mean absolute deviation
            ])
            
            if len(feature_names) == 0:  # First iteration
                feature_names.extend([
                    'mean', 'std', 'median', 'q25', 'q75', 'q10', 'q90', 
                    'range', 'mad'
                ])
            
            # 2. TREND ANALYSIS (robust)
            try:
                x = np.arange(len(signal))
                # Linear trend
                slope, intercept = np.polyfit(x, signal, 1)
                
                # Quadratic trend
                quad_coeffs = np.polyfit(x, signal, 2)
                curvature = quad_coeffs[0]
                
                feature_vector.extend([slope, intercept, curvature])
                
                if len(feature_names) == 9:
                    feature_names.extend(['slope', 'intercept', 'curvature'])
                    
            except Exception:
                feature_vector.extend([0, 0, 0])
                if len(feature_names) == 9:
                    feature_names.extend(['slope', 'intercept', 'curvature'])
            
            # 3. VOLATILITY & DYNAMICS
            diff = np.diff(signal)
            diff2 = np.diff(diff)  # Second order differences
            
            feature_vector.extend([
                np.std(diff),  # Volatility
                np.mean(np.abs(diff)),  # Mean absolute change
                np.std(diff2),  # Acceleration volatility
                len(np.where(np.diff(np.sign(diff)))[0]) / len(signal),  # Turning points ratio
                np.sum(diff > 0) / len(diff) if len(diff) > 0 else 0,  # Positive change ratio
            ])
            
            if len(feature_names) == 12:
                feature_names.extend([
                    'volatility', 'mean_abs_change', 'accel_volatility', 
                    'turning_points', 'positive_ratio'
                ])
            
            # 4. SHAPE CHARACTERISTICS
            feature_vector.extend([
                signal[0],  # Start value
                signal[-1],  # End value
                signal[-1] - signal[0],  # Total change
                (signal[-1] - signal[0]) / len(signal),  # Change per unit
                np.sum(signal > np.mean(signal)) / len(signal),  # Above mean ratio
                np.sum(signal > np.median(signal)) / len(signal),  # Above median ratio
            ])
            
            if len(feature_names) == 17:
                feature_names.extend([
                    'start_val', 'end_val', 'total_change', 'change_per_unit',
                    'above_mean', 'above_median'
                ])
            
            # 5. FREQUENCY DOMAIN (robust)
            try:
                # Remove DC component
                signal_detrended = signal - np.mean(signal)
                
                # FFT analysis
                fft = np.fft.fft(signal_detrended)
                fft_magnitude = np.abs(fft[:len(fft)//2])
                
                if len(fft_magnitude) > 0:
                    feature_vector.extend([
                        np.mean(fft_magnitude),
                        np.std(fft_magnitude),
                        np.argmax(fft_magnitude),  # Dominant frequency
                        np.max(fft_magnitude),     # Peak amplitude
                        np.sum(fft_magnitude[:5]) / np.sum(fft_magnitude) if np.sum(fft_magnitude) > 0 else 0,  # Low freq energy
                    ])
                else:
                    feature_vector.extend([0, 0, 0, 0, 0])
                    
            except Exception:
                feature_vector.extend([0, 0, 0, 0, 0])
            
            if len(feature_names) == 23:
                feature_names.extend([
                    'fft_mean', 'fft_std', 'dom_freq', 'peak_amplitude', 'low_freq_energy'
                ])
            
            # 6. AUTOCORRELATION FEATURES
            try:
                # Lag-1 autocorrelation
                if len(signal) > 1:
                    lag1_corr = np.corrcoef(signal[:-1], signal[1:])[0, 1]
                    if np.isnan(lag1_corr):
                        lag1_corr = 0
                else:
                    lag1_corr = 0
                    
                feature_vector.append(lag1_corr)
                
                if len(feature_names) == 28:
                    feature_names.append('lag1_autocorr')
                    
            except Exception:
                feature_vector.append(0)
                if len(feature_names) == 28:
                    feature_names.append('lag1_autocorr')
            
            features.append(feature_vector)
        
        self.feature_names = feature_names
        return np.array(features)
    
    def rigorous_validation(self, X, y, test_size=0.2):
        """
        Validare riguroasă cu cross-validation și multiple metrici
        """
        print("🔬 RIGOROUS VALIDATION")
        print("=" * 40)
        
        # Extract features
        features = self.extract_production_features(X)
        print(f"Extracted {features.shape[1]} features")
        
        # Scale features
        features_scaled = self.scaler.fit_transform(features)
        
        # Cross-validation cu multiple folds
        cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
        
        # Test multiple algorithms
        models = {
            'RandomForest': RandomForestClassifier(
                n_estimators=200, max_depth=10, random_state=42, class_weight='balanced'
            ),
            'RandomForest_Deep': RandomForestClassifier(
                n_estimators=300, max_depth=None, min_samples_split=5, 
                random_state=42, class_weight='balanced'
            ),
            'RandomForest_Conservative': RandomForestClassifier(
                n_estimators=100, max_depth=5, min_samples_split=10,
                random_state=42, class_weight='balanced'
            )
        }
        
        results = {}
        
        for name, model in models.items():
            print(f"\n📊 Testing {name}...")
            
            # Cross-validation scores
            cv_scores = cross_val_score(model, features_scaled, y, cv=cv, scoring='accuracy')
            
            # Additional metrics
            precision_scores = cross_val_score(model, features_scaled, y, cv=cv, scoring='precision_macro')
            recall_scores = cross_val_score(model, features_scaled, y, cv=cv, scoring='recall_macro')
            f1_scores = cross_val_score(model, features_scaled, y, cv=cv, scoring='f1_macro')
            
            results[name] = {
                'accuracy_mean': np.mean(cv_scores),
                'accuracy_std': np.std(cv_scores),
                'precision_mean': np.mean(precision_scores),
                'recall_mean': np.mean(recall_scores),
                'f1_mean': np.mean(f1_scores),
                'cv_scores': cv_scores
            }
            
            print(f"  Accuracy: {np.mean(cv_scores):.4f} ± {np.std(cv_scores):.4f}")
            print(f"  Precision: {np.mean(precision_scores):.4f}")
            print(f"  Recall: {np.mean(recall_scores):.4f}")
            print(f"  F1: {np.mean(f1_scores):.4f}")
            
            # Check for overfitting
            if np.std(cv_scores) > 0.05:
                print(f"  ⚠️  High variance - possible overfitting!")
            else:
                print(f"  ✅ Stable performance")
        
        # Select best model
        best_model_name = max(results.keys(), key=lambda x: results[x]['accuracy_mean'])
        self.best_model = models[best_model_name]
        
        print(f"\n🏆 Best model: {best_model_name}")
        print(f"   Accuracy: {results[best_model_name]['accuracy_mean']:.4f}")
        
        return results
    
    def hyperparameter_optimization(self, X, y):
        """
        Optimizare hiperparametri pentru performanță maximă
        """
        print("\n🔧 HYPERPARAMETER OPTIMIZATION")
        print("=" * 40)
        
        # Extract and scale features
        features = self.extract_production_features(X)
        features_scaled = self.scaler.fit_transform(features)
        
        # Define hyperparameter grid
        param_grid = {
            'n_estimators': [100, 200, 300],
            'max_depth': [5, 10, 15, None],
            'min_samples_split': [2, 5, 10],
            'min_samples_leaf': [1, 2, 4],
            'max_features': ['sqrt', 'log2', None]
        }
        
        # Grid search with cross-validation
        grid_search = GridSearchCV(
            RandomForestClassifier(random_state=42, class_weight='balanced'),
            param_grid,
            cv=3,  # Reduced for speed
            scoring='accuracy',
            n_jobs=-1,
            verbose=1
        )
        
        print("🚀 Starting grid search (this may take a while)...")
        grid_search.fit(features_scaled, y)
        
        print(f"\n🏆 Best parameters: {grid_search.best_params_}")
        print(f"🎯 Best CV score: {grid_search.best_score_:.4f}")
        
        self.best_model = grid_search.best_estimator_
        
        return grid_search.best_params_, grid_search.best_score_
    
    def stress_test_robustness(self, X, y):
        """
        Test robustețea modelului cu diverse perturbări
        """
        print("\n💪 ROBUSTNESS STRESS TESTING")
        print("=" * 40)
        
        if self.best_model is None:
            print("⚠️  No model trained yet. Training default model...")
            features = self.extract_production_features(X)
            features_scaled = self.scaler.fit_transform(features)
            self.best_model = RandomForestClassifier(n_estimators=200, random_state=42, class_weight='balanced')
            self.best_model.fit(features_scaled, y)
        
        # Test 1: Noise robustness
        print("\n🔊 Testing noise robustness...")
        noise_levels = [0.01, 0.05, 0.1, 0.2]
        noise_results = []
        
        for noise_level in noise_levels:
            X_noisy = X + np.random.normal(0, noise_level, X.shape)
            features_noisy = self.extract_production_features(X_noisy)
            features_noisy_scaled = self.scaler.transform(features_noisy)
            
            accuracy = self.best_model.score(features_noisy_scaled, y)
            noise_results.append(accuracy)
            print(f"  Noise {noise_level:.2f}: Accuracy = {accuracy:.4f}")
        
        # Test 2: Missing data robustness
        print("\n❓ Testing missing data robustness...")
        missing_ratios = [0.05, 0.1, 0.2]
        missing_results = []
        
        for missing_ratio in missing_ratios:
            X_missing = X.copy()
            n_missing = int(missing_ratio * X.shape[0] * X.shape[1])
            missing_indices = np.random.choice(X.size, n_missing, replace=False)
            X_missing.flat[missing_indices] = np.nan
            
            features_missing = self.extract_production_features(X_missing)
            features_missing_scaled = self.scaler.transform(features_missing)
            
            accuracy = self.best_model.score(features_missing_scaled, y)
            missing_results.append(accuracy)
            print(f"  Missing {missing_ratio:.1%}: Accuracy = {accuracy:.4f}")
        
        # Test 3: Outlier robustness
        print("\n🎯 Testing outlier robustness...")
        outlier_ratios = [0.01, 0.05, 0.1]
        outlier_results = []
        
        for outlier_ratio in outlier_ratios:
            X_outliers = X.copy()
            n_outliers = int(outlier_ratio * X.shape[0] * X.shape[1])
            outlier_indices = np.random.choice(X.size, n_outliers, replace=False)
            
            # Add extreme outliers
            outlier_values = np.random.choice([-1, 1], n_outliers) * (np.abs(X).max() * 5)
            X_outliers.flat[outlier_indices] = outlier_values
            
            features_outliers = self.extract_production_features(X_outliers)
            features_outliers_scaled = self.scaler.transform(features_outliers)
            
            accuracy = self.best_model.score(features_outliers_scaled, y)
            outlier_results.append(accuracy)
            print(f"  Outliers {outlier_ratio:.1%}: Accuracy = {accuracy:.4f}")
        
        # Summary
        print(f"\n📈 ROBUSTNESS SUMMARY:")
        print(f"  Average noise resistance: {np.mean(noise_results):.4f}")
        print(f"  Average missing data resistance: {np.mean(missing_results):.4f}")
        print(f"  Average outlier resistance: {np.mean(outlier_results):.4f}")
        
        overall_robustness = np.mean([np.mean(noise_results), np.mean(missing_results), np.mean(outlier_results)])
        print(f"  🎯 Overall Robustness Score: {overall_robustness:.4f}")
        
        if overall_robustness > 0.95:
            print("  ✅ EXCELLENT robustness!")
        elif overall_robustness > 0.90:
            print("  ✅ Good robustness")
        elif overall_robustness > 0.80:
            print("  ⚠️  Moderate robustness")
        else:
            print("  ❌ Poor robustness - needs improvement")
            
        return {
            'noise': noise_results,
            'missing': missing_results,
            'outliers': outlier_results,
            'overall': overall_robustness
        }
    
    def generate_production_ready_code(self, save_path="production_classifier.py"):
        """
        Generează cod production-ready pentru deployment
        """
        print(f"\n💾 GENERATING PRODUCTION CODE -> {save_path}")
        print("=" * 50)
        
        if self.best_model is None:
            print("❌ No trained model available!")
            return
        
        production_code = f'''"""
PRODUCTION TIME SERIES CLASSIFIER
=================================
Auto-generated code for deployment

Features: {len(self.feature_names)} statistical features
Model: {type(self.best_model).__name__}
Performance: Optimized through rigorous validation
"""

import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
import pickle
import warnings
warnings.filterwarnings('ignore')

class ProductionTimeSeriesClassifier:
    def __init__(self, model_path=None, scaler_path=None):
        self.feature_names = {self.feature_names}
        
        if model_path and scaler_path:
            self.load_model(model_path, scaler_path)
        else:
            self.model = None
            self.scaler = None
    
    def extract_features(self, signals):
        """Extract production-ready features"""
        if not isinstance(signals, np.ndarray):
            signals = np.array(signals)
        
        if len(signals.shape) == 1:
            signals = signals.reshape(1, -1)
        
        features = []
        
        for signal in signals:
            # Handle missing values
            if np.any(np.isnan(signal)):
                signal = np.nan_to_num(signal, nan=np.nanmean(signal))
            
            feature_vector = []
            
            # Statistical features (robust implementation)
            feature_vector.extend([
                np.mean(signal),
                np.std(signal),
                np.median(signal),
                np.percentile(signal, 25),
                np.percentile(signal, 75),
                np.percentile(signal, 10),
                np.percentile(signal, 90),
                np.ptp(signal),
                np.mean(np.abs(signal - np.mean(signal))),
            ])
            
            # Trend analysis
            try:
                x = np.arange(len(signal))
                slope, intercept = np.polyfit(x, signal, 1)
                quad_coeffs = np.polyfit(x, signal, 2)
                curvature = quad_coeffs[0]
                feature_vector.extend([slope, intercept, curvature])
            except Exception:
                feature_vector.extend([0, 0, 0])
            
            # Volatility & dynamics
            diff = np.diff(signal)
            diff2 = np.diff(diff) if len(diff) > 1 else np.array([0])
            
            feature_vector.extend([
                np.std(diff),
                np.mean(np.abs(diff)),
                np.std(diff2),
                len(np.where(np.diff(np.sign(diff)))[0]) / len(signal),
                np.sum(diff > 0) / len(diff) if len(diff) > 0 else 0,
            ])
            
            # Shape characteristics
            feature_vector.extend([
                signal[0],
                signal[-1],
                signal[-1] - signal[0],
                (signal[-1] - signal[0]) / len(signal),
                np.sum(signal > np.mean(signal)) / len(signal),
                np.sum(signal > np.median(signal)) / len(signal),
            ])
            
            # Frequency domain
            try:
                signal_detrended = signal - np.mean(signal)
                fft = np.fft.fft(signal_detrended)
                fft_magnitude = np.abs(fft[:len(fft)//2])
                
                if len(fft_magnitude) > 0:
                    feature_vector.extend([
                        np.mean(fft_magnitude),
                        np.std(fft_magnitude),
                        np.argmax(fft_magnitude),
                        np.max(fft_magnitude),
                        np.sum(fft_magnitude[:5]) / np.sum(fft_magnitude) if np.sum(fft_magnitude) > 0 else 0,
                    ])
                else:
                    feature_vector.extend([0, 0, 0, 0, 0])
            except Exception:
                feature_vector.extend([0, 0, 0, 0, 0])
            
            # Autocorrelation
            try:
                if len(signal) > 1:
                    lag1_corr = np.corrcoef(signal[:-1], signal[1:])[0, 1]
                    if np.isnan(lag1_corr):
                        lag1_corr = 0
                else:
                    lag1_corr = 0
                feature_vector.append(lag1_corr)
            except Exception:
                feature_vector.append(0)
            
            features.append(feature_vector)
        
        return np.array(features)
    
    def predict(self, X):
        """Make predictions on new data"""
        if self.model is None or self.scaler is None:
            raise ValueError("Model not loaded. Use load_model() first.")
        
        features = self.extract_features(X)
        features_scaled = self.scaler.transform(features)
        
        predictions = self.model.predict(features_scaled)
        probabilities = self.model.predict_proba(features_scaled)
        
        return predictions, probabilities
    
    def predict_single(self, signal):
        """Predict single time series"""
        predictions, probabilities = self.predict([signal])
        return predictions[0], probabilities[0]
    
    def save_model(self, model_path="model.pkl", scaler_path="scaler.pkl"):
        """Save trained model and scaler"""
        import pickle
        with open(model_path, 'wb') as f:
            pickle.dump(self.model, f)
        with open(scaler_path, 'wb') as f:
            pickle.dump(self.scaler, f)
        print(f"Model saved to {model_path}")
        print(f"Scaler saved to {scaler_path}")
    
    def load_model(self, model_path, scaler_path):
        """Load trained model and scaler"""
        import pickle
        with open(model_path, 'rb') as f:
            self.model = pickle.load(f)
        with open(scaler_path, 'rb') as f:
            self.scaler = pickle.load(f)
        print("Model and scaler loaded successfully")

        '''
        with open(save_path, 'w') as f:
            f.write(production_code)
        print(f"✅ Production code generated: {save_path}")
        print("📋 Next steps:")
        print("  1. Save your trained model: classifier.save_model()")
        print("  2. Test the production code")
        print("  3. Deploy to your application")

def complete_production_pipeline():
    """
    Pipeline complet pentru validare și deployment
    """
    print("🏭 COMPLETE PRODUCTION PIPELINE")
    print("=" * 60)
    
    # Initialize classifier
    classifier = ProductionTimeSeriesClassifier()
    
    # Generate test data (replace with your real data)
    # Simulate time series data
    print("📊 Generating test data...")
    n_samples, n_features = 1000, 100
    X = np.random.randn(n_samples, n_features)
    
    # Add different patterns
    for i in range(n_samples):
        pattern_type = i % 4
        t = np.linspace(0, 10, n_features)
        
        if pattern_type == 0:  # Trend up
            X[i] = 0.1 * t + np.random.normal(0, 0.2, n_features)
        elif pattern_type == 1:  # Trend down  
            X[i] = -0.1 * t + 5 + np.random.normal(0, 0.2, n_features)
        elif pattern_type == 2:  # Volatile
            X[i] = np.random.normal(0, 1, n_features).cumsum() * 0.1
        else:  # Complex
            X[i] = np.sin(t) * np.exp(-t/10) + np.random.normal(0, 0.1, n_features)
    
    y = np.array([i % 4 for i in range(n_samples)])
    
    # Run complete pipeline
    print("\n1️⃣ Rigorous Validation...")
    validation_results = classifier.rigorous_validation(X, y)
    
    print("\n2️⃣ Hyperparameter Optimization...")
    best_params, best_score = classifier.hyperparameter_optimization(X, y)
    
    print("\n3️⃣ Robustness Testing...")
    robustness_results = classifier.stress_test_robustness(X, y)
    
    print("\n4️⃣ Generating Production Code...")
    classifier.generate_production_ready_code()
    
    print("\n🎉 PIPELINE COMPLETED!")
    print("=" * 30)
    print(f"✅ Best validation score: {best_score:.4f}")
    print(f"✅ Robustness score: {robustness_results['overall']:.4f}")
    print("✅ Production code generated")
    
    return classifier, validation_results, robustness_results


if __name__ == "__main__":
    # Run the complete pipeline
    complete_production_pipeline()


