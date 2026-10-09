import 'package:example/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _homeButtons = [
  'Fade',
  'Scale',
  'Slide',
  'Chained',
  'Combined',
];

/// Product of every FadeTransition and Opacity above the widget.
double _effectiveOpacity(WidgetTester tester, Finder finder) {
  double opacity = 1;
  tester.element(finder).visitAncestorElements((ancestor) {
    final Widget widget = ancestor.widget;
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    if (widget is Opacity) opacity *= widget.opacity;
    return true;
  });
  return opacity;
}

void _expectHomeButtonsVisible(WidgetTester tester) {
  for (final String label in _homeButtons) {
    expect(_effectiveOpacity(tester, find.text(label)), 1, reason: label);
  }
}

void main() {
  testWidgets('home content is visible after launch', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    _expectHomeButtonsVisible(tester);
  });

  testWidgets('home content is visible again after a round trip',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('List'));
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.text('Item 0'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    _expectHomeButtonsVisible(tester);
  });
}
