import 'package:mytrademate/ai/engine_interface.dart';
import 'package:mytrademate/ai/entities.dart';

class FakeEngine implements ISignalEngine {
  @override
  Future<Prediction?> predict(String symbol, List<Candle> window) async {
    return Prediction(
      symbol: symbol,
      asOf: DateTime.utc(2025, 1, 5, 12, 0, 0),
      pBuy: 0.72,
      pHold: 0.18,
      pSell: 0.10,
      expReturn: 0.0042,
      annVol: 0.18,
      relVolume: 1.0,
    );
  }

  @override
  String decide(Prediction p) {
    return p.pBuy >= 0.55 ? 'BUY' : (p.pSell >= 0.55 ? 'SELL' : 'HOLD');
  }

  @override
  void dispose() {}
}


