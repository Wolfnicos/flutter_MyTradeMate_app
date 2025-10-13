import 'dart:collection';

class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Queue<DateTime> _timestamps = Queue<DateTime>();

  RateLimiter({required this.maxRequests, required this.window});

  Future<void> acquire() async {
    final now = DateTime.now();
    // Drop timestamps outside the window
    while (_timestamps.isNotEmpty && now.difference(_timestamps.first) > window) {
      _timestamps.removeFirst();
    }
    if (_timestamps.length < maxRequests) {
      _timestamps.addLast(now);
      return;
    }
    // Need to wait until the oldest falls out of the window
    final oldest = _timestamps.first;
    final delay = window - now.difference(oldest);
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }
    _timestamps.addLast(DateTime.now());
  }
}


