import 'package:everyvaluation/game/engine.dart';
import 'package:everyvaluation/game/faction.dart';
import 'package:everyvaluation/screen/orderwar.dart';
import 'package:everyvaluation/screen/orderwarbattle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void usePhone(WidgetTester tester, Size logicalSize) {
  tester.binding.window.devicePixelRatioTestValue = 3;
  tester.binding.window.physicalSizeTestValue = logicalSize * 3;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
  addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
}

void main() {
  for (final size in const [Size(412, 915), Size(360, 640)]) {
    testWidgets(
        '로비에서 매수군에 합류해 돌격 (${size.width.toInt()}x${size.height.toInt()})',
        (tester) async {
      usePhone(tester, size);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: OrderWarScreen())));
      expect(find.text('호가전쟁'), findsOneWidget);
      expect(find.text('오늘의 전장'), findsOneWidget);

      await tester.tap(find.text('매수군 합류'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OrderWarBattle), findsOneWidget);
      expect(find.text('돌격 · 시장가 매수'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining(' · 09:06'), findsOneWidget);

      await tester.tap(find.text('돌격 · 시장가 매수'));
      await tester.pump();
      expect(find.textContaining('돌격!'), findsOneWidget);
      expect(find.textContaining('보유'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('장 마감까지 싸우면 결과가 나오고 다시 싸울 수 있다', (tester) async {
    usePhone(tester, const Size(360, 640));
    await tester.pumpWidget(const MaterialApp(
      home: OrderWarBattle(
        company: Company('모두전자', '전자부품', 12000),
        faction: Faction.bear,
        seed: 5,
      ),
    ));
    await tester.tap(find.text('벽 쌓기'));
    for (var i = 0; i < BattleEngine.ticksPerDay + 5; i++) {
      await tester.pump(OrderWarBattle.tickInterval);
    }
    await tester.pump();
    expect(find.text('다시 싸우기'), findsOneWidget);
    expect(find.textContaining('장 마감'), findsWidgets);

    await tester.tap(find.text('다시 싸우기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('다시 싸우기'), findsNothing);
    expect(find.textContaining(' · 09:02'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
