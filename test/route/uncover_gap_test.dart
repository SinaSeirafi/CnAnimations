// Review R6: on pop and during interactive back, is there a window where
// neither page's elements are visible? Samples a button pop every frame and
// a predictive back at fixed progress values, on both installs, with flat
// timing (no stagger), and reports the window.
//
// "Visible" composes the element's own opacity with the page fade: the top
// element shows through the top page's fade-through opacity, and the element
// below shows through what the top page leaves uncovered (its background is
// opaque, so it hides the page below in proportion to its opacity).
//
// Measured on Flutter 3.32.7 (fake clock, 60 Hz frames, 400 ms pop):
// before the uncover slice (the exit slice replayed backwards) a pop had 7 of
// 24 frames with neither page's elements showing, S in [0.375, 0.625], and
// the back gesture 7 of 19 samples, S in [0.35, 0.65]. With the default
// uncover slice: 1 frame (S = 0.625) and 2 samples (S = 0.65, 0.6). What is
// left is S in (0.6, 0.65): the uncover slice ends at 0.6 and the top
// element's own exit slice (0..0.35 of leaving) ends at A = 0.65.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration/support.dart';

/// Below this, an element counts as invisible.
const double _invisible = 0.01;

class _Frame {
  _Frame(this.a, this.s, this.topElement, this.topPage, this.belowElement);
  final double a;
  final double s;
  final double topElement;
  final double topPage;
  final double belowElement;

  double get topVisible => topElement * topPage;
  double get belowVisible => belowElement * (1 - topPage);
  bool get dead => topVisible < _invisible && belowVisible < _invisible;
  bool get deadOwn => topElement < _invisible && belowElement < _invisible;

  @override
  String toString() => 'A=${a.toStringAsFixed(3)} S=${s.toStringAsFixed(3)} '
      'top=${topElement.toStringAsFixed(3)}x${topPage.toStringAsFixed(3)} '
      'below=${belowElement.toStringAsFixed(3)}';
}

/// The fade-through's own opacity on the top page: the nearest
/// `FadeTransition` above the element 't'.
double _topPageOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find
        .ancestor(
          of: find.byKey(const ValueKey<String>('t'), skipOffstage: false),
          matching: find.byType(FadeTransition, skipOffstage: false),
        )
        .first)
    .opacity
    .value;

class _Stack {
  _Stack(this.nav, this.below, this.top);
  final GlobalKey<NavigatorState> nav;
  final ModalRoute<Object?> below;
  final ModalRoute<Object?> top;
}

Future<_Stack> _twoPages(WidgetTester tester, Install install) async {
  final GlobalKey<NavigatorState> nav = await pumpApp(
    tester,
    const SizedBox(),
    theme: themeFor(install),
  );
  nav.currentState!.push(routeFor<void>(
      install,
      (_) => column(<Widget>[
            item('b'),
          ])));
  await tester.pumpAndSettle();
  nav.currentState!.push(routeFor<void>(
      install,
      (_) => column(<Widget>[
            item('t'),
          ])));
  await tester.pumpAndSettle();
  final _Stack stack = _Stack(nav, routeOf(tester, 'b'), routeOf(tester, 't'));
  expect(stack.below.secondaryAnimation!.value, 1.0);
  expect(opacityOf(tester, 'b'), 0.0);
  return stack;
}

_Frame _sample(WidgetTester tester, _Stack stack) => _Frame(
      stack.top.animation!.value,
      stack.below.secondaryAnimation!.value,
      opacityOf(tester, 't'),
      _topPageOpacity(tester),
      opacityOf(tester, 'b'),
    );

