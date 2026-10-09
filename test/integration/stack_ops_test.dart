// Stack operations (design §4 rows for pushReplacement and popUntil, §5
// "pushReplacement" and "popUntil", §8 "Reverse direction mid-flight").
//
// Every test runs with both route installs. Values are sampled every frame
// against the flat-timing formulas from support.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// [n] tappable 60 px elements named '$prefix$i'; a tap on one calls
/// [onTap] with the page's context.
Widget listPage(
  String prefix,
  int n, {
  void Function(BuildContext context)? onTap,
}) =>
    Builder(
      builder: (BuildContext context) => column(<Widget>[
        for (int i = 0; i < n; i++)
          item(
            '$prefix$i',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap == null ? null : () => onTap(context),
              child: SizedBox(height: 60, child: Text('$prefix$i')),
            ),
          ),
      ]),
    );

/// Asserts a plain element of a page fully covered by another page.
void expectPlainCovered(WidgetTester tester, String label) {
  expect(opacityOf(tester, label), 0.0, reason: label);
  expect(offsetOf(tester, label), const Offset(0, -0.1), reason: label);
}

void expectRest(WidgetTester tester, Iterable<String> labels) {
  for (final String label in labels) {
    expect(opacityOf(tester, label), 1.0, reason: label);
    expect(offsetOf(tester, label), Offset.zero, reason: label);
  }
}

