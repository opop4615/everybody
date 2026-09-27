import 'dart:math';

import 'package:everyvaluation/game/candle.dart';
import 'package:everyvaluation/game/event.dart';
import 'package:everyvaluation/game/faction.dart';
import 'package:everyvaluation/game/krx.dart';
import 'package:everyvaluation/game/orderbook.dart';
import 'package:everyvaluation/game/pattern.dart';
import 'package:everyvaluation/game/skill.dart';

/// 전장이 되는 가상 종목.
class Company {
  const Company(this.name, this.sector, this.basePrice);

  final String name;
  final String sector;

  /// 전일 종가 = 오늘의 기준가.
  final int basePrice;

  static const List<Company> roster = [
    Company('모두전자', '전자부품', 12000),
    Company('한빛바이오', '바이오', 3150),
    Company('새벽엔터', '엔터테인먼트', 8600),
    Company('파랑에너지', '2차전지', 96000),
    Company('누리로보틱스', '로봇', 23400),
  ];
}

/// 플레이어 계좌. 포지션은 음수(공매도)도 가능하다.
class PlayerAccount {
  PlayerAccount(this.cash);

  int cash;
  int position = 0;
  double averagePrice = 0;
  int realized = 0;

  void apply(Side side, int price, int quantity) {
    final signed = side == Side.buy ? quantity : -quantity;
    cash -= signed * price;
    if (position == 0 || position.sign == signed.sign) {
      final size = position.abs();
      averagePrice =
          (averagePrice * size + price * quantity) / (size + quantity);
      position += signed;
      return;
    }
    final closing = min(quantity, position.abs());
    realized += ((price - averagePrice) * closing * position.sign).round();
    position += signed.sign * closing;
    final rest = quantity - closing;
    if (position == 0) averagePrice = 0;
    if (rest > 0) {
      position = signed.sign * rest;
      averagePrice = price.toDouble();
    }
  }

  int equity(int price) => cash + position * price;
  int unrealized(int price) => ((price - averagePrice) * position).round();
}

enum FeedKind { news, skill, warning, system }

class FeedItem {
  const FeedItem({
    required this.time,
    required this.kind,
    required this.title,
    this.detail = '',
    this.label = '',
    this.tone,
  });

  final String time;
  final FeedKind kind;
  final String title;
  final String detail;

  /// [공시] [속보] 같은 머리표.
  final String label;

  /// 어느 진영에 유리한 소식인지 (중립이면 null).
  final Faction? tone;
}

/// 플레이어 손에 들린 스킬 카드. 제때 쓰지 않으면 사라진다.
class SkillCard {
  const SkillCard(this.skill, this.expiresAt);

  final Skill skill;
  final int expiresAt;
}

/// 적 진영이 준비 중인 스킬.
class IncomingSkill {
  const IncomingSkill(this.skill, this.firesAt);

  final Skill skill;
  final int firesAt;
}

/// 화면 연출용: 스킬이 호가창을 휩쓴 기록.
class SkillBlast {
  const SkillBlast(this.skill, this.from, this.to, this.byPlayer);

  final Skill skill;
  final int from;
  final int to;
  final bool byPlayer;
}

class ActionResult {
  const ActionResult(this.ok, this.message);

  final bool ok;
  final String message;
}

class BattleResult {
  const BattleResult({
    required this.winner,
    required this.reason,
    required this.playerFaction,
    required this.basePrice,
    required this.closePrice,
    required this.startingCash,
    required this.pnl,
    required this.attackValue,
    required this.defenseValue,
    required this.skillsUsed,
    required this.skillTicks,
  });

  /// 이긴 진영 (보합이면 null).
  final Faction? winner;
  final String reason;
  final Faction playerFaction;
  final int basePrice;
  final int closePrice;
  final int startingCash;
  final int pnl;
  final int attackValue;
  final int defenseValue;
  final int skillsUsed;
  final int skillTicks;

  bool get victory => winner == playerFaction;
  double get returnRate => pnl / startingCash;
  double get priceChange => (closePrice - basePrice) / basePrice;

  String get grade {
    if (victory && returnRate >= 0.05) return 'S';
    if (victory && returnRate >= 0) return 'A';
    if (victory || returnRate > 0) return 'B';
    return 'C';
  }
}

class _Trader {
  const _Trader(this.name, this.weight, this.size);