String _report(String what, List<_Frame> frames) {
  final List<_Frame> dead = frames.where((_Frame f) => f.dead).toList();
  final List<_Frame> deadOwn = frames.where((_Frame f) => f.deadOwn).toList();
  final double worst = frames
      .map((_Frame f) =>
          f.topVisible > f.belowVisible ? f.topVisible : f.belowVisible)
      .reduce((double a, double b) => a < b ? a : b);
  String range(List<_Frame> fs) => fs.isEmpty
      ? 'none'
      : 'S in [${fs.last.s.toStringAsFixed(3)}, '
          '${fs.first.s.toStringAsFixed(3)}]';
  return '$what: ${frames.length} frames; '
      'dead (composited) ${dead.length} ${range(dead)}; '
      'dead (own opacity) ${deadOwn.length} ${range(deadOwn)}; '
      'min over frames of max(visible) ${worst.toStringAsFixed(3)}';
}

/// The uncover slice the element applies while S falls from 1, no stagger.
const Interval _uncoverSlice = Interval(0.25, 0.6, curve: Curves.easeIn);

/// The steepest slope of either slice (easeIn over a 0.35 window is about
/// 4.9), for per-frame continuity bounds.
const double _maxSlope = 5.0;

/// Every frame where neither page's elements show lies in the residual
/// window between the end of the uncover slice (S = 0.6) and the end of the
/// top element's own exit slice (A = 0.65).
void _expectResidualOnly(List<_Frame> frames) {
  for (final _Frame f in frames) {
    if (f.dead) {
      expect(f.s, inInclusiveRange(0.6 - eps, 0.65 + eps), reason: '$f');
    }
  }
}

void _expectContinuous(List<double> s, List<double> v) {
  for (int i = 1; i < s.length; i++) {
    expect(
      (v[i] - v[i - 1]).abs(),
      lessThanOrEqualTo(_maxSlope * (s[i] - s[i - 1]).abs() + 1e-9),
      reason:
          'frame $i: S ${s[i - 1]} -> ${s[i]}, value ${v[i - 1]} -> ${v[i]}',
    );
  }
}

