// Interactive back, end to end (design §4 swipe-back rows, §8 "Driving
// interactive back without a platform").
//
// The choreography test file already checks one plain element under
// predictive back on CnPageRoute and parted siblings under the stock iOS
// (Cupertino) swipe. These tests add: parted siblings sampled every pump
// against the exact exit-curve formula, both route installs (CnPageRoute,
// and the theme builder over MaterialPageRoute), a cancel that returns to the
// covering state, and the real input paths (platform back-gesture channel,
// edge drag) with each install.
import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

enum Install { cnPageRoute, themeOverMaterial }

Route<void> routeFor(Install install, WidgetBuilder builder) {
  switch (install) {
    case Install.cnPageRoute:
      return CnPageRoute<void>(builder: builder);
    case Install.themeOverMaterial:
      return MaterialPageRoute<void>(builder: builder);
  }
}

/// CnPageRoute must work without touching the theme, so its variant runs
/// under the stock theme.
ThemeData themeFor(
  Install install, {
  TargetPlatform platform = TargetPlatform.android,
}) {
  switch (install) {
    case Install.cnPageRoute:
      return ThemeData(platform: platform);
    case Install.themeOverMaterial:
      return fadeThroughTheme(platform: platform);
  }
}

/// Five 60 px items; tapping one pushes a page holding element 't'.
Widget listPage(Install install, CnRouteTiming timing) => Builder(
      builder: (BuildContext context) => column(<Widget>[
        for (int i = 0; i < 5; i++)
          CnRouteAnimation(
            key: ValueKey<String>('s$i'),
            timing: timing,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                routeFor(install, (_) => column(<Widget>[item('t')])),
              ),
              child: SizedBox(height: 60, child: Text('s$i')),
            ),
          ),
      ]),
    );

class Stack2 {
  Stack2(this.nav, this.below, this.top, this.parted0, this.parted4);
  final GlobalKey<NavigatorState> nav;
  final ModalRoute<Object?> below;
  final ModalRoute<Object?> top;

  /// Fully covered sibling offsets.
  final Offset parted0;
  final Offset parted4;
}

