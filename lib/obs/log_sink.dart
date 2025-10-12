import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

abstract class LogSink {
  Future<void> write(Map<String, dynamic> json);
}

class InMemorySink implements LogSink {
  final List<Map<String, dynamic>> lines = [];
  @override
  Future<void> write(Map<String, dynamic> json) async => lines.add(json);
}

class FileJsonlSink implements LogSink {
  final Future<File> _fileFut;
  FileJsonlSink(this._fileFut);

  @override
  Future<void> write(Map<String, dynamic> json) async {
    if (kIsWeb) return;
    final file = await _fileFut;
    final line = '${jsonEncode(json)}\n';
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }
}
