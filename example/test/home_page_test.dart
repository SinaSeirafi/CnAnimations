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

/// The home Column is taller than the default 800x600 test surface.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('home buttons are visible after launch', (tester) async {
    _useTallSurface(tester);
    app.main();
    await tester.pumpAndSettle();

    _expectHomeButtonsVisible(tester);
  });

  testWidgets('home buttons are visible again after a round trip',
      (tester) async {
    _useTallSurface(tester);
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fade'));
    await tester.pumpAndSettle();
    expect(find.text('Back'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    _expectHomeButtonsVisible(tester);
  });
}
