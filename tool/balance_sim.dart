// 호가전쟁 밸런스 시뮬레이터.
//
//   dart run tool/balance_sim.dart [판 수]
//
// 가만히 있는 플레이어와 적극적인 플레이어로 여러 판을 돌려
// 하루 변동폭, VI·상하한가 빈도, 패턴(스킬) 발생 횟수, 진영 승률을 본다.

// ignore_for_file: avoid_print
import 'dart:math';

import 'package:everyvaluation/game/engine.dart';
import 'package:everyvaluation/game/faction.dart';
import 'package:everyvaluation/game/krx.dart';

void main(List<String> args) {
  final games = args.isEmpty ? 200 : int.parse(args.first);
  for (final company in Company.roster) {
    _report(company, games, active: false);
  }
  _report(Company.roster.first, games, active: true);
}

void _report(Company company, int games, {required bool active}) {
  final changes = <double>[];
  final ranges = <double>[];
  var vi = 0;
  var limitWins = 0;
  var bullWins = 0;
  var playerWins = 0;
  var skills = 0;
  var enemySkills = 0;
  final patterns = <String, int>{};
  final returns = <double>[];

  for (var seed = 0; seed < games; seed++) {
    final engine = BattleEngine(
      company: company,
      faction: seed.isEven ? Faction.bull : Faction.bear,
      seed: seed,
    );
    var high = engine.lastPrice;
    var low = engine.lastPrice;
    while (!engine.isOver) {
      engine.step();
      if (active) {
        if (engine.tick == 3) engine.attack(0.5);
        if (engine.hand.isNotEmpty) engine.useSkill(0);
        if (engine.incoming.isNotEmpty) engine.placeWall(0.25);
      }
      high = max(high, engine.lastPrice);
      low = min(low, engine.lastPrice);
    }
    final r = engine.result!;
    changes.add(r.priceChange * 100);
    ranges.add((high - low) / engine.basePrice * 100);
    returns.add(r.returnRate * 100);
    if (r.winner == Faction.bull) bullWins++;
    if (r.victory) playerWins++;
    if (r.reason.contains('안착')) limitWins++;
    for (final item in engine.feed) {
      if (item.title.startsWith('정적 VI')) vi++;
      if (item.title.contains('스킬 「')) skills++;
      if (item.title.contains('준비 중')) enemySkills++;
      final match = RegExp(r'^(\S+) 완성').firstMatch(item.title);
      if (match != null) {
        patterns[match.group(1)!] = (patterns[match.group(1)!] ?? 0) + 1;
      }
    }
  }

  changes.sort();
  ranges.sort();
  String pct(List<double> v, double q) =>
      v[(q * (v.length - 1)).round()].toStringAsFixed(1);
  final absMean =
      changes.map((c) => c.abs()).reduce((a, b) => a + b) / changes.length;
  final meanReturn = returns.reduce((a, b) => a + b) / returns.length;

  print('── ${company.name} (${formatNumber(company.basePrice)}원) '
      '${active ? '적극 플레이어' : '관망 플레이어'} · $games판');
  print('  종가 등락 |평균| ${absMean.toStringAsFixed(1)}%  '
      'p5 ${pct(changes, 0.05)} / p50 ${pct(changes, 0.5)} / p95 ${pct(changes, 0.95)}');
  print('  하루 변동폭 p50 ${pct(ranges, 0.5)}%  p95 ${pct(ranges, 0.95)}%');
  print('  VI ${(vi / games).toStringAsFixed(2)}회/판  '
      '상·하한가 안착 ${(limitWins / games * 100).toStringAsFixed(1)}%  '
      '매수군 승 ${(bullWins / games * 100).toStringAsFixed(0)}%');
  print('  스킬 획득 ${(skills / games).toStringAsFixed(1)}  '
      '적 스킬 ${(enemySkills / games).toStringAsFixed(1)} /판  '
      '플레이어 승률 ${(playerWins / games * 100).toStringAsFixed(0)}%  '
      '평균 수익률 ${meanReturn.toStringAsFixed(2)}%');
  final sorted = patterns.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  print(
      '  패턴/판: ${sorted.map((e) => '${e.key} ${(e.value / games).toStringAsFixed(2)}').join(', ')}');
}
