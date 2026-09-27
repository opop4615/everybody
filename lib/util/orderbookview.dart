import 'dart:math';

import 'package:everyvaluation/game/krx.dart';
import 'package:everyvaluation/game/orderbook.dart';
import 'package:everyvaluation/util/warstyle.dart';
import 'package:flutter/material.dart';

/// 호가창: 위는 매도 호가(파랑), 아래는 매수 호가(빨강). 이곳이 전장이다.
///
/// 높이에 맞춰 한쪽 최대 10칸까지 보여주고, 칸을 누르면 그 가격을 알려준다.
class OrderBookView extends StatelessWidget {
  const OrderBookView({
    Key? key,
    required this.asks,
    required this.bids,
    required this.basePrice,
    required this.lastPrice,
    required this.upperLimit,
    required this.lowerLimit,
    this.onTapPrice,
  }) : super(key: key);

  /// 최우선 호가부터.
  final List<BookLevel> asks;
  final List<BookLevel> bids;
  final int basePrice;
  final int lastPrice;
  final int upperLimit;
  final int lowerLimit;
  final ValueChanged<int>? onTapPrice;

  static const double minRowHeight = 18;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final perSide =
          (constraints.maxHeight / 2 / minRowHeight).floor().clamp(1, 10);
      final rowHeight = constraints.maxHeight / (perSide * 2);
      final shownAsks = asks.take(perSide).toList();
      final shownBids = bids.take(perSide).toList();
      final maxQuantity = [...shownAsks, ...shownBids]
          .fold<int>(1, (m, level) => max(m, level.quantity));
      return Column(children: [
        for (var i = perSide - 1; i >= 0; i--)
          _row(i < shownAsks.length ? shownAsks[i] : null, Side.sell, rowHeight,
              maxQuantity),
        for (var i = 0; i < perSide; i++)
          _row(i < shownBids.length ? shownBids[i] : null, Side.buy, rowHeight,
              maxQuantity),
      ]);
    });
  }

  Widget _row(BookLevel? level, Side side, double height, int maxQuantity) {
    final isAsk = side == Side.sell;
    final color = isAsk ? WarColors.bear : WarColors.bull;
    final quantity = _QuantityCell(
      quantity: level?.quantity ?? 0,
      share: (level?.quantity ?? 0) / maxQuantity,
      color: color,
      towardRight: isAsk,
    );
    final mine = _MineCell(
      quantity: level?.playerQuantity ?? 0,
      towardRight: !isAsk,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: level == null || onTapPrice == null
          ? null
          : () => onTapPrice!(level.price),
      child: SizedBox(
        height: height,
        child: Row(children: [
          Expanded(child: isAsk ? quantity : mine),
          Expanded(child: _priceCell(level?.price, color)),
          Expanded(child: isAsk ? mine : quantity),
        ]),
      ),
    );
  }

  Widget _priceCell(int? price, Color tint) {
    if (price == null) {
      return Container(color: tint.withOpacity(0.06));
    }
    final isLast = price == lastPrice;
    final tag = price == upperLimit
        ? '상'
        : price == lowerLimit
            ? '하'
            : null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0.5),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.12),
        border: isLast ? Border.all(color: Colors.white, width: 1.2) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatNumber(price),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isLast ? FontWeight.w500 : FontWeight.w300,
                  color: WarColors.forPrice(price, basePrice),
                ),
              ),
            ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 2),
            Text(tag,
                style: const TextStyle(
                    fontSize: 9, color: WarColors.warning, height: 1)),
          ],
        ],
      ),
    );
  }
}

class _QuantityCell extends StatelessWidget {
  const _QuantityCell({
    required this.quantity,
    required this.share,
    required this.color,
    required this.towardRight,
  });

  final int quantity;
  final double share;
  final Color color;

  /// 막대가 오른쪽(가격 칸 쪽)에 붙는지.
  final bool towardRight;

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) return const SizedBox.shrink();
    final alignment =
        towardRight ? Alignment.centerRight : Alignment.centerLeft;
    return Stack(children: [
      Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: share.clamp(0.02, 1.0),
          heightFactor: 0.72,
          child: Container(color: color.withOpacity(0.32)),
        ),
      ),
      Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(formatNumber(quantity),
                style: const TextStyle(fontSize: 11.5)),
          ),
        ),
      ),
    ]);
  }
}

/// 내 주문 잔량 표시.
class _MineCell extends StatelessWidget {
  const _MineCell({required this.quantity, required this.towardRight});

  final int quantity;
  final bool towardRight;

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) return const SizedBox.shrink();
    return Align(
      alignment: towardRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('내 ${formatNumber(quantity)}',
              style: const TextStyle(fontSize: 10.5, color: WarColors.warning)),
        ),
      ),
    );
  }
}

/// 스킬 연출: 진영 색 빛줄기가 한 방향으로 호가창을 가로지른다.
class SkillBeamPainter extends CustomPainter {
  SkillBeamPainter({
    required this.progress,
    required this.color,
    required this.upward,
  });

  final double progress;
  final Color color;
  final bool upward;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - progress).clamp(0.0, 1.0);
    final band = size.height * 0.35;
    final center = upward
        ? size.height * (1.1 - 1.2 * progress)
        : size.height * (-0.1 + 1.2 * progress);
    // 지나간 자리
    final trail = upward
        ? Rect.fromLTRB(0, center, size.width, size.height)
        : Rect.fromLTRB(0, 0, size.width, center);
    canvas.drawRect(trail, Paint()..color = color.withOpacity(0.10 * fade));
    // 빛줄기
    final beam =
        Rect.fromLTRB(0, center - band / 2, size.width, center + band / 2);
    canvas.drawRect(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0),
            color.withOpacity(0.65 * fade),
            color.withOpacity(0),
          ],
        ).createShader(beam),
    );
  }

  @override
  bool shouldRepaint(SkillBeamPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.upward != upward;
}
