// Choreography claims (design §3.4 timing and stagger, §3.5 parting, §3.6
// mounts at rest, §5 zero-duration routes, §8 "Choreography claims"; README
// "Parting around the tapped item" and "Reduced motion").
import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Default timing (CnRouteTiming.standard), spelled out for the formulas.
const double exitStagger = 0.12;
const double enterStagger = 0.25;
const double viewportHeight = 600; // the test surface is 800 x 600

/// Stagger factor of item [i] (100 px tall) in a list filling the screen:
/// distance of its center from [anchor] over the viewport height, or 1 when
/// it is laid out outside the viewport.
double factorOf(int i, {double anchor = 0}) {
  final double top = 100.0 * i;
  if (top >= viewportHeight) return 1.0;
  return ((top + 50 - anchor).abs() / viewportHeight).clamp(0.0, 1.0);
}

double coveredWith(double f, double s) => Interval(
      f * exitStagger,
      0.35 + f * exitStagger,
      curve: Curves.easeIn,
    ).transform(s);

double enteredWith(double f, double a) => Interval(
      0.35 + f * enterStagger,
      1.0,
      curve: Curves.easeOutCubic,
    ).transform(a);

/// A 200-item list of 100 px items with the default (staggered) timing.
Widget longList({void Function(BuildContext context)? onTap}) => Builder(
      builder: (BuildContext context) => ListView.builder(
        itemCount: 200,
        itemExtent: 100,
        itemBuilder: (BuildContext context, int i) => item(
          'L$i',
          timing: null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap(context),
            child: SizedBox(height: 100, child: Text('L$i')),
          ),
        ),
      ),
    );

/// The items of [longList] that exist (built, on screen or in the cache
/// extent).
List<int> builtItems() => <int>[
      for (int i = 0; i < 200; i++)
        if (exists('L$i')) i,
    ];

void pushBlank(BuildContext context) => Navigator.of(context).push(
      CnPageRoute<void>(builder: (_) => const SizedBox()),
    );

