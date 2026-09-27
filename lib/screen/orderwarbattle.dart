import 'dart:async';

import 'package:everyvaluation/game/engine.dart';
import 'package:everyvaluation/game/faction.dart';
import 'package:everyvaluation/game/krx.dart';
import 'package:everyvaluation/util/candlechart.dart';
import 'package:everyvaluation/util/orderbookview.dart';
import 'package:everyvaluation/util/warstyle.dart';
import 'package:flutter/material.dart';

/// 호가전쟁 전투 화면. 0.5초가 장중 1분이다.
class OrderWarBattle extends StatefulWidget {
  const OrderWarBattle({
    Key? key,
    required this.company,
    required this.faction,
    this.seed,
  }) : super(key: key);

  final Company company;
  final Faction faction;
  final int? seed;

  static const tickInterval = Duration(milliseconds: 500);

  @override
  State<OrderWarBattle> createState() => _OrderWarBattleState();
}

class _OrderWarBattleState extends State<OrderWarBattle>
    with SingleTickerProviderStateMixin {
  late BattleEngine _engine;
  late final AnimationController _beam = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750));
  Timer? _timer;
  SkillBlast? _blast;
  bool _paused = false;
  bool _fast = false;
  bool _resultShown = false;
  double _fraction = 0.25;

  static const _fractions = [0.1, 0.25, 0.5, 1.0];

  @override
  void initState() {
    super.initState();
    _engine = _newEngine(widget.seed);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _beam.dispose();
    super.dispose();
  }

  BattleEngine _newEngine(int? seed) => BattleEngine(
      company: widget.company, faction: widget.faction, seed: seed);

  void _startTimer() {
    _timer?.cancel();
    final interval =
        _fast ? OrderWarBattle.tickInterval ~/ 2 : OrderWarBattle.tickInterval;
    _timer = Timer.periodic(interval, (_) => _onTick());
  }

  void _onTick() {
    if (_paused || !mounted) return;
    setState(_engine.step);
    _playBlasts();
    if (_engine.isOver) {
      _timer?.cancel();
      _showResult();
    }
  }

  void _playBlasts() {
    final blasts = _engine.takeBlasts();
    if (blasts.isEmpty) return;
    _blast = blasts.last;
    _beam.forward(from: 0);
  }

  void _act(ActionResult result) {
    setState(() {});
    _playBlasts();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(result.message),
        duration: const Duration(milliseconds: 1400),
        backgroundColor: result.ok ? WarColors.accent : Colors.grey[800],
      ));
  }

  Future<void> _showResult() async {
    if (_resultShown) return;
    _resultShown = true;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(result: _engine.result!),
    );
    if (!mounted) return;
    if (again == true) {
      setState(() {
        _engine = _newEngine(null);
        _resultShown = false;
        _paused = false;
        _blast = null;
      });
      _startTimer();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmExit() async {
    if (_engine.isOver) return true;
    final wasPaused = _paused;
    setState(() => _paused = true);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WarColors.panel,
        title: const Text('전장을 떠날까요?'),
        content: const Text('진행 중인 전투는 기록되지 않습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('계속 싸우기')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('떠나기')),
        ],
      ),
    );
    if (!mounted) return false;
    if (leave != true) setState(() => _paused = wasPaused);
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final e = _engine;
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: WarColors.deep,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(children: [
              _header(e),
              const SizedBox(height: 4),
              _gauge(e),
              const SizedBox(height: 6),
              SizedBox(
                height: 110,
                child: CandleChart(
                  candles: e.candles,
                  current: e.currentCandle,
                  basePrice: e.basePrice,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _battlefield(e)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _sidePanel(e)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _actionBar(e),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 상단 ──────────────────────────────────────────────────────────

  Widget _header(BattleEngine e) {
    final color = WarColors.forPrice(e.lastPrice, e.basePrice);
    final arrow = e.lastPrice > e.basePrice
        ? '▲'
        : e.lastPrice < e.basePrice
            ? '▼'
            : '';
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          final leave = await _confirmExit();
          if (leave && mounted) Navigator.of(context).pop();
        },
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.company.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
            Text('${e.company.sector} · ${e.clock}',
                style: const TextStyle(fontSize: 11, color: WarColors.muted)),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatNumber(e.lastPrice),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w500, color: color)),
          Text('$arrow ${signedPercent(e.changeRate)}',
              style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
      IconButton(
        tooltip: _paused ? '재개' : '일시정지',
        visualDensity: VisualDensity.compact,
        icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
        onPressed: e.isOver ? null : () => setState(() => _paused = !_paused),
      ),
      GestureDetector(
        onTap: () {
          setState(() => _fast = !_fast);
          if (!e.isOver) _startTimer();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: WarColors.muted),
            borderRadius: BorderRadius.circular(4),
          ),
          child:
              Text(_fast ? '2x' : '1x', style: const TextStyle(fontSize: 11)),
        ),
      ),
    ]);
  }

  /// 매수세 vs 매도세 줄다리기 (최근 20분 체결량 비중).
  Widget _gauge(BattleEngine e) {
    final buy = (e.buyShare * 100).round();
    return Column(children: [
      Row(children: [
        Text('매수세 $buy',
            style: const TextStyle(fontSize: 11, color: WarColors.bull)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(children: [
                Expanded(
                    flex: buy.clamp(1, 99),
                    child: Container(color: WarColors.bull)),
                Container(width: 2, color: Colors.white),
                Expanded(
                    flex: (100 - buy).clamp(1, 99),
                    child: Container(color: WarColors.bear)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${100 - buy} 매도세',
            style: const TextStyle(fontSize: 11, color: WarColors.bear)),
      ]),
      const SizedBox(height: 3),
      Row(children: [
        Text('나: ${widget.faction.label}',
            style:
                TextStyle(fontSize: 11, color: WarColors.of(widget.faction))),
        const Spacer(),
        if (e.inVi)
          Text('VI 발동 · 단일가 ${e.viRemaining}분 (벽 쌓기만 가능)',
              style: const TextStyle(fontSize: 11, color: WarColors.warning))
        else
          Text('체결강도 ${e.tradeStrength.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: WarColors.muted)),
      ]),
    ]);
  }

  // ── 호가창 = 전장 ────────────────────────────────────────────────

  Widget _battlefield(BattleEngine e) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: WarColors.panel.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: OrderBookView(
            asks: e.asks(10),
            bids: e.bids(10),
            basePrice: e.basePrice,
            lastPrice: e.lastPrice,
            upperLimit: e.upperLimit,
            lowerLimit: e.lowerLimit,
            onTapPrice: e.isOver
                ? null
                : (price) => _act(e.placeWall(_fraction, price: price)),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _beam,
              builder: (context, _) => _beamOverlay(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _beamOverlay() {
    final blast = _blast;
    if (blast == null || !_beam.isAnimating) return const SizedBox.shrink();
    final t = _beam.value;
    final color = WarColors.of(blast.skill.faction);
    return CustomPaint(
      painter: SkillBeamPainter(
        progress: t,
        color: color,
        upward: blast.skill.faction == Faction.bull,
      ),
      child: Center(
        child: Opacity(
          opacity: (1.4 - t).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.85 + 0.35 * t,
            child: Text(
              blast.skill.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                shadows: [Shadow(color: color, blurRadius: 14)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 오른쪽: 계좌 · 스킬 · 전장 소식 ──────────────────────────────

  Widget _sidePanel(BattleEngine e) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _accountCard(e),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < e.hand.length; i++) _skillCard(e, i),
              for (final threat in e.incoming) _threatCard(e, threat),
              for (final item in e.feed.take(40)) _feedLine(item),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountCard(BattleEngine e) {
    final pnl = e.pnl;
    final color = pnl > 0
        ? WarColors.bull
        : pnl < 0
            ? WarColors.bear
            : Colors.white;
    final position = e.account.position;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: WarColors.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('평가손익',
              style: TextStyle(fontSize: 10, color: WarColors.muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(signedNumber(pnl),
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, color: color)),
          ),
          Text(signedPercent(pnl / e.startingCash),
              style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              position == 0
                  ? '포지션 없음'
                  : '${position > 0 ? '보유' : '공매도'} ${formatNumber(position.abs())}주 · '
                      '평단 ${formatNumber(e.account.averagePrice)}',
              style: const TextStyle(fontSize: 10, color: WarColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillCard(BattleEngine e, int index) {
    final card = e.hand[index];
    final color = WarColors.of(card.skill.faction);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _act(e.useSkill(index)),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(card.skill.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Text('${card.expiresAt - e.tick}분',
                      style: const TextStyle(fontSize: 10)),
                ]),
                Text(
                    '${card.skill.pattern.label} ${'★' * card.skill.tier} · 탭하여 발동',
                    style:
                        const TextStyle(fontSize: 9.5, color: WarColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _threatCard(BattleEngine e, IncomingSkill threat) {
    final wait = threat.firesAt - e.tick;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        border: Border.all(color: WarColors.warning),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⚠ 적 「${threat.skill.name}」',
              style: const TextStyle(fontSize: 11.5, color: WarColors.warning)),
          Text(wait > 0 ? '$wait분 후 발동 · 벽을 쌓아라' : '곧 발동!',
              style: const TextStyle(fontSize: 9.5, color: WarColors.muted)),
        ],
      ),
    );
  }

  Widget _feedLine(FeedItem item) {
    final color = item.kind == FeedKind.warning
        ? WarColors.warning
        : item.kind == FeedKind.system && item.tone == null
            ? WarColors.muted
            : WarColors.of(item.tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '${item.time} ',
                  style: const TextStyle(color: WarColors.muted)),
              if (item.label.isNotEmpty)
                TextSpan(
                    text: '[${item.label}] ', style: TextStyle(color: color)),
              TextSpan(text: item.title),
            ]),
            style: const TextStyle(fontSize: 10.5, height: 1.3),
          ),
          if (item.detail.isNotEmpty)
            Text(item.detail,
                style: const TextStyle(
                    fontSize: 9.5, color: WarColors.muted, height: 1.3)),
        ],
      ),
    );
  }

  // ── 하단: 주문 ───────────────────────────────────────────────────

  Widget _actionBar(BattleEngine e) {
    final side = widget.faction.attackSide;
    final available =
        e.maxQuantity(side, e.book.best(side.opposite) ?? e.lastPrice);
    final color = WarColors.of(widget.faction);
    final bull = widget.faction == Faction.bull;
    return Column(children: [
      Row(children: [
        for (final f in _fractions)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _fraction = f),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _fraction == f ? color.withOpacity(0.35) : null,
                  border: Border.all(
                      color: _fraction == f ? color : WarColors.accent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${(f * 100).round()}%',
                    style: const TextStyle(fontSize: 11.5)),
              ),
            ),
          ),
        const Spacer(),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${formatNumber((available * _fraction).floor())}주',
                style: const TextStyle(fontSize: 11, color: WarColors.muted)),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          flex: 3,
          child: _button(bull ? '돌격 · 시장가 매수' : '돌격 · 시장가 매도', color,
              () => _act(e.attack(_fraction))),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: _button('벽 쌓기', color.withOpacity(0.55),
              () => _act(e.placeWall(_fraction))),
        ),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
            child: _button(
                '포지션 정리', WarColors.accent, () => _act(e.closePosition()))),
        const SizedBox(width: 6),
        Expanded(
            child: _button(
                '주문 취소', WarColors.accent, () => _act(e.cancelOrders()))),
      ]),
    ]);
  }

  Widget _button(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: _engine.isOver ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.result});

  final BattleResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final title = r.winner == null
        ? '무승부'
        : r.victory
            ? '승리'
            : '패배';
    final color = r.winner == null ? Colors.white : WarColors.of(r.winner);
    return AlertDialog(
      backgroundColor: WarColors.panel,
      title: Column(children: [
        Text(title,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w500, color: color)),
        const SizedBox(height: 4),
        Text(r.reason,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: WarColors.muted)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: WarColors.warning, width: 2),
            ),
            child: Text(r.grade,
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    color: WarColors.warning)),
          ),
          const SizedBox(height: 14),
          _stat(
              '종가',
              '${formatNumber(r.closePrice)} (${signedPercent(r.priceChange)})',
              WarColors.forPrice(r.closePrice, r.basePrice)),
          _stat(
              '내 손익',
              '${signedNumber(r.pnl)}원 (${signedPercent(r.returnRate)})',
              r.pnl > 0
                  ? WarColors.bull
                  : r.pnl < 0
                      ? WarColors.bear
                      : Colors.white),
          _stat('돌격 체결', compactWon(r.attackValue), Colors.white),
          _stat('방어 체결', compactWon(r.defenseValue), Colors.white),
          _stat('스킬', '${r.skillsUsed}회 · +${r.skillTicks}호가', Colors.white),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('로비로'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('다시 싸우기'),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: WarColors.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 13, color: color)),
            ),
          ),
        ),
      ]),
    );
  }
}