  final String name;
  final int weight;

  /// 한 번에 내는 물량 (표준 잔량 칸 수).
  final double size;
}

class _Pressure {
  _Pressure(this.levels, this.ticksLeft);

  final double levels;
  int ticksLeft;
}

class _ActiveSkill {
  _ActiveSkill(this.skill, this.wavesLeft, this.byPlayer);

  final Skill skill;
  int wavesLeft;
  final bool byPlayer;
}

class _Scheduled {
  const _Scheduled(this.tick, this.event);

  final int tick;
  final MarketEvent event;
}

/// 호가전쟁 한 판 (09:00~15:30 하루 장). step() 한 번이 1분이다.
class BattleEngine {
  BattleEngine({
    required this.company,
    required this.faction,
    int? seed,
    this.startingCash = 100000000,
    this.newsRate = 1 / 32,
  })  : _rng = Random(seed),
        basePrice = company.basePrice,
        upperLimit = upperLimitPrice(company.basePrice),
        lowerLimit = lowerLimitPrice(company.basePrice),
        depthUnit = max(1, (depthValue / company.basePrice).round()),
        lastPrice = company.basePrice,
        account = PlayerAccount(startingCash) {
    _viAnchor = basePrice;
    _current = Candle(0, basePrice);
    _provideLiquidity(refill: 1);
    _log(
      FeedKind.system,
      '장 시작 — ${faction.label} 합류',
      '기준가 ${formatNumber(basePrice)}원 · 상한가 ${formatNumber(upperLimit)} · '
          '하한가 ${formatNumber(lowerLimit)}',
    );
  }

  static const int ticksPerDay = 390;
  static const int ticksPerCandle = 5;

  /// 호가 한 칸에 평소 쌓이는 금액.
  static const int depthValue = 15000000;
  static const int handLimit = 3;
  static const int cardLifetime = 30;
  static const int enemyWindup = 3;
  static const int viDuration = 2;
  static const int limitHoldToWin = 10;
  static const int patternCooldown = 6;

  static const List<_Trader> _traders = [
    _Trader('개미', 55, 0.4),
    _Trader('기관', 20, 1.2),
    _Trader('외국인', 20, 1.5),
    _Trader('세력', 5, 4.0),
  ];

  final Company company;
  final Faction faction;
  final int startingCash;
  final double newsRate;
  final Random _rng;
  final OrderBook book = OrderBook();
  final PlayerAccount account;
  final int basePrice;
  final int upperLimit;
  final int lowerLimit;

  /// 표준 호가 잔량 (주). 스킬·이벤트 물량의 단위.
  final int depthUnit;

  int tick = 0;
  int lastPrice;

  /// 시장 심리: -1(공포, 매도세) ~ +1(탐욕, 매수세).
  double sentiment = 0;
  double _mood = 0;
  double _volatility = 1;
  int _volatilityTicks = 0;

  final List<Candle> candles = [];
  late Candle _current;
  final List<FeedItem> feed = [];
  final List<SkillCard> hand = [];
  final List<IncomingSkill> incoming = [];
  final List<_ActiveSkill> _active = [];
  final List<_Pressure> _pressures = [];
  final List<_Scheduled> _scheduled = [];
  final List<SkillBlast> _blasts = [];
  final Map<ChartPattern, int> _lastFired = {};
  final List<int> _priceHistory = [];
  final List<int> _buyHistory = [];
  final List<int> _sellHistory = [];
  int _tickBuy = 0;
  int _tickSell = 0;

  /// 남은 VI(변동성 완화장치) 시간. 0보다 크면 시장가·스킬이 봉인된다.
  int viRemaining = 0;
  late int _viAnchor;
  int _upperHold = 0;
  int _lowerHold = 0;

  BattleResult? result;

  // 플레이어 전공
  int attackValue = 0;
  int defenseValue = 0;
  int skillsUsed = 0;
  int skillTicks = 0;

  bool get isOver => result != null;
  bool get inVi => viRemaining > 0;
  Candle get currentCandle => _current;
  double get changeRate => (lastPrice - basePrice) / basePrice;

