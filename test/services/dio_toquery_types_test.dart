import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('toQueryForTest stringifies primitives, drops null and nested types',
      () {
    final c = DioBinanceClient.fakeForTest();

    final out = c.toQueryForTest({
      'a_null': null,
      'b_int': 42,
      'c_double': 3.1415,
      'd_bool': true,
      'e_str': 'ok',
      'f_list': [1, 2, 3],
      'g_map': {'k': 'v'},
      'h_nested_null': {'x': null},
    });

    expect(out.containsKey('a_null'), isFalse);
    expect(out['b_int'], '42');
    expect(out['c_double'], '3.1415');
    expect(out['d_bool'], 'true');
    expect(out['e_str'], 'ok');
    expect(out.containsKey('f_list'), isFalse);
    expect(out.containsKey('g_map'), isFalse);
    expect(out.containsKey('h_nested_null'), isFalse);
  });
}

