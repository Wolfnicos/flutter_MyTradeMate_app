import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/core/errors.dart';

void main() {
  test('maps timeout', () {
    final e = ErrorMapper.map(Exception('Request timed out after 5s'));
    expect(e.type, AppErrorType.timeout);
    expect(e.message.contains('timeout'), isTrue);
  });
  test('maps auth', () {
    final e = ErrorMapper.map(Exception('Binance error -2015 invalid api-key'));
    expect(e.type, AppErrorType.auth);
  });
  test('maps model load', () {
    final e = ErrorMapper.map(Exception('AI model load failed'));
    expect(e.type, AppErrorType.modelLoad);
  });
  test('maps network', () {
    final e = ErrorMapper.map(Exception('Socket error: network unreachable'));
    expect(e.type, AppErrorType.network);
  });
}