void main() {
  for (final Install install in Install.values) {
    group(install.name, () {
      testWidgets('button pop: the page below returns as the top page fades',
          (WidgetTester tester) async {
        final _Stack stack = await _twoPages(tester, install);
        stack.nav.currentState!.pop();
        await tester.pump();
        final List<_Frame> frames = <_Frame>[];
        while (stack.top.animation!.value > 0.0) {
          final _Frame f = _sample(tester, stack);
          frames.add(f);
          expect(f.a, moreOrLessEquals(f.s, epsilon: eps));
          expect(f.belowElement,
              moreOrLessEquals(1 - _uncoverSlice.transform(f.s), epsilon: eps),
              reason: '$f');
          await tester.pump(const Duration(microseconds: 16667));
        }
        await tester.pumpAndSettle();
        debugPrint(_report('pop ${install.name}', frames));
        expect(frames.length, greaterThan(20));
        expect(opacityOf(tester, 'b'), 1.0);
        // Before the uncover slice (exit replayed backwards) 7 of 24 frames
        // showed nothing, S in [0.375, 0.625]. Now at most one frame does.
        expect(frames.where((_Frame f) => f.dead).length, lessThanOrEqualTo(1));
        _expectResidualOnly(frames);
      });

      testWidgets(
          'predictive back: scrubbed values show one page or the other, and '
          'a cancel re-covers on the same slice without a jump',
          (WidgetTester tester) async {
        final _Stack stack = await _twoPages(tester, install);
        // The real platform channel, as the engine sends it: gesture
        // progress p puts the route at A = 1 - p.
        await sendBackGesture(tester, 'startBackGesture');
        await tester.pump();
        final List<_Frame> frames = <_Frame>[];
        for (int i = 1; i <= 19; i++) {
          await sendBackGesture(
            tester,
            'updateBackGestureProgress',
            progress: 0.05 * i,
          );
          await tester.pump();
          expect(stack.top.animation!.value, moreOrLessEquals(1 - 0.05 * i));
          final _Frame f = _sample(tester, stack);
          frames.add(f);
          expect(f.belowElement,
              moreOrLessEquals(1 - _uncoverSlice.transform(f.s), epsilon: eps),
              reason: '$f');
        }
        debugPrint(_report('back ${install.name}', frames));
        // Before: 7 of 19 samples showed nothing, S in [0.35, 0.65].
        _expectResidualOnly(frames);
        expect(frames.where((_Frame f) => f.dead).length, lessThanOrEqualTo(2));

        // Cancel from S = 0.05: S climbs back to 1, still on the uncover
        // slice (locked by the rest it left), so the element below fades out
        // smoothly instead of jumping to the exit slice's value.
        final List<double> s = <double>[stack.below.secondaryAnimation!.value];
        final List<double> b = <double>[opacityOf(tester, 'b')];
        await sendBackGesture(tester, 'cancelBackGesture');
        for (int i = 0; i < 90; i++) {
          await tester.pump(const Duration(milliseconds: 4));
          final double sv = stack.below.secondaryAnimation!.value;
          s.add(sv);
          b.add(opacityOf(tester, 'b'));
          expect(b.last,
              moreOrLessEquals(1 - _uncoverSlice.transform(sv), epsilon: eps));
        }
        await tester.pumpAndSettle();
        expect(opacityOf(tester, 'b'), 0.0, reason: 'cancel re-covers');
        expect(opacityOf(tester, 't'), 1.0);
        _expectContinuous(s, b);
      });

      testWidgets(
          'a push popped before it finishes stays on the exit slice both '
          'ways', (WidgetTester tester) async {
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          const SizedBox(),
          theme: themeFor(install),
        );
        nav.currentState!
            .push(routeFor<void>(install, (_) => column(<Widget>[item('b')])));
        await tester.pumpAndSettle();
        final ModalRoute<Object?> below = routeOf(tester, 'b');
        nav.currentState!
            .push(routeFor<void>(install, (_) => column(<Widget>[item('t')])));
        await tester.pump();
        final List<double> s = <double>[];
        final List<double> b = <double>[];
        void sample() {
          final double sv = below.secondaryAnimation!.value;
          s.add(sv);
          b.add(opacityOf(tester, 'b'));
          expect(b.last, moreOrLessEquals(1 - coveredAt(sv), epsilon: eps),
              reason: 'S $sv');
        }

        for (int i = 0; i < 7; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          sample();
        }
        final double peak = s.last;
        expect(peak, inExclusiveRange(0.2, 0.35));
        nav.currentState!.pop();
        for (int i = 0; i < 30 && below.secondaryAnimation!.value > 0; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          sample();
        }
        await tester.pumpAndSettle();
        expect(s.reduce((double x, double y) => x > y ? x : y), peak);
        expect(opacityOf(tester, 'b'), 1.0);
        _expectContinuous(s, b);
      });

      testWidgets('a push over the page below while the top page pops',
          (WidgetTester tester) async {
        final _Stack stack = await _twoPages(tester, install);
        stack.nav.currentState!.pop();
        await tester.pump();
        final List<double> s = <double>[];
        final List<double> b = <double>[];
        for (int i = 0; i < 12; i++) {
          await tester.pump(const Duration(microseconds: 16667));
          s.add(stack.below.secondaryAnimation!.value);
          b.add(opacityOf(tester, 'b'));
        }
        expect(s.last, inExclusiveRange(0.4, 0.6));
        expect(b.last, greaterThan(0.0), reason: 'returning');
        stack.nav.currentState!
            .push(routeFor<void>(install, (_) => column(<Widget>[item('n')])));
        for (int i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 8));
          s.add(stack.below.secondaryAnimation!.value);
          b.add(opacityOf(tester, 'b'));
        }
        await tester.pumpAndSettle();
        expect(stack.below.secondaryAnimation!.value, 1.0);
        expect(opacityOf(tester, 'b'), 0.0, reason: 'covered again');
        expect(opacityOf(tester, 'n'), 1.0);
        _expectContinuous(s, b);
      });
    });
  }
}
