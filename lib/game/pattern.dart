import 'dart:math';

import 'package:everyvaluation/game/candle.dart';
import 'package:everyvaluation/game/faction.dart';

/// 완성되면 한 진영에 스킬을 내려주는 차트 패턴.
///
/// 판정은 모두 '방금 마감된 봉'(candles.last) 기준이다.
/// 하락 패턴은 가격을 뒤집은 차트에서 대응하는 상승 패턴을 찾는 식으로 판정한다.
enum ChartPattern {
  bullishEngulfing('상승장악형', Faction.bull, _bullishEngulfing),
  hammer('망치형', Faction.bull, _hammer),
  threeWhiteSoldiers('적삼병', Faction.bull, _threeWhiteSoldiers),
  goldenCross('골든크로스', Faction.bull, _goldenCross),
  doubleBottom('쌍바닥(W)', Faction.bull, _doubleBottom),
  inverseHeadAndShoulders('역헤드앤숄더', Faction.bull, _inverseHeadAndShoulders),
  bearishEngulfing('하락장악형', Faction.bear, _bearishEngulfing),
  shootingStar('유성형', Faction.bear, _shootingStar),
  threeBlackCrows('흑삼병', Faction.bear, _threeBlackCrows),
  deadCross('데드크로스', Faction.bear, _deadCross),
  doubleTop('쌍봉(M)', Faction.bear, _doubleTop),
  headAndShoulders('헤드앤숄더', Faction.bear, _headAndShoulders);

  const ChartPattern(this.label, this.direction, this._test);

  final String label;

  /// 이 패턴이 완성되면 스킬을 얻는 진영.
  final Faction direction;
  final bool Function(List<Candle> candles) _test;

  bool matches(List<Candle> candles) => _test(candles);

  /// 방금 마감된 봉에서 완성된 패턴들.
  static List<ChartPattern> detect(List<Candle> candles) =>
      values.where((p) => p.matches(candles)).toList();
}

// ── 하락 패턴: 뒤집은 차트의 상승 패턴 ──────────────────────────────

List<Candle> _mirror(List<Candle> candles) => [
      for (final c in candles)
        Candle.ohlc(c.index, -c.open, -c.low, -c.high, -c.close),
    ];

bool _bearishEngulfing(List<Candle> c) => _bullishEngulfing(_mirror(c));
bool _shootingStar(List<Candle> c) => _hammer(_mirror(c));
bool _threeBlackCrows(List<Candle> c) => _threeWhiteSoldiers(_mirror(c));
bool _deadCross(List<Candle> c) => _goldenCross(_mirror(c));
bool _doubleTop(List<Candle> c) => _doubleBottom(_mirror(c));
bool _headAndShoulders(List<Candle> c) => _inverseHeadAndShoulders(_mirror(c));

// ── 공통 계산 ──────────────────────────────────────────────────────

/// candles[end - period, end) 몸통 평균 (최소 1).
double _averageBody(List<Candle> c, int end, [int period = 10]) {
  final start = max(0, end - period);
  if (end <= start) return 1;
  var sum = 0;
  for (var i = start; i < end; i++) {
    sum += c[i].body;
  }
  return max(1, sum / (end - start));
}

/// candles[end - period, end) 고저폭 평균 (최소 1). 패턴 기준을 변동성에 맞춘다.
double _averageRange(List<Candle> c, int end, [int period = 14]) {
  final start = max(0, end - period);
  if (end <= start) return 1;
  var sum = 0;
  for (var i = start; i < end; i++) {
    sum += c[i].range;
  }
  return max(1, sum / (end - start));
}

/// i번째 봉까지 하락 추세였는지.
bool _declinedInto(List<Candle> c, int i, [int lookback = 3]) =>
    i - lookback >= 0 && c[i].close < c[i - lookback].close;

/// [from, to] 구간에서 좌우 window개 봉보다 저가가 낮은 봉 (to까지 확인 가능한 것만).
List<int> _pivotLows(List<Candle> c, int from, int to, [int window = 2]) {
  final pivots = <int>[];
  for (var i = max(from, window); i <= to - window; i++) {
    var pivot = true;
    for (var j = i - window; j <= i + window && pivot; j++) {
      if (j == i) continue;
      pivot = j < i ? c[j].low >= c[i].low : c[j].low > c[i].low;
    }
    if (pivot) pivots.add(i);
  }
  return pivots;
}

int _highestHigh(List<Candle> c, int from, int to) {
  var high = c[from].high;
  for (var i = from + 1; i <= to; i++) {
    high = max(high, c[i].high);
  }
  return high;
}

int _lowestLow(List<Candle> c, int from, int to) {
  var low = c[from].low;
  for (var i = from + 1; i <= to; i++) {
    low = min(low, c[i].low);
  }
  return low;
}

