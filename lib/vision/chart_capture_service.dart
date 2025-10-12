import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:mytrademate/ai/entities.dart';

class ChartCaptureService {
  /// Renders an offscreen candlestick+EMA chart for the given candles (most recent last).
  /// Returns a tuple: (Uint8List rgbBytes, int width, int height).
  static Future<({Uint8List bytes, int width, int height})> renderCandlesImage({
    required List<Candle> candles,
    int width = 320,
    int height = 200,
    bool drawEma9 = true,
    bool drawEma21 = true,
  }) async {
    final int w = width;
    final int h = height;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    // Background (dark)
    final ui.Paint bg = ui.Paint()..color = const ui.Color(0xFF0B0E14);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), bg);

    if (candles.isEmpty) {
      final ui.Image img = await recorder.endRecording().toImage(w, h);
      final ByteData? bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final Uint8List rgba = bd!.buffer.asUint8List();
      final Uint8List rgb = _rgbaToRgb(rgba);
      return (bytes: rgb, width: w, height: h);
    }

    // Use last up to 96 bars
    final List<Candle> seq = candles.length <= 96 ? List<Candle>.from(candles) : candles.sublist(candles.length - 96);

    // Compute price range
    double minP = double.infinity;
    double maxP = -double.infinity;
    for (final c in seq) {
      if (c.low < minP) minP = c.low;
      if (c.high > maxP) maxP = c.high;
    }
    if (minP == maxP) {
      minP *= 0.99;
      maxP *= 1.01;
    }

    // Paddings
    const double leftPad = 8;
    const double rightPad = 8;
    const double topPad = 6;
    const double bottomPad = 12;

    final double plotW = w - leftPad - rightPad;
    final double plotH = h - topPad - bottomPad;

    double yFor(double price) {
      final double t = (price - minP) / (maxP - minP);
      return topPad + (1.0 - t) * plotH;
    }

    // X spacing
    final int n = seq.length;
    final double step = n > 1 ? plotW / (n - 1) : plotW;

    // Candle paints
    final ui.Paint upBody = ui.Paint()..color = const ui.Color(0xFF16C784);
    final ui.Paint dnBody = ui.Paint()..color = const ui.Color(0xFFEA3943);
    final ui.Paint wick = ui.Paint()
      ..color = const ui.Color(0xFFE6E6E6)
      ..strokeWidth = 1.0
      ..style = ui.PaintingStyle.stroke;

    // Draw wicks and bodies
    final double bodyWidth = math.max(1.0, step * 0.5);
    for (int i = 0; i < n; i++) {
      final Candle c = seq[i];
      final double x = leftPad + i * step;
      // Wick
      canvas.drawLine(ui.Offset(x, yFor(c.high)), ui.Offset(x, yFor(c.low)), wick);
      // Body
      final bool up = c.close >= c.open;
      final double yOpen = yFor(c.open);
      final double yClose = yFor(c.close);
      final double top = up ? yClose : yOpen;
      final double bottom = up ? yOpen : yClose;
      final ui.Rect r = ui.Rect.fromCenter(center: ui.Offset(x, (top + bottom) * 0.5), width: bodyWidth, height: (bottom - top).abs() + 1.0);
      canvas.drawRect(r, up ? upBody : dnBody);
    }

    // Optional EMA lines
    List<double> closes = seq.map((c) => c.close).toList();
    List<double>? ema9;
    List<double>? ema21;
    if (drawEma9) ema9 = _ema(closes, 9);
    if (drawEma21) ema21 = _ema(closes, 21);

    void drawLine(List<double> series, ui.Color color) {
      final ui.Path path = ui.Path();
      for (int i = 0; i < series.length; i++) {
        final double x = leftPad + i * step;
        final double y = yFor(series[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final ui.Paint p = ui.Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = ui.PaintingStyle.stroke
        ..isAntiAlias = true;
      canvas.drawPath(path, p);
    }

    if (ema21 != null) drawLine(ema21, const ui.Color(0xFF4DA3FF));
    if (ema9 != null) drawLine(ema9, const ui.Color(0xFFFFC857));

    final ui.Image image = await recorder.endRecording().toImage(w, h);
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final Uint8List rgba = bytes!.buffer.asUint8List();
    final Uint8List rgb = _rgbaToRgb(rgba);

    // ignore: avoid_print
    print('[Vision-Capture] rendered ${w}x${h}');
    return (bytes: rgb, width: w, height: h);
  }

  static List<double> _ema(List<double> x, int period) {
    if (x.isEmpty) return <double>[];
    final double alpha = 2.0 / (period + 1);
    final List<double> out = List<double>.filled(x.length, 0.0);
    double e = x.first;
    out[0] = e;
    for (int i = 1; i < x.length; i++) {
      e = x[i] * alpha + e * (1 - alpha);
      out[i] = e;
    }
    return out;
  }

  static Uint8List _rgbaToRgb(Uint8List rgba) {
    final int nPix = rgba.length ~/ 4;
    final Uint8List rgb = Uint8List(nPix * 3);
    int ri = 0;
    for (int i = 0; i < rgba.length; i += 4) {
      rgb[ri++] = rgba[i];
      rgb[ri++] = rgba[i + 1];
      rgb[ri++] = rgba[i + 2];
    }
    return rgb;
  }
}


