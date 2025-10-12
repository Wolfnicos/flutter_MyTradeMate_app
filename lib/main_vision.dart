import 'package:flutter/material.dart';
import 'screens/vision_screen.dart';

void main() {
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: const VisionScreen(),
    );
  }
}
