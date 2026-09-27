/// 한국거래소(KRX) 가격 규칙: 호가가격단위와 가격제한폭(±30%).

/// 2023년 개편된 유가증권·코스닥 공통 호가가격단위.
int tickSize(int price) {
  if (price < 2000) return 1;
  if (price < 5000) return 5;
  if (price < 20000) return 10;
  if (price < 50000) return 50;
  if (price < 200000) return 100;
  if (price < 500000) return 500;
  return 1000;
}

/// price 이하에서 가장 가까운 유효 호가.
int floorToTick(int price) => price - price % tickSize(price);

/// price 이상에서 가장 가까운 유효 호가.
int ceilToTick(int price) {
  final floored = floorToTick(price);
  return floored == price ? price : nextTick(floored);
}

/// 한 호가 위.
int nextTick(int price) => price + tickSize(price);

/// 한 호가 아래.
int prevTick(int price) => floorToTick(price - 1);

/// price에서 n호가 떨어진 가격 (n이 음수면 아래로).
int shiftTicks(int price, int n) {
  var p = price;
  for (var i = 0; i < n.abs(); i++) {
    p = n > 0 ? nextTick(p) : prevTick(p);
  }
  return p;
}

/// from에서 to까지 몇 호가인지 (to가 아래면 음수).
int ticksBetween(int from, int to) {
  var count = 0;
  var p = from;
  while (p < to) {
    p = nextTick(p);
    count++;
  }
  while (p > to) {
    p = prevTick(p);
    count--;
  }
  return count;
}

/// 상한가: 기준가 +30% 이내의 최고 호가.
int upperLimitPrice(int base) => floorToTick(base + base * 3 ~/ 10);

/// 하한가: 기준가 -30% 이내의 최저 호가.
int lowerLimitPrice(int base) => ceilToTick(base - base * 3 ~/ 10);

/// 1,234,567 형태의 천 단위 구분 문자열.
String formatNumber(num value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}
