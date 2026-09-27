import 'package:everyvaluation/game/faction.dart';
import 'package:everyvaluation/game/pattern.dart';

/// 차트 패턴이 완성되면 해당 진영이 얻는 스킬.
///
/// 스킬은 진영 병력(시장가 물량)이 한 방향으로 호가를 쓸어버리는 공격이다.
/// power는 '표준 호가 잔량 몇 칸 분량'의 물량이라서, 상대가 두껍게 쌓은 벽에 막히면
/// 그만큼 덜 나간다.
class Skill {
  const Skill({
    required this.name,
    required this.pattern,
    required this.power,
    this.waves = 1,
    this.wall = 0,
    this.morale = 0,
    required this.description,
  });

  final String name;
  final ChartPattern pattern;

  /// 한 번 공격할 때 쓰는 물량 (표준 잔량 칸 수).
  final double power;

  /// 몇 분(틱)에 걸쳐 연속으로 공격하는지.
  final int waves;

  /// 발동 시 아군 최우선 호가에 쌓는 방어벽 (표준 잔량 칸 수).
  final double wall;

  /// 발동 시 시장 심리 변화량 (진영 방향 기준, 0~1).
  final double morale;

  final String description;

  Faction get faction => pattern.direction;

  /// 스킬 등급: 패턴이 크고 드물수록 강하다.
  int get tier => power * waves >= 18
      ? 3
      : power * waves >= 10
          ? 2
          : 1;

  static Skill of(ChartPattern pattern) =>
      all.firstWhere((s) => s.pattern == pattern);

  static const List<Skill> all = [
    Skill(
      name: '장악 돌파',
      pattern: ChartPattern.bullishEngulfing,
      power: 6,
      morale: 0.12,
      description: '직전 음봉을 삼킨 기세로 매도 호가를 들이받는다',
    ),
    Skill(
      name: '망치 방패',
      pattern: ChartPattern.hammer,
      power: 3,
      wall: 6,
      morale: 0.08,
      description: '아래꼬리 지지선에 거대한 매수벽을 세우고 반격한다',
    ),
    Skill(
      name: '삼병 돌격',
      pattern: ChartPattern.threeWhiteSoldiers,
      power: 4,
      waves: 3,
      morale: 0.15,
      description: '세 병사가 3분 동안 연속으로 매도 호가를 들이받는다',
    ),
    Skill(
      name: '골든 브레이크',
      pattern: ChartPattern.goldenCross,
      power: 10,
      morale: 0.25,
      description: '단기선이 장기선을 뚫는 순간 매도 호가를 관통',
    ),
    Skill(
      name: 'W 반격',
      pattern: ChartPattern.doubleBottom,
      power: 11,
      wall: 5,
      morale: 0.25,
      description: '두 번 버틴 바닥에 벽을 세우고 넥라인 위로 역습한다',
    ),
    Skill(
      name: '넥라인 붕괴',
      pattern: ChartPattern.inverseHeadAndShoulders,
      power: 9,
      waves: 2,
      morale: 0.35,
      description: '궁극기. 머리를 딛고 넥라인을 부수며 2연속 돌파한다',
    ),
    Skill(
      name: '장악 붕괴',
      pattern: ChartPattern.bearishEngulfing,
      power: 6,
      morale: 0.12,
      description: '직전 양봉을 덮친 기세로 매수 호가를 짓밟는다',
    ),
    Skill(
      name: '유성 낙하',
      pattern: ChartPattern.shootingStar,
      power: 3,
      wall: 6,
      morale: 0.08,
      description: '윗꼬리 저항선에 매도벽을 세우고 내리꽂는다',
    ),
    Skill(
      name: '삼까마귀 급강하',
      pattern: ChartPattern.threeBlackCrows,
      power: 4,
      waves: 3,
      morale: 0.15,
      description: '까마귀 세 마리가 3분 동안 매수 호가를 연속 강타한다',
    ),
    Skill(
      name: '데드 슬래시',
      pattern: ChartPattern.deadCross,
      power: 10,
      morale: 0.25,
      description: '단기선이 장기선 아래로 꺾이며 매수 호가를 베어낸다',
    ),
    Skill(
      name: 'M 폭격',
      pattern: ChartPattern.doubleTop,
      power: 11,
      wall: 5,
      morale: 0.25,
      description: '두 번 막힌 천장에 벽을 치고 넥라인 아래로 폭격한다',
    ),
    Skill(
      name: '목 베기',
      pattern: ChartPattern.headAndShoulders,
      power: 9,
      waves: 2,
      morale: 0.35,
      description: '궁극기. 넥라인을 베어내며 2연속 하방 돌파한다',
    ),
  ];
}
