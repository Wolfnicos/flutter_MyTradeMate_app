import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'logging.dart';
import '../src/core/trading_prefs.dart';

Future<String?> createDiagnosticBundle() async {
  final logger = AppLogger.instance;
  final session = logger.sessionId;
  final logPath = logger.filePath;
  final tmpDir = Directory.systemTemp;
  final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final outPath = '${tmpDir.path}/mytrademate-diagnostics-$session-$ts.zip';

  final archive = Archive();

  // Include log file if available
  if (logPath != null && await File(logPath).exists()) {
    final bytes = await File(logPath).readAsBytes();
    archive.addFile(
        ArchiveFile('logs/mytrademate.log.jsonl', bytes.length, bytes));
  }

  // Build anonymized config snapshot
  final prefs = await TradingPrefs.load();
  final cfg = <String, Object?>{
    'env': prefs.env.name,
    'fixedQuote': prefs.fixedQuote,
    'hasApiKey': (prefs.apiKey ?? '').isNotEmpty,
    'hasApiSecret': (prefs.apiSecret ?? '').isNotEmpty,
    'apiKeyMasked': _mask(prefs.apiKey),
    'apiSecretMasked': _mask(prefs.apiSecret),
    'session': session,
    'platform': Platform.operatingSystem,
    'platformVersion': Platform.version.split(' ').first,
  };
  final cfgBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(cfg));
  archive.addFile(ArchiveFile('config/config.json', cfgBytes.length, cfgBytes));

  final zipData = ZipEncoder().encode(archive);
  if (zipData == null) return null;
  final outFile = File(outPath);
  await outFile.writeAsBytes(zipData, flush: true);
  return outFile.path;
}

String? _mask(String? s) {
  if (s == null || s.isEmpty) return null;
  if (s.length <= 8) return '********';
  final head = s.substring(0, 4);
  final tail = s.substring(s.length - 4);
  return '$head********$tail';
}