void main() {
  group('stagger bound (§3.4)', () {
    testWidgets(
        'a 200-item list: only the built items animate, each on its own '
        'geometric slice, and all are covered by S = exit.end + exitStagger',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
        theme: themeFor(Install.cnPageRoute),
      );
      nav.currentState!.push(CnPageRoute<void>(builder: (_) => longList()));
      await tester.pumpAndSettle();
      // 6 on screen plus the cache extent: the list length does not matter.
      final List<int> built = builtItems();
      expect(built, <int>[for (int i = 0; i < 9; i++) i]);
      final ModalRoute<Object?> page = routeOf(tester, 'L0');
      for (final int i in built) {
        expect(opacityOf(tester, 'L$i'), 1.0, reason: 'L$i at rest');
        expect(offsetOf(tester, 'L$i'), Offset.zero, reason: 'L$i at rest');
      }

      // Programmatic push: no subject, every item exits as a plain element
      // staggered from the viewport's top edge.
      nav.currentState!
          .push(CnPageRoute<void>(builder: (_) => const SizedBox()));
      await tester.pump();
      final Map<int, double> exitStart = <int, double>{};
      double previousS = 0;
      while (!page.secondaryAnimation!.isCompleted) {
        await tester.pump(const Duration(milliseconds: 8));
        final double s = page.secondaryAnimation!.value;
        for (final int i in built) {
          final double c = coveredWith(factorOf(i), s);
          expect(
              opacityOf(tester, 'L$i'), moreOrLessEquals(1 - c, epsilon: eps),
              reason: 'L$i at S = $s');
          expect(offsetOf(tester, 'L$i'),
              offsetMoreOrLessEquals(Offset(0, -0.1 * c), epsilon: eps),
              reason: 'L$i at S = $s');
          if (opacityOf(tester, 'L$i') < 1.0) {
            exitStart.putIfAbsent(i, () => previousS);
          }
          if (s >= 0.35 + exitStagger) {
            expect(opacityOf(tester, 'L$i'), 0.0, reason: 'L$i done by 0.47');
          }
        }
        previousS = s;
      }
      // Nearer the top starts first, and nothing starts after exitStagger.
      for (final int i in built) {
        expect(exitStart[i], lessThanOrEqualTo(exitStagger), reason: 'L$i');
        if (i > 0) {
          expect(exitStart[i], greaterThanOrEqualTo(exitStart[i - 1]!),
              reason: 'L$i');
        }
      }

      nav.currentState!.pop();
      await tester.pumpAndSettle();
      for (final int i in built) {
        expect(opacityOf(tester, 'L$i'), 1.0, reason: 'L$i back at rest');
        expect(offsetOf(tester, 'L$i'), Offset.zero, reason: 'L$i');
      }
    });

    testWidgets(
        'a 200-item list: off-screen built items part with f = 1 (the '
        'farthest distance) and nearer siblings part less',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
        theme: themeFor(Install.cnPageRoute),
      );
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => longList(onTap: pushBlank)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('L2'));
      await tester.pumpAndSettle();
      expect(offsetOf(tester, 'L2'), Offset.zero);
      expect(opacityOf(tester, 'L2'), 1.0);
      for (final int i in builtItems()) {
        if (i == 2) continue;
        // distance 0.6 grown by distanceGrowth 0.5 times f.
        final double magnitude = 0.6 * (1 + 0.5 * factorOf(i, anchor: 250));
        expect(
          offsetOf(tester, 'L$i'),
          offsetMoreOrLessEquals(
            Offset(0, (i < 2 ? -1 : 1) * magnitude),
            epsilon: eps,
          ),
          reason: 'L$i',
        );
        expect(opacityOf(tester, 'L$i'), 0.0, reason: 'L$i fades');
      }
      // Off-screen items (6, 7, 8) use f = 1: 0.6 x 1.5.
      expect(offsetOf(tester, 'L7').dy, moreOrLessEquals(0.9));
    });

    testWidgets(
        'entrance: each built item enters on its geometric slice, the '
        'farthest by enter.begin + enterStagger, and all rest when A = 1',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
        theme: themeFor(Install.cnPageRoute),
      );
      nav.currentState!.push(CnPageRoute<void>(builder: (_) => longList()));
      await tester.pump();
      final ModalRoute<Object?> page = routeOf(tester, 'L0');
      final List<int> built = builtItems();
      expect(built, hasLength(9));
      while (!page.animation!.isCompleted) {
        await tester.pump(const Duration(milliseconds: 8));
        final double a = page.animation!.value;
        for (final int i in built) {
          expect(
            opacityOf(tester, 'L$i'),
            moreOrLessEquals(enteredWith(factorOf(i), a), epsilon: eps),
            reason: 'L$i at A = $a',
          );
          if (a > 0.35 + enterStagger) {
            expect(opacityOf(tester, 'L$i'), greaterThan(0.0), reason: 'L$i');
          }
        }
      }
      for (final int i in built) {
        expect(opacityOf(tester, 'L$i'), 1.0, reason: 'L$i');
        expect(offsetOf(tester, 'L$i'), Offset.zero, reason: 'L$i');
      }
    });
  });

  group('parting via tap on a CnPageRoute page (README, §3.5)', () {
    /// Nine 60 px items; a tap pushes the route made by [next].
    Widget partingList(Route<void> Function() next) => Builder(
          builder: (BuildContext context) => ListView.builder(
            itemCount: 9,
            itemExtent: 60,
            itemBuilder: (BuildContext context, int i) => item(
              'p$i',
              timing: null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).push(next()),
                child: SizedBox(height: 60, child: Text('p$i')),
              ),
            ),
          ),
        );

    void expectParted(WidgetTester tester) {
      expect(offsetOf(tester, 'p4'), Offset.zero);
      expect(opacityOf(tester, 'p4'), 1.0);
      double previous = 0;
      for (int i = 3; i >= 0; i--) {
        final Offset o = offsetOf(tester, 'p$i');
        expect(o.dx, 0, reason: 'p$i');
        expect(o.dy, lessThan(-previous), reason: 'p$i moves up, farther');
        previous = o.dy.abs();
      }
      previous = 0;
      for (int i = 5; i < 9; i++) {
        final Offset o = offsetOf(tester, 'p$i');
        expect(o.dx, 0, reason: 'p$i');
        expect(o.dy, greaterThan(previous), reason: 'p$i moves down, farther');
        previous = o.dy;
      }
    }

    final Map<String, Route<void> Function()> nextRoutes =
        <String, Route<void> Function()>{
      'CnPageRoute': () => CnPageRoute<void>(builder: (_) => const SizedBox()),
      'a stock MaterialPageRoute': () =>
          MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    };

    for (final MapEntry<String, Route<void> Function()> next
        in nextRoutes.entries) {
      testWidgets('list: tapping item 4 of 9 and pushing ${next.key}',
          (WidgetTester tester) async {
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          const SizedBox(),
          theme: themeFor(Install.cnPageRoute),
        );
        nav.currentState!.push(
          CnPageRoute<void>(builder: (_) => partingList(next.value)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('p4'));
        await tester.pump();
        // Mid-cover: nearer siblings are ahead of farther ones.
        await tester.pump(const Duration(milliseconds: 60));
        expect(opacityOf(tester, 'p3'), lessThan(opacityOf(tester, 'p0')));
        expect(opacityOf(tester, 'p5'), lessThan(opacityOf(tester, 'p8')));
        expect(offsetOf(tester, 'p4'), Offset.zero);
        await tester.pumpAndSettle();
        expectParted(tester);
        nav.currentState!.pop();
        await tester.pumpAndSettle();
        for (int i = 0; i < 9; i++) {
          expect(offsetOf(tester, 'p$i'), Offset.zero, reason: 'p$i');
          expect(opacityOf(tester, 'p$i'), 1.0, reason: 'p$i');
        }
      });
    }

    testWidgets('grid: same-row cells part sideways, other rows vertically',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
        theme: themeFor(Install.cnPageRoute),
      );
      nav.currentState!.push(
        CnPageRoute<void>(
          builder: (BuildContext context) => GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 2,
            children: <Widget>[
              for (int i = 0; i < 9; i++)
                item(
                  'g$i',
                  timing: null,
                  child: Builder(
                    builder: (BuildContext cell) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => pushBlank(cell),
                      child: Center(child: Text('g$i')),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('g4'));
      await tester.pumpAndSettle();
      expect(offsetOf(tester, 'g4'), Offset.zero);
      expect(opacityOf(tester, 'g4'), 1.0);
      expect(offsetOf(tester, 'g3').dx, lessThan(0));
      expect(offsetOf(tester, 'g3').dy, 0);
      expect(offsetOf(tester, 'g5').dx, greaterThan(0));
      expect(offsetOf(tester, 'g5').dy, 0);
      for (final int i in <int>[0, 1, 2]) {
        expect(offsetOf(tester, 'g$i').dx, 0, reason: 'g$i');
        expect(offsetOf(tester, 'g$i').dy, lessThan(0), reason: 'g$i');
      }
      for (final int i in <int>[6, 7, 8]) {
        expect(offsetOf(tester, 'g$i').dx, 0, reason: 'g$i');
        expect(offsetOf(tester, 'g$i').dy, greaterThan(0), reason: 'g$i');
      }
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      for (int i = 0; i < 9; i++) {
        expect(offsetOf(tester, 'g$i'), Offset.zero, reason: 'g$i');
      }
    });
  });

  group('mounts at rest (§3.6, §5 zero-duration)', () {
    testWidgets(
        'zero-duration push: the page below snaps covered in one frame and '
        'back on pop; the new page plays the timed entrance',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        column(<Widget>[item('h')]),
      );
      await tester.pumpAndSettle();
      final ModalRoute<Object?> home = routeOf(tester, 'h');
      nav.currentState!.push(
        _InstantMaterialRoute(builder: (_) => column(<Widget>[item('z')])),
      );
      await tester.pump();
      expect(home.secondaryAnimation!.value, 1.0);
      expect(opacityOf(tester, 'h'), 0.0);
      expect(offsetOf(tester, 'h'), const Offset(0, -0.1));
      // The new page is at rest from its first frame: an initial mount.
      expect(routeOf(tester, 'z').animation!.value, 1.0);
      expect(opacityOf(tester, 'z'), 0.0);
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacityOf(tester, 'z'), greaterThan(0.0));
      expect(opacityOf(tester, 'z'), lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacityOf(tester, 'z'), 1.0);
      expect(offsetOf(tester, 'z'), Offset.zero);

      nav.currentState!.pop();
      await tester.pump();
      expect(home.secondaryAnimation!.value, 0.0);
      expect(opacityOf(tester, 'h'), 1.0);
      expect(offsetOf(tester, 'h'), Offset.zero);
      expect(exists('z'), isFalse);
    });

    Widget growingPage(ValueNotifier<int> count) => ValueListenableBuilder<int>(
          valueListenable: count,
          builder: (_, int n, _) => column(<Widget>[
            for (int i = 0; i < n; i++) item('m$i'),
          ]),
        );

    for (final bool reveal in <bool>[false, true]) {
      testWidgets(
          'an element added to a page at rest '
          '${reveal ? 'reveals once with scrollReveal' : 'renders at rest'}',
          (WidgetTester tester) async {
        final ValueNotifier<int> count = ValueNotifier<int>(1);
        addTearDown(count.dispose);
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          const SizedBox(),
          builder: reveal
              ? (_, Widget? child) => CnRouteChoreography(
                    scrollReveal: const CnScrollReveal(),
                    child: child!,
                  )
              : null,
        );
        nav.currentState!.push(
          CnPageRoute<void>(builder: (_) => growingPage(count)),
        );
        await tester.pumpAndSettle();
        count.value = 2;
        await tester.pump();
        if (!reveal) {
          expect(opacityOf(tester, 'm1'), 1.0);
          expect(offsetOf(tester, 'm1'), Offset.zero);
          return;
        }
        expect(opacityOf(tester, 'm1'), 0.0);
        expect(offsetOf(tester, 'm1'), const Offset(0, 0.1));
        expect(opacityOf(tester, 'm0'), 1.0, reason: 'only the new one');
        await tester.pump(const Duration(milliseconds: 300));
        expect(opacityOf(tester, 'm1'), 1.0);
        expect(offsetOf(tester, 'm1'), Offset.zero);
        // A rebuild does not replay it.
        count.value = 3;
        await tester.pump();
        expect(opacityOf(tester, 'm1'), 1.0);
      });
    }
  });

  group('reduced motion (README "Reduced motion", §4 rows)', () {
    /// Wraps the app in `disableAnimations` from [reduce], under [scope].
    TransitionBuilder reducedApp(
      ValueListenable<bool> reduce, {
      Widget Function(Widget child)? scope,
    }) =>
        (BuildContext context, Widget? child) => ValueListenableBuilder<bool>(
              valueListenable: reduce,
              builder: (BuildContext context, bool on, _) {
                final Widget reduced = MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: on),
                  child: child!,
                );
                return scope == null ? reduced : scope(reduced);
              },
            );

    Widget scaled(String label, {CnReducedMotionMode? mode}) =>
        CnRouteAnimation(
          key: ValueKey<String>(label),
          timing: flat,
          scale: 0.9,
          reducedMotionMode: mode,
          child: SizedBox(height: 100, child: Text(label)),
        );

    /// Home with h0 and a tappable h1 (pushes a page holding 'n').
    Widget home() => Builder(
          builder: (BuildContext context) => column(<Widget>[
            scaled('h0'),
            item(
              'h1',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).push(
                  CnPageRoute<void>(
                    builder: (_) => column(<Widget>[scaled('n')]),
                  ),
                ),
                child: const SizedBox(height: 100, child: Text('h1')),
              ),
            ),
          ]),
        );

    /// Initial entrance, a tap-push that parts the home page, and a pop,
    /// calling [check] after every pump.
    Future<void> journey(WidgetTester tester, void Function() check) async {
      check();
      await pumpFrames(tester, 20, each: (_) => check());
      await tester.pumpAndSettle();
      check();
      await tester.tap(find.text('h1'));
      await tester.pump();
      await pumpFrames(tester, 30, each: (_) => check());
      await tester.pumpAndSettle();
      check();
      final NavigatorState nav = tester.state(find.byType(Navigator));
      nav.pop();
      await tester.pump();
      await pumpFrames(tester, 30, each: (_) => check());
      await tester.pumpAndSettle();
      check();
    }

    List<String> present() => <String>[
          for (final String label in <String>['h0', 'h1', 'n'])
            if (exists(label)) label,
        ];

    testWidgets(
        'fadeOnly (default): no translation or scale at any pump, while '
        'opacity follows the route', (WidgetTester tester) async {
      final ValueNotifier<bool> reduce = ValueNotifier<bool>(true);
      addTearDown(reduce.dispose);
      await pumpApp(tester, home(), builder: reducedApp(reduce));
      bool sawPartial = false;
      await journey(tester, () {
        for (final String label in present()) {
          expect(offsetOf(tester, label), Offset.zero, reason: label);
          if (label != 'h1') {
            expect(scaleOf(tester, label), 1.0, reason: label);
          }
          final double o = opacityOf(tester, label);
          if (o > 0.05 && o < 0.95) sawPartial = true;
        }
        if (exists('n')) {
          final ModalRoute<Object?> top = routeOf(tester, 'n');
          final ModalRoute<Object?> below = routeOf(tester, 'h0');
          final double s = below.secondaryAnimation!.value;
          // h1 is the tapped subject; h0 a sibling that still fades.
          expect(opacityOf(tester, 'h1'), 1.0);
          // Pushed: the cover left 0 (exit slice). Popping: it left 1
          // (uncover slice).
          final double covered =
              top.animation!.status == AnimationStatus.reverse
                  ? uncoveredAt(s)
                  : coveredAt(s);
          expect(opacityOf(tester, 'h0'),
              moreOrLessEquals(1 - covered, epsilon: eps));
          final double a = top.animation!.value;
          final double expected =
              top.animation!.status == AnimationStatus.reverse
                  ? shownLeaving(a)
                  : shownEntering(a);
          expect(
              opacityOf(tester, 'n'), moreOrLessEquals(expected, epsilon: eps));
        }
      });
      expect(sawPartial, isTrue, reason: 'opacity still animates');
    });

    testWidgets('none: every element at rest at every pump',
        (WidgetTester tester) async {
      final ValueNotifier<bool> reduce = ValueNotifier<bool>(true);
      addTearDown(reduce.dispose);
      await pumpApp(
        tester,
        home(),
        builder: reducedApp(
          reduce,
          scope: (Widget child) => CnRouteChoreography(
            reducedMotionMode: CnReducedMotionMode.none,
            child: child,
          ),
        ),
      );
      await journey(tester, () {
        for (final String label in present()) {
          expect(opacityOf(tester, label), 1.0, reason: label);
          expect(offsetOf(tester, label), Offset.zero, reason: label);
          if (label != 'h1') {
            expect(scaleOf(tester, label), 1.0, reason: label);
          }
        }
      });
    });

    /// Pushes a page holding 'p' (mode [widgetMode]) and returns its
    /// opacity and offset at A = 0.5.
    Future<(double, Offset)> midPush(
      WidgetTester tester, {
      required Widget Function(Widget child) scope,
      CnReducedMotionMode? widgetMode,
    }) async {
      final ValueNotifier<bool> reduce = ValueNotifier<bool>(true);
      addTearDown(reduce.dispose);
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
        builder: reducedApp(reduce, scope: scope),
      );
      nav.currentState!.push(
        CnPageRoute<void>(
          builder: (_) => column(<Widget>[scaled('p', mode: widgetMode)]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(routeOf(tester, 'p').animation!.value, moreOrLessEquals(0.5));
      return (opacityOf(tester, 'p'), offsetOf(tester, 'p'));
    }

    testWidgets('mode precedence: widget fadeOnly beats scope none',
        (WidgetTester tester) async {
      final (double opacity, Offset offset) = await midPush(
        tester,
        scope: (Widget child) => CnRouteChoreography(
          reducedMotionMode: CnReducedMotionMode.none,
          child: child,
        ),
        widgetMode: CnReducedMotionMode.fadeOnly,
      );
      expect(opacity, moreOrLessEquals(shownEntering(0.5), epsilon: 1e-3));
      expect(opacity, lessThan(1.0));
      expect(offset, Offset.zero);
    });

    testWidgets('mode precedence: widget none beats the default fadeOnly',
        (WidgetTester tester) async {
      final (double opacity, Offset offset) = await midPush(
        tester,
        scope: (Widget child) => child,
        widgetMode: CnReducedMotionMode.none,
      );
      expect(opacity, 1.0);
      expect(offset, Offset.zero);
    });

    testWidgets(
        'nested scopes merge field by field: inner respectReducedMotion '
        'with the outer mode', (WidgetTester tester) async {
      final (double opacity, Offset offset) = await midPush(
        tester,
        scope: (Widget child) => CnRouteChoreography(
          respectReducedMotion: false,
          reducedMotionMode: CnReducedMotionMode.none,
          child: CnRouteChoreography(respectReducedMotion: true, child: child),
        ),
      );
      expect(opacity, 1.0, reason: 'inner respects it, outer mode is none');
      expect(offset, Offset.zero);
    });

    testWidgets('the outer scope alone opts out: full motion',
        (WidgetTester tester) async {
      final (double opacity, Offset offset) = await midPush(
        tester,
        scope: (Widget child) => CnRouteChoreography(
          respectReducedMotion: false,
          reducedMotionMode: CnReducedMotionMode.none,
          child: child,
        ),
      );
      expect(opacity, lessThan(1.0));
      expect(offset.dy, greaterThan(0));
    });

    testWidgets(
        'toggling disableAnimations mid-transition switches at once, keeps '
        'following progress and keeps the child State',
        (WidgetTester tester) async {
      final ValueNotifier<bool> reduce = ValueNotifier<bool>(false);
      addTearDown(reduce.dispose);
      final List<State> states = <State>[];
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
        builder: reducedApp(reduce),
      );
      nav.currentState!.push(
        CnPageRoute<void>(
          builder: (_) => column(<Widget>[
            item('t', child: _StateProbe(states)),
          ]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      final ModalRoute<Object?> route = routeOf(tester, 't');
      void expectMotion({required bool reduced}) {
        final double shown = shownEntering(route.animation!.value);
        expect(opacityOf(tester, 't'), moreOrLessEquals(shown, epsilon: eps));
        expect(
          offsetOf(tester, 't'),
          offsetMoreOrLessEquals(
            reduced ? Offset.zero : Offset(0, 0.1 * (1 - shown)),
            epsilon: eps,
          ),
        );
      }

      expectMotion(reduced: false);
      expect(offsetOf(tester, 't').dy, greaterThan(0));
      reduce.value = true;
      await tester.pump();
      expectMotion(reduced: true);
      await tester.pump(const Duration(milliseconds: 40));
      expectMotion(reduced: true);
      reduce.value = false;
      await tester.pump();
      expectMotion(reduced: false);
      expect(offsetOf(tester, 't').dy, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(opacityOf(tester, 't'), 1.0);
      expect(states, hasLength(1), reason: 'the child was never rebuilt anew');
      expect(tester.state(find.byType(_StateProbe)), same(states.single));
    });
  });
}

/// Records every State it creates.
class _StateProbe extends StatefulWidget {
  const _StateProbe(this.states);

  final List<State> states;

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.states.add(this);
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 100, child: Text('t'));
}

/// A Material route with no transition time (some apps use one for tabs).
class _InstantMaterialRoute extends MaterialPageRoute<void> {
  _InstantMaterialRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}