/// Pushes the list page with [install], taps s2 and settles: s2 is the
/// subject, the others are parted.
Future<Stack2> partedStack(
  WidgetTester tester,
  Install install, {
  CnRouteTiming timing = flat,
  TargetPlatform platform = TargetPlatform.android,
  ThemeData? theme,
}) async {
  final GlobalKey<NavigatorState> nav = await pumpApp(
    tester,
    const SizedBox(),
    theme: theme ?? themeFor(install, platform: platform),
  );
  nav.currentState!.push(routeFor(install, (_) => listPage(install, timing)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('s2'));
  await tester.pumpAndSettle();
  final Stack2 stack = Stack2(
    nav,
    routeOf(tester, 's0'),
    routeOf(tester, 't'),
    offsetOf(tester, 's0'),
    offsetOf(tester, 's4'),
  );
  expect(stack.below.secondaryAnimation!.value, 1.0);
  expect(stack.parted0.dy, lessThan(0));
  expect(stack.parted4.dy, greaterThan(0));
  expect(offsetOf(tester, 's2'), Offset.zero);
  return stack;
}

/// Samples the two pages every pump. With [exact] (flat timing) every value
/// must equal the exit-curve formula of the route value at that frame.
class Sampler {
  Sampler(this.tester, this.stack, {required this.exact});

  final WidgetTester tester;
  final Stack2 stack;
  final bool exact;
  final List<double> s = <double>[];
  final List<double> sibling0 = <double>[];
  final List<double> sibling4 = <double>[];
  final List<double> topOpacity = <double>[];

  void sample() {
    final double sv = stack.below.secondaryAnimation!.value;
    s.add(sv);
    sibling0.add(offsetOf(tester, 's0').dy);
    sibling4.add(offsetOf(tester, 's4').dy);
    expect(offsetOf(tester, 's2'), Offset.zero, reason: 'subject stays');
    expect(opacityOf(tester, 's2'), 1.0, reason: 'subject stays');
    if (stack.top.isActive) {
      final double a = stack.top.animation!.value;
      expect(sv, moreOrLessEquals(a, epsilon: eps));
      topOpacity.add(opacityOf(tester, 't'));
      if (exact) {
        // This page leaves on the exit curve whatever the status (forward
        // while dragging and cancelling, reverse after commit).
        expect(topOpacity.last, moreOrLessEquals(shownLeaving(a), epsilon: eps));
      }
    }
    if (exact) {
      final double c = coveredAt(sv);
      expect(sibling0.last, moreOrLessEquals(stack.parted0.dy * c, epsilon: eps));
      expect(sibling4.last, moreOrLessEquals(stack.parted4.dy * c, epsilon: eps));
      expect(opacityOf(tester, 's0'), moreOrLessEquals(1 - c, epsilon: eps));
    }
  }

  /// No jumps: each frame's change is bounded by the route's own change
  /// times the steepest slope of the exit slice (easeIn over 0.35 ≈ 4.9,
  /// times a parting distance ≤ 0.9).
  void expectContinuity() {
    for (int i = 1; i < s.length; i++) {
      final double ds = (s[i] - s[i - 1]).abs();
      for (final List<double> series in <List<double>>[sibling0, sibling4]) {
        expect(
          (series[i] - series[i - 1]).abs(),
          lessThanOrEqualTo(5.0 * ds + 1e-9),
          reason: 'frame $i: S ${s[i - 1]} -> ${s[i]}, '
              'offset ${series[i - 1]} -> ${series[i]}',
        );
      }
    }
  }
}

Future<void> scrubAndCancel(
  WidgetTester tester,
  Stack2 stack,
  Sampler sampler,
) async {
  final ModalRoute<Object?> top = stack.top;
  top.handleStartBackGesture(progress: 1.0);
  await tester.pump();
  sampler.sample();
  // Finger moves in: 0.95 .. 0.05, then partly back out: 0.10, 0.15.
  for (int i = 1; i <= 19; i++) {
    top.handleUpdateBackGestureProgress(progress: 1.0 - 0.05 * i);
    await tester.pump();
    expect(top.animation!.status, AnimationStatus.forward);
    sampler.sample();
  }
  for (int i = 1; i <= 2; i++) {
    top.handleUpdateBackGestureProgress(progress: 0.05 + 0.05 * i);
    await tester.pump();
    sampler.sample();
  }
  final List<double> beforeCancel = List<double>.of(sampler.sibling0);
  top.handleCancelBackGesture();
  // Flutter's cancel uses fastLinearToSlowEaseIn over <= 300 ms, so the
  // route itself moves fast at first: sample at 4 ms to see the shape.
  for (int i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 4));
    sampler.sample();
  }
  await tester.pumpAndSettle();
  sampler.sample();
  // The cancel returns to fully covered, moving one way only.
  expect(stack.below.secondaryAnimation!.value, 1.0);
  expect(offsetOf(tester, 's0').dy, moreOrLessEquals(stack.parted0.dy));
  expect(offsetOf(tester, 's4').dy, moreOrLessEquals(stack.parted4.dy));
  expect(opacityOf(tester, 't'), 1.0);
  final List<double> afterCancel =
      sampler.sibling0.sublist(beforeCancel.length - 1);
  for (int i = 1; i < afterCancel.length; i++) {
    // s0 parts upward (negative): cancelling moves it monotonically up.
    expect(afterCancel[i], lessThanOrEqualTo(afterCancel[i - 1] + eps));
  }
  expect(
    afterCancel.where((double v) => v > stack.parted0.dy + eps).length,
    greaterThanOrEqualTo(3),
    reason: 'the cancel is spread over several frames',
  );
}

Future<void> scrubAndCommit(
  WidgetTester tester,
  Stack2 stack,
  Sampler sampler,
) async {
  final ModalRoute<Object?> top = stack.top;
  top.handleStartBackGesture(progress: 1.0);
  await tester.pump();
  for (int i = 1; i <= 6; i++) {
    top.handleUpdateBackGestureProgress(progress: 1.0 - 0.05 * i);
    await tester.pump();
    sampler.sample();
  }
  top.handleCommitBackGesture();
  await tester.pump();
  sampler.sample();
  for (int i = 0; i < 60 && top.isActive; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    sampler.sample();
  }
  await tester.pumpAndSettle();
  sampler.sample();
  for (final String label in <String>['s0', 's1', 's2', 's3', 's4']) {
    expect(offsetOf(tester, label), Offset.zero, reason: label);
    expect(opacityOf(tester, label), 1.0, reason: label);
  }
}

