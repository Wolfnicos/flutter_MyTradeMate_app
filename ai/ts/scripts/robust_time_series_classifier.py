"""
ROBUST PRODUCTION TIME SERIES CLASSIFIER
========================================
Versiune îmbunătățită cu robustețe sporită pentru date reale
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import cross_val_score, StratifiedKFold
from sklearn.ensemble import RandomForestClassifier, IsolationForest
from sklearn.preprocessing import StandardScaler, RobustScaler
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight
from scipy import stats
import pickle
import warnings
warnings.filterwarnings('ignore')


class RobustTimeSeriesClassifier:
    """
    Classifier robust pentru date reale cu noise, outliers, missing values
    """
    
    def __init__(self, use_robust_scaling=True, outlier_detection=True):
        self.use_robust_scaling = use_robust_scaling
        self.outlier_detection = outlier_detection
        
        # Use RobustScaler instead of StandardScaler for better outlier handling
        if use_robust_scaling:
            self.scaler = RobustScaler()  # Uses median and IQR instead of mean/std
        else:
            self.scaler = StandardScaler()
            
        self.outlier_detector = IsolationForest(contamination=0.1, random_state=42) if outlier_detection else None
        self.best_model = None
        self.feature_names = None
        
    def extract_robust_features(self, signals):
        """
        Features extra-robuste pentru date reale cu probleme
        """
        features = []
        feature_names = []
        
        for signal in signals:
            # Robust preprocessing
            signal = self._preprocess_signal(signal)
            
            feature_vector = []
            
            # 1. ROBUST STATISTICAL FEATURES (resistant to outliers)
            feature_vector.extend([
                np.median(signal),  # More robust than mean
                stats.iqr(signal),  # More robust than std
                np.percentile(signal, 25),
                np.percentile(signal, 75),
                np.percentile(signal, 10),
                np.percentile(signal, 90),
                stats.trim_mean(signal, 0.1),  # Trimmed mean (removes 10% extremes)
                np.ptp(signal),  # Range
                stats.median_abs_deviation(signal),  # Robust MAD
            ])
            
            if len(feature_names) == 0:
                feature_names.extend([
                    'median', 'iqr', 'q25', 'q75', 'q10', 'q90', 
                    'trimmed_mean', 'range', 'mad'
                ])
            
            # 2. ROBUST TREND ANALYSIS
            try:
                x = np.arange(len(signal))
                # Use robust regression (Theil-Sen estimator)
                from sklearn.linear_model import TheilSenRegressor
                
                regressor = TheilSenRegressor(random_state=42)
                slope = regressor.fit(x.reshape(-1, 1), signal).coef_[0]
                intercept = regressor.intercept_
                
                # Kendall's tau for monotonic trend
                kendall_tau, _ = stats.kendalltau(x, signal)
                
                feature_vector.extend([slope, intercept, kendall_tau])
                
                if len(feature_names) == 9:
                    feature_names.extend(['robust_slope', 'robust_intercept', 'kendall_tau'])
                    
            except:
                # Fallback to simple robust methods
                try:
                    slope = (np.percentile(signal, 75) - np.percentile(signal, 25)) / (len(signal) * 0.5)
                    intercept = np.median(signal)
                    kendall_tau = 0
                    feature_vector.extend([slope, intercept, kendall_tau])
                except:
                    feature_vector.extend([0, 0, 0])
                
                if len(feature_names) == 9:
                    feature_names.extend(['robust_slope', 'robust_intercept', 'kendall_tau'])
            
            # 3. ROBUST VOLATILITY MEASURES
            diff = np.diff(signal)
            
            # Use median-based volatility measures
            feature_vector.extend([
                stats.iqr(diff),  # Robust volatility
                np.median(np.abs(diff)),  # Robust mean absolute change
                len(np.where(np.abs(diff) > 2 * stats.iqr(diff))[0]) / len(diff),  # Spike ratio
                self._count_trend_changes(signal),  # Robust turning points
                np.sum(diff > 0) / len(diff) if len(diff) > 0 else 0.5,  # Direction ratio
            ])
            
            if len(feature_names) == 12:
                feature_names.extend([
                    'robust_volatility', 'median_abs_change', 'spike_ratio',
                    'trend_changes', 'positive_ratio'
                ])
            
            # 4. SHAPE CHARACTERISTICS (robust versions)
            start_robust = np.median(signal[:min(5, len(signal)//10)])  # Robust start
            end_robust = np.median(signal[max(-5, -len(signal)//10):])  # Robust end
            
            feature_vector.extend([
                start_robust,
                end_robust,
                end_robust - start_robust,  # Robust total change
                (end_robust - start_robust) / len(signal),  # Robust change per unit
                np.sum(signal > np.median(signal)) / len(signal),  # Above median ratio
                self._calculate_symmetry(signal),  # Distribution symmetry
            ])
            
            if len(feature_names) == 17:
                feature_names.extend([
                    'robust_start', 'robust_end', 'robust_total_change', 
                    'robust_change_per_unit', 'above_median', 'symmetry'
                ])
            
            # 5. FREQUENCY DOMAIN (robust)
            try:
                # Remove outliers before FFT
                signal_clean = self._remove_outliers_iqr(signal)
                signal_detrended = signal_clean - np.median(signal_clean)
                
                # Windowing to reduce spectral leakage
                window = np.hanning(len(signal_detrended))
                signal_windowed = signal_detrended * window
                
                fft = np.fft.fft(signal_windowed)
                fft_magnitude = np.abs(fft[:len(fft)//2])
                
                if len(fft_magnitude) > 0 and np.sum(fft_magnitude) > 0:
                    feature_vector.extend([
                        np.median(fft_magnitude),  # Robust mean
                        stats.iqr(fft_magnitude),  # Robust std
                        np.argmax(fft_magnitude),  # Dominant frequency
                        np.percentile(fft_magnitude, 95),  # Robust peak
                        np.sum(fft_magnitude[:max(1, len(fft_magnitude)//10)]) / np.sum(fft_magnitude),  # Low freq energy
                    ])
                else:
                    feature_vector.extend([0, 0, 0, 0, 0.5])
                    
            except:
                feature_vector.extend([0, 0, 0, 0, 0.5])
            
            if len(feature_names) == 23:
                feature_names.extend([
                    'robust_fft_median', 'robust_fft_iqr', 'dom_freq', 
                    'robust_peak', 'low_freq_energy'
                ])
            
            # 6. ROBUST AUTOCORRELATION
            try:
                # Use Spearman correlation (rank-based, robust to outliers)
                if len(signal) > 1:
                    spearman_lag1, _ = stats.spearmanr(signal[:-1], signal[1:])
                    if np.isnan(spearman_lag1):
                        spearman_lag1 = 0
                else:
                    spearman_lag1 = 0
                feature_vector.append(spearman_lag1)
                
                if len(feature_names) == 28:
                    feature_names.append('robust_autocorr')
                    
            except:
                feature_vector.append(0)
                if len(feature_names) == 28:
                    feature_names.append('robust_autocorr')
            
            # 7. ADDITIONAL ROBUST FEATURES
            # Entropy (measure of randomness)
            try:
                # Discrete entropy based on histogram
                hist, _ = np.histogram(signal, bins=10)
                hist = hist + 1e-8  # Avoid log(0)
                prob = hist / hist.sum()
                entropy = -np.sum(prob * np.log(prob))
                feature_vector.append(entropy)
                
                if len(feature_names) == 29:
                    feature_names.append('entropy')
            except:
                feature_vector.append(0)
                if len(feature_names) == 29:
                    feature_names.append('entropy')
            
            features.append(feature_vector)
        
        self.feature_names = feature_names
        return np.array(features)
    
    def _preprocess_signal(self, signal):
        """Robust preprocessing of signal"""
        signal = np.array(signal, dtype=float)
        
        # Handle missing values with robust imputation
        if np.any(np.isnan(signal)):
            # Use median imputation (more robust than mean)
            median_val = np.nanmedian(signal)
            signal = np.where(np.isnan(signal), median_val, signal)
        
        # Handle infinite values
        if np.any(np.isinf(signal)):
            finite_mask = np.isfinite(signal)
            if np.any(finite_mask):
                median_val = np.median(signal[finite_mask])
                signal = np.where(np.isinf(signal), median_val, signal)
            else:
                signal = np.zeros_like(signal)
        
        return signal
    
    def _remove_outliers_iqr(self, signal, k=1.5):
        """Remove outliers using IQR method"""
        Q1 = np.percentile(signal, 25)
        Q3 = np.percentile(signal, 75)
        IQR = Q3 - Q1
        
        lower_bound = Q1 - k * IQR
        upper_bound = Q3 + k * IQR
        
        # Replace outliers with boundary values (winsorizing)
        signal_clean = np.where(signal < lower_bound, lower_bound, signal)
        signal_clean = np.where(signal_clean > upper_bound, upper_bound, signal_clean)
        
        return signal_clean
    
    def _count_trend_changes(self, signal):
        """Count robust trend changes"""
        # Use robust smoothing first
        window_size = max(3, len(signal) // 20)
        signal_smooth = pd.Series(signal).rolling(window=window_size, center=True).median().fillna(method='bfill').fillna(method='ffill').values
        
        # Count sign changes in differences
        diff = np.diff(signal_smooth)
        sign_changes = np.sum(np.diff(np.sign(diff)) != 0)
        
        return sign_changes / len(signal)
    
    def _calculate_symmetry(self, signal):
        """Calculate distribution symmetry (skewness resistance)"""
        try:
            # Use robust skewness measure
            median = np.median(signal)
            q1 = np.percentile(signal, 25)
            q3 = np.percentile(signal, 75)
            
            # Bowley skewness (robust alternative to moment skewness)
            bowley_skew = (q3 + q1 - 2*median) / (q3 - q1) if q3 != q1 else 0
            
            return bowley_skew
        except:
            return 0
    
    def advanced_validation_with_robustness(self, X, y):
        """
        Validare avansată cu focus pe robustețe
        """
        print("🔬 ADVANCED ROBUSTNESS VALIDATION")
        print("=" * 50)
        
        # Extract robust features
        features = self.extract_robust_features(X)
        print(f"Extracted {features.shape[1]} robust features")
        
        # Detect and handle outliers in features if enabled
        if self.outlier_detection:
            print("🎯 Detecting outliers in feature space...")
            outlier_mask = self.outlier_detector.fit_predict(features) == -1
            n_outliers = np.sum(outlier_mask)
            
            if n_outliers > 0:
                print(f"  Found {n_outliers} ({n_outliers/len(features):.1%}) potential outlier samples")
                
                # Option 1: Remove outliers
                features_clean = features[~outlier_mask]
                y_clean = y[~outlier_mask]
                
                print("  Testing with outliers removed...")
                self._test_model_variants(features_clean, y_clean, "Without outliers")
                
                # Option 2: Keep all data but use robust methods
                print("  Testing with outliers kept (robust methods)...")
                self._test_model_variants(features, y, "With outliers (robust)")
            else:
                print("  ✅ No outliers detected")
                self._test_model_variants(features, y, "Clean data")
        else:
            self._test_model_variants(features, y, "Standard processing")
        
        return features
    
    def _test_model_variants(self, features, y, data_description):
        """Test different model configurations"""
        print(f"\n📊 Testing models on: {data_description}")
        
        # Scale features
        features_scaled = self.scaler.fit_transform(features)
        
        # Model variants optimized for robustness
        models = {
            'Robust_RF_Deep': RandomForestClassifier(
                n_estimators=500,  # More trees for stability
                max_depth=8,       # Moderate depth to avoid overfitting
                min_samples_split=10,  # Require more samples to split
                min_samples_leaf=5,    # Larger leaf size for stability
                max_features='sqrt',   # Feature randomness
                class_weight='balanced',
                random_state=42,
                bootstrap=True,        # Enable bootstrap sampling
                oob_score=True        # Out-of-bag score
            ),
            'Robust_RF_Conservative': RandomForestClassifier(
                n_estimators=300,
                max_depth=5,       # Shallow trees
                min_samples_split=20,  # Conservative splitting
                min_samples_leaf=10,   # Large leaves
                max_features='log2',   # Less feature randomness
                class_weight='balanced',
                random_state=42,
                bootstrap=True,
                oob_score=True
            ),
            'Robust_RF_Balanced': RandomForestClassifier(
                n_estimators=400,
                max_depth=10,
                min_samples_split=5,
                min_samples_leaf=2,
                max_features='sqrt',
                class_weight='balanced_subsample',  # Different balancing
                random_state=42,
                bootstrap=True,
                oob_score=True
            )
        }
        
        cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
        best_score = 0
        
        for name, model in models.items():
            # Cross-validation
            cv_scores = cross_val_score(model, features_scaled, y, cv=cv, scoring='accuracy')
            
            print(f"  {name}: {np.mean(cv_scores):.4f} ± {np.std(cv_scores):.4f}")
            
            # Track best model
            if np.mean(cv_scores) > best_score:
                best_score = np.mean(cv_scores)
                self.best_model = model
                
            # Check stability
            if np.std(cv_scores) > 0.05:
                print(f"    ⚠️  High variance detected!")
            
            # Fit and check OOB score
            model.fit(features_scaled, y)
            if hasattr(model, 'oob_score_'):
                print(f"    OOB Score: {model.oob_score_:.4f}")
    
    def comprehensive_robustness_test(self, X, y):
        """
        Test comprehensiv de robustețe cu strategii îmbunătățite
        """
        print("\n💪 COMPREHENSIVE ROBUSTNESS TESTING")
        print("=" * 50)
        
        if self.best_model is None:
            print("Training default robust model...")
            features = self.extract_robust_features(X)
            features_scaled = self.scaler.fit_transform(features)
            self.best_model = RandomForestClassifier(
                n_estimators=500, max_depth=8, min_samples_split=10,
                min_samples_leaf=5, class_weight='balanced', random_state=42
            )
            self.best_model.fit(features_scaled, y)
        
        # Baseline performance
        features_clean = self.extract_robust_features(X)
        features_clean_scaled = self.scaler.transform(features_clean)
        baseline_accuracy = self.best_model.score(features_clean_scaled, y)
        print(f"📊 Baseline accuracy: {baseline_accuracy:.4f}")
        
        # Enhanced robustness tests
        robustness_results = {}
        
        # 1. Graduated noise testing
        print("\n🔊 Graduated noise robustness...")
        noise_levels = [0.001, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5]
        noise_results = []
        
        for noise_level in noise_levels:
            X_noisy = X + np.random.normal(0, noise_level * np.std(X), X.shape)
            features_noisy = self.extract_robust_features(X_noisy)
            features_noisy_scaled = self.scaler.transform(features_noisy)
            
            accuracy = self.best_model.score(features_noisy_scaled, y)
            noise_results.append(accuracy)
            
            # Color coding for results
            if accuracy > 0.95:
                status = "✅"
            elif accuracy > 0.85:
                status = "⚠️ "
            else:
                status = "❌"
                
            print(f"  Noise {noise_level:.3f}: {status} {accuracy:.4f}")
        
        robustness_results['noise'] = noise_results
        
        # 2. Systematic missing data testing
        print("\n❓ Missing data robustness...")
        missing_patterns = [
            ('random_5%', 0.05, 'random'),
            ('random_10%', 0.10, 'random'),
            ('random_20%', 0.20, 'random'),
            ('block_start', 0.10, 'start'),
            ('block_end', 0.10, 'end'),
            ('block_middle', 0.10, 'middle')
        ]
        
        missing_results = []
        
        for pattern_name, ratio, pattern_type in missing_patterns:
            X_missing = self._create_missing_pattern(X, ratio, pattern_type)
            features_missing = self.extract_robust_features(X_missing)
            features_missing_scaled = self.scaler.transform(features_missing)
            
            accuracy = self.best_model.score(features_missing_scaled, y)
            missing_results.append(accuracy)
            
            if accuracy > 0.90:
                status = "✅"
            elif accuracy > 0.75:
                status = "⚠️ "
            else:
                status = "❌"
                
            print(f"  {pattern_name:15s}: {status} {accuracy:.4f}")
        
        robustness_results['missing'] = missing_results
        
        # 3. Intelligent outlier testing
        print("\n🎯 Outlier robustness...")
        outlier_scenarios = [
            ('mild_1%', 0.01, 2),     # 1% mild outliers (2 sigma)
            ('mild_5%', 0.05, 2),     # 5% mild outliers
            ('moderate_1%', 0.01, 5), # 1% moderate outliers (5 sigma)
            ('moderate_5%', 0.05, 5), # 5% moderate outliers
            ('extreme_1%', 0.01, 10), # 1% extreme outliers (10 sigma)
            ('extreme_5%', 0.05, 10), # 5% extreme outliers
        ]
        
        outlier_results = []
        
        for scenario_name, ratio, sigma_multiplier in outlier_scenarios:
            X_outliers = self._create_outlier_scenario(X, ratio, sigma_multiplier)
            features_outliers = self.extract_robust_features(X_outliers)
            features_outliers_scaled = self.scaler.transform(features_outliers)
            
            accuracy = self.best_model.score(features_outliers_scaled, y)
            outlier_results.append(accuracy)
            
            if accuracy > 0.85:
                status = "✅"
            elif accuracy > 0.70:
                status = "⚠️ "
            else:
                status = "❌"
                
            print(f"  {scenario_name:15s}: {status} {accuracy:.4f}")
        
        robustness_results['outliers'] = outlier_results
        
        # 4. Combined stress test
        print("\n🚨 Combined stress test...")
        X_stressed = X.copy()
        
        # Add moderate noise
        X_stressed += np.random.normal(0, 0.02 * np.std(X), X.shape)
        
        # Add missing data
        X_stressed = self._create_missing_pattern(X_stressed, 0.05, 'random')
        
        # Add outliers
        X_stressed = self._create_outlier_scenario(X_stressed, 0.02, 3)
        
        features_stressed = self.extract_robust_features(X_stressed)
        features_stressed_scaled = self.scaler.transform(features_stressed)
        
        combined_accuracy = self.best_model.score(features_stressed_scaled, y)
        
        if combined_accuracy > 0.80:
            status = "✅ EXCELLENT"
        elif combined_accuracy > 0.70:
            status = "✅ GOOD"
        elif combined_accuracy > 0.60:
            status = "⚠️  ACCEPTABLE"
        else:
            status = "❌ NEEDS IMPROVEMENT"
            
        print(f"  Combined stress: {status} - {combined_accuracy:.4f}")
        
        # Summary
        overall_scores = [
            np.mean(noise_results[-3:]),  # Last 3 noise levels
            np.mean(missing_results),
            np.mean(outlier_results),
            combined_accuracy
        ]
        
        overall_robustness = np.mean(overall_scores)
        
        print(f"\n📈 ROBUSTNESS SUMMARY:")
        print(f"  Noise resistance:     {np.mean(noise_results[-3:]):.4f}")
        print(f"  Missing data resistance: {np.mean(missing_results):.4f}")
        print(f"  Outlier resistance:   {np.mean(outlier_results):.4f}")
        print(f"  Combined stress test: {combined_accuracy:.4f}")
        print(f"  🎯 Overall Robustness: {overall_robustness:.4f}")
        
        if overall_robustness > 0.85:
            print("  🏆 EXCELLENT robustness for production!")
        elif overall_robustness > 0.75:
            print("  ✅ GOOD robustness - suitable for most applications")
        elif overall_robustness > 0.65:
            print("  ⚠️  MODERATE robustness - monitor in production")
        else:
            print("  ❌ POOR robustness - needs significant improvement")
        
        return overall_robustness, robustness_results
    
    def _create_missing_pattern(self, X, ratio, pattern_type):
        """Create specific missing data patterns"""
        X_missing = X.copy()
        n_total = X.shape[0] * X.shape[1]
        n_missing = int(ratio * n_total)
        
        if pattern_type == 'random':
            missing_indices = np.random.choice(X.size, n_missing, replace=False)
            X_missing.flat[missing_indices] = np.nan
            
        elif pattern_type == 'start':
            # Missing data at the start of sequences
            missing_length = int(ratio * X.shape[1])
            X_missing[:, :missing_length] = np.nan
            
        elif pattern_type == 'end':
            # Missing data at the end of sequences
            missing_length = int(ratio * X.shape[1])
            X_missing[:, -missing_length:] = np.nan
            
        elif pattern_type == 'middle':
            # Missing data in the middle of sequences
            missing_length = int(ratio * X.shape[1])
            start_idx = (X.shape[1] - missing_length) // 2
            X_missing[:, start_idx:start_idx + missing_length] = np.nan
        
        return X_missing
    
    def _create_outlier_scenario(self, X, ratio, sigma_multiplier):
        """Create realistic outlier scenarios"""
        X_outliers = X.copy()
        n_total = X.shape[0] * X.shape[1]
        n_outliers = int(ratio * n_total)
        
        # Choose random positions for outliers
        outlier_indices = np.random.choice(X.size, n_outliers, replace=False)
        
        # Create outliers based on data distribution
        data_std = np.std(X)
        data_mean = np.mean(X)
        
        # Generate outliers that are realistic but extreme
        outlier_values = np.random.choice([-1, 1], n_outliers) * (data_mean + sigma_multiplier * data_std)
        
        X_outliers.flat[outlier_indices] = outlier_values
        
        return X_outliers
    
    def save_robust_model(self, model_path="robust_model.pkl", scaler_path="robust_scaler.pkl"):
        """Save the robust model and scaler"""
        with open(model_path, 'wb') as f:
            pickle.dump(self.best_model, f)
        with open(scaler_path, 'wb') as f:
            pickle.dump(self.scaler, f)
        print(f"✅ Robust model saved to {model_path}")
        print(f"✅ Robust scaler saved to {scaler_path}")


def complete_robust_pipeline():
    """
    Pipeline complet cu robustețe îmbunătățită
    """
    print("🛡️  ROBUST TIME SERIES CLASSIFIER PIPELINE")
    print("=" * 60)
    
    # Initialize robust classifier
    classifier = RobustTimeSeriesClassifier(
        use_robust_scaling=True,
        outlier_detection=True
    )
    
    # Generate more realistic test data with problems
    print("📊 Generating realistic test data with noise...")
    n_samples, n_features = 1000, 100
    X = np.random.randn(n_samples, n_features)
    
    # Add realistic patterns with noise and problems
    for i in range(n_samples):
        pattern_type = i % 4
        t = np.linspace(0, 10, n_features)
        base_noise = np.random.normal(0, 0.1, n_features)
        
        if pattern_type == 0:  # Noisy upward trend
            X[i] = 0.08 * t + 0.3 * np.sin(2 * np.pi * t / 20) + base_noise
            # Add some outliers
            if np.random.random() < 0.1:
                outlier_pos = np.random.randint(0, n_features)
                X[i][outlier_pos] += np.random.choice([-1, 1]) * 3
                
        elif pattern_type == 1:  # Noisy downward trend
            X[i] = -0.08 * t + 5 + 0.2 * np.cos(2 * np.pi * t / 15) + base_noise
            # Add missing values occasionally
            if np.random.random() < 0.05:
                missing_start = np.random.randint(0, n_features - 10)
                X[i][missing_start:missing_start + 5] = np.nan
                
        elif pattern_type == 2:  # Very volatile
            random_walk = np.cumsum(np.random.normal(0, 0.3, n_features))
            X[i] = random_walk + 0.5 * np.sin(5 * t) + base_noise
            
        else:  # Complex with regime change
            regime1 = 1.5 * np.sin(2 * t) * np.exp(-t/15)
            regime2 = 0.4 * t + np.cos(t)
            switch_point = n_features // 2 + np.random.randint(-10, 10)
            X[i] = np.concatenate([regime1[:switch_point], regime2[switch_point:]]) + base_noise
    
    y = np.array([i % 4 for i in range(n_samples)])
    
    # Add some systematic problems to make it realistic
    print("🚨 Adding realistic data problems...")
    
    # Add more missing values
    missing_mask = np.random.random(X.shape) < 0.02
    X[missing_mask] = np.nan
    
    # Add more outliers
    outlier_mask = np.random.random(X.shape) < 0.01
    X[outlier_mask] = np.random.choice([-1, 1], np.sum(outlier_mask)) * np.abs(X).max() * 2
    
    print(f"  • Missing values: {np.sum(np.isnan(X)) / X.size:.2%}")
    print(f"  • Potential outliers: {np.sum(outlier_mask)}")
    
    # Run robust pipeline
    print("\n1️⃣ Advanced Robustness Validation...")
    features = classifier.advanced_validation_with_robustness(X, y)
    
    print("\n2️⃣ Comprehensive Robustness Testing...")
    overall_robustness, detailed_results = classifier.comprehensive_robustness_test(X, y)
    
    print("\n3️⃣ Saving Robust Model...")
    classifier.save_robust_model()
    
    print("\n🎯 FINAL RESULTS:")
    print("=" * 30)
    print(f"✅ Robust features extracted: {features.shape[1]}")
    print(f"✅ Overall robustness score: {overall_robustness:.4f}")
    
    if overall_robustness > 0.80:
        print("🏆 SUCCESS: Model is production-ready with excellent robustness!")
    elif overall_robustness > 0.70:
        print("✅ GOOD: Model has adequate robustness for most applications")
    else:
        print("⚠️  MODERATE: Monitor model performance in production")
    
    return classifier, overall_robustness, detailed_results


if __name__ == "__main__":
    classifier, robustness_score, results = complete_robust_pipeline()


