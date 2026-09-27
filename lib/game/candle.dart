import 'dart:math';

/// 봉 하나 (게임에서는 5분봉).
class Candle {
  Candle(this.index, this.open)
      : high = open,
        low = open,
        close = open;

  /// 테스트나 차트 초기값용 완성된 봉.
  Candle.ohlc(this.index, this.open, this.high, this.low, this.close);

  final int index;
  final int open;
  int high;
  int low;
  int close;
  int volume = 0;

  void update(int price, int quantity) {
    high = max(high, price);
    low = min(low, price);
    close = price;
    volume += quantity;
  }

  bool get isBullish => close > open;
  bool get isBearish => close < open;
  int get body => (close - open).abs();
  int get range => high - low;
  int get upperShadow => high - max(open, close);
  int get lowerShadow => min(open, close) - low;
}

/// candles[end - period, end) 종가의 단순이동평균. 봉이 모자라면 null.
double? movingAverage(List<Candle> candles, int period, [int? end]) {
  final stop = end ?? candles.length;
  if (stop < period || period <= 0) return null;
  var sum = 0;
  for (var i = stop - period; i < stop; i++) {
    sum += candles[i].close;
  }
  return sum / period;
}