void main() {
  for (final Install install in Install.values) {
    group('predictive back API, ${install.name}', () {
      testWidgets(
          'scrub then cancel: parted siblings track the exit curve every '
          'frame and the cancel returns smoothly', (WidgetTester tester) async {
        final Stack2 stack = await partedStack(tester, install);
        final Sampler sampler = Sampler(tester, stack, exact: true);
        await scrubAndCancel(tester, stack, sampler);
        sampler.expectContinuity();
        expect(sampler.s.reduce((double a, double b) => a < b ? a : b),
            moreOrLessEquals(0.05));
      });

      testWidgets('scrub then commit: siblings return to rest without a jump',
          (WidgetTester tester) async {
        final Stack2 stack = await partedStack(tester, install);
        final Sampler sampler = Sampler(tester, stack, exact: true);
        await scrubAndCommit(tester, stack, sampler);
        sampler.expectContinuity();
      });

      testWidgets('default (staggered) timing: still continuous both ways',
          (WidgetTester tester) async {
        final Stack2 stack = await partedStack(
          tester,
          install,
          timing: CnRouteTiming.standard,
        );
        final Sampler sampler = Sampler(tester, stack, exact: false);
        await scrubAndCancel(tester, stack, sampler);
        sampler.expectContinuity();
        final Sampler commit = Sampler(tester, stack, exact: false);
        await scrubAndCommit(tester, stack, commit);
        commit.expectContinuity();
      });
    });
  }

  group('real input paths', () {
    testWidgets(
        'control: the system back-gesture channel scrubs the elements under '
        "Flutter's PredictiveBackPageTransitionsBuilder",
        (WidgetTester tester) async {
      final Stack2 stack = await partedStack(
        tester,
        Install.themeOverMaterial,
        theme: ThemeData(
          platform: TargetPlatform.android,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: <TargetPlatform, PageTransitionsBuilder>{
              TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
            },
          ),
        ),
      );
      await sendBackGesture(tester, 'startBackGesture');
      await tester.pump();
      await sendBackGesture(tester, 'updateBackGestureProgress', progress: 0.7);
      await tester.pump();
      expect(stack.top.animation!.value, moreOrLessEquals(0.3));
      expect(offsetOf(tester, 's0').dy, greaterThan(stack.parted0.dy));
      await sendBackGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(offsetOf(tester, 's0').dy, moreOrLessEquals(stack.parted0.dy));
    });

    for (final Install install in Install.values) {
      testWidgets(
        'the system back-gesture channel scrubs the elements, ${install.name}',
        (WidgetTester tester) async {
          final Stack2 stack = await partedStack(tester, install);
          await sendBackGesture(tester, 'startBackGesture');
          await tester.pump();
          await sendBackGesture(
            tester,
            'updateBackGestureProgress',
            progress: 0.5,
          );
          await tester.pump();
          expect(stack.top.animation!.value, lessThan(1.0),
              reason: 'nothing routes the system gesture to the route');
          expect(offsetOf(tester, 's0').dy, greaterThan(stack.parted0.dy));
        },
        // BUG: the Cn fade-through has no predictive-back hookup; the system
        // gesture is ignored and commit becomes a plain 400 ms pop.
        skip: !runBugs,
      );

      testWidgets(
        'iOS edge drag scrubs the elements, ${install.name}',
        (WidgetTester tester) async {
          final Stack2 stack = await partedStack(
            tester,
            install,
            platform: TargetPlatform.iOS,
          );
          final TestGesture gesture = await tester.startGesture(
            const Offset(5, 300),
          );
          await tester.pump();
          for (int i = 0; i < 3; i++) {
            await gesture.moveBy(const Offset(100, 0));
            await tester.pump();
          }
          expect(stack.nav.currentState!.userGestureInProgress, isTrue);
          expect(stack.top.animation!.value, lessThan(1.0));
          expect(offsetOf(tester, 's0').dy, greaterThan(stack.parted0.dy));
          await gesture.up();
          await tester.pumpAndSettle();
        },
        // BUG: the Cn fade-through has no Cupertino back-swipe detector;
        // an iOS edge drag does nothing.
        skip: !runBugs,
      );
    }
  });
}
