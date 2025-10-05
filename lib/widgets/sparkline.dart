import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  final List<double> values;
  final EdgeInsets padding;
  final double strokeWidth;
  const Sparkline({
    super.key,
    required this.values,
    this.padding = const EdgeInsets.all(12),
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 1.6,
      child: CustomPaint(
        painter: _SparkPainter(values, Theme.of(context).colorScheme.primary, strokeWidth),
        child: Container(padding: padding),
      ),
    );
  }
}

class SparklineCard extends StatelessWidget {
  final String title;
  final List<double> values;
  const SparklineCard({super.key, required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Sparkline(values: values),
          ],
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  final double width;
  _SparkPainter(this.v, this.color, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.isEmpty) return;
    final minV = v.reduce((a, b) => a < b ? a : b);
    final maxV = v.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    final p = Path();
    for (int i = 0; i < v.length; i++) {
      final x = size.width * (i / (v.length - 1));
      final y = size.height * (1 - (v[i] - minV) / range);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // linie
    canvas.drawPath(p, paint);

    // gradient ușor sub linie
    final fillPath = Path.from(p)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.18), color.withOpacity(0.03)],
    ).createShader(Offset.zero & size);

    final fillPaint = Paint()..shader = shader;
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.v != v || oldDelegate.color != color || oldDelegate.width != width;
}
