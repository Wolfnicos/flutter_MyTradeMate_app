"""
GHID COMPLET PENTRU TESTAREA MODELULUI ÎN PRODUCȚIE
==================================================
Pipeline complet pentru validarea și monitorizarea în aplicația reală
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.model_selection import train_test_split
import pickle
import json
import time
from datetime import datetime
import logging
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')


class ProductionModelTester:
    """
    Sistem complet pentru testarea și monitorizarea modelului în producție
    """
    
    def __init__(self, model_path="final_robust_model.pkl", scaler_path="final_robust_scaler.pkl"):
        self.model = None
        self.scaler = None
        self.feature_extractor = None
        self.performance_log = []
        self.review_queue = []
        self.load_model(model_path, scaler_path)
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('model_production.log'),
                logging.StreamHandler()
            ]
        )
        
    def load_model(self, model_path, scaler_path):
        """Încarcă modelul salvat"""
        try:
            with open(model_path, 'rb') as f:
                self.model = pickle.load(f)
            with open(scaler_path, 'rb') as f:
                self.scaler = pickle.load(f)
            
            # Import feature extractor from final classifier
            try:
                from ai.ts.scripts.final_production_ready_classifier import FinalRobustTimeSeriesClassifier
            except Exception:
                from final_production_ready_classifier import FinalRobustTimeSeriesClassifier
            self.feature_extractor = FinalRobustTimeSeriesClassifier()
            
            print("✅ Model și scaler încărcate cu succes")
            logging.info("Model loaded successfully")
            
        except Exception as e:
            print(f"❌ Eroare la încărcarea modelului: {e}")
            logging.error(f"Failed to load model: {e}")
    
    def predict_single_series(self, time_series, return_confidence=True):
        """
        Predicție pentru o singură serie temporală cu confidence score
        """
        try:
            # Extract features
            features = self.feature_extractor.extract_production_features([time_series])
            
            # Scale features
            features_scaled = self.scaler.transform(features)
            
            # Predict
            prediction = self.model.predict(features_scaled)[0]
            
            if return_confidence:
                probabilities = self.model.predict_proba(features_scaled)[0]
                confidence = float(np.max(probabilities))
                # Cast numpy types to native Python
                all_probs = {int(i): float(p) for i, p in enumerate(np.asarray(probabilities).tolist())}

                # Threshold-based secondary check: if class 0 with low confidence, consider class 3
                # Example rule: if top==0 and confidence<0.65 and p(class3)>=0.55 → switch to class 3
                adjusted_pred = int(prediction)
                secondary_applied = False
                if int(prediction) == 0 and confidence < 0.65:
                    p_class3 = probabilities[3] if len(probabilities) > 3 else 0.0
                    if p_class3 >= 0.55:
                        adjusted_pred = 3
                        secondary_applied = True
                
                flagged = bool((adjusted_pred in (0, 3)) and (confidence < 0.70))
                result = {
                    'prediction': adjusted_pred,
                    'confidence': confidence,
                    'probabilities': all_probs,
                    'secondary_adjustment': secondary_applied,
                    'timestamp': datetime.now().isoformat(),
                    'flag_for_review': flagged,
                }
                if flagged:
                    self._flag_for_review(result)
                return result
            
            return int(prediction)
            
        except Exception as e:
            logging.error(f"Prediction failed: {e}")
            return None
    
    def batch_predict(self, time_series_batch):
        """
        Predicții în lot pentru eficiență
        """
        try:
            # Extract features for all series
            features = self.feature_extractor.extract_production_features(time_series_batch)
            
            # Scale features
            features_scaled = self.scaler.transform(features)
            
            # Predict
            predictions = self.model.predict(features_scaled)
            probabilities = self.model.predict_proba(features_scaled)
            
            results = []
            for i, (pred, probs) in enumerate(zip(predictions, probabilities)):
                results.append({
                    'series_id': i,
                    'prediction': int(pred),
                    'confidence': float(np.max(probs)),
                    'probabilities': dict(enumerate(probs)),
                    'timestamp': datetime.now().isoformat()
                })
            
            return results
            
        except Exception as e:
            logging.error(f"Batch prediction failed: {e}")
            return []
    
    def validate_on_real_data(self, real_data, real_labels, data_description="Real Data"):
        """
        Validare pe datele reale din aplicația ta
        """
        print(f"\n📊 VALIDARE PE {data_description.upper()}")
        print("=" * 50)
        
        try:
            # Predict on real data
            predictions = []
            confidences = []
            
            for series in real_data:
                result = self.predict_single_series(series, return_confidence=True)
                if result:
                    predictions.append(result['prediction'])
                    confidences.append(result['confidence'])
                else:
                    predictions.append(-1)  # Error indicator
                    confidences.append(0.0)
            
            predictions = np.array(predictions)
            confidences = np.array(confidences)
            
            # Remove error predictions for evaluation
            valid_mask = predictions != -1
            predictions_valid = predictions[valid_mask]
            labels_valid = np.array(real_labels)[valid_mask]
            confidences_valid = confidences[valid_mask]
            
            if len(predictions_valid) == 0:
                print("❌ Nu s-au putut face predicții valide")
                return None
            
            # Calculate metrics
            accuracy = accuracy_score(labels_valid, predictions_valid)
            avg_confidence = np.mean(confidences_valid)
            
            print(f"📈 Rezultate pe {data_description}:")
            print(f"  • Accuracy: {accuracy:.4f}")
            print(f"  • Average Confidence: {avg_confidence:.4f}")
            print(f"  • Valid Predictions: {len(predictions_valid)}/{len(real_data)}")
            print(f"  • Prediction Errors: {np.sum(~valid_mask)}")
            
            # Detailed classification report
            print(f"\n📋 Classification Report:")
            print(classification_report(labels_valid, predictions_valid))
            
            # Confusion Matrix
            cm = confusion_matrix(labels_valid, predictions_valid)
            
            plt.figure(figsize=(8, 6))
            sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
            plt.title(f'Confusion Matrix - {data_description}')
            plt.ylabel('True Label')
            plt.xlabel('Predicted Label')
            plt.show()
            
            # Confidence distribution
            plt.figure(figsize=(10, 6))
            plt.subplot(1, 2, 1)
            plt.hist(confidences_valid, bins=20, alpha=0.7, edgecolor='black')
            plt.title('Confidence Distribution')
            plt.xlabel('Confidence Score')
            plt.ylabel('Frequency')
            
            plt.subplot(1, 2, 2)
            plt.boxplot([confidences_valid[predictions_valid == labels_valid],
                        confidences_valid[predictions_valid != labels_valid]])
            plt.xticks([1, 2], ['Correct', 'Incorrect'])
            plt.title('Confidence by Prediction Correctness')
            plt.ylabel('Confidence Score')
            
            plt.tight_layout()
            plt.show()
            
            # Log results
            self.performance_log.append({
                'timestamp': datetime.now().isoformat(),
                'data_description': data_description,
                'accuracy': accuracy,
                'avg_confidence': avg_confidence,
                'n_samples': len(predictions_valid),
                'n_errors': np.sum(~valid_mask)
            })
            
            return {
                'accuracy': accuracy,
                'avg_confidence': avg_confidence,
                'confusion_matrix': cm,
                'valid_predictions': len(predictions_valid),
                'total_samples': len(real_data)
            }
            
        except Exception as e:
            print(f"❌ Eroare în validare: {e}")
            logging.error(f"Validation failed: {e}")
            return None
    
    def a_b_test_setup(self, baseline_model_path=None):
        """
        Setup pentru A/B testing cu modelul curent vs baseline
        """
        print("\n🔬 SETUP A/B TESTING")
        print("=" * 40)
        
        self.baseline_model = None
        self.baseline_scaler = None
        
        if baseline_model_path:
            try:
                with open(baseline_model_path, 'rb') as f:
                    self.baseline_model = pickle.load(f)
                print("✅ Baseline model încărcat pentru comparație")
            except:
                print("⚠️  Nu s-a putut încărca baseline model")
        
        self.ab_results = {
            'current_model': [],
            'baseline_model': []
        }
        
        return True
    
    def a_b_test_prediction(self, time_series, true_label=None, use_baseline=True):
        """
        Predicție A/B cu ambele modele pentru comparație
        """
        results = {}
        
        # Current model prediction
        current_result = self.predict_single_series(time_series)
        results['current'] = current_result
        
        # Baseline model prediction (dacă disponibil)
        if use_baseline and self.baseline_model:
            try:
                features = self.feature_extractor.extract_production_features([time_series])
                features_scaled = self.scaler.transform(features)
                baseline_pred = self.baseline_model.predict(features_scaled)[0]
                baseline_prob = self.baseline_model.predict_proba(features_scaled)[0]
                
                results['baseline'] = {
                    'prediction': int(baseline_pred),
                    'confidence': float(np.max(baseline_prob))
                }
            except:
                results['baseline'] = None
        
        # Log pentru A/B comparison
        if true_label is not None:
            self.ab_results['current_model'].append({
                'prediction': current_result['prediction'] if current_result else -1,
                'true_label': true_label,
                'correct': (current_result['prediction'] == true_label) if current_result else False
            })
            
            if results.get('baseline'):
                self.ab_results['baseline_model'].append({
                    'prediction': results['baseline']['prediction'],
                    'true_label': true_label,
                    'correct': results['baseline']['prediction'] == true_label
                })
        
        return results
    
    def monitor_drift(self, recent_predictions, window_size=100):
        """
        Monitorizează concept drift în timp
        """
        print("\n📊 CONCEPT DRIFT MONITORING")
        print("=" * 40)
        
        if len(recent_predictions) < window_size:
            print(f"⚠️  Insuficiente predicții pentru monitoring (need {window_size}, got {len(recent_predictions)})")
            return None
        
        # Extract confidence scores and predictions over time
        timestamps = [p['timestamp'] for p in recent_predictions[-window_size:]]
        confidences = [p['confidence'] for p in recent_predictions[-window_size:]]
        predictions = [p['prediction'] for p in recent_predictions[-window_size:]]
        
        # Calculate drift indicators
        recent_avg_confidence = np.mean(confidences[-20:])  # Last 20 predictions
        historical_avg_confidence = np.mean(confidences[:-20])  # All but last 20
        
        confidence_drift = abs(recent_avg_confidence - historical_avg_confidence)
        
        # Prediction distribution drift
        from collections import Counter
        recent_dist = Counter(predictions[-20:])
        historical_dist = Counter(predictions[:-20])
        
        # Simple distribution change measure
        distribution_change = 0
        all_classes = set(list(recent_dist.keys()) + list(historical_dist.keys()))
        for cls in all_classes:
            recent_ratio = recent_dist.get(cls, 0) / 20
            historical_ratio = historical_dist.get(cls, 0) / (len(predictions) - 20)
            distribution_change += abs(recent_ratio - historical_ratio)
        
        print(f"📈 Drift Analysis:")
        print(f"  • Confidence Drift: {confidence_drift:.4f}")
        print(f"  • Distribution Change: {distribution_change:.4f}")
        print(f"  • Recent Avg Confidence: {recent_avg_confidence:.4f}")
        print(f"  • Historical Avg Confidence: {historical_avg_confidence:.4f}")
        
        # Alerting thresholds
        alerts = []
        if confidence_drift > 0.1:
            alerts.append("ALERT: Significant confidence drift detected!")
        if distribution_change > 0.3:
            alerts.append("ALERT: Significant prediction distribution change!")
        if recent_avg_confidence < 0.7:
            alerts.append("WARNING: Low recent confidence scores!")
        
        for alert in alerts:
            print(f"🚨 {alert}")
            logging.warning(alert)
        
        # Visualizations
        plt.figure(figsize=(15, 5))
        
        plt.subplot(1, 3, 1)
        plt.plot(confidences)
        plt.title('Confidence Over Time')
        plt.xlabel('Prediction #')
        plt.ylabel('Confidence')
        plt.axhline(y=np.mean(confidences), color='r', linestyle='--', label='Average')
        plt.legend()
        
        plt.subplot(1, 3, 2)
        predictions_numeric = [int(p) for p in predictions]
        plt.hist(predictions_numeric, bins=len(set(predictions_numeric)), alpha=0.7, edgecolor='black')
        plt.title('Prediction Distribution')
        plt.xlabel('Predicted Class')
        plt.ylabel('Frequency')
        
        plt.subplot(1, 3, 3)
        # Rolling confidence average
        window = 10
        rolling_conf = pd.Series(confidences).rolling(window=window).mean()
        plt.plot(rolling_conf)
        plt.title(f'Rolling Confidence (window={window})')
        plt.xlabel('Prediction #')
        plt.ylabel('Rolling Average Confidence')
        
        plt.tight_layout()
        plt.show()
        
        return {
            'confidence_drift': confidence_drift,
            'distribution_change': distribution_change,
            'recent_avg_confidence': recent_avg_confidence,
            'alerts': alerts
        }
    
    def generate_production_report(self, save_path="production_report.json"):
        """
        Generează raport complet de performanță
        """
        print("\n📄 GENERARE RAPORT DE PRODUCȚIE")
        print("=" * 45)
        
        report = {
            'model_info': {
                'model_type': type(self.model).__name__,
                'feature_count': len(self.feature_extractor.feature_names) if self.feature_extractor.feature_names else 'unknown',
                'model_parameters': self.model.get_params() if hasattr(self.model, 'get_params') else {}
            },
            'performance_history': self.performance_log,
            'summary_stats': {
                'total_evaluations': len(self.performance_log),
                'average_accuracy': np.mean([log['accuracy'] for log in self.performance_log]) if self.performance_log else 0,
                'average_confidence': np.mean([log['avg_confidence'] for log in self.performance_log]) if self.performance_log else 0,
            },
            'timestamp': datetime.now().isoformat()
        }
        
        # A/B test results if available
        if hasattr(self, 'ab_results') and self.ab_results['current_model']:
            current_accuracy = np.mean([r['correct'] for r in self.ab_results['current_model']])
            report['ab_test'] = {
                'current_model_accuracy': current_accuracy,
                'current_model_samples': len(self.ab_results['current_model'])
            }
            
            if self.ab_results['baseline_model']:
                baseline_accuracy = np.mean([r['correct'] for r in self.ab_results['baseline_model']])
                report['ab_test']['baseline_model_accuracy'] = baseline_accuracy
                report['ab_test']['improvement'] = current_accuracy - baseline_accuracy
        
        # Save report
        try:
            with open(save_path, 'w') as f:
                json.dump(report, f, indent=2)
            print(f"✅ Raport salvat în {save_path}")
        except Exception as e:
            print(f"❌ Eroare la salvarea raportului: {e}")
        
        # Print summary
        print("\n📊 SUMAR PERFORMANȚĂ:")
        print(f"  • Total evaluări: {report['summary_stats']['total_evaluations']}")
        print(f"  • Average accuracy: {report['summary_stats']['average_accuracy']:.4f}")
        print(f"  • Average confidence: {report['summary_stats']['average_confidence']:.4f}")
        
        if 'ab_test' in report:
            print(f"  • A/B Test samples: {report['ab_test']['current_model_samples']}")
            if 'improvement' in report['ab_test']:
                improvement = report['ab_test']['improvement']
                print(f"  • Improvement vs baseline: {improvement:+.4f}")
        
        return report

    # ────────────────────────────────────────────────────────────────────────────
    # Review helpers
    def _flag_for_review(self, result_entry):
        try:
            self.review_queue.append(result_entry)
            logging.info(f"Flagged for review: pred={result_entry.get('prediction')} conf={result_entry.get('confidence'):.3f}")
        except Exception:
            pass

    def export_review_queue(self, path="review_queue.jsonl"):
        try:
            with open(path, 'a') as f:
                for r in self.review_queue:
                    f.write(json.dumps(r, default=self._json_default) + "\n")
            self.review_queue.clear()
            print(f"✅ Review queue exported to {path}")
        except Exception as e:
            print(f"❌ Failed to export review queue: {e}")

    @staticmethod
    def _json_default(o):
        try:
            import numpy as np
            if isinstance(o, (np.bool_, np.bool8)):
                return bool(o)
            if isinstance(o, (np.integer,)):
                return int(o)
            if isinstance(o, (np.floating,)):
                return float(o)
            if isinstance(o, (np.ndarray,)):
                return o.tolist()
        except Exception:
            pass
        return str(o)


def example_production_usage():
    """
    Exemplu de utilizare în producție
    """
    print("🚀 EXEMPLU UTILIZARE ÎN PRODUCȚIE")
    print("=" * 50)
    
    # Initialize tester
    tester = ProductionModelTester()
    
    # Simulează date reale (înlocuiește cu datele tale)
    print("\n1️⃣ Simulare date reale...")
    
    # Generează exemple de date "reale" pentru test
    n_real_samples = 200
    real_data = []
    real_labels = []
    
    for i in range(n_real_samples):
        # Simulează pattern-uri din aplicația ta
        t = np.linspace(0, 10, 100)
        pattern_type = np.random.choice([0, 1, 2, 3])
        
        if pattern_type == 0:
            series = 0.2 * t + 0.1 * np.sin(2 * np.pi * t / 20) + 0.05 * np.random.randn(100)
        elif pattern_type == 1:
            series = -0.2 * t + 8 + 0.1 * np.cos(2 * np.pi * t / 15) + 0.05 * np.random.randn(100)
        elif pattern_type == 2:
            series = np.sin(3 * t) + 0.3 * np.sin(10 * t) + 0.05 * np.random.randn(100)
        else:
            series = 2 * np.exp(-t/10) * np.sin(2 * t) + 0.2 * t + 0.05 * np.random.randn(100)
        
        # Adaugă probleme realiste
        if np.random.random() < 0.02:  # 2% missing data
            missing_indices = np.random.choice(100, 5, replace=False)
            series[missing_indices] = np.nan
        
        if np.random.random() < 0.01:  # 1% outliers
            outlier_indices = np.random.choice(100, 2, replace=False)
            series[outlier_indices] += np.random.choice([-1, 1]) * 2 * np.std(series)
        
        real_data.append(series)
        real_labels.append(pattern_type)
    
    # Testează pe datele "reale"
    print("\n2️⃣ Validare pe datele reale...")
    results = tester.validate_on_real_data(real_data, real_labels, "Aplicația Reală")
    
    # Setup A/B testing
    print("\n3️⃣ Setup A/B testing...")
    tester.a_b_test_setup()
    
    # Simulează monitoring în timp real
    print("\n4️⃣ Simulare monitoring timp real...")
    recent_predictions = []
    
    for i in range(150):
        # Generează o nouă predicție
        test_series = real_data[i % len(real_data)]
        test_label = real_labels[i % len(real_labels)]
        
        prediction = tester.predict_single_series(test_series)
        if prediction:
            recent_predictions.append(prediction)
    
    # Drift monitoring
    if len(recent_predictions) >= 100:
        print("\n5️⃣ Analiza concept drift...")
        drift_results = tester.monitor_drift(recent_predictions)
    
    # Generează raport final
    print("\n6️⃣ Generare raport final...")
    report = tester.generate_production_report()
    
    return tester, report


if __name__ == "__main__":
    # Rulează exemplul de producție
    tester, report = example_production_usage()


