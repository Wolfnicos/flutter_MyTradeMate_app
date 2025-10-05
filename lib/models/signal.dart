enum Direction { up, down, hold }

class Signal {
  final double nextReturn;
  final double probUp;
  final double volatility;
  final Direction dir;

  const Signal({
    required this.nextReturn,
    required this.probUp,
    required this.volatility,
    required this.dir,
  });

  Map<String, dynamic> toJson() {
    return {
      'nextReturn': nextReturn,
      'probUp': probUp,
      'volatility': volatility,
      'dir': dir.toString().split('.').last,
    };
  }

  factory Signal.fromJson(Map<String, dynamic> json) {
    Direction parseDirection(String dir) {
      switch (dir) {
        case 'up':
          return Direction.up;
        case 'down':
          return Direction.down;
        case 'hold':
          return Direction.hold;
        default:
          throw ArgumentError('Unknown direction: $dir');
      }
    }

    return Signal(
      nextReturn: (json['nextReturn'] as num).toDouble(),
      probUp: (json['probUp'] as num).toDouble(),
      volatility: (json['volatility'] as num).toDouble(),
      dir: parseDirection(json['dir'] as String),
    );
  }

  @override
  String toString() {
    return 'Signal(nextReturn: $nextReturn, probUp: $probUp, volatility: $volatility, dir: $dir)';
  }
}
