import 'dart:async';

class Throttler {
  Throttler(this.duration);

  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    if (_timer?.isActive ?? false) return;
    action();
    _timer = Timer(duration, () {});
  }
}



