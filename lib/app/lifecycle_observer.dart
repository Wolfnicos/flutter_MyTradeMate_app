import 'package:flutter/widgets.dart';
import 'package:mytrademate/services/market_data_service.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  MarketDataService? _service;
  
  void setMarketDataService(MarketDataService service) {
    _service = service;
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_service == null) return;
    
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _service!.pause();
    } else if (state == AppLifecycleState.resumed) {
      _service!.resume();
    }
  }
}