/// 마지막 봉이 넥라인을 처음 종가로 뚫었는지.
bool _breaksOut(List<Candle> c, int neck) {
  final last = c.length - 1;
  return c[last].close > neck && c[last - 1].close <= neck;
}

// ── 상승 패턴 ──────────────────────────────────────────────────────

/// 하락 끝에 직전 음봉을 통째로 감싸는 양봉.
bool _bullishEngulfing(List<Candle> c) {
  final n = c.length;
  if (n < 5) return false;
  final prev = c[n - 2];
  final cur = c[n - 1];
  final avg = _averageBody(c, n - 2);
  return prev.isBearish &&
      cur.isBullish &&
      prev.body >= avg * 0.5 &&
      cur.body >= avg * 1.2 &&
      cur.body > prev.body &&
      cur.open <= prev.close &&
      cur.close >= prev.open &&
      _declinedInto(c, n - 2);
}

/// 하락 끝에 긴 아래꼬리를 달고 새 저점을 찍은 봉.
bool _hammer(List<Candle> c) {
  final n = c.length;
  if (n < 5) return false;
  final cur = c[n - 1];
  final range = cur.range;
  return range > 0 &&
      range >= _averageRange(c, n - 1) &&
      cur.lowerShadow >= range * 0.6 &&
      cur.upperShadow <= range * 0.15 &&
      cur.low < min(c[n - 2].low, c[n - 3].low) &&
      _declinedInto(c, n - 2);
}

/// 몸통이 실한 양봉 세 개가 종가를 높이며 이어진다.
bool _threeWhiteSoldiers(List<Candle> c) {
  final n = c.length;
  if (n < 4) return false;
  final avg = _averageBody(c, n - 3);
  for (var i = n - 3; i < n; i++) {
    final k = c[i];
    if (!k.isBullish || k.body < avg * 0.8 || k.upperShadow * 2 > k.body) {
      return false;
    }
    if (i > n - 3 && (k.close <= c[i - 1].close || k.open < c[i - 1].open)) {
      return false;
    }
  }
  return true;
}

/// 5봉 이동평균이 20봉 이동평균을 아래에서 위로 뚫는다.
bool _goldenCross(List<Candle> c) {
  final n = c.length;
  final short = movingAverage(c, 5, n);
  final long = movingAverage(c, 20, n);
  final prevShort = movingAverage(c, 5, n - 1);
  final prevLong = movingAverage(c, 20, n - 1);
  if (short == null || long == null || prevShort == null || prevLong == null) {
    return false;
  }
  return prevShort <= prevLong && short > long;
}

/// 비슷한 높이의 두 바닥 뒤 넥라인 돌파.
bool _doubleBottom(List<Candle> c) {
  final n = c.length;
  if (n < 12) return false;
  final last = n - 1;
  final atr = _averageRange(c, last);
  final pivots = _pivotLows(c, max(0, n - 30), last - 1);
  if (pivots.length < 2) return false;
  final second = pivots.last;
  for (var k = pivots.length - 2; k >= 0; k--) {
    final first = pivots[k];
    if (second - first < 3) continue;
    final lowA = c[first].low;
    final lowB = c[second].low;
    final floor = min(lowA, lowB);
    if ((lowA - lowB).abs() > atr * 0.8) continue;
    // 두 바닥 사이에 더 깊은 바닥이 있으면 W가 아니다.
    if (_lowestLow(c, first + 1, second - 1) < floor) continue;
    final neck = _highestHigh(c, first + 1, second - 1);
    if (neck - max(lowA, lowB) < atr * 1.5) continue;
    if (_lowestLow(c, second + 1, last) < floor) return false;
    return _breaksOut(c, neck);
  }
  return false;
}

/// 왼어깨·머리·오른어깨 세 바닥 (머리가 가장 깊음) 뒤 넥라인 돌파.
bool _inverseHeadAndShoulders(List<Candle> c) {
  final n = c.length;
  if (n < 16) return false;
  final last = n - 1;
  final atr = _averageRange(c, last);
  final pivots = _pivotLows(c, max(0, n - 40), last - 1);
  if (pivots.length < 3) return false;
  final left = pivots[pivots.length - 3];
  final head = pivots[pivots.length - 2];
  final right = pivots.last;
  final leftLow = c[left].low;
  final headLow = c[head].low;
  final rightLow = c[right].low;
  if (headLow > min(leftLow, rightLow) - atr * 0.5) return false;
  if ((leftLow - rightLow).abs() > atr) return false;
  final neck = _highestHigh(c, left + 1, right - 1);
  if (neck - max(leftLow, rightLow) < atr) return false;
  if (_lowestLow(c, right + 1, last) < min(leftLow, rightLow)) return false;
  return _breaksOut(c, neck);
}
