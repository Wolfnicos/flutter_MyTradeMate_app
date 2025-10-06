import 'dart:convert';
import 'package:dio/dio.dart';
import 'fixture_loader.dart';

class MockBinanceAdapter implements HttpClientAdapter {
  final Map<String, String> routes; // key: METHOD path, value: fixture file
  MockBinanceAdapter(this.routes);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final key =
        '${options.method.toUpperCase()} ${options.path.split('?').first}';
    final file = routes[key];
    if (file == null) {
      return _json(404, {'error': 'No mock for $key'});
    }
    if (file.endsWith('.html')) {
      final html = loadFixtureString(file);
      return _bytes(503, html.codeUnits, headers: {
        Headers.contentTypeHeader: ['text/html']
      });
    }
    final data = loadFixtureJson(file);
    if (data is Map && data['__status'] is int) {
      final status = data['__status'] as int;
      final body = Map<String, dynamic>.from(data)..remove('__status');
      return _json(status, body);
    }
    return _json(200, data);
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );

  ResponseBody _bytes(int status, List<int> bytes,
          {Map<String, List<String>>? headers}) =>
      ResponseBody.fromBytes(bytes, status, headers: headers);
}
