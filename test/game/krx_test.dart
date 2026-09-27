import 'package:everyvaluation/game/krx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('호가가격단위는 가격 구간마다 다르다', () {
    expect(tickSize(1999), 1);
    expect(tickSize(2000), 5);
    expect(tickSize(12000), 10);
    expect(tickSize(23400), 50);
    expect(tickSize(96000), 100);
    expect(tickSize(250000), 500);
    expect(tickSize(700000), 1000);
  });

  test('구간 경계에서 한 호가 위아래', () {
    expect(nextTick(19990), 20000);
    expect(nextTick(20000), 20050);
    expect(prevTick(20000), 19990);
    expect(prevTick(2000), 1999);
    expect(shiftTicks(19980, 3), 20050);
    expect(ticksBetween(19980, 20050), 3);
    expect(ticksBetween(20050, 19980), -3);
  });

  test('유효 호가로 맞추기', () {
    expect(floorToTick(12345), 12340);
    expect(ceilToTick(12345), 12350);
    expect(ceilToTick(19995), 20000);
    expect(ceilToTick(12340), 12340);
  });

  test('상한가·하한가는 기준가 ±30% 이내 호가', () {
    expect(upperLimitPrice(12000), 15600);
    expect(lowerLimitPrice(12000), 8400);
    expect(upperLimitPrice(3150), 4095);
    expect(lowerLimitPrice(3150), 2205);
    // 30% 위가 호가단위에 안 맞으면 아래로 자른다.
    expect(upperLimitPrice(23400), 30400);
    expect(lowerLimitPrice(23400), 16380);
  });

  test('천 단위 구분', () {
    expect(formatNumber(0), '0');
    expect(formatNumber(999), '999');
    expect(formatNumber(1234567), '1,234,567');
    expect(formatNumber(-45000), '-45,000');
  });
}
