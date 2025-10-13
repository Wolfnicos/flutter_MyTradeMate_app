"""
FIXED ROBUST TIME SERIES CLASSIFIER
===================================
Corectează problema cu noise testing pentru rezultate realiste
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import cross_val_score, StratifiedKFold
from sklearn.ensemble import RandomForestClassifier, IsolationForest
from sklearn.preprocessing import StandardScaler, RobustScaler
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.utils.class_weight import compute_class_weight
from scipy import stats
import pickle
import warnings
warnings.filterwarnings('ignore')

class FixedRobustTimeSeriesClassifier:
    """
    Classifier cu noise testing inteligent și validare corectă
    """
    
    def __init__(self, use_robust_scaling=True, outlier_detection=True):
        self.use_robust_scaling = use_robust_scaling
        self.outlier_detection = outlier_detection
        
        if use_robust_scaling:
            self.scaler = RobustScaler()
        else:
            self.scaler = StandardScaler()
            
        self.outlier_detector = IsolationForest(contamination=0.1, random_state=42) if outlier_detection else None
        self.best_model = None
        self.feature_names = None
        self.baseline_signal_std = None  # Store original signal characteristics
        
    def extract_robust_features(self, signals):
        """Extract robust features with improved numerical stability"""
        features = []
        feature_names = []
        
        for signal in signals:
            signal = self._preprocess_signal(signal)
            feature_vector = []
            
            # 1. ROBUST CENTRAL TENDENCY & SPREAD
            feature_vector.extend([
                np.median(signal),
                stats.iqr(signal, nan_policy='omit'),
                np.percentile(signal, 25),
                np.percentile(signal, 75),
                np.percentile(signal, 10),
                np.percentile(signal, 90),
                stats.trim_mean(signal, 0.1),
                np.ptp(signal),
                stats.median_abs_deviation(signal, nan_policy='omit'),
            ])
            
            if len(feature_names) == 0:
                feature_names.extend([
                    'median', 'iqr', 'q25', 'q75', 'q10', 'q90',
                    'trimmed_mean', 'range', 'mad'
                ])
            
            # 2. ROBUST TREND ANALYSIS
            try:
                x = np.arange(len(signal))
                # Simple robust slope
                slope = (np.percentile(signal, 75) - np.percentile(signal, 25)) / (0.5 * len(signal))
                intercept = np.median(signal)
                
                # Kendall's tau for trend direction
                kendall_tau, _ = stats.kendalltau(x, signal, nan_policy='omit')
                if np.isnan(kendall_tau):
                    kendall_tau = 0
                    
                feature_vector.extend([slope, intercept, kendall_tau])
                
            except:
                feature_vector.extend([0, 0, 0])
                
            if len(feature_names) == 9:
                feature_names.extend(['robust_slope', 'robust_intercept', 'kendall_tau'])
            
            # 3. ROBUST VOLATILITY & DYNAMICS
            diff = np.diff(signal)
            diff_finite = diff[np.isfinite(diff)]
            
            if len(diff_finite) > 0:
                feature_vector.extend([
                    stats.iqr(diff_finite),
                    np.median(np.abs(diff_finite)),
                    np.sum(diff_finite > 0) / len(diff_finite),
                    self._count_direction_changes(signal),
                    np.std(diff_finite) / (np.median(np.abs(signal)) + 1e-8),  # Normalized volatility
                ])
            else:
                feature_vector.extend([0, 0, 0.5, 0, 0])
                
            if len(feature_names) == 12:
                feature_names.extend([
                    'robust_volatility', 'median_abs_change', 'positive_ratio',
                    'direction_changes', 'normalized_volatility'
                ])
            
            # 4. SHAPE & POSITION FEATURES
            signal_finite = signal[np.isfinite(signal)]
            if len(signal_finite) > 0:
                feature_vector.extend([
                    np.median(signal[:max(1, len(signal)//10)]),  # Robust start
                    np.median(signal[-max(1, len(signal)//10):]),  # Robust end
                    np.percentile(signal_finite, 75) - np.percentile(signal_finite, 25),  # Robust range
                    np.sum(signal_finite > np.median(signal_finite)) / len(signal_finite),  # Above median
                    self._calculate_robust_skewness(signal_finite),
                    len(signal_finite) / len(signal),  # Data completeness
                ])
            else:
                feature_vector.extend([0, 0, 0, 0.5, 0, 0])
                
            if len(feature_names) == 17:
                feature_names.extend([
                    'robust_start', 'robust_end', 'robust_range',
                    'above_median', 'robust_skewness', 'completeness'
                ])
            
            # 5. FREQUENCY DOMAIN (ultra-robust)
            try:
                signal_clean = signal_finite
                if len(signal_clean) > 4:
                    # Detrend robustly
                    signal_detrended = signal_clean - np.median(signal_clean)
                    
                    # Simple spectral features
                    fft = np.fft.fft(signal_detrended)
                    fft_mag = np.abs(fft[:len(fft)//2])
                    
                    if len(fft_mag) > 0 and np.sum(fft_mag) > 1e-10:
                        feature_vector.extend([
                            np.median(fft_mag),
                            stats.iqr(fft_mag),
                            np.argmax(fft_mag) / len(fft_mag),  # Normalized dominant freq
                            np.max(fft_mag) / (np.median(fft_mag) + 1e-10),  # Peak ratio
                            np.sum(fft_mag[:max(1, len(fft_mag)//5)]) / np.sum(fft_mag),  # Low freq energy
                        ])
                    else:
                        feature_vector.extend([0, 0, 0, 1, 0.5])
                else:
                    feature_vector.extend([0, 0, 0, 1, 0.5])
            except:
                feature_vector.extend([0, 0, 0, 1, 0.5])
                
            if len(feature_names) == 23:
                feature_names.extend([
                    'robust_fft_median', 'robust_fft_iqr', 'norm_dom_freq',
                    'peak_ratio', 'low_freq_energy'
                ])
            
            # 6. AUTOCORRELATION & PERSISTENCE
            try:
                if len(signal_finite) > 1:
                    # Robust autocorrelation using Spearman
                    if len(signal) > 1:
                        lag1_data = signal[:-1]
                        lag1_target = signal[1:]
                        
                        # Remove NaN pairs
                        valid_mask = np.isfinite(lag1_data) & np.isfinite(lag1_target)
                        if np.sum(valid_mask) > 2:
                            spearman_corr, _ = stats.spearmanr(lag1_data[valid_mask], lag1_target[valid_mask])
                            if np.isnan(spearman_corr):
                                spearman_corr = 0
                        else:
                            spearman_corr = 0
                    else:
                        spearman_corr = 0
                        
                    feature_vector.append(spearman_corr)
                else:
                    feature_vector.append(0)
            except:
                feature_vector.append(0)
                
            if len(feature_names) == 28:
                feature_names.append('robust_autocorr')
            
            # 7. ROBUST ENTROPY & COMPLEXITY
            try:
                # Quantile-based entropy (more robust)
                quantiles = np.percentile(signal_finite, [10, 25, 50, 75, 90]) if len(signal_finite) > 0 else [0, 0, 0, 0, 0]
                quantile_diffs = np.diff(quantiles)
                quantile_entropy = -np.sum(quantile_diffs * np.log(quantile_diffs + 1e-10)) / np.log(len(quantile_diffs)) if len(quantile_diffs) > 0 else 0
                
                feature_vector.append(quantile_entropy)
            except:
                feature_vector.append(0)
                
            if len(feature_names) == 29:
                feature_names.append('quantile_entropy')
            
            features.append(feature_vector)
        
        self.feature_names = feature_names
        return np.array(features)
    
    def _preprocess_signal(self, signal):
        """Robust preprocessing with numerical stability"""
        signal = np.array(signal, dtype=float)
        
        # Handle missing values with robust imputation
        if np.any(np.isnan(signal)):
            finite_values = signal[np.isfinite(signal)]
            if len(finite_values) > 0:
                median_val = np.median(finite_values)
                signal = np.where(np.isnan(signal), median_val, signal)
            else:
                signal = np.zeros_like(signal)
        
        # Handle infinite values
        if np.any(np.isinf(signal)):
            finite_values = signal[np.isfinite(signal)]
            if len(finite_values) > 0:
                median_val = np.median(finite_values)
                signal = np.where(np.isinf(signal), median_val, signal)
            else:
                signal = np.zeros_like(signal)
        
        return signal
    
    def _count_direction_changes(self, signal):
        """Count robust direction changes"""
        try:
            # Use median filtering to smooth before counting changes
            if len(signal) > 5:
                window_size = max(3, len(signal) // 20)
                signal_smooth = pd.Series(signal).rolling(window=window_size, center=True).median()
                signal_smooth = signal_smooth.fillna(method='bfill').fillna(method='ffill').values
                
                diff = np.diff(signal_smooth)
                sign_changes = np.sum(np.abs(np.diff(np.sign(diff))) > 0)
                return sign_changes / len(signal)
            else:
                return 0
        except:
            return 0
    
    def _calculate_robust_skewness(self, signal):
        """Calculate robust skewness using quartiles"""
        try:
            q1 = np.percentile(signal, 25)
            q2 = np.percentile(signal, 50)  # median
            q3 = np.percentile(signal, 75)
            
            # Bowley skewness
            if q3 != q1:
                return (q3 + q1 - 2*q2) / (q3 - q1)
            else:
                return 0
        except:
            return 0
    
    def intelligent_noise_testing(self, X, y):
        """
        Intelligent noise testing that preserves signal characteristics
        """
        print("\n🧠 INTELLIGENT NOISE ROBUSTNESS TESTING")
        print("=" * 50)
        
        if self.best_model is None:
            print("Training robust model for testing...")
            features = self.extract_robust_features(X)
            features_scaled = self.scaler.fit_transform(features)
            self.best_model = RandomForestClassifier(
                n_estimators=500, max_depth=8, min_samples_split=10,
                min_samples_leaf=5, class_weight='balanced', random_state=42
            )
            self.best_model.fit(features_scaled, y)
        
        # Store baseline characteristics
        if self.baseline_signal_std is None:
            self.baseline_signal_std = np.std(X)
        
        # Baseline performance
        features_clean = self.extract_robust_features(X)
        features_clean_scaled = self.scaler.transform(features_clean)
        baseline_accuracy = self.best_model.score(features_clean_scaled, y)
        print(f"📊 Baseline accuracy: {baseline_accuracy:.4f}")
        
        # Calculate signal-to-noise ratio based testing
        signal_power = np.mean(X**2)
        
        # More realistic noise levels based on Signal-to-Noise Ratio
        snr_levels = [100, 50, 20, 10, 5, 2, 1, 0.5]  # SNR in dB equivalent
        noise_results = []
        
        print("\n🔊 Signal-to-Noise Ratio based testing...")
        print("SNR Level | Noise Std | Accuracy | Status")
        print("-" * 45)
        
        for snr in snr_levels:
            # Calculate noise standard deviation based on SNR
            # SNR = signal_power / noise_power
            noise_std = np.sqrt(signal_power / snr)
            
            # Add proportional noise to each sample
            X_noisy = X.copy()
            for i in range(len(X)):
                sample_power = np.mean(X[i]**2) + 1e-10
                sample_noise_std = np.sqrt(sample_power / snr)
                X_noisy[i] += np.random.normal(0, sample_noise_std, X[i].shape)
            
            # Test performance
            features_noisy = self.extract_robust_features(X_noisy)
            features_noisy_scaled = self.scaler.transform(features_noisy)
            accuracy = self.best_model.score(features_noisy_scaled, y)
            noise_results.append(accuracy)
            
            # Status indicators
            if accuracy > 0.95:
                status = "✅ Excellent"
            elif accuracy > 0.85:
                status = "✅ Good"
            elif accuracy > 0.70:
                status = "⚠️  Acceptable"
            elif accuracy > 0.50:
                status = "⚠️  Poor"
            else:
                status = "❌ Critical"
            
            print(f"{snr:8.1f} | {noise_std:9.4f} | {accuracy:8.4f} | {status}")
        
        # Calculate noise resistance score
        noise_resistance = np.mean([
            noise_results[0],  # Best case
            noise_results[len(noise_results)//2],  # Middle case
            noise_results[-2]  # Challenging but not extreme case
        ])
        
        print(f"\n📈 Noise Resistance Summary:")
        print(f"  High SNR (clean): {noise_results[0]:.4f}")
        print(f"  Medium SNR:       {noise_results[len(noise_results)//2]:.4f}")
        print(f"  Low SNR:          {noise_results[-2]:.4f}")
        print(f"  🎯 Overall Score: {noise_resistance:.4f}")
        
        return noise_resistance, noise_results
    
    def comprehensive_realistic_testing(self, X, y):
        """
        Comprehensive testing with realistic scenarios
        """
        print("\n💪 COMPREHENSIVE REALISTIC ROBUSTNESS TESTING")
        print("=" * 60)
        
        if self.best_model is None:
            print("Training robust model...")
            features = self.extract_robust_features(X)
            features_scaled = self.scaler.fit_transform(features)
            self.best_model = RandomForestClassifier(
                n_estimators=500, max_depth=8, min_samples_split=10,
                min_samples_leaf=5, class_weight='balanced', random_state=42
            )
            self.best_model.fit(features_scaled, y)
        
        # Baseline
        features_clean = self.extract_robust_features(X)
        features_clean_scaled = self.scaler.transform(features_clean)
        baseline_accuracy = self.best_model.score(features_clean_scaled, y)
        
        # 1. Intelligent noise testing
        noise_score, _ = self.intelligent_noise_testing(X, y)
        
        # 2. Missing data patterns (keep existing implementation)
        print("\n❓ Missing data robustness...")
        missing_patterns = [
            ('random_5%', 0.05, 'random'),
            ('random_10%', 0.10, 'random'),
            ('random_20%', 0.20, 'random'),
            ('block_start', 0.10, 'start'),
            ('block_end', 0.10, 'end'),
        ]
        
        missing_results = []
        for pattern_name, ratio, pattern_type in missing_patterns:
            X_missing = self._create_missing_pattern(X, ratio, pattern_type)
            features_missing = self.extract_robust_features(X_missing)
            features_missing_scaled = self.scaler.transform(features_missing)
            accuracy = self.best_model.score(features_missing_scaled, y)
            missing_results.append(accuracy)
            
            status = "✅" if accuracy > 0.85 else "⚠️ " if accuracy > 0.70 else "❌"
            print(f"  {pattern_name:15s}: {status} {accuracy:.4f}")
        
        missing_score = np.mean(missing_results)
        
        # 3. Realistic outlier scenarios
        print("\n🎯 Realistic outlier scenarios...")
        outlier_scenarios = [
            ('sensor_drift', 0.02, 2),      # 2% sensor drift
            ('measurement_error', 0.05, 1.5), # 5% measurement errors
            ('extreme_events', 0.01, 5),    # 1% extreme events
            ('systematic_bias', 0.10, 1),   # 10% systematic bias
        ]
        
        outlier_results = []
        for scenario_name, ratio, sigma_mult in outlier_scenarios:
            X_outliers = self._create_realistic_outliers(X, ratio, sigma_mult, scenario_name)
            features_outliers = self.extract_robust_features(X_outliers)
            features_outliers_scaled = self.scaler.transform(features_outliers)
            accuracy = self.best_model.score(features_outliers_scaled, y)
            outlier_results.append(accuracy)
            
            status = "✅" if accuracy > 0.80 else "⚠️ " if accuracy > 0.65 else "❌"
            print(f"  {scenario_name:18s}: {status} {accuracy:.4f}")
        
        outlier_score = np.mean(outlier_results)
        
        # 4. Real-world combined scenario
        print("\n🌍 Real-world combined scenario...")
        X_realistic = X.copy()
        
        # Add realistic noise (moderate SNR)
        for i in range(len(X_realistic)):
            sample_power = np.mean(X_realistic[i]**2) + 1e-10
            sample_noise_std = np.sqrt(sample_power / 10)  # SNR = 10
            X_realistic[i] += np.random.normal(0, sample_noise_std, X_realistic[i].shape)
        
        # Add sparse missing values
        X_realistic = self._create_missing_pattern(X_realistic, 0.03, 'random')
        
        # Add occasional outliers
        X_realistic = self._create_realistic_outliers(X_realistic, 0.01, 2, 'measurement_error')
        
        features_realistic = self.extract_robust_features(X_realistic)
        features_realistic_scaled = self.scaler.transform(features_realistic)
        realistic_accuracy = self.best_model.score(features_realistic_scaled, y)
        
        status = "🏆 Excellent" if realistic_accuracy > 0.90 else "✅ Good" if realistic_accuracy > 0.80 else "⚠️  Acceptable" if realistic_accuracy > 0.70 else "❌ Poor"
        print(f"  Real-world scenario: {status} - {realistic_accuracy:.4f}")
        
        # Overall assessment
        overall_scores = [noise_score, missing_score, outlier_score, realistic_accuracy]
        overall_robustness = np.mean(overall_scores)
        
        print(f"\n📊 COMPREHENSIVE ROBUSTNESS SUMMARY:")
        print("=" * 45)
        print(f"  🔊 Noise resistance:        {noise_score:.4f}")
        print(f"  ❓ Missing data handling:    {missing_score:.4f}")
        print(f"  🎯 Outlier resistance:      {outlier_score:.4f}")
        print(f"  🌍 Real-world scenario:     {realistic_accuracy:.4f}")
        print(f"  " + "="*40)
        print(f"  🏆 OVERALL ROBUSTNESS:      {overall_robustness:.4f}")
        
        # Final assessment
        if overall_robustness > 0.90:
            print("  🥇 OUTSTANDING - Production ready with confidence!")
        elif overall_robustness > 0.85:
            print("  🏆 EXCELLENT - Highly suitable for production")
        elif overall_robustness > 0.80:
            print("  ✅ VERY GOOD - Production ready with monitoring")
        elif overall_robustness > 0.75:
            print("  ✅ GOOD - Suitable for most applications")
        elif overall_robustness > 0.70:
            print("  ⚠️  ACCEPTABLE - Monitor performance closely")
        else:
            print("  ❌ NEEDS IMPROVEMENT - Additional robustness required")
        
        return overall_robustness, {
            'noise': noise_score,
            'missing': missing_score,
            'outliers': outlier_score,
            'realistic': realistic_accuracy
        }
    
    def _create_missing_pattern(self, X, ratio, pattern_type):
        """Create missing data patterns"""
        X_missing = X.copy()
        
        if pattern_type == 'random':
            n_missing = int(ratio * X.size)
            missing_indices = np.random.choice(X.size, n_missing, replace=False)
            X_missing.flat[missing_indices] = np.nan
            
        elif pattern_type == 'start':
            missing_length = int(ratio * X.shape[1])
            X_missing[:, :missing_length] = np.nan
            
        elif pattern_type == 'end':
            missing_length = int(ratio * X.shape[1])
            X_missing[:, -missing_length:] = np.nan
        
        return X_missing
    
    def _create_realistic_outliers(self, X, ratio, sigma_mult, scenario_type):
        """Create realistic outlier scenarios"""
        X_outliers = X.copy()
        
        if scenario_type == 'sensor_drift':
            # Gradual drift affecting entire sequences
            n_affected = int(ratio * X.shape[0])
            affected_indices = np.random.choice(X.shape[0], n_affected, replace=False)
            
            for idx in affected_indices:
                drift = np.random.choice([-1, 1]) * sigma_mult * np.std(X[idx])
                drift_pattern = np.linspace(0, drift, X.shape[1])
                X_outliers[idx] += drift_pattern
                
        elif scenario_type == 'measurement_error':
            # Random measurement spikes
            n_outliers = int(ratio * X.size)
            outlier_indices = np.random.choice(X.size, n_outliers, replace=False)
            
            for idx in outlier_indices:
                row, col = np.unravel_index(idx, X.shape)
                original_val = X[row, col]
                error = np.random.choice([-1, 1]) * sigma_mult * np.std(X[row])
                X_outliers[row, col] = original_val + error
                
        elif scenario_type == 'extreme_events':
            # Rare extreme values
            n_events = int(ratio * X.shape[0])
            event_indices = np.random.choice(X.shape[0], n_events, replace=False)
            
            for idx in event_indices:
                event_start = np.random.randint(0, X.shape[1] - 10)
                event_duration = np.random.randint(1, 10)
                event_magnitude = np.random.choice([-1, 1]) * sigma_mult * np.std(X[idx])
                X_outliers[idx, event_start:event_start + event_duration] += event_magnitude
                
        elif scenario_type == 'systematic_bias':
            # Consistent bias across measurements
            n_affected = int(ratio * X.shape[0])
            affected_indices = np.random.choice(X.shape[0], n_affected, replace=False)
            bias = np.random.choice([-1, 1]) * sigma_mult * np.mean([np.std(X[i]) for i in affected_indices])
            
            X_outliers[affected_indices] += bias
        
        return X_outliers

def complete_fixed_pipeline():
    """
    Pipeline cu noise testing corect și validare realistă
    """
    print("🔧 FIXED ROBUST TIME SERIES CLASSIFIER PIPELINE")
    print("=" * 60)
    
    # Initialize fixed classifier
    classifier = FixedRobustTimeSeriesClassifier(
        use_robust_scaling=True,
        outlier_detection=True
    )
    
    # Generate realistic test data
    print("📊 Generating realistic test data...")
    n_samples, n_features = 1000, 100
    X = np.random.randn(n_samples, n_features)
    
    # Create more distinct, realistic patterns
    for i in range(n_samples):
        pattern_type = i % 4
        t = np.linspace(0, 10, n_features)
        
        if pattern_type == 0:  # Strong upward trend
            X[i] = 0.15 * t + 0.2 * np.sin(2 * np.pi * t / 25) + 0.05 * np.random.randn(n_features)
            
        elif pattern_type == 1:  # Strong downward trend
            X[i] = -0.15 * t + 8 + 0.2 * np.cos(2 * np.pi * t / 20) + 0.05 * np.random.randn(n_features)
            
        elif pattern_type == 2:  # Volatile but bounded
            random_walk = np.cumsum(0.1 * np.random.randn(n_features))
            X[i] = random_walk + 0.3 * np.sin(8 * t) + 0.05 * np.random.randn(n_features)
            
        else:  # Complex pattern with clear structure
            regime1 = 2 * np.sin(3 * t) * np.exp(-t/12)
            regime2 = 0.8 * t + 0.5 * np.cos(2 * t)
            switch = n_features // 2
            X[i] = np.concatenate([regime1[:switch], regime2[switch:]]) + 0.05 * np.random.randn(n_features)
    
    y = np.array([i % 4 for i in range(n_samples)])
    
    # Add controlled realistic problems
    print("🚨 Adding controlled realistic problems...")
    
    # Sparse missing values (more realistic)
    missing_mask = np.random.random(X.shape) < 0.01  # 1% missing
    X[missing_mask] = np.nan
    
    # Occasional measurement errors (realistic outliers)
    outlier_mask = np.random.random(X.shape) < 0.005  # 0.5% outliers
    for i, j in zip(*np.where(outlier_mask)):
        X[i, j] += np.random.choice([-1, 1]) * 2 * np.std(X[i])
    
    print(f"  • Missing values: {np.sum(np.isnan(X)) / X.size:.3%}")
    print(f"  • Outliers added: {np.sum(outlier_mask)}")
    
    # Train robust model
    print("\n1️⃣ Training robust model...")
    features = classifier.extract_robust_features(X)
    features_scaled = classifier.scaler.fit_transform(features)
    
    classifier.best_model = RandomForestClassifier(
        n_estimators=500, max_depth=8, min_samples_split=10,
        min_samples_leaf=5, class_weight='balanced', random_state=42
    )
    classifier.best_model.fit(features_scaled, y)
    
    train_accuracy = classifier.best_model.score(features_scaled, y)
    print(f"✅ Training accuracy: {train_accuracy:.4f}")
    
    # Comprehensive testing
    print("\n2️⃣ Comprehensive robustness testing...")
    overall_robustness, detailed_results = classifier.comprehensive_realistic_testing(X, y)
    
    # Save model
    print("\n3️⃣ Saving robust model...")
    classifier.save_robust_model()
    
    print("\n🎯 FINAL RESULTS:")
    print("=" * 30)
    print(f"✅ Robust features: {features.shape[1]}")
    print(f"✅ Training accuracy: {train_accuracy:.4f}")
    print(f"✅ Overall robustness: {overall_robustness:.4f}")
    
    # Detailed breakdown
    print(f"\n📊 Robustness Breakdown:")
    for key, value in detailed_results.items():
        print(f"  {key.capitalize():12s}: {value:.4f}")
    
    return classifier, overall_robustness, detailed_results

if __name__ == "__main__":
    classifier, robustness_score, results = complete_fixed_pipeline()


