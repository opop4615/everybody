import 'package:everyvaluation/game/candle.dart';
import 'package:everyvaluation/game/pattern.dart';
import 'package:flutter_test/flutter_test.dart';

/// [open, high, low, close] 목록을 봉으로.
List<Candle> candles(List<List<int>> ohlc) => [
      for (var i = 0; i < ohlc.length; i++)
        Candle.ohlc(i, ohlc[i][0], ohlc[i][1], ohlc[i][2], ohlc[i][3]),
    ];

/// 가격축을 뒤집은 차트 (상승 패턴 → 하락 패턴).
List<Candle> flipped(List<Candle> source) => [
      for (final c in source)
        Candle.ohlc(c.index, 20000 - c.open, 20000 - c.low, 20000 - c.high,
            20000 - c.close),
    ];

final engulfing = candles([
  [10100, 10110, 10040, 10050],
  [10050, 10060, 9990, 10000],
  [10000, 10010, 9940, 9950],
  [9950, 9960, 9890, 9900],
  [9900, 10010, 9890, 10000],
]);

final hammer = candles([
  [10100, 10110, 10050, 10060],
  [10060, 10070, 10010, 10020],
  [10020, 10030, 9970, 9980],
  [9980, 9990, 9930, 9940],
  [9940, 9965, 9800, 9960],
]);

final soldiers = candles([
  [10000, 10025, 9990, 10020],
  [10020, 10075, 10015, 10070],
  [10070, 10125, 10065, 10120],
  [10120, 10185, 10110, 10180],
]);

/// 15봉 보합, 5봉 하락 뒤 급등 → 5봉선이 20봉선을 뚫는다.
final cross = candles([
  for (var i = 0; i < 15; i++) [10000, 10000, 10000, 10000],
  for (var i = 0; i < 5; i++) [9900, 9900, 9900, 9900],
  [9900, 10400, 9900, 10400],
]);

final doubleBottom = candles([
  [10100, 10110, 10070, 10080],
  [10080, 10090, 10030, 10040],
  [10040, 10050, 9990, 10000],
  [10000, 10010, 9950, 9960],
  [9960, 9970, 9900, 9930], // 첫 번째 바닥
  [9930, 9990, 9920, 9980],
  [9980, 10040, 9970, 10030],
  [10030, 10060, 10020, 10050], // 넥라인 10060
  [10050, 10055, 9990, 10000],
  [10000, 10005, 9940, 9950],
  [9950, 9960, 9905, 9930], // 두 번째 바닥
  [9930, 9980, 9920, 9970],
  [9970, 10030, 9960, 10020],
  [10020, 10050, 10010, 10040],
  [10040, 10110, 10030, 10100], // 넥라인 돌파
]);

final inverseHeadAndShoulders = candles([
  [10100, 10110, 10070, 10080],
  [10080, 10090, 10030, 10040],
  [10040, 10050, 9980, 9990],
  [9990, 10000, 9900, 9930], // 왼어깨
  [9930, 10000, 9920, 9990],
  [9990, 10060, 9980, 10040], // 넥라인 10060
  [10040, 10045, 9940, 9950],
  [9950, 9955, 9830, 9840],
  [9840, 9850, 9780, 9810], // 머리
  [9810, 9910, 9800, 9900],
  [9900, 10050, 9890, 10000],
  [10000, 10010, 9950, 9960],
  [9960, 9970, 9885, 9920], // 오른어깨
  [9920, 9990, 9890, 9980],
  [9980, 10040, 9970, 10030],
  [10030, 10055, 10020, 10050],
  [10050, 10130, 10040, 10120], // 넥라인 돌파
]);

void main() {
  group('상승 패턴', () {
    test('상승장악형', () {
      expect(ChartPattern.bullishEngulfing.matches(engulfing), isTrue);
    });

    test('감싸지 못하면 장악형이 아니다', () {
      final weak = List<Candle>.of(engulfing)
        ..[4] = Candle.ohlc(4, 9900, 9945, 9890, 9940);
      expect(ChartPattern.bullishEngulfing.matches(weak), isFalse);
    });

    test('망치형', () {
      expect(ChartPattern.hammer.matches(hammer), isTrue);
    });

    test('적삼병', () {
      expect(ChartPattern.threeWhiteSoldiers.matches(soldiers), isTrue);
      final broken = List<Candle>.of(soldiers)
        ..[3] = Candle.ohlc(3, 10120, 10130, 10060, 10070);
      expect(ChartPattern.threeWhiteSoldiers.matches(broken), isFalse);
    });

    test('골든크로스는 교차한 그 봉에서만', () {
      expect(ChartPattern.goldenCross.matches(cross), isTrue);
      expect(ChartPattern.goldenCross.matches(cross.sublist(0, 20)), isFalse);
    });

    test('쌍바닥은 넥라인을 뚫는 봉에서 완성', () {
      expect(ChartPattern.doubleBottom.matches(doubleBottom), isTrue);
      expect(ChartPattern.doubleBottom.matches(doubleBottom.sublist(0, 14)),
          isFalse);
    });

    test('역헤드앤숄더 (머리가 깊어서 쌍바닥은 아님)', () {
      final found = ChartPattern.detect(inverseHeadAndShoulders);
      expect(found, contains(ChartPattern.inverseHeadAndShoulders));
      expect(found, isNot(contains(ChartPattern.doubleBottom)));
    });
  });

  group('하락 패턴은 뒤집은 차트에서 같은 모양', () {
    final cases = {
      ChartPattern.bearishEngulfing: engulfing,
      ChartPattern.shootingStar: hammer,
      ChartPattern.threeBlackCrows: soldiers,
      ChartPattern.deadCross: cross,
      ChartPattern.doubleTop: doubleBottom,
      ChartPattern.headAndShoulders: inverseHeadAndShoulders,
    };
    cases.forEach((pattern, source) {
      test(pattern.label, () {
        expect(pattern.matches(flipped(source)), isTrue);
        expect(pattern.matches(source), isFalse);
      });
    });
  });

  test('상승 차트에서는 하락 패턴이 나오지 않는다', () {
    for (final chart in [
      engulfing,
      hammer,
      soldiers,
      cross,
      doubleBottom,
      inverseHeadAndShoulders,
    ]) {
      final found = ChartPattern.detect(chart);
      expect(found, isNotEmpty);
      expect(found.where((p) => p.direction.label == '매도군'), isEmpty);
    }
  });
}
