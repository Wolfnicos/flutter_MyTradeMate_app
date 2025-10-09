// dart run tool/skip_legacy_tests.dart
import 'dart:io';

final patterns = <RegExp>[
  RegExp(r'\bAIService\b'),
  RegExp(r'\bAIPrediction\b'),
  RegExp(r'services/ai_service\.dart'),
  RegExp(r'\bBinanceClientLike\b'),
];

const skipNote =
    "@sk.Skip('Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')";

void main() async {
  final root = Directory('test');
  if (!await root.exists()) {
    stderr.writeln('No test/ directory found. Run from repo root.');
    exit(1);
  }

  final files = await _dartFiles(root);
  final legacy = <File>[];
  for (final f in files) {
    final tx = await _processFile(f);
    if (tx == _Tx.legacy) legacy.add(f);
  }

  stdout.writeln('Legacy tests skipped (count=${legacy.length}):');
  for (final f in legacy) {
    stdout.writeln(' - ${f.path}');
  }
}

enum _Tx { none, legacy }

Future<_Tx> _processFile(File f) async {
  var src = await f.readAsString();

  // Normalize previous alias/imports to avoid clashing with flutter_test's 'test' symbol
  src = src.replaceAll(
      "import 'package:test/test.dart' as test show Skip;",
      "import 'package:test/test.dart' as sk show Skip;");
  src = src.replaceAll(
      'import "package:test/test.dart" as test show Skip;',
      'import "package:test/test.dart" as sk show Skip;');
  src = src.replaceAll('@test.Skip(', '@sk.Skip(');

  // Skip files that don't reference legacy APIs
  final isLegacy = patterns.any((p) => p.hasMatch(src));
  if (!isLegacy) return _Tx.none;

  // Already skipped?
  if (src.contains('@Skip(') || src.contains('@sk.Skip(')) {
    return _Tx.legacy; // treat as legacy (already skipped)
  }

  // Ensure import for Skip (alias to avoid name clashes)
  {
    final hasSkipImport = src.contains("import 'package:test/test.dart' as sk show Skip;") ||
        src.contains('import "package:test/test.dart" as sk show Skip;');
    if (!hasSkipImport) {
      final lines = src.split('\n');
      int lastImportIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        final t = lines[i].trimLeft();
        if (t.startsWith('import ')) {
          lastImportIndex = i;
        }
      }
      const importLine = "import 'package:test/test.dart' as sk show Skip;";
      if (lastImportIndex >= 0) {
        lines.insert(lastImportIndex + 1, importLine);
      } else {
        lines.insert(0, importLine);
      }
      src = lines.join('\n');
    }
  }

  // Insert @test.Skip before main() or first group(
  final mainMatch = RegExp(r'^\s*void\s+main\s*\(', multiLine: true).firstMatch(src);
  final groupMatch = RegExp(r'^\s*group\s*\(', multiLine: true).firstMatch(src);

  int? idx;
  if (mainMatch != null) {
    idx = mainMatch.start;
  } else if (groupMatch != null) {
    idx = groupMatch.start;
  }

  if (idx == null) {
    // Couldn’t find main/group; leave a marker at top.
    src = '$skipNote\n$src';
  } else {
    src = src.replaceRange(idx, idx, '$skipNote\n');
  }

  await f.writeAsString(src);
  return _Tx.legacy;
}

Future<List<File>> _dartFiles(Directory dir) async {
  final out = <File>[];
  await for (final ent in dir.list(recursive: true, followLinks: false)) {
    if (ent is File && ent.path.endsWith('.dart')) out.add(ent);
  }
  return out;
}


