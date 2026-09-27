import 'package:everyvaluation/game/engine.dart';
import 'package:everyvaluation/game/event.dart';
import 'package:everyvaluation/game/faction.dart';
import 'package:everyvaluation/game/krx.dart';
import 'package:everyvaluation/game/orderbook.dart';
import 'package:everyvaluation/game/pattern.dart';
import 'package:everyvaluation/game/skill.dart';
import 'package:flutter_test/flutter_test.dart';

const modu = Company('모두전자', '전자부품', 12000);

BattleEngine battle({Faction faction = Faction.bull, int seed = 1}) =>
    BattleEngine(company: modu, faction: faction, seed: seed);

void main() {
  test('하루 장이 끝까지 돌고 호가·가격 규칙이 깨지지 않는다', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final engine = battle(seed: seed);
      while (!engine.isOver) {
        engine.step();
        final bid = engine.book.bestBid;
        final ask = engine.book.bestAsk;
        if (bid != null && ask != null) expect(bid, lessThan(ask));
        expect(engine.lastPrice,
            inInclusiveRange(engine.lowerLimit, engine.upperLimit));
        expect(engine.lastPrice, floorToTick(engine.lastPrice));
      }
      final result = engine.result!;
      if (engine.tick == BattleEngine.ticksPerDay) {
        expect(engine.clock, '15:30');
        expect(engine.candles.length, 78);
        expect(
            result.winner,
            result.closePrice > engine.basePrice
                ? Faction.bull
                : result.closePrice < engine.basePrice
                    ? Faction.bear
                    : null);
      }
      expect(engine.book.playerOrders, isEmpty);
    }
  });

  test('같은 시드면 같은 전투', () {
    final a = battle(seed: 42);
    final b = battle(seed: 42);
    while (!a.isOver) {
      a.step();
      b.step();
    }
    expect(b.lastPrice, a.lastPrice);
    expect(b.feed.map((f) => f.title), a.feed.map((f) => f.title));
  });

  test('매수군 돌격은 시장가 매수, 순자산 한도를 넘지 않는다', () {
    final engine = battle();
    engine.step();
    final result = engine.attack(1);
    expect(result.ok, isTrue);
    expect(engine.account.position, greaterThan(0));
    expect(engine.attackValue, greaterThan(0));
    expect(engine.account.position * engine.lastPrice,
        lessThanOrEqualTo(engine.equity * 1.1));
    expect(engine.maxQuantity(Side.buy, engine.lastPrice), lessThan(100));
  });

  test('포지션 정리는 내 벽과 맞체결하지 않는다', () {
    final engine = battle();
    engine.step();
    engine.attack(0.5);
    expect(engine.placeWall(0.5).ok, isTrue);
    expect(engine.closePosition().ok, isTrue);
    expect(engine.account.position, 0);
    expect(engine.book.playerOpenQuantity(Side.buy), 0);
  });

  test('매도군 돌격은 공매도', () {
    final engine = battle(faction: Faction.bear);
    engine.step();
    expect(engine.attack(0.5).ok, isTrue);
    expect(engine.account.position, lessThan(0));
    expect(engine.closePosition().ok, isTrue);
    expect(engine.account.position, 0);
  });

  test('벽 쌓기는 아군 최우선 호가에 내 잔량으로 보인다', () {
    final engine = battle();
    engine.step();
    final bestBid = engine.book.bestBid!;
    expect(engine.placeWall(0.3).ok, isTrue);
    final level = engine.bids(10).firstWhere((l) => l.price == bestBid);
    expect(level.playerQuantity, greaterThan(0));
    expect(engine.cancelOrders().ok, isTrue);
    expect(engine.book.playerOpenQuantity(Side.buy), 0);
  });

  test('상대 호가를 눌러 낸 지정가는 그 가격까지 즉시 체결', () {
    final engine = battle();
    engine.step();
    final target = shiftTicks(engine.book.bestAsk!, 2);
    final result = engine.placeWall(0.5, price: target);
    expect(result.ok, isTrue);
    expect(engine.account.position, greaterThan(0));
    expect(engine.lastPrice, lessThanOrEqualTo(target));
  });

  test('아군 패턴은 스킬 카드가 되고, 쓰면 한 방향으로 호가를 쓸어버린다', () {
    final engine = battle();
    engine.step();
    engine.grantSkill(Skill.of(ChartPattern.goldenCross));
    expect(engine.hand.single.skill.name, '골든 브레이크');
    final before = engine.lastPrice;
    expect(engine.useSkill(0).ok, isTrue);
    expect(engine.hand, isEmpty);
    expect(ticksBetween(before, engine.lastPrice), greaterThanOrEqualTo(5));
    final blasts = engine.takeBlasts();
    expect(blasts.single.byPlayer, isTrue);
    expect(engine.skillsUsed, 1);
    expect(engine.skillTicks, greaterThan(0));
  });

  test('쓰지 않은 스킬 카드는 30분 뒤 사라진다', () {
    final engine = battle();
    engine.grantSkill(Skill.of(ChartPattern.hammer));
    final card = engine.hand.single;
    for (var i = 0; i < BattleEngine.cardLifetime - 1; i++) {
      engine.step();
    }
    expect(engine.hand, contains(card));
    engine.step();
    expect(engine.hand, isNot(contains(card)));
  });

  test('적 패턴은 경고 후 3분 뒤 자동 발동', () {
    final engine = battle();
    engine.step();
    engine.grantSkill(Skill.of(ChartPattern.deadCross));
    expect(engine.incoming.single.skill.name, '데드 슬래시');
    expect(engine.feed.first.kind, FeedKind.warning);
    engine.takeBlasts();
    var fired = false;
    for (var i = 0; i < BattleEngine.enemyWindup + 2 && !fired; i++) {
      engine.step();
      fired = engine
          .takeBlasts()
          .any((b) => b.skill.pattern == ChartPattern.deadCross && !b.byPlayer);
    }
    expect(fired, isTrue);
    expect(engine.incoming, isEmpty);
  });

  test('10% 급등하면 VI가 걸려 시장가·스킬이 봉인된다', () {
    final engine = BattleEngine(
        company: const Company('한빛바이오', '바이오', 3150),
        faction: Faction.bull,
        seed: 3);
    for (var i = 0; i < 200 && !engine.inVi; i++) {
      engine.step();
      if (engine.inVi) break;
      engine.grantSkill(Skill.of(ChartPattern.inverseHeadAndShoulders));
      engine.useSkill(engine.hand.length - 1);
    }
    expect(engine.inVi, isTrue);
    expect(engine.feed.any((f) => f.title.startsWith('정적 VI')), isTrue);
    final attack = engine.attack(0.5);
    expect(attack.ok, isFalse);
    expect(attack.message, contains('VI'));
    engine.grantSkill(Skill.of(ChartPattern.goldenCross));
    expect(engine.useSkill(0).ok, isFalse);
  });

  test('유상증자 공시: 심리 급랭과 위쪽 신주 물량벽', () {
    final engine = battle();
    final rightsOffering =
        MarketEvent.deck.firstWhere((e) => e.title.contains('주주배정 유상증자'));
    final wallPrice = ceilToTick((engine.lastPrice * 1.02).round());
    engine.fireEvent(rightsOffering);
    expect(engine.sentiment, lessThan(0));
    expect(engine.lastPrice, lessThan(engine.basePrice));
    expect(engine.book.quantityAt(Side.sell, wallPrice),
        greaterThanOrEqualTo(6 * engine.depthUnit));
    expect(engine.feed.first.title, contains('모두전자'));
    expect(engine.feed.first.label, '공시');
  });

  test('합병비율 논란 공시는 매수청구가에 매수벽을 세운다', () {
    final engine = battle();
    final merger = MarketEvent.deck.firstWhere((e) => e.wallTag == '매수청구');
    final wallPrice = floorToTick((engine.lastPrice * 0.94).round());
    engine.fireEvent(merger);
    expect(engine.book.quantityAt(Side.buy, wallPrice),
        greaterThanOrEqualTo(12 * engine.depthUnit));
  });

  test('루머는 조회공시 답변으로 이어진다', () {
    final engine = battle(seed: 9);
    final rumor =
        MarketEvent.deck.firstWhere((e) => e.category == NewsCategory.rumor);
    engine.fireEvent(rumor);
    final answers = rumor.followUps.map((e) => e.titleFor('모두전자')).toSet();
    var answered = false;
    for (var i = 0; i < rumor.followUpDelay + 1; i++) {
      engine.step();
      answered = engine.feed.any((f) => answers.contains(f.title));
      if (answered) break;
    }
    expect(answered, isTrue);
  });

  test('계좌: 평단, 실현손익, 공매도 전환', () {
    final account = PlayerAccount(1000000);
    account.apply(Side.buy, 10000, 100);
    account.apply(Side.sell, 11000, 50);
    expect(account.realized, 50000);
    expect(account.position, 50);
    expect(account.averagePrice, 10000);
    account.apply(Side.sell, 12000, 100);
    expect(account.realized, 150000);
    expect(account.position, -50);
    expect(account.averagePrice, 12000);
    expect(account.equity(12000), 1150000);
    account.apply(Side.buy, 11000, 50);
    expect(account.realized, 200000);
    expect(account.position, 0);
  });

  test('등급: 이기고 5% 이상 벌면 S', () {
    BattleResult result(Faction? winner, int pnl) => BattleResult(
          winner: winner,
          reason: '',
          playerFaction: Faction.bull,
          basePrice: 10000,
          closePrice: 10500,
          startingCash: 100000000,
          pnl: pnl,
          attackValue: 0,
          defenseValue: 0,
          skillsUsed: 0,
          skillTicks: 0,
        );
    expect(result(Faction.bull, 6000000).grade, 'S');
    expect(result(Faction.bull, -1).grade, 'B');
    expect(result(Faction.bear, 1).grade, 'B');
    expect(result(Faction.bear, -1).grade, 'C');
    expect(result(null, 0).victory, isFalse);
  });
}
