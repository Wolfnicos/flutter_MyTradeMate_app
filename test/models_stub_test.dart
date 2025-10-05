import 'package:flutter_test/flutter_test.dart';

// Contract test: simulate model I/O shape expectations without TFLite
class FakeModels {
  double predictDirection(Object input) => 0.6; // BUY-ish
  double predictReturn(Object input) => 0.02;   // +2%
  double predictVolatility(Object input) => 0.01;
}

void main() {
  test('FakeModels outputs deterministic values', () {
    final m = FakeModels();
    expect(m.predictDirection([List.filled(5, 1.0)]), 0.6);
    expect(m.predictReturn([List.filled(5, 1.0)]), 0.02);
    expect(m.predictVolatility([List.filled(5, 1.0)]), 0.01);
  });
}


