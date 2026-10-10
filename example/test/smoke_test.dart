import 'package:cn_animations/cn_animations.dart';
import 'package:example/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _item(int i) => find.descendant(
  of: find.byKey(ValueKey('list-item-$i'), skipOffstage: false),
  matching: find.byType(Card),
  skipOffstage: false,
);

Offset _pos(WidgetTester tester, Finder f) =>
    tester.getTopLeft(f, warnIfMissed: false);

Future<void> _launch(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app builds and uses the fade-through route', (tester) async {
    await _launch(tester);
    expect(find.text('Cn Animations Example'), findsOneWidget);
    expect(find.text('Combined'), findsOneWidget);
  });

  testWidgets('every page is reachable', (tester) async {
    await _launch(tester);
    for (final (String label, String marker) in [
      ('List', 'Item 0'),
      ('Grid', 'Cell 0'),
      ('Settings', 'Respect reduced motion'),
      ('No navigator', 'Pane 1'),
    ]) {
      await _open(tester, label);
      expect(find.text(marker), findsOneWidget, reason: label);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('detail page is reachable from list and grid', (tester) async {
    await _launch(tester);
    await _open(tester, 'Grid');
    await tester.tap(find.text('Cell 4'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 4'), findsOneWidget);
    expect(find.text('Open dialog'), findsOneWidget);

    await _open(tester, 'Replace');
    expect(find.text('Detail 5'), findsOneWidget);
    await _open(tester, 'Pop to root');
    expect(find.text('Cn Animations Example'), findsOneWidget);
  });

  testWidgets('tapping list item 3 parts its neighbours', (tester) async {
    await _launch(tester);
    await _open(tester, 'List');

    final Offset above = _pos(tester, _item(2));
    final Offset tapped = _pos(tester, _item(3));
    final Offset below = _pos(tester, _item(4));

    await tester.tap(find.text('Item 3'));
    await tester.pump(); // push starts
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      _pos(tester, _item(2)).dy - above.dy,
      lessThan(0),
      reason: 'item above moves up',
    );
    expect(
      _pos(tester, _item(4)).dy - below.dy,
      greaterThan(0),
      reason: 'item below moves down',
    );
    expect(
      _pos(tester, _item(3)).dy - tapped.dy,
      0,
      reason: 'the tapped item stays',
    );

    await tester.pumpAndSettle();
    expect(find.text('Detail 3'), findsOneWidget);

    // Returning restores the list.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_pos(tester, _item(2)), above);
    expect(_pos(tester, _item(4)), below);
  });

  testWidgets('opening a dialog does not cover the page', (tester) async {
    await _launch(tester);
    await _open(tester, 'List');
    await tester.tap(find.text('Item 3'));
    await tester.pumpAndSettle();

    final Finder paragraph = find.byKey(const ValueKey('detail-paragraph-0'));
    final Offset before = _pos(tester, paragraph);
    // The covered list page is offstage; read it with skipOffstage: false.
    final Finder listItem = find.byKey(
      const ValueKey('list-item-4'),
      skipOffstage: false,
    );
    final Offset coveredBefore = _pos(tester, listItem);

    await _open(tester, 'Open dialog');
    expect(find.text('A dialog'), findsOneWidget);

    expect(_pos(tester, paragraph), before);
    expect(_pos(tester, listItem), coveredBefore);
    final Finder fades = find.ancestor(
      of: paragraph,
      matching: find.byType(FadeTransition),
    );
    for (final Element e in fades.evaluate()) {
      expect((e.widget as FadeTransition).opacity.value, 1);
    }
    expect(find.byType(CnRouteAnimation, skipOffstage: false), findsWidgets);
  });
}
