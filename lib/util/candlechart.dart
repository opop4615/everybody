import 'dart:math';

import 'package:everyvaluation/game/candle.dart';
import 'package:everyvaluation/game/krx.dart';
import 'package:everyvaluation/util/warstyle.dart';
import 'package:flutter/material.dart';

/// 5분봉 차트: 양봉 빨강, 음봉 파랑, 5·20 이동평균선, 기준가 점선.
class CandleChart extends StatelessWidget {
  const CandleChart({
    Key? key,
    required this.candles,
    required this.current,
    required this.basePrice,
    this.visible = 36,
  }) : super(key: key);

  final List<Candle> candles;
  final Candle current;
  final int basePrice;
  final int visible;

  static const shortColor = Color.fromARGB(255, 255, 214, 90);
  static const longColor = Color.fromARGB(255, 190, 150, 255);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WarColors.panel.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _CandlePainter([...candles, current], basePrice, visible),
          ),
        ),
        const Positioned(
          left: 0,
          top: 0,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '5분봉 '),
              TextSpan(text: 'MA5 ', style: TextStyle(color: shortColor)),
              TextSpan(text: 'MA20', style: TextStyle(color: longColor)),
            ]),
            style: TextStyle(fontSize: 9, color: WarColors.muted),
          ),
        ),
      ]),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter(this.all, this.basePrice, this.visible);

  final List<Candle> all;
  final int basePrice;
  final int visible;

  @override
  void paint(Canvas canvas, Size size) {
    final start = max(0, all.length - visible);
    final shown = all.sublist(start);
    var high = shown.map((c) => c.high).reduce(max).toDouble();
    var low = shown.map((c) => c.low).reduce(min).toDouble();
    final pad = max((high - low) * 0.12, basePrice * 0.002);
    high += pad;
    low -= pad;
    const labelWidth = 44.0;
    final width = size.width - labelWidth;
    final slot = width / visible;
    double y(num price) => size.height * (high - price) / (high - low);

    // 기준가
    if (basePrice > low && basePrice < high) {
      final paint = Paint()
        ..color = WarColors.muted.withOpacity(0.5)
        ..strokeWidth = 0.8;
      for (var x = 0.0; x < width; x += 6) {
        canvas.drawLine(
            Offset(x, y(basePrice)), Offset(x + 3, y(basePrice)), paint);
      }
    }

    // 봉
    for (var i = 0; i < shown.length; i++) {
      final c = shown[i];
      final x = (i + 0.5) * slot;
      final color = c.close > c.open
          ? WarColors.bull
          : c.close < c.open
              ? WarColors.bear
              : Colors.white70;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, y(c.high)), Offset(x, y(c.low)), paint);
      final top = y(max(c.open, c.close));
      final bottom = max(y(min(c.open, c.close)), top + 1);
      canvas.drawRect(
          Rect.fromLTRB(x - slot * 0.32, top, x + slot * 0.32, bottom), paint);
    }

    // 이동평균선
    for (final entry
        in {5: CandleChart.shortColor, 20: CandleChart.longColor}.entries) {
      final path = Path();
      var started = false;
      for (var i = 0; i < shown.length; i++) {
        final ma = movingAverage(all, entry.key, start + i + 1);
        if (ma == null) continue;
        final point = Offset((i + 0.5) * slot, y(ma));
        if (started) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          started = true;
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = entry.value
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }

    // 현재가 꼬리표
    final last = shown.last.close;
    final color = WarColors.forPrice(last, basePrice);
    final label = TextPainter(
      text: TextSpan(
        text: formatNumber(last),
        style: const TextStyle(
            fontSize: 10, color: Colors.white, fontFamily: 'nanum'),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: labelWidth);
    final ly = y(last).clamp(label.height / 2, size.height - label.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width + 2, ly - label.height / 2 - 1, labelWidth - 2,
            label.height + 2),
        const Radius.circular(3),
      ),
      Paint()..color = color.withOpacity(0.85),
    );
    label.paint(canvas, Offset(width + 5, ly - label.height / 2));
  }

  @override
  bool shouldRepaint(_CandlePainter oldDelegate) => true;
}
