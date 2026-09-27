import 'package:everyvaluation/game/orderbook.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OrderBook book;

  setUp(() {
    book = OrderBook()
      ..placeLimit(Side.sell, 10020, 300)
      ..placeLimit(Side.sell, 10010, 200)
      ..placeLimit(Side.buy, 10000, 500)
      ..placeLimit(Side.buy, 9990, 400);
  });

  test('최우선 호가와 호가 칸', () {
    expect(book.bestAsk, 10010);
    expect(book.bestBid, 10000);
    expect(book.levels(Side.sell, 5).map((l) => l.price), [10010, 10020]);
    expect(book.levels(Side.buy, 5).map((l) => l.price), [10000, 9990]);
    expect(book.totalQuantity(Side.buy, 10), 900);
  });

  test('시장가 매수는 낮은 매도 호가부터 쓸어 올라간다', () {
    final fills = book.placeMarket(Side.buy, 350);
    expect(fills.map((f) => f.price), [10010, 10020]);
    expect(fills.map((f) => f.quantity), [200, 150]);
    expect(book.bestAsk, 10020);
    expect(book.quantityAt(Side.sell, 10020), 150);
  });

  test('limit을 넘는 호가는 먹지 않는다', () {
    final fills = book.placeMarket(Side.buy, 1000, limit: 10010);
    expect(fills.fold<int>(0, (s, f) => s + f.quantity), 200);
    expect(book.bestAsk, 10020);
  });

  test('같은 가격에서는 먼저 낸 주문이 먼저 체결된다', () {
    book.placeLimit(Side.buy, 10000, 100, isPlayer: true);
    final fills = book.placeMarket(Side.sell, 550);
    expect(fills.first.makerIsPlayer, isFalse);
    expect(fills.first.quantity, 500);
    expect(fills[1].makerIsPlayer, isTrue);
    expect(fills[1].quantity, 50);
    expect(book.playerQuantityAt(Side.buy, 10000), 50);
  });

  test('교차하는 지정가는 즉시 체결되고 남은 수량만 쌓인다', () {
    final result = book.placeLimit(Side.buy, 10010, 500, isPlayer: true);
    expect(result.filledQuantity, 200);
    expect(result.resting!.remaining, 300);
    expect(book.bestBid, 10010);
    expect(book.bestAsk, 10020);
    expect(book.playerOpenQuantity(Side.buy), 300);
  });

  test('조건부 취소', () {
    book.placeLimit(Side.buy, 9980, 100, isPlayer: true);
    book.placeLimit(Side.sell, 10030, 100, isPlayer: true);
    expect(book.cancelWhere((o) => o.isPlayer), 2);
    expect(book.playerOrders, isEmpty);
    expect(book.quantityAt(Side.buy, 9980), 0);
    expect(book.levels(Side.sell, 10).map((l) => l.price), [10010, 10020]);
  });
}
