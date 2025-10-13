import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/norm_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads norm.json via ensureLoaded()', () async {
    final stats = await NormLoader.ensureLoaded();
    expect(stats.featureOrder.isNotEmpty, true);
    expect(stats.mean.containsKey('close'), true);
    expect(stats.std.containsKey('close'), true);
  });
}
