import 'dart:async';

class Debouncer {
  Debouncer({required this.delay});
  final Duration delay;
  Timer? _t;

  void call(void Function() action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }

  void dispose() {
    _t?.cancel();
  }
}

