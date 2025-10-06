import 'package:flutter/widgets.dart';
import 'package:mytrademate/services/price_stream_manager.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  final PriceStreamManager _pm = PriceStreamManager();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pm.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      _pm.resumeAll();
    }
  }
}