void main() {
  for (final Install install in Install.values) {
    group(install.name, () {
      testWidgets(
          'push then pop at A = 0.4: the entrance plays backwards on the '
          'enter curve and the page below uncovers, with no jump',
          (WidgetTester tester) async {
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          listPage('h', 1),
          theme: themeFor(install),
        );
        await tester.pumpAndSettle();
        final ModalRoute<Object?> home = routeOf(tester, 'h0');
        nav.currentState!
            .push(routeFor<void>(install, (_) => listPage('x', 1)));
        await tester.pump();
        final ModalRoute<Object?> top = routeOf(tester, 'x0');
        while (top.animation!.value < 0.4) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        nav.currentState!.pop();
        final List<double> a = <double>[];
        final List<double> shown = <double>[];
        final List<double> below = <double>[];
        while (exists('x0') && !top.animation!.isDismissed) {
          final double av = top.animation!.value;
          final double sv = home.secondaryAnimation!.value;
          expect(sv, moreOrLessEquals(av, epsilon: eps));
          // Left rest 0, so the enter lock holds while A runs back down.
          expect(opacityOf(tester, 'x0'),
              moreOrLessEquals(shownEntering(av), epsilon: eps));
          final double c = coveredAt(sv);
          expect(offsetOf(tester, 'h0'),
              offsetMoreOrLessEquals(Offset(0, -0.1 * c), epsilon: eps));
          expect(
              opacityOf(tester, 'h0'), moreOrLessEquals(1 - c, epsilon: eps));
          a.add(av);
          shown.add(opacityOf(tester, 'x0'));
          below.add(opacityOf(tester, 'h0'));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull);
        expect(a.first, greaterThanOrEqualTo(0.4));
        for (int i = 1; i < a.length; i++) {
          expect(a[i], lessThanOrEqualTo(a[i - 1]), reason: 'A runs back');
          // Steepest slope of easeOutCubic over the 0.65 enter slice is
          // 3 / 0.65 < 4.7; of easeIn over the 0.35 exit slice < 5.
          expect((shown[i] - shown[i - 1]).abs(),
              lessThanOrEqualTo(4.7 * (a[i - 1] - a[i]) + eps));
          expect((below[i] - below[i - 1]).abs(),
              lessThanOrEqualTo(5.0 * (a[i - 1] - a[i]) + eps));
        }
        expect(a.length, greaterThan(3), reason: 'the reverse takes frames');
        await tester.pumpAndSettle();
        expect(exists('x0'), isFalse);
        expectRest(tester, <String>['h0']);
      });

      testWidgets(
          'pushReplacement: the replaced page parts and exits while the page '
          'two levels down stays covered (train-hop)',
          (WidgetTester tester) async {
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          const SizedBox(),
          theme: themeFor(install),
        );
        nav.currentState!
            .push(routeFor<void>(install, (_) => listPage('a', 3)));
        await tester.pumpAndSettle();
        final ModalRoute<Object?> a = routeOf(tester, 'a0');
        nav.currentState!.push(
          routeFor<void>(
            install,
            (_) => listPage(
              'b',
              5,
              onTap: (BuildContext context) =>
                  Navigator.of(context).pushReplacement(
                routeFor<void>(install, (_) => listPage('c', 2)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(a.secondaryAnimation!.value, 1.0);
        for (final String label in <String>['a0', 'a1', 'a2']) {
          expectPlainCovered(tester, label);
        }
        final ModalRoute<Object?> b = routeOf(tester, 'b0');

        await tester.tap(find.text('b2'));
        await tester.pump();
        final ModalRoute<Object?> c = routeOf(tester, 'c0');
        final List<double> aSecondary = <double>[];
        final List<double> bSecondary = <double>[];
        Offset? parted0;
        Offset? parted4;
        for (int i = 0; i < 40 && !c.animation!.isCompleted; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          aSecondary.add(a.secondaryAnimation!.value);
          for (final String label in <String>['a0', 'a1', 'a2']) {
            expectPlainCovered(tester, label);
          }
          if (exists('b0')) {
            final double s = b.secondaryAnimation!.value;
            bSecondary.add(s);
            expect(s, moreOrLessEquals(c.animation!.value, epsilon: eps));
            // The tapped item stays, its neighbours part away from it.
            expect(offsetOf(tester, 'b2'), Offset.zero);
            expect(opacityOf(tester, 'b2'), 1.0);
            if (s > 0) {
              expect(offsetOf(tester, 'b0').dy, lessThan(0));
              expect(offsetOf(tester, 'b4').dy, greaterThan(0));
            }
            parted0 = offsetOf(tester, 'b0');
            parted4 = offsetOf(tester, 'b4');
          }
        }
        // The belief from §5: the page two levels down never uncovers.
        expect(aSecondary.length, greaterThan(10));
        expect(aSecondary, everyElement(1.0));
        // The replaced page's secondary ran 0 -> 1, monotonically.
        expect(bSecondary.first, lessThan(0.2));
        for (int i = 1; i < bSecondary.length; i++) {
          expect(bSecondary[i], greaterThanOrEqualTo(bSecondary[i - 1]));
        }
        expect(parted0!.dy, lessThan(0));
        expect(parted4!.dy, greaterThan(0));

        await tester.pumpAndSettle();
        expect(exists('b0'), isFalse, reason: 'the replaced route is gone');
        expect(a.secondaryAnimation!.value, 1.0);
        expectRest(tester, <String>['c0', 'c1']);

        // Popping the replacement uncovers the page below once.
        nav.currentState!.pop();
        final List<double> uncover = <double>[];
        for (int i = 0; i < 40 && !a.secondaryAnimation!.isDismissed; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          uncover.add(a.secondaryAnimation!.value);
          expect(opacityOf(tester, 'a0'),
              moreOrLessEquals(1 - coveredAt(uncover.last), epsilon: eps));
        }
        for (int i = 1; i < uncover.length; i++) {
          expect(uncover[i], lessThanOrEqualTo(uncover[i - 1]));
        }
        await tester.pumpAndSettle();
        expectRest(tester, <String>['a0', 'a1', 'a2']);
      });

      testWidgets(
          'popUntil past three pages: the surviving page uncovers once, '
          'driven by the top route', (WidgetTester tester) async {
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          const SizedBox(),
          theme: themeFor(install),
        );
        nav.currentState!
            .push(routeFor<void>(install, (_) => listPage('a', 3)));
        await tester.pumpAndSettle();
        final ModalRoute<Object?> a = routeOf(tester, 'a0');
        for (final String prefix in <String>['b', 'c', 'd']) {
          nav.currentState!
              .push(routeFor<void>(install, (_) => listPage(prefix, 2)));
          await tester.pumpAndSettle();
        }
        final ModalRoute<Object?> d = routeOf(tester, 'd0');
        expect(a.secondaryAnimation!.value, 1.0);
        expectPlainCovered(tester, 'a0');

        nav.currentState!.popUntil((Route<dynamic> r) => r == a);
        final List<double> s = <double>[];
        final List<double> opacity = <double>[];
        int drivenFrames = 0;
        for (int i = 0; i < 60 && !a.secondaryAnimation!.isDismissed; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          s.add(a.secondaryAnimation!.value);
          opacity.add(opacityOf(tester, 'a0'));
          if (exists('d0')) {
            drivenFrames++;
            expect(s.last, moreOrLessEquals(d.animation!.value, epsilon: eps),
                reason: 'driven by the top popped route');
          }
          expect(opacity.last,
              moreOrLessEquals(1 - coveredAt(s.last), epsilon: eps));
        }
        expect(tester.takeException(), isNull);
        expect(drivenFrames, greaterThan(3));
        expect(s.last, 0.0);
        expect(s.length, greaterThan(3), reason: 'animated, not a jump');
        for (int i = 1; i < s.length; i++) {
          expect(s[i], lessThanOrEqualTo(s[i - 1]), reason: 'runs 1 -> 0 once');
          expect(opacity[i], greaterThanOrEqualTo(opacity[i - 1]),
              reason: 'returns once');
        }
        await tester.pumpAndSettle();
        for (final String gone in <String>['b0', 'c0', 'd0']) {
          expect(exists(gone), isFalse, reason: gone);
        }
        expectRest(tester, <String>['a0', 'a1', 'a2']);
      });
    });
  }
}
