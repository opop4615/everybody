import 'package:everyvaluation/game/orderbook.dart';

/// 호가창 전쟁의 두 진영.
enum Faction {
  bull('매수군', '매수세'),
  bear('매도군', '매도세');

  const Faction(this.label, this.force);

  final String label;

  /// 시장 용어로 부르는 이름.
  final String force;

  Faction get enemy => this == Faction.bull ? Faction.bear : Faction.bull;

  /// 이 진영이 공격(시장가)할 때 내는 주문 방향.
  Side get attackSide => this == Faction.bull ? Side.buy : Side.sell;

  /// 가격이 이 진영에 유리하게 움직이는 방향 (+1 위, -1 아래).
  int get direction => this == Faction.bull ? 1 : -1;
}
