import 'dart:collection';
import 'dart:math';

/// 주문 방향.
enum Side {
  buy,
  sell;

  Side get opposite => this == Side.buy ? Side.sell : Side.buy;
}

/// 호가창에 걸려 있는 지정가 주문.
class Order {
  Order({
    required this.id,
    required this.side,
    required this.price,
    required this.remaining,
    required this.isPlayer,
    required this.tag,
  });

  final int id;
  final Side side;
  final int price;
  final bool isPlayer;

  /// 주문 주체 (개미, 외국인, 기관, LP, 매수군 ...)
  final String tag;
  int remaining;
}

/// 체결 한 건. aggressor는 호가를 먹은(시장가·교차 지정가) 쪽.
class Fill {
  const Fill({
    required this.price,
    required this.quantity,
    required this.aggressor,
    required this.takerIsPlayer,
    required this.makerIsPlayer,
  });

  final int price;
  final int quantity;
  final Side aggressor;
  final bool takerIsPlayer;
  final bool makerIsPlayer;
}

/// 지정가 주문 결과: 즉시 체결분과 호가창에 남은 주문.
class PlaceResult {
  const PlaceResult(this.fills, this.resting);

  final List<Fill> fills;
  final Order? resting;

  int get filledQuantity => fills.fold<int>(0, (sum, f) => sum + f.quantity);
}

/// 화면에 그릴 호가 한 칸.
class BookLevel {
  const BookLevel(this.price, this.quantity, this.playerQuantity);

  final int price;
  final int quantity;
  final int playerQuantity;
}

/// 가격-시간 우선 원칙으로 체결하는 호가창.
class OrderBook {
  final SplayTreeMap<int, Queue<Order>> _bids =
      SplayTreeMap<int, Queue<Order>>((a, b) => b.compareTo(a));
  final SplayTreeMap<int, Queue<Order>> _asks =
      SplayTreeMap<int, Queue<Order>>();
  final Map<int, Order> _orders = {};
  int _nextId = 1;

  SplayTreeMap<int, Queue<Order>> _levels(Side side) =>
      side == Side.buy ? _bids : _asks;

  int? get bestBid => _bids.isEmpty ? null : _bids.firstKey();
  int? get bestAsk => _asks.isEmpty ? null : _asks.firstKey();

  /// side 방향 최우선 호가 (매수면 최고 매수호가, 매도면 최저 매도호가).
  int? best(Side side) => side == Side.buy ? bestBid : bestAsk;

  /// 지정가 주문. 반대 호가와 교차하면 먼저 체결하고 남은 수량만 호가창에 쌓는다.
  PlaceResult placeLimit(
    Side side,
    int price,
    int quantity, {
    bool isPlayer = false,
    String tag = '',
  }) {
    final fills = _match(side, quantity, price, isPlayer);
    final left = quantity - fills.fold<int>(0, (sum, f) => sum + f.quantity);
    Order? resting;
    if (left > 0) {
      resting = Order(
        id: _nextId++,
        side: side,
        price: price,
        remaining: left,
        isPlayer: isPlayer,
        tag: tag,
      );
      _levels(side).putIfAbsent(price, () => Queue<Order>()).add(resting);
      _orders[resting.id] = resting;
    }
    return PlaceResult(fills, resting);
  }

  /// 시장가 주문. limit을 주면 그 가격을 넘어서는 호가는 먹지 않는다.
  List<Fill> placeMarket(
    Side side,
    int quantity, {
    int? limit,
    bool isPlayer = false,
  }) =>
      _match(side, quantity, limit, isPlayer);

  List<Fill> _match(Side side, int quantity, int? limit, bool isPlayer) {
    final opposite = _levels(side.opposite);
    final fills = <Fill>[];
    var left = quantity;
    while (left > 0 && opposite.isNotEmpty) {
      final price = opposite.firstKey()!;
      if (limit != null && (side == Side.buy ? price > limit : price < limit)) {
        break;
      }
      final queue = opposite[price]!;
      while (left > 0 && queue.isNotEmpty) {
        final maker = queue.first;
        final qty = min(left, maker.remaining);
        maker.remaining -= qty;
        left -= qty;
        fills.add(Fill(
          price: price,
          quantity: qty,
          aggressor: side,
          takerIsPlayer: isPlayer,
          makerIsPlayer: maker.isPlayer,
        ));
        if (maker.remaining == 0) {
          queue.removeFirst();
          _orders.remove(maker.id);
        }
      }
      if (queue.isEmpty) opposite.remove(price);
    }
    return fills;
  }

  /// 조건에 맞는 주문을 모두 취소하고 취소한 건수를 돌려준다.
  int cancelWhere(bool Function(Order order) test) {
    final targets = _orders.values.where(test).toList();
    for (final order in targets) {
      final levels = _levels(order.side);
      final queue = levels[order.price];
      if (queue == null) continue;
      queue.remove(order);
      if (queue.isEmpty) levels.remove(order.price);
      _orders.remove(order.id);
    }
    return targets.length;
  }

  int quantityAt(Side side, int price) =>
      _levels(side)[price]?.fold<int>(0, (sum, o) => sum + o.remaining) ?? 0;

  int playerQuantityAt(Side side, int price) =>
      _levels(side)[price]
          ?.where((o) => o.isPlayer)
          .fold<int>(0, (sum, o) => sum + o.remaining) ??
      0;

  /// 최우선 호가부터 count개 칸.
  List<BookLevel> levels(Side side, int count) => _levels(side)
      .keys
      .take(count)
      .map((price) => BookLevel(
            price,
            quantityAt(side, price),
            playerQuantityAt(side, price),
          ))
      .toList();

  /// 최우선 호가부터 count개 칸의 잔량 합.
  int totalQuantity(Side side, int count) =>
      levels(side, count).fold<int>(0, (sum, l) => sum + l.quantity);

  Iterable<Order> get playerOrders => _orders.values.where((o) => o.isPlayer);

  int playerOpenQuantity(Side side) => playerOrders
      .where((o) => o.side == side)
      .fold<int>(0, (sum, o) => sum + o.remaining);
}
