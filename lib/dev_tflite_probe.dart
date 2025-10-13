import 'dart:developer';
import 'package:flutter/material.dart';
// Legacy dev probe not used in builds; keep minimal to avoid analyzer errors.

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _App());
}

class _App extends StatefulWidget {
  const _App({super.key});
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  String _status = 'Loading…';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      // No-op run: avoids importing deprecated predictors in normal builds.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      setState(() => _status = 'Dev probe idle');
      log(_status);
    } catch (e, st) {
      setState(() => _status = 'Eroare: $e');
      log('Eroare', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0E0E12),
        body: Center(
          child: Text(_status, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