  String get clock {
    final minutes = 9 * 60 + tick;
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 최근 20분 체결량 중 매수 체결 비중 (0~1). 줄다리기 게이지.
  double get buyShare {
    final buy = _buyHistory.fold<int>(_tickBuy, (a, b) => a + b);
    final sell = _sellHistory.fold<int>(_tickSell, (a, b) => a + b);
    return buy + sell == 0 ? 0.5 : buy / (buy + sell);
  }

  /// 체결강도 = 매수 체결량 / 매도 체결량 × 100.
  double get tradeStrength {
    final share = buyShare;
    return share >= 1 ? 999 : share / (1 - share) * 100;
  }

  int get equity => account.equity(lastPrice);
  int get pnl => equity - startingCash;

  List<BookLevel> asks(int count) => book.levels(Side.sell, count);
  List<BookLevel> bids(int count) => book.levels(Side.buy, count);

  /// 스킬 연출을 꺼내 간다 (화면이 한 번씩 소비).
  List<SkillBlast> takeBlasts() {
    final taken = List<SkillBlast>.of(_blasts);
    _blasts.clear();
    return taken;
  }

  // ── 시간 진행 ────────────────────────────────────────────────────

  /// 1분 진행.
  void step() {
    if (isOver) return;
    tick++;
    _runSchedule();
    if (tick == 1 || _rng.nextDouble() < newsRate) _fireEvent(_drawEvent());
    _mood = (_mood * 0.97 + (_rng.nextDouble() - 0.5) * 0.08).clamp(-0.4, 0.4);
    if (inVi) {
      _provideLiquidity();
      viRemaining--;
      if (!inVi) {
        _log(FeedKind.system, 'VI 해제 — 접속매매 재개', '시장가·스킬 봉인이 풀렸다');
      }
    } else {
      _runPressures();
      _runActiveSkills();
      _fireIncoming();
      _provideLiquidity();
      _aggress();
    }
    sentiment *= 0.97;
    if (_volatilityTicks > 0 && --_volatilityTicks == 0) _volatility = 1;
    _expireCards();
    _recordTick();
    if (tick % ticksPerCandle == 0) _closeCandle();
    _checkLimits();
    if (!isOver && tick >= ticksPerDay) _closeMarket();
  }

  void _recordTick() {
    _priceHistory.add(lastPrice);
    _buyHistory.add(_tickBuy);
    _sellHistory.add(_tickSell);
    if (_buyHistory.length > 20) {
      _buyHistory.removeAt(0);
      _sellHistory.removeAt(0);
    }
    _tickBuy = 0;
    _tickSell = 0;
  }

  /// 매수(+) / 매도(-) 쏠림. 심리 + 추세 추종 + 분위기 - 가치투자자의 되돌림.
  double _bias() {
    var momentum = 0.0;
    if (_priceHistory.length >= 10) {
      final past = _priceHistory[_priceHistory.length - 10];
      momentum = (ticksBetween(past, lastPrice) / 30).clamp(-1.0, 1.0);
    }
    final reversion = changeRate * 4;
    return (sentiment + 0.2 * momentum + _mood - reversion).clamp(-0.9, 0.9);
  }

  // ── NPC: 유동성 공급(LP)과 시장가 공격 ────────────────────────────

  /// 현재가 위아래 10호가에 LP 잔량을 채운다. 쏠림이 있으면 불리한 쪽 호가가 얇아진다.
  void _provideLiquidity({double refill = 0}) {
    final bias = _bias();
    _refillSide(Side.sell, 1 - 0.3 * bias, refill);
    _refillSide(Side.buy, 1 + 0.3 * bias, refill);
    final high = shiftTicks(lastPrice, 20);
    final low = shiftTicks(lastPrice, -20);
    book.cancelWhere((o) => o.tag == 'LP' && (o.price > high || o.price < low));
  }

  void _refillSide(Side side, double factor, double refill) {
    final opposite = book.best(side.opposite);
    var price = lastPrice;
    for (var level = 0; level < 10; level++) {
      price = side == Side.sell ? nextTick(price) : prevTick(price);
      if (price > upperLimit || price < lowerLimit) break;
      if (opposite != null &&
          (side == Side.sell ? price <= opposite : price >= opposite)) {
        continue;
      }
      final target = (depthUnit * factor * (0.6 + 0.1 * level)).round();
      final have = book.quantityAt(side, price);
      if (have >= target) continue;
      final share = refill > 0 ? refill : 0.25 + _rng.nextDouble() * 0.35;
      final add = ((target - have) * share).round();
      if (add > 0) book.placeLimit(side, price, add, tag: 'LP');
    }
  }

  void _aggress() {
    final bias = _bias();
    final count = 1 + _rng.nextInt(3);
    for (var i = 0; i < count; i++) {
      final trader = _pickTrader();
      final side = _rng.nextDouble() < 0.5 + 0.35 * bias ? Side.buy : Side.sell;
      final size = depthUnit * trader.size * (0.3 + _rng.nextDouble());
      final quantity = (size * _volatility).round();
      if (quantity >= depthUnit * 4.5) {
        _log(
          FeedKind.system,
          '${trader.name} 출현 — ${formatNumber(quantity)}주 시장가 ${_verb(side)}',
          '',
          tone: side == Side.buy ? Faction.bull : Faction.bear,
        );
      }
      _npcMarket(side, quantity);
    }
  }

  _Trader _pickTrader() {
    var roll = _rng.nextInt(_traders.fold<int>(0, (sum, t) => sum + t.weight));
    for (final trader in _traders) {
      roll -= trader.weight;
      if (roll < 0) return trader;
    }
    return _traders.first;
  }

  void _npcMarket(Side side, int quantity) {
    if (quantity <= 0 || inVi || isOver) return;
    final limit = _limitFor(side);
    final fills = book.placeMarket(side, quantity, limit: limit);
    _apply(fills);
    // 상·하한가에서 못 받은 물량은 그 가격에 잔량으로 쌓인다.
    final left = quantity - fills.fold<int>(0, (sum, f) => sum + f.quantity);
    if (left > 0 && lastPrice == limit) {
      book.placeLimit(side, limit, left, tag: '잔량');
    }
  }

  int _limitFor(Side side) => side == Side.buy ? upperLimit : lowerLimit;

  // ── 체결 반영 ────────────────────────────────────────────────────

  void _apply(List<Fill> fills) {
    for (final f in fills) {
      lastPrice = f.price;
      _current.update(f.price, f.quantity);
      if (f.aggressor == Side.buy) {
        _tickBuy += f.quantity;
      } else {
        _tickSell += f.quantity;
      }
      if (f.takerIsPlayer) _playerFill(f.aggressor, f.price, f.quantity, true);
      if (f.makerIsPlayer) {
        _playerFill(f.aggressor.opposite, f.price, f.quantity, false);
      }
    }
    if (fills.isNotEmpty) _checkVi();
  }

  void _playerFill(Side side, int price, int quantity, bool aggressive) {
    account.apply(side, price, quantity);
    if (side != faction.attackSide) return;
    if (aggressive) {
      attackValue += price * quantity;
    } else {
      defenseValue += price * quantity;
    }
  }

  /// 정적 VI: 직전 단일가 대비 10% 이상 움직이면 2분간 단일가 매매.
  void _checkVi() {
    if (inVi || isOver) return;
    if ((lastPrice - _viAnchor).abs() * 10 < _viAnchor) return;
    final up = lastPrice > _viAnchor;
    viRemaining = viDuration;
    _viAnchor = lastPrice;
    _log(
      FeedKind.system,
      '정적 VI 발동 ${up ? '▲' : '▼'} ${formatNumber(lastPrice)}원',
      '2분간 단일가 매매 — 시장가·스킬 봉인, 벽 쌓기만 가능',
      tone: up ? Faction.bull : Faction.bear,
    );
  }

  void _checkLimits() {
    _upperHold = lastPrice >= upperLimit ? _upperHold + 1 : 0;
    _lowerHold = lastPrice <= lowerLimit ? _lowerHold + 1 : 0;
    if (_upperHold == 1) {
      _log(FeedKind.system, '상한가 도달!', '$limitHoldToWin분 동안 지키면 매수군 완승',
          tone: Faction.bull);
    }
    if (_lowerHold == 1) {
      _log(FeedKind.system, '하한가 도달!', '$limitHoldToWin분 동안 지키면 매도군 완승',
          tone: Faction.bear);
    }
    if (_upperHold >= limitHoldToWin) _finish(Faction.bull, '상한가 안착');
    if (_lowerHold >= limitHoldToWin) _finish(Faction.bear, '하한가 안착');
  }

  // ── 뉴스·공시 ────────────────────────────────────────────────────

  MarketEvent _drawEvent() {
    const deck = MarketEvent.deck;
    var roll = _rng.nextInt(deck.fold<int>(0, (sum, e) => sum + e.weight));
    for (final event in deck) {
      roll -= event.weight;
      if (roll < 0) return event;
    }
    return deck.first;
  }

  void _runSchedule() {
    final due = _scheduled.where((s) => s.tick <= tick).toList();
    for (final s in due) {
      _scheduled.remove(s);
      _fireEvent(s.event);
    }
  }

  /// 이벤트를 즉시 터뜨린다 (테스트·연출용으로 공개).
  void fireEvent(MarketEvent event) => _fireEvent(event);

  void _fireEvent(MarketEvent e) {
    final tone = e.sentiment > 0
        ? Faction.bull
        : e.sentiment < 0
            ? Faction.bear
            : null;
    _log(
      FeedKind.news,
      e.titleFor(company.name),
      e.detailFor(company.name),
      label: e.category.label,
      tone: tone,
    );
    sentiment = (sentiment + e.sentiment).clamp(-1.0, 1.0);
    if (e.volatilityTicks > 0) {
      _volatility = e.volatility;
      _volatilityTicks = e.volatilityTicks;
    }
    if (e.wallSize > 0) _placeEventWall(e);
    if (e.shock != 0) {
      _npcMarket(e.shock > 0 ? Side.buy : Side.sell,
          (e.shock.abs() * depthUnit).round());
    }
    if (e.pressureTicks > 0) {
      _pressures.add(_Pressure(e.pressure, e.pressureTicks));
    }
    if (e.followUps.isNotEmpty) {
      final next = e.followUps[_rng.nextInt(e.followUps.length)];
      _scheduled.add(_Scheduled(tick + e.followUpDelay, next));
    }
  }

  void _placeEventWall(MarketEvent e) {
    final side = e.wallOffset < 0 ? Side.buy : Side.sell;
    final raw = (lastPrice * (1 + e.wallOffset)).round();
    final price = (side == Side.buy ? floorToTick(raw) : ceilToTick(raw))
        .clamp(lowerLimit, upperLimit);
    final opposite = book.best(side.opposite);
    if (opposite != null &&
        (side == Side.buy ? price >= opposite : price <= opposite)) {
      return;
    }
    book.placeLimit(side, price, (e.wallSize * depthUnit).round(),
        tag: e.wallTag);
  }

  void _runPressures() {
    for (final p in _pressures) {
      final size = p.levels.abs() * depthUnit * (0.5 + _rng.nextDouble());
      _npcMarket(p.levels > 0 ? Side.buy : Side.sell, size.round());
      p.ticksLeft--;
    }
    _pressures.removeWhere((p) => p.ticksLeft <= 0);
  }

  // ── 차트 패턴 → 스킬 ─────────────────────────────────────────────

  void _closeCandle() {
    candles.add(_current);
    _current = Candle(candles.length, lastPrice);
    for (final pattern in ChartPattern.detect(candles)) {
      final last = _lastFired[pattern];
      if (last != null && candles.length - last < patternCooldown) continue;
      _lastFired[pattern] = candles.length;
      _grant(Skill.of(pattern));
    }
  }

  void _grant(Skill skill) {
    if (skill.faction == faction) {
      if (hand.length >= handLimit) {
        final dropped = hand.removeAt(0);
        _log(FeedKind.system, '「${dropped.skill.name}」 카드가 밀려났다',
            '스킬 카드는 최대 $handLimit장');
      }
      hand.add(SkillCard(skill, tick + cardLifetime));
      _log(
        FeedKind.skill,
        '${skill.pattern.label} 완성! 스킬 「${skill.name}」 획득',
        '${skill.description} · $cardLifetime분 안에 사용',
        tone: faction,
      );
    } else {
      incoming.add(IncomingSkill(skill, tick + enemyWindup));
      _log(
        FeedKind.warning,
        '${skill.pattern.label} 완성 — 적 ${skill.faction.label}이 「${skill.name}」 준비 중',
        '$enemyWindup분 뒤 발동. 벽을 쌓아 막아라!',
        tone: skill.faction,
      );
    }
  }

  void _expireCards() {
    final expired = hand.where((c) => tick >= c.expiresAt).toList();
    for (final card in expired) {
      hand.remove(card);
      _log(FeedKind.system, '「${card.skill.name}」 기세 소멸', '때를 놓쳤다');
    }
  }

  void _fireIncoming() {
    final due = incoming.where((s) => tick >= s.firesAt).toList();
    for (final s in due) {
      if (inVi) break;
      incoming.remove(s);
      _launch(s.skill, byPlayer: false);
    }
  }

  void _runActiveSkills() {
    for (final active in List<_ActiveSkill>.of(_active)) {
      if (inVi) break;
      _wave(active);
    }
    _active.removeWhere((a) => a.wavesLeft <= 0);
  }

  void _launch(Skill skill, {required bool byPlayer}) {
    final side = skill.faction.attackSide;
    sentiment =
        (sentiment + skill.morale * skill.faction.direction).clamp(-1.0, 1.0);
    if (skill.wall > 0) {
      final price = book.best(side) ??
          (side == Side.buy ? prevTick(lastPrice) : nextTick(lastPrice));
      book.placeLimit(side, price, (skill.wall * depthUnit).round(),
          tag: skill.faction.label);
    }
    final active = _ActiveSkill(skill, skill.waves, byPlayer);
    _wave(active);
    if (active.wavesLeft > 0) _active.add(active);
  }

  /// 스킬 한 번: 진영 병력이 한 방향으로 시장가 물량을 쏟아붓는다.
  void _wave(_ActiveSkill active) {
    final skill = active.skill;
    final side = skill.faction.attackSide;
    final from = lastPrice;
    active.wavesLeft--;
    _apply(book.placeMarket(side, (skill.power * depthUnit).round(),
        limit: _limitFor(side)));
    final moved = ticksBetween(from, lastPrice) * skill.faction.direction;
    if (active.byPlayer) skillTicks += max(0, moved);
    _blasts.add(SkillBlast(skill, from, lastPrice, active.byPlayer));
    _log(
      FeedKind.skill,
      '${active.byPlayer ? '내 ' : ''}${skill.faction.label} 「${skill.name}」 발동!',
      '${formatNumber(from)} → ${formatNumber(lastPrice)} '
          '(${moved >= 0 ? '+' : ''}$moved호가)',
      tone: skill.faction,
    );
  }

  // ── 플레이어 행동 ────────────────────────────────────────────────

  String? _blocked({bool market = true}) {
    if (isOver) return '장이 끝났습니다';
    if (market && inVi) return 'VI 발동 중 — 시장가·스킬 봉인 (벽 쌓기만 가능)';
    return null;
  }

  /// price 기준으로 새로 낼 수 있는 최대 수량 (순자산 1배 한도, 미체결 주문 포함).
  int maxQuantity(Side side, int price) {
    final capital = equity;
    if (capital <= 0 || price <= 0) return 0;
    final limit = capital ~/ price;
    final open = book.playerOpenQuantity(side);
    final room = side == Side.buy
        ? limit - account.position - open
        : limit + account.position - open;
    return max(0, room);
  }

  /// 돌격: 진영 방향 시장가 주문 (주문 가능 수량의 fraction만큼).
  ActionResult attack(double fraction) {
    final blocked = _blocked();
    if (blocked != null) return ActionResult(false, blocked);
    final side = faction.attackSide;
    final reference = book.best(side.opposite) ?? lastPrice;
    final quantity = (maxQuantity(side, reference) * fraction).floor();
    if (quantity <= 0) return const ActionResult(false, '주문 가능 수량이 없습니다');
    final fills = book.placeMarket(side, quantity,
        limit: _limitFor(side), isPlayer: true);
    _apply(fills);
    final filled = fills.fold<int>(0, (sum, f) => sum + f.quantity);
    if (filled == 0) return const ActionResult(false, '받아줄 상대 호가가 없습니다');
    return ActionResult(true,
        '돌격! ${formatNumber(filled)}주 ${_verb(side)} · 현재가 ${formatNumber(lastPrice)}');
  }

  /// 벽 쌓기: 진영 방향 지정가 주문. price를 안 주면 아군 최우선 호가에 쌓는다.
  /// 상대 호가에 닿는 가격이면 그 가격까지 즉시 체결된다.
  ActionResult placeWall(double fraction, {int? price}) {
    final blocked = _blocked(market: false);
    if (blocked != null) return ActionResult(false, blocked);
    final side = faction.attackSide;
    final at = price ??
        book.best(side) ??
        (side == Side.buy ? prevTick(lastPrice) : nextTick(lastPrice));
    if (at > upperLimit || at < lowerLimit) {
      return const ActionResult(false, '가격제한폭 밖입니다');
    }
    final opposite = book.best(side.opposite);
    final crosses = opposite != null &&
        (side == Side.buy ? at >= opposite : at <= opposite);
    if (crosses && inVi) {
      return const ActionResult(false, 'VI 중에는 즉시 체결되는 주문을 낼 수 없습니다');
    }
    final quantity = (maxQuantity(side, at) * fraction).floor();
    if (quantity <= 0) return const ActionResult(false, '주문 가능 수량이 없습니다');
    final placed =
        book.placeLimit(side, at, quantity, isPlayer: true, tag: '나');
    _apply(placed.fills);
    final filled = placed.filledQuantity;
    final resting = quantity - filled;
    if (filled == 0) {
      return ActionResult(
          true, '${formatNumber(at)}원에 ${formatNumber(quantity)}주 벽 구축');
    }
    return ActionResult(
        true,
        '${formatNumber(filled)}주 즉시 ${_verb(side)}'
        '${resting > 0 ? ', ${formatNumber(resting)}주는 벽으로 대기' : ''}');
  }

  /// 내 미체결 주문 전부 취소.
  ActionResult cancelOrders() {
    final count = book.cancelWhere((o) => o.isPlayer);
    return ActionResult(
        count > 0, count > 0 ? '주문 $count건 취소' : '취소할 주문이 없습니다');
  }

  /// 보유 포지션을 시장가로 정리.
  ActionResult closePosition() {
    final blocked = _blocked();
    if (blocked != null) return ActionResult(false, blocked);
    final position = account.position;
    if (position == 0) return const ActionResult(false, '정리할 포지션이 없습니다');
    final side = position > 0 ? Side.sell : Side.buy;
    // 내 벽과 맞체결되지 않도록 반대편 내 주문은 먼저 거둔다.
    book.cancelWhere((o) => o.isPlayer && o.side == side.opposite);
    final fills = book.placeMarket(side, position.abs(),
        limit: _limitFor(side), isPlayer: true);
    _apply(fills);
    final filled = fills.fold<int>(0, (sum, f) => sum + f.quantity);
    return ActionResult(
        filled > 0, '포지션 정리: ${formatNumber(filled)}주 ${_verb(side)}');
  }

  /// 손에 든 스킬 카드 사용.
  ActionResult useSkill(int index) {
    final blocked = _blocked();
    if (blocked != null) return ActionResult(false, blocked);
    if (index < 0 || index >= hand.length) {
      return const ActionResult(false, '스킬 카드가 없습니다');
    }
    final card = hand.removeAt(index);
    skillsUsed++;
    _launch(card.skill, byPlayer: true);
    return ActionResult(true, '「${card.skill.name}」 발동!');
  }

  /// 테스트·튜토리얼용: 스킬 카드를 직접 쥐여준다.
  void grantSkill(Skill skill) => _grant(skill);

  String _verb(Side side) => side == Side.buy ? '매수' : '매도';

  // ── 종료 ────────────────────────────────────────────────────────

  void _closeMarket() {
    final winner = lastPrice > basePrice
        ? Faction.bull
        : lastPrice < basePrice
            ? Faction.bear
            : null;
    _finish(winner, '장 마감 · 종가 ${formatNumber(lastPrice)}원');
  }

  void _finish(Faction? winner, String reason) {
    if (isOver) return;
    book.cancelWhere((o) => o.isPlayer);
    result = BattleResult(
      winner: winner,
      reason: reason,
      playerFaction: faction,
      basePrice: basePrice,
      closePrice: lastPrice,
      startingCash: startingCash,
      pnl: pnl,
      attackValue: attackValue,
      defenseValue: defenseValue,
      skillsUsed: skillsUsed,
      skillTicks: skillTicks,
    );
    _log(
      FeedKind.system,
      winner == null ? '$reason — 무승부' : '$reason — ${winner.label} 승리',
      '',
      tone: winner,
    );
  }

  void _log(FeedKind kind, String title, String detail,
      {String label = '', Faction? tone}) {
    feed.insert(
      0,
      FeedItem(
        time: clock,
        kind: kind,
        title: title,
        detail: detail,
        label: label,
        tone: tone,
      ),
    );
    if (feed.length > 120) feed.removeLast();
  }
}
