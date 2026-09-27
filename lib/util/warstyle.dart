import 'package:everyvaluation/game/faction.dart';
import 'package:everyvaluation/game/krx.dart';
import 'package:flutter/material.dart';

/// 호가전쟁 화면 색. 한국 증시 관례대로 상승·매수는 빨강, 하락·매도는 파랑.
class WarColors {
  static const bull = Color.fromARGB(255, 240, 72, 82);
  static const bear = Color.fromARGB(255, 64, 142, 250);
  static const deep = Color.fromARGB(255, 10, 38, 71);
  static const panel = Color.fromARGB(255, 20, 66, 114);
  static const accent = Color.fromARGB(255, 32, 82, 149);
  static const muted = Color.fromARGB(255, 150, 172, 198);
  static const warning = Color.fromARGB(255, 255, 178, 36);

  static Color of(Faction? faction) => faction == null
      ? Colors.white
      : faction == Faction.bull
          ? bull
          : bear;

  static Color forPrice(int price, int base) => price > base
      ? bull
      : price < base
          ? bear
          : Colors.white;
}

String signedPercent(double rate) =>
    '${rate > 0 ? '+' : ''}${(rate * 100).toStringAsFixed(2)}%';

String signedNumber(int value) =>
    '${value > 0 ? '+' : ''}${formatNumber(value)}';

/// 3.4억 / 5,200만 / 3,000 처럼 짧게.
String compactWon(int won) {
  final abs = won.abs();
  final sign = won < 0 ? '-' : '';
  if (abs >= 100000000) return '$sign${(abs / 100000000).toStringAsFixed(1)}억';
  if (abs >= 10000) return '$sign${formatNumber(abs ~/ 10000)}만';
  return '$sign${formatNumber(abs)}';
}
