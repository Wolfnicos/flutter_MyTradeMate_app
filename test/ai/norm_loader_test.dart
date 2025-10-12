import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/norm_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads norm.json from assets', () async {
    final stats = await NormLoader.load('assets/models/norm.json');
    expect(stats.featureOrder.isNotEmpty, true);
    expect(stats.mean.containsKey('close'), true);
    expect(stats.std.containsKey('close'), true);
  });
}
