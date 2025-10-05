import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mytrademate/services/calibration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'assets/models/calibration.json') {
        final calibration = jsonEncode({
          "version": 1,
          "calibrator": "platt",
          "params": {"A": 1.2, "B": -0.3},
          "train_meta": {"seed": 1337, "commit": "TEST"}
        });
        final bytes = Uint8List.fromList(utf8.encode(calibration));
        return ByteData.sublistView(bytes);
      }
      return null; // asset not found for others
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('loads calibrator from assets and applies it', () async {
    final cal = await Calibrator.loadFromAssets(
      rootBundle,
      path: 'assets/models/calibration.json',
      fallback: const IdentityCalibrator(),
    );

    final raw = 0.40;
    final calibrated = cal.apply(raw);
    expect(calibrated, isNot(raw));
    expect(calibrated, inInclusiveRange(1e-9, 1 - 1e-9));
  });
}


