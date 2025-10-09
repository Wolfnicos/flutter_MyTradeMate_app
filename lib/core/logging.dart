import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum LogLevel { trace, debug, info, warn, error }

class AppLogger {
  AppLogger._(this._sessionId, this._optInTelemetry);

  static AppLogger? _instance;

  final String _sessionId;
  final bool _optInTelemetry;
  IOSink? _sink;
  String? _filePath;

  static AppLogger init({String? sessionId, bool optInTelemetry = false}) {
    _instance ??= AppLogger._(
      sessionId ?? _generateSessionId(),
      optInTelemetry,
    );
    _instance!._open();
    return _instance!;
  }

  static AppLogger get instance => _instance ?? init();

  String? get filePath => _filePath;
  String get sessionId => _sessionId;
  bool get optInTelemetry => _optInTelemetry;

  void log(LogLevel level, String message, {Map<String, Object?> context = const {}}) {
    final now = DateTime.now().toUtc().toIso8601String();
    final sanitized = _sanitize(context);
    final rec = {
      'ts': now,
      'level': level.name,
      'session': _sessionId,
      'msg': _sanitizeMsg(message),
      'ctx': sanitized,
    };
    final line = jsonEncode(rec);
    _sink?.writeln(line);
  }

  void trace(String m, {Map<String, Object?> context = const {}}) => log(LogLevel.trace, m, context: context);
  void debug(String m, {Map<String, Object?> context = const {}}) => log(LogLevel.debug, m, context: context);
  void info(String m, {Map<String, Object?> context = const {}}) => log(LogLevel.info, m, context: context);
  void warn(String m, {Map<String, Object?> context = const {}}) => log(LogLevel.warn, m, context: context);
  void error(String m, {Map<String, Object?> context = const {}}) => log(LogLevel.error, m, context: context);

  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  void _open() {
    try {
      final dir = Directory.systemTemp;
      final f = File('${dir.path}/mytrademate.log.jsonl');
      _filePath = f.path;
      _sink = f.openWrite(mode: FileMode.append);
    } catch (_) {
      // ignore file errors; logging remains best-effort
    }
  }

  static String _generateSessionId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    final r = (t * 48271) % 0xFFFFF;
    return 's${t.toRadixString(16)}-${r.toRadixString(16)}';
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> ctx) {
    if (ctx.isEmpty) return ctx;
    final out = <String, Object?>{};
    ctx.forEach((k, v) {
      final key = k.toLowerCase();
      if (key.contains('secret') || key.contains('apikey') || key.contains('key')) {
        out[k] = '[REDACTED]';
      } else if (v is String && v.length > 24) {
        out[k] = _mask(v);
      } else if (v is Map<String, Object?>) {
        out[k] = _sanitize(v);
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  static String _sanitizeMsg(String m) {
    // crude masking for long tokens
    if (m.length <= 48) return m;
    return _mask(m);
  }

  static String _mask(String s) {
    if (s.length <= 8) return '********';
    final head = s.substring(0, 4);
    final tail = s.substring(s.length - 4);
    return '$head********$tail';
  }
}




