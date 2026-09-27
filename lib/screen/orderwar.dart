import 'dart:math';

import 'package:everyvaluation/game/engine.dart';
import 'package:everyvaluation/game/faction.dart';
import 'package:everyvaluation/game/krx.dart';
import 'package:everyvaluation/game/skill.dart';
import 'package:everyvaluation/screen/orderwarbattle.dart';
import 'package:everyvaluation/util/warstyle.dart';
import 'package:flutter/material.dart';

/// 호가전쟁 로비: 오늘의 전장(종목)을 보고 매수군·매도군 중 한쪽에 합류한다.
class OrderWarScreen extends StatefulWidget {
  const OrderWarScreen({Key? key}) : super(key: key);

  @override
  State<OrderWarScreen> createState() => _OrderWarScreenState();
}

class _OrderWarScreenState extends State<OrderWarScreen> {
  final _random = Random();
  late Company _company =
      Company.roster[_random.nextInt(Company.roster.length)];

  void _reroll() {
    setState(() {
      final others = Company.roster.where((c) => c != _company).toList();
      _company = others[_random.nextInt(others.length)];
    });
  }

  void _join(Faction faction) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OrderWarBattle(company: _company, faction: faction),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(25, 17, 25, 25),
        children: [
          const Text(
            '호가전쟁',
            style: TextStyle(
                fontWeight: FontWeight.w500, fontSize: 25, letterSpacing: -1.5),
          ),
          const SizedBox(height: 5),
          const Text(
            '매수세와 매도세가 호가창에서 싸운다. 어느 편에 설 것인가?',
            style: TextStyle(
                fontWeight: FontWeight.w100, fontSize: 15, letterSpacing: -1),
          ),
          const SizedBox(height: 20),
          _companyCard(),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _joinButton(Faction.bull)),
            const SizedBox(width: 12),
            Expanded(child: _joinButton(Faction.bear)),
          ]),
          const SizedBox(height: 24),
          const _RuleCard(title: '승리 조건', lines: [
            '장 마감(15:30) 종가가 기준가보다 높으면 매수군, 낮으면 매도군 승리',
            '상한가(하한가)를 ${BattleEngine.limitHoldToWin}분 동안 지키면 즉시 완승',
            '기준가 대비 10% 급변하면 VI 발동: 2분간 시장가·스킬 봉인',
            '진영이 이겨도 내 계좌가 깨지면 등급은 낮다. 전공과 수익을 함께 챙겨라',
          ]),
          const _RuleCard(title: '싸우는 법', lines: [
            '돌격: 시장가로 상대 호가를 먹어 치운다',
            '벽 쌓기: 아군 최우선 호가에 지정가 물량을 쌓아 적의 돌격을 받아낸다',
            '호가 칸을 누르면 그 가격에 지정가 주문. 상대 호가를 누르면 그 가격까지 돌격',
            '차트 패턴이 완성되면 스킬 카드 획득. ${BattleEngine.cardLifetime}분 안에 써야 한다',
            '적 진영 패턴은 ${BattleEngine.enemyWindup}분 뒤 자동 발동. 벽을 두껍게 쌓으면 덜 뚫린다',
          ]),
          _skillCard(),
          const _RuleCard(title: '전장 이벤트', lines: [
            '공시: 유상증자·무상증자·합병·자사주·블록딜·CB·실적·공급계약',
            '루머와 조회공시 답변, 결과 발표를 기다리는 긴장 구간',
            '매크로·세계정세: 금리·CPI·환율·사이드카·전쟁·무역협상',
            '어떤 공시는 호가창에 거대한 벽을 세운다 (합병 매수청구가, 유증 신주 물량 등)',
          ]),
          const SizedBox(height: 8),
          const Text(
            '등장 종목과 뉴스는 모두 가상입니다. 실제 투자 판단의 근거가 아닙니다.',
            style: TextStyle(fontSize: 11, color: WarColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _companyCard() {
    final base = _company.basePrice;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WarColors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('오늘의 전장',
                style: TextStyle(fontSize: 12, color: WarColors.muted)),
            const Spacer(),
            GestureDetector(
              onTap: _reroll,
              child: Row(children: const [
                Icon(Icons.refresh, size: 15, color: WarColors.muted),
                SizedBox(width: 3),
                Text('다른 종목',
                    style: TextStyle(fontSize: 12, color: WarColors.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${_company.name} · ${_company.sector}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w400)),
          const SizedBox(height: 10),
          Row(children: [
            _priceTag('기준가', base, Colors.white),
            _priceTag('상한가', upperLimitPrice(base), WarColors.bull),
            _priceTag('하한가', lowerLimitPrice(base), WarColors.bear),
          ]),
        ],
      ),
    );
  }

  Widget _priceTag(String label, int price, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: WarColors.muted)),
          Text(formatNumber(price),
              style: TextStyle(fontSize: 15, color: color)),
        ],
      ),
    );
  }

  Widget _joinButton(Faction faction) {
    final bull = faction == Faction.bull;
    final color = WarColors.of(faction);
    return Material(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _join(faction),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(bull ? Icons.trending_up : Icons.trending_down,
                  color: color, size: 28),
              const SizedBox(height: 8),
              Text('${faction.label} 합류',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w500, color: color)),
              const SizedBox(height: 4),
              Text(
                bull ? '가격을 밀어 올려라\n목표: 상한가' : '가격을 끌어 내려라\n목표: 하한가',
                style: const TextStyle(fontSize: 12, color: WarColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skillCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WarColors.panel.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('차트 패턴 = 스킬',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400)),
          const SizedBox(height: 4),
          const Text('패턴이 완성되는 순간, 그 방향의 진영이 한 방향으로 호가를 쓸어버린다',
              style: TextStyle(fontSize: 12, color: WarColors.muted)),
          const SizedBox(height: 10),
          for (final skill in Skill.all) _skillLine(skill),
        ],
      ),
    );
  }

  Widget _skillLine(Skill skill) {
    final color = WarColors.of(skill.faction);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 30,
            margin: const EdgeInsets.only(right: 8, top: 2),
            color: color,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${skill.pattern.label} → '),
                      TextSpan(
                          text: skill.name,
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.w500)),
                      TextSpan(
                          text: '  ${'★' * skill.tier}',
                          style: const TextStyle(
                              color: WarColors.warning, fontSize: 10)),
                    ]),
                    style: const TextStyle(fontSize: 13)),
                Text(skill.description,
                    style:
                        const TextStyle(fontSize: 11, color: WarColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WarColors.panel.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w400)),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(fontSize: 12, color: WarColors.muted)),
                  Expanded(
                    child: Text(line,
                        style: const TextStyle(fontSize: 12, height: 1.35)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
