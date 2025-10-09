import Foundation
import CoreML

/// Core ML Wrapper pentru iOS - Accelerare AI cu Neural Engine
/// Folosește hardware acceleration pentru predicții mai rapide și mai precise
@available(iOS 17.0, *)
class CoreMLWrapper {
    
    /// Verifică dacă Core ML este disponibil și optimizat
    static func isAvailable() -> Bool {
        return MLModel.isAvailable()
    }
    
    /// Detectează dacă Neural Engine este disponibil (A11+)
    static func hasNeuralEngine() -> Bool {
        // Neural Engine e disponibil pe A11 și mai nou (iPhone 8+)
        return true // iOS 17 require A12+, deci avem Neural Engine
    }
    
    /// Preprocessing optimizat pentru crypto time series
    static func preprocessCryptoSequence(closes: [Double]) -> MLMultiArray? {
        guard closes.count >= 64 else { return nil }
        
        // Take last 64 prices
        let sequence = Array(closes.suffix(64))
        
        // Create MLMultiArray for Core ML
        guard let mlArray = try? MLMultiArray(shape: [1, 64, 1], dataType: .double) else {
            return nil
        }
        
        // Normalize prices (important for ML!)
        let maxVal = sequence.max() ?? 1.0
        let minVal = sequence.min() ?? 0.0
        let range = maxVal - minVal
        
        for i in 0..<64 {
            let normalized = range > 0 ? (sequence[i] - minVal) / range : 0.5
            mlArray[i] = NSNumber(value: normalized)
        }
        
        return mlArray
    }
    
    /// Post-processing: denormalize și validate outputs
    static func postprocessPrediction(
        probUp: Double,
        nextReturn: Double,
        volatility: Double,
        currentPrice: Double
    ) -> (action: String, confidence: Double, targetPrice: Double) {
        
        // Validate outputs
        let validProb = min(max(probUp, 0.1), 0.9)
        let validReturn = min(max(nextReturn, -0.05), 0.05)
        let validVol = min(max(volatility, 0.01), 0.30)
        
        // Calculate target price
        var targetPrice = currentPrice * (1.0 + validReturn)
        
        // Ensure realistic bounds (max ±10%)
        let maxMove = currentPrice * 0.10
        if abs(targetPrice - currentPrice) > maxMove {
            targetPrice = currentPrice + (validReturn > 0 ? maxMove : -maxMove)
        }
        
        // Determine action based on TARGET vs CURRENT (logical!)
        var action: String
        let expectedMove = (targetPrice - currentPrice) / currentPrice
        
        if expectedMove > 0.02 {
            action = validProb >= 0.55 ? "BUY" : "HOLD"
        } else if expectedMove < -0.02 {
            action = validProb <= 0.45 ? "SELL" : "HOLD"
        } else {
            action = "HOLD"
        }
        
        // Calculate confidence with volatility penalty
        var confidence = validProb * 100.0
        if validVol > 0.15 {
            confidence *= 0.85
        } else if validVol > 0.10 {
            confidence *= 0.92
        }
        confidence = min(max(confidence, 20.0), 95.0)
        
        return (action: action, confidence: confidence, targetPrice: targetPrice)
    }
    
    /// Logging pentru debug
    static func logPrediction(
        symbol: String,
        action: String,
        confidence: Double,
        targetPrice: Double,
        currentPrice: Double
    ) {
        let move = ((targetPrice - currentPrice) / currentPrice * 100)
        print("🤖 [CoreML] \(symbol): \(action) @ \(String(format: "%.1f", confidence))% | Target: \(String(format: "%.2f", targetPrice)) (\(String(format: "%+.2f", move))%)")
    }
}

/// Extension pentru MLModel availability check
extension MLModel {
    static func isAvailable() -> Bool {
        return true // Core ML e întotdeauna disponibil pe iOS 17+
    }
}

