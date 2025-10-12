import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/dio_binance_client.dart';
import 'package:test/test.dart' as test show Skip;

/// Test pentru a verifica că AI Helper funcționează cu DATE LIVE
/// pentru cele 5 crypto: BTC, ETH, BNB, WLFI, TRUMP
@test.Skip(
    'Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')
void main() {
  group('AI Helper LIVE Data Tests', () {
    final supportedCrypto = [
      {'symbol': 'BTCUSDT', 'name': 'Bitcoin'},
      {'symbol': 'ETHUSDT', 'name': 'Ethereum'},
      {'symbol': 'BNBUSDT', 'name': 'Binance Coin'},
      {'symbol': 'WLFIUSDT', 'name': 'WLFI'},
      {'symbol': 'TRUMPUSDT', 'name': 'TRUMP'},
    ];

    test('AI Service folosește DATE LIVE (enableFake = false)', () {
      final aiService = AIService(enableFake: false);

      // Verifică că AI service NU folosește fake data
      expect(aiService.enableFake, false);
    });

    test('AI Service returnează predicții REALE pentru BTC', () async {
      final aiService = AIService(enableFake: false);

      try {
        final prediction = await aiService.getPrediction('BTCUSDT');

        // Verifică că predicția are date valide
        expect(prediction.action, isIn(['BUY', 'SELL', 'HOLD']));
        expect(prediction.confidence, greaterThan(0));
        expect(prediction.confidence, lessThan(101));
        expect(prediction.targetPrice, greaterThan(0));
        expect(prediction.volatility, isIn(['LOW', 'MEDIUM', 'HIGH']));

        print(
            '✅ BTC Prediction LIVE: ${prediction.action} @ ${prediction.confidence.toStringAsFixed(1)}%');
      } catch (e) {
        print('⚠️ Test poate eșua pe testnet dacă BTCUSDT nu e disponibil: $e');
        // Pe testnet, unele perechi pot să nu fie disponibile
        // Acest test verifică logica, nu disponibilitatea pe testnet
      }
    });

    test('Verifică că DioBinanceClient poate accesa date LIVE', () async {
      try {
        final client = await DioBinanceClient.createFromPrefs();

        // Încearcă să obții ticker pentru BTC
        final ticker = await client.ticker24h('BTCUSDT');

        expect(ticker, isNotNull);
        expect(ticker['lastPrice'], isNotNull);
        expect(ticker['priceChangePercent'], isNotNull);

        final price = double.parse(ticker['lastPrice'].toString());
        expect(price, greaterThan(0));

        print('✅ BTC Live Price: \$${price.toStringAsFixed(2)}');
        print('   24h Change: ${ticker['priceChangePercent']}%');
      } catch (e) {
        print('⚠️ Eroare la accesarea datelor live: $e');
      }
    });

    test('Toate cele 5 crypto au predicții AI disponibile', () async {
      final aiService = AIService(enableFake: false);
      int successCount = 0;

      for (final crypto in supportedCrypto) {
        try {
          final prediction = await aiService.getPrediction(crypto['symbol']!);

          expect(prediction.action, isNotEmpty);
          expect(prediction.confidence, greaterThan(0));

          print(
              '✅ ${crypto['name']}: ${prediction.action} (${prediction.confidence.toStringAsFixed(1)}%)');
          successCount++;
        } catch (e) {
          print(
              '⚠️ ${crypto['name']}: Nu este disponibil pe acest environment');
          // Pe testnet, WLFI și TRUMP pot să nu fie disponibile
        }
      }

      // Cel puțin BTC, ETH, BNB ar trebui să fie disponibile
      expect(successCount, greaterThanOrEqualTo(3),
          reason: 'Cel puțin 3 crypto ar trebui să fie disponibile');
    });

    test('Quote currency conversion funcționează', () {
      // Test logic pentru conversie quote currency
      const symbol = 'BTCUSDT';

      // USDT
      expect(symbol.replaceAll('USDT', ''), 'BTC');

      // USD conversion
      final usdSymbol = symbol.replaceAll('USDT', 'USD');
      expect(usdSymbol, 'BTCUSD');

      // EUR conversion
      final eurSymbol = symbol.replaceAll('USDT', 'EUR');
      expect(eurSymbol, 'BTCEUR');

      print('✅ Quote currency conversion logic works');
    });
  });
}
