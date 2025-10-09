typedef NowProvider = DateTime Function();

class FakeClock {
  DateTime _now;
  FakeClock(this._now);
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}


