import 'package:cn_animations/src/choreography/cn_route_animation.dart';
import 'package:cn_animations/src/choreography/cn_route_choreography.dart';
import 'package:cn_animations/src/progress/route_progress.dart';
import 'package:cn_animations/src/route/cn_fade_through_page_transitions_builder.dart';
import 'package:cn_animations/src/route/cn_page_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// No stagger, so expected values are exact functions of route progress.
const CnRouteTiming flat = CnRouteTiming(exitStagger: 0, enterStagger: 0);

const Interval enterSlice = Interval(0.35, 1.0, curve: Curves.easeOutCubic);
const Interval exitSlice = Interval(0.0, 0.35, curve: Curves.easeIn);

/// shown while this page enters (A rising from 0).
double shownEntering(double a) => enterSlice.transform(a);

/// shown while this page leaves (A falling from 1): the exit slice measured
/// from the start of leaving.
double shownLeaving(double a) => 1.0 - exitSlice.transform(1.0 - a);

/// covered while S rises from 0 (a page pushed over this one), or falls back
/// to 0 without having reached 1 (that push reversed).
double coveredAt(double s) => exitSlice.transform(s);

/// The default uncover slice (review R6), with the exit curve.
const Interval uncoverSlice = Interval(0.3, 0.65, curve: Curves.easeIn);

/// covered while S falls from 1 (the page above pops or is dragged back),
/// including a cancelled gesture climbing back to 1.
double uncoveredAt(double s) => uncoverSlice.transform(s);

/// Every platform uses the fade-through, so the page below holds still and
/// geometry is untransformed.
ThemeData fadeThroughTheme() => ThemeData(
  platform: TargetPlatform.android,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CnFadeThroughPageTransitionsBuilder(),
      TargetPlatform.iOS: CnFadeThroughPageTransitionsBuilder(),
      TargetPlatform.macOS: CnFadeThroughPageTransitionsBuilder(),
      TargetPlatform.linux: CnFadeThroughPageTransitionsBuilder(),
      TargetPlatform.windows: CnFadeThroughPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CnFadeThroughPageTransitionsBuilder(),
    },
  ),
);

Finder _own<T>(String label) =>
    find
        .descendant(
          of: find.byKey(ValueKey<String>(label), skipOffstage: false),
          matching: find.byType(T, skipOffstage: false),
        )
        .first;

/// The element's own fade (the first FadeTransition below the widget).
double opacityOf(WidgetTester tester, String label) =>
    tester.widget<FadeTransition>(_own<FadeTransition>(label)).opacity.value;

/// The element's own slide, as a fraction of its size.
Offset offsetOf(WidgetTester tester, String label) =>
    tester.widget<SlideTransition>(_own<SlideTransition>(label)).position.value;

double scaleOf(WidgetTester tester, String label) =>
    tester.widget<ScaleTransition>(_own<ScaleTransition>(label)).scale.value;

ModalRoute<Object?> routeOf(WidgetTester tester, String label) =>
    ModalRoute.of(
      tester.element(find.byKey(ValueKey<String>(label), skipOffstage: false)),
    )!;

/// A 100 px tall element.
Widget item(
  String label, {
  CnRouteTiming? timing = flat,
  bool enabled = true,
  bool? subject,
  bool? respectReducedMotion,
  CnReducedMotionMode? reducedMotionMode,
  CnRouteAnimationBuilder? builder,
  Widget? child,
  double height = 100,
}) {
  return CnRouteAnimation(
    key: ValueKey<String>(label),
    timing: timing,
    enabled: enabled,
    subject: subject,
    respectReducedMotion: respectReducedMotion,
    reducedMotionMode: reducedMotionMode,
    builder: builder,
    child: child ?? SizedBox(height: height, child: Text(label)),
  );
}

Widget page(List<Widget> children) =>
    Column(mainAxisSize: MainAxisSize.min, children: children);

/// Records the creation of timed fallback controllers (debug label
/// `CnTimedFallback`, set by the progress foundation).
class FallbackControllerTracker {
  final List<AnimationController> created = <AnimationController>[];

  void _listener(ObjectEvent event) {
    final Object object = event.object;
    if (event is ObjectCreated &&
        object is AnimationController &&
        object.debugLabel == 'CnTimedFallback') {
      created.add(object);
    }
  }

  void start() => FlutterMemoryAllocations.instance.addListener(_listener);
  void stop() => FlutterMemoryAllocations.instance.removeListener(_listener);
}

Future<GlobalKey<NavigatorState>> pumpApp(
  WidgetTester tester,
  Widget home, {
  TransitionBuilder? builder,
  ThemeData? theme,
}) async {
  final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      theme: theme ?? fadeThroughTheme(),
      builder: builder,
      home: home,
    ),
  );
  return nav;
}

const double eps = 1e-6;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('route progress (§4 rows)', () {
    testWidgets('push: elements follow animation over the enter slice', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
      );
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => page(<Widget>[item('a')])),
      );
      await tester.pump(); // first frame of the push (Hero measuring frame)
      final ModalRoute<Object?> route = routeOf(tester, 'a');
      bool sawMidway = false;
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        final double a = route.animation!.value;
        final double shown = shownEntering(a);
        expect(opacityOf(tester, 'a'), moreOrLessEquals(shown, epsilon: eps));
        expect(
          offsetOf(tester, 'a'),
          offsetMoreOrLessEquals(Offset(0, 0.1 * (1 - shown)), epsilon: eps),
        );
        if (shown > 0.05 && shown < 0.95) sawMidway = true;
      }
      expect(sawMidway, isTrue);
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'a'), 1.0);
      expect(offsetOf(tester, 'a'), Offset.zero);
    });

    testWidgets('push: enterOffset defaults to entering from below', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
      );
      nav.currentState!.push(
        CnPageRoute<void>(
          builder:
              (_) => const CnRouteAnimation(
                key: ValueKey<String>('d'),
                child: SizedBox(height: 50),
              ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(offsetOf(tester, 'd').dy, greaterThan(0));
      expect(offsetOf(tester, 'd').dx, 0);
    });

    testWidgets('push: stagger starts the top element before a lower one', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
      );
      nav.currentState!.push(
        CnPageRoute<void>(
          builder:
              (_) => page(<Widget>[
                item('top', timing: null),
                const SizedBox(height: 350),
                item('low', timing: null),
              ]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 200));
      final double top = opacityOf(tester, 'top');
      final double low = opacityOf(tester, 'low');
      expect(top, greaterThan(0.0));
      expect(low, lessThan(top));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'low'), 1.0);
      expect(opacityOf(tester, 'top'), 1.0);
    });

    testWidgets('pop: elements leave over the exit slice, measured from the '
        'start of leaving', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
      );
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => page(<Widget>[item('a')])),
      );
      await tester.pumpAndSettle();
      final ModalRoute<Object?> route = routeOf(tester, 'a');
      nav.currentState!.pop();
      await tester.pump();
      bool sawMidway = false;
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        final double a = route.animation!.value;
        expect(route.animation!.status, AnimationStatus.reverse);
        final double shown = shownLeaving(a);
        expect(opacityOf(tester, 'a'), moreOrLessEquals(shown, epsilon: eps));
        expect(
          offsetOf(tester, 'a'),
          offsetMoreOrLessEquals(Offset(0, 0.1 * (1 - shown)), epsilon: eps),
        );
        if (shown > 0.05 && shown < 0.95) sawMidway = true;
      }
      expect(sawMidway, isTrue);
      // The exit is fast: gone once 35 % of the pop has elapsed.
      await tester.pump(const Duration(milliseconds: 40));
      expect(route.animation!.value, lessThan(0.65));
      expect(opacityOf(tester, 'a'), 0.0);
    });

    testWidgets(
      'cover then uncover: plain elements move up to the mirrored exitOffset '
      'and return from above',
      (WidgetTester tester) async {
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          page(<Widget>[item('h')]),
        );
        await tester.pumpAndSettle(); // initial entrance done
        final ModalRoute<Object?> home = routeOf(tester, 'h');
        nav.currentState!.push(
          CnPageRoute<void>(builder: (_) => const SizedBox()),
        );
        await tester.pump();
        bool sawMidway = false;
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          final double s = home.secondaryAnimation!.value;
          final double covered = coveredAt(s);
          expect(
            opacityOf(tester, 'h'),
            moreOrLessEquals(1 - covered, epsilon: eps),
          );
          expect(
            offsetOf(tester, 'h'),
            offsetMoreOrLessEquals(Offset(0, -0.1 * covered), epsilon: eps),
          );
          if (covered > 0.05 && covered < 0.95) sawMidway = true;
        }
        expect(sawMidway, isTrue);
        await tester.pumpAndSettle();
        expect(home.secondaryAnimation!.value, 1.0);
        expect(opacityOf(tester, 'h'), 0.0);
        // Default exitOffset mirrors enterOffset: covered content moves up.
        expect(offsetOf(tester, 'h'), const Offset(0, -0.1));

        nav.currentState!.pop();
        await tester.pump();
        sawMidway = false;
        for (int i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 30));
          final double s = home.secondaryAnimation!.value;
          // S falls from 1: the uncover slice, not the exit slice backwards.
          final double covered = uncoveredAt(s);
          expect(
            opacityOf(tester, 'h'),
            moreOrLessEquals(1 - covered, epsilon: eps),
          );
          expect(
            offsetOf(tester, 'h'),
            offsetMoreOrLessEquals(Offset(0, -0.1 * covered), epsilon: eps),
          );
          if (covered > 0.05 && covered < 0.95) {
            sawMidway = true;
            // Returning from above.
            expect(offsetOf(tester, 'h').dy, lessThan(0));
          }
        }
        expect(sawMidway, isTrue);
        await tester.pumpAndSettle();
        expect(opacityOf(tester, 'h'), 1.0);
        expect(offsetOf(tester, 'h'), Offset.zero);
      },
    );

    testWidgets('an explicit exitOffset wins over the mirrored default', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const CnRouteAnimation(
          key: ValueKey<String>('x'),
          exitOffset: Offset(0.2, 0),
          child: SizedBox(height: 50),
        ),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      expect(offsetOf(tester, 'x'), const Offset(0.2, 0));
    });

    testWidgets('a dialog over the page does not cover it', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, page(<Widget>[item('h')]));
      await tester.pumpAndSettle();
      showDialog<void>(
        context: tester.element(find.byKey(const ValueKey<String>('h'))),
        builder: (_) => const AlertDialog(title: Text('dialog')),
      );
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(routeOf(tester, 'h').secondaryAnimation!.isDismissed, isTrue);
        expect(opacityOf(tester, 'h'), 1.0);
        expect(offsetOf(tester, 'h'), Offset.zero);
      }
      expect(find.text('dialog'), findsOneWidget);
    });

    testWidgets('pop reversed mid-push plays the entrance backwards without '
        'a jump', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
      );
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => page(<Widget>[item('a')])),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final ModalRoute<Object?> route = routeOf(tester, 'a');
      double previous = opacityOf(tester, 'a');
      expect(previous, greaterThan(0.0));
      nav.currentState!.pop();
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (!route.isActive) break;
        final double a = route.animation!.value;
        final double now = opacityOf(tester, 'a');
        // Still the enter lock (we left rest 0): the entrance runs backwards.
        expect(now, moreOrLessEquals(shownEntering(a), epsilon: eps));
        expect((now - previous).abs(), lessThan(0.15));
        previous = now;
      }
    });
  });

  group('mounts at rest (§3.6)', () {
    testWidgets('initial mount: first route plays the timed entrance', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, page(<Widget>[item('i')]));
      expect(opacityOf(tester, 'i'), 0.0);
      expect(offsetOf(tester, 'i'), const Offset(0, 0.1));
      await tester.pump(const Duration(milliseconds: 150));
      final double shown = Curves.easeOutCubic.transform(0.5);
      expect(opacityOf(tester, 'i'), moreOrLessEquals(shown, epsilon: eps));
      expect(
        offsetOf(tester, 'i'),
        offsetMoreOrLessEquals(Offset(0, 0.1 * (1 - shown)), epsilon: eps),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacityOf(tester, 'i'), 1.0);
      expect(offsetOf(tester, 'i'), Offset.zero);
    });

    testWidgets('initial mount: the timed entrance is staggered by geometry', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        page(<Widget>[
          item('top', timing: null),
          const SizedBox(height: 350),
          item('low', timing: null),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(opacityOf(tester, 'low'), lessThan(opacityOf(tester, 'top')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacityOf(tester, 'low'), 1.0);
    });

    testWidgets('zero-duration push: elements are initial mounts', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
      );
      nav.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => page(<Widget>[item('z')]),
        ),
      );
      await tester.pump();
      expect(routeOf(tester, 'z').animation!.value, 1.0);
      expect(opacityOf(tester, 'z'), 0.0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacityOf(tester, 'z'), 1.0);
    });

    testWidgets('no ModalRoute: plays the timed entrance once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder:
              (_, _) => Align(alignment: Alignment.topLeft, child: item('n')),
        ),
      );
      expect(
        ModalRoute.of(tester.element(find.byKey(const ValueKey<String>('n')))),
        isNull,
      );
      expect(opacityOf(tester, 'n'), 0.0);
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        opacityOf(tester, 'n'),
        moreOrLessEquals(Curves.easeOutCubic.transform(0.5), epsilon: eps),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacityOf(tester, 'n'), 1.0);
      // A rebuild does not replay it.
      await tester.pumpWidget(
        MaterialApp(
          builder:
              (_, _) => Align(alignment: Alignment.topLeft, child: item('n')),
        ),
      );
      expect(opacityOf(tester, 'n'), 1.0);
    });

    testWidgets('no ModalRoute and no MaterialApp: plays the timed entrance', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(800, 600)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CnRouteAnimation(
              key: ValueKey<String>('bare'),
              timing: flat,
              child: SizedBox(height: 10),
            ),
          ),
        ),
      );
      expect(opacityOf(tester, 'bare'), 0.0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacityOf(tester, 'bare'), 1.0);
    });

    Widget lazyList(ScrollController controller, {CnScrollReveal? reveal}) {
      final Widget list = ListView.builder(
        controller: controller,
        itemCount: 40,
        itemExtent: 100,
        itemBuilder: (_, int i) => item('L$i'),
      );
      return reveal == null
          ? list
          : CnRouteChoreography(scrollReveal: reveal, child: list);
    }

    testWidgets('late mount without scrollReveal renders at rest', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpApp(tester, lazyList(controller));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('L13')), findsNothing);
      controller.jumpTo(800);
      await tester.pump();
      expect(opacityOf(tester, 'L13'), 1.0);
      expect(offsetOf(tester, 'L13'), Offset.zero);
    });

    testWidgets('late mount with scrollReveal plays the reveal once', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpApp(
        tester,
        lazyList(controller, reveal: const CnScrollReveal()),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(800);
      await tester.pump();
      expect(opacityOf(tester, 'L13'), lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 150));
      final double shown = Curves.easeOutCubic.transform(0.5);
      expect(opacityOf(tester, 'L13'), moreOrLessEquals(shown, epsilon: eps));
      expect(
        offsetOf(tester, 'L13'),
        offsetMoreOrLessEquals(Offset(0, 0.1 * (1 - shown)), epsilon: eps),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacityOf(tester, 'L13'), 1.0);
      expect(offsetOf(tester, 'L13'), Offset.zero);
      // An item that was already built does not reveal again.
      controller.jumpTo(700);
      await tester.pump();
      expect(opacityOf(tester, 'L8'), 1.0);
    });
  });

  group('configuration', () {
    Future<GlobalKey<NavigatorState>> pumpReduced(
      WidgetTester tester, {
      CnRouteChoreography Function(Widget child)? scope,
    }) {
      return pumpApp(
        tester,
        const SizedBox(),
        builder: (BuildContext context, Widget? child) {
          final Widget reduced = MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          );
          return scope == null ? reduced : scope(reduced);
        },
      );
    }

    testWidgets('enabled: false shows the child as-is through push and cover', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
      );
      nav.currentState!.push(
        CnPageRoute<void>(
          builder: (_) => page(<Widget>[item('e', enabled: false)]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacityOf(tester, 'e'), 1.0);
      expect(offsetOf(tester, 'e'), Offset.zero);
      await tester.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacityOf(tester, 'e'), 1.0);
      expect(offsetOf(tester, 'e'), Offset.zero);
    });

    testWidgets('reduced motion fadeOnly: opacity follows progress, no '
        'translation', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpReduced(tester);
      nav.currentState!.push(
        CnPageRoute<void>(
          builder:
              (_) => page(<Widget>[
                CnRouteAnimation(
                  key: const ValueKey<String>('r'),
                  timing: flat,
                  scale: 0.9,
                  child: const SizedBox(height: 100),
                ),
              ]),
        ),
      );
      await tester.pump();
      final ModalRoute<Object?> route = routeOf(tester, 'r');
      bool sawMidway = false;
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        final double shown = shownEntering(route.animation!.value);
        expect(opacityOf(tester, 'r'), moreOrLessEquals(shown, epsilon: eps));
        expect(offsetOf(tester, 'r'), Offset.zero);
        expect(scaleOf(tester, 'r'), 1.0);
        if (shown > 0.05 && shown < 0.95) sawMidway = true;
      }
      expect(sawMidway, isTrue);
    });

    testWidgets('reduced motion none: at rest from the first frame', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpReduced(
        tester,
        scope:
            (Widget child) => CnRouteChoreography(
              reducedMotionMode: CnReducedMotionMode.none,
              child: child,
            ),
      );
      final FallbackControllerTracker tracker =
          FallbackControllerTracker()..start();
      addTearDown(tracker.stop);
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => page(<Widget>[item('r')])),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(opacityOf(tester, 'r'), 1.0);
      expect(offsetOf(tester, 'r'), Offset.zero);
      await tester.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacityOf(tester, 'r'), 1.0);
      expect(offsetOf(tester, 'r'), Offset.zero);
      expect(tracker.created, isEmpty);
    });

    testWidgets('reduced motion none: no timed entrance on the first route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: fadeThroughTheme(),
          builder:
              (BuildContext context, Widget? child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
          home: page(<Widget>[
            item('r', reducedMotionMode: CnReducedMotionMode.none),
          ]),
        ),
      );
      expect(opacityOf(tester, 'r'), 1.0);
      expect(offsetOf(tester, 'r'), Offset.zero);
    });

    Future<Offset> midPushOffset(
      WidgetTester tester,
      GlobalKey<NavigatorState> nav, {
      bool? respectReducedMotion,
    }) async {
      nav.currentState!.push(
        CnPageRoute<void>(
          builder:
              (_) => page(<Widget>[
                item('p', respectReducedMotion: respectReducedMotion),
              ]),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      return offsetOf(tester, 'p');
    }

    testWidgets('respectReducedMotion: widget false beats the default', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpReduced(tester);
      expect(
        (await midPushOffset(tester, nav, respectReducedMotion: false)).dy,
        greaterThan(0),
      );
    });

    testWidgets('respectReducedMotion: default respects it', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpReduced(tester);
      expect(await midPushOffset(tester, nav), Offset.zero);
    });

    testWidgets('respectReducedMotion: scope false beats the default', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpReduced(
        tester,
        scope:
            (Widget child) =>
                CnRouteChoreography(respectReducedMotion: false, child: child),
      );
      expect((await midPushOffset(tester, nav)).dy, greaterThan(0));
    });

    testWidgets('respectReducedMotion: widget true beats scope false', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpReduced(
        tester,
        scope:
            (Widget child) =>
                CnRouteChoreography(respectReducedMotion: false, child: child),
      );
      expect(
        await midPushOffset(tester, nav, respectReducedMotion: true),
        Offset.zero,
      );
    });

    testWidgets('respectReducedMotion: widget false beats scope true', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpReduced(
        tester,
        scope:
            (Widget child) =>
                CnRouteChoreography(respectReducedMotion: true, child: child),
      );
      expect(
        (await midPushOffset(tester, nav, respectReducedMotion: false)).dy,
        greaterThan(0),
      );
    });

    testWidgets('the route-driven path creates no AnimationController', (
      WidgetTester tester,
    ) async {
      final FallbackControllerTracker tracker =
          FallbackControllerTracker()..start();
      addTearDown(tracker.stop);
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        page(<Widget>[item('h1'), item('h2')]),
      );
      // The first route's elements are initial mounts: one each.
      expect(tracker.created, hasLength(2));
      await tester.pumpAndSettle();
      tracker.created.clear();
      nav.currentState!.push(
        CnPageRoute<void>(
          builder:
              (_) => page(<Widget>[
                for (int i = 0; i < 5; i++) item('p$i', height: 60),
              ]),
        ),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tracker.created, isEmpty);
    });
  });

  group('rebuilds and builder', () {
    testWidgets('enabled tied to isCurrent toggles across a push without '
        'setState during build', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        Builder(
          builder:
              (BuildContext context) => page(<Widget>[
                item('t', enabled: ModalRoute.of(context)!.isCurrent),
              ]),
        ),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        // Disabled while covered: shown as-is.
        expect(opacityOf(tester, 't'), 1.0);
      }
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(opacityOf(tester, 't'), 1.0);
    });

    testWidgets('enabled toggled by the parent mid-push picks up progress', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
      addTearDown(enabled.dispose);
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
      );
      nav.currentState!.push(
        CnPageRoute<void>(
          builder:
              (_) => ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder:
                    (_, bool on, _) => page(<Widget>[item('t', enabled: on)]),
              ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(opacityOf(tester, 't'), 1.0);
      enabled.value = true;
      await tester.pump();
      final double a = routeOf(tester, 't').animation!.value;
      expect(
        opacityOf(tester, 't'),
        moreOrLessEquals(shownEntering(a), epsilon: eps),
      );
      expect(opacityOf(tester, 't'), lessThan(1.0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(opacityOf(tester, 't'), 1.0);
    });

    testWidgets('the child keeps its state across enabled and reduced-motion '
        'changes', (WidgetTester tester) async {
      final List<State> states = <State>[];
      Widget build({required bool enabled, required bool reduce}) {
        return MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            disableAnimations: reduce,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CnRouteAnimation(
              key: const ValueKey<String>('s'),
              enabled: enabled,
              child: _StateProbe(states),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(enabled: true, reduce: false));
      await tester.pumpWidget(build(enabled: false, reduce: false));
      await tester.pumpWidget(build(enabled: false, reduce: true));
      await tester.pumpWidget(build(enabled: true, reduce: true));
      await tester.pumpWidget(build(enabled: true, reduce: false));
      expect(states, hasLength(1));
      expect(tester.state(find.byType(_StateProbe)), same(states.single));
    });

    testWidgets('builder: receives the element progress', (
      WidgetTester tester,
    ) async {
      final List<CnElementProgress> seen = <CnElementProgress>[];
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
      );
      nav.currentState!.push(
        CnPageRoute<void>(
          builder:
              (_) => page(<Widget>[
                item(
                  'b',
                  builder: (_, CnElementProgress progress, Widget? child) {
                    seen.add(progress);
                    return child!;
                  },
                ),
              ]),
        ),
      );
      await tester.pump();
      final ModalRoute<Object?> route = routeOf(tester, 'b');
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final CnElementProgress last = seen.last;
        expect(
          last.shown,
          moreOrLessEquals(shownEntering(route.animation!.value), epsilon: eps),
        );
        expect(last.covered, 0.0);
        expect(last.role, CnElementRole.plain);
        expect(last.partingDirection, Offset.zero);
      }
      // The builder replaces the built-in rendering.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('b')),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(seen.last, CnElementProgress.rest);
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pump();
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(
          seen.last.covered,
          moreOrLessEquals(
            coveredAt(route.secondaryAnimation!.value),
            epsilon: eps,
          ),
        );
        expect(seen.last.shown, 1.0);
      }
    });

    testWidgets('builder: gets rest when disabled', (
      WidgetTester tester,
    ) async {
      final List<CnElementProgress> seen = <CnElementProgress>[];
      await pumpApp(
        tester,
        page(<Widget>[
          item(
            'b',
            enabled: false,
            builder: (_, CnElementProgress progress, Widget? child) {
              seen.add(progress);
              return child!;
            },
          ),
        ]),
      );
      expect(seen.last, CnElementProgress.rest);
    });
  });

  group('parting (§3.5)', () {
    void pushBlank(BuildContext context) => Navigator.of(
      context,
    ).push(CnPageRoute<void>(builder: (_) => const SizedBox()));

    /// Nine 60 px items in a ListView.builder, all on screen.
    Widget partingList({
      Map<int, bool> subject = const <int, bool>{},
      bool navigateOnTap = true,
      GlobalKey? key4,
    }) {
      return ListView.builder(
        itemCount: 9,
        itemExtent: 60,
        itemBuilder:
            (BuildContext context, int i) => CnRouteAnimation(
              key: ValueKey<String>('p$i'),
              subject: subject[i],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: navigateOnTap ? () => pushBlank(context) : null,
                child: SizedBox(
                  key: i == 4 ? key4 : null,
                  height: 60,
                  child: Text('p$i'),
                ),
              ),
            ),
      );
    }

    void expectParted(WidgetTester tester, {required int subject}) {
      expect(offsetOf(tester, 'p$subject'), Offset.zero);
      expect(opacityOf(tester, 'p$subject'), 1.0);
      double previous = 0;
      for (int i = subject - 1; i >= 0; i--) {
        final Offset o = offsetOf(tester, 'p$i');
        expect(o.dx, 0);
        expect(o.dy, lessThan(0), reason: 'p$i is above the subject');
        expect(o.dy.abs(), greaterThan(previous), reason: 'p$i farther');
        previous = o.dy.abs();
      }
      previous = 0;
      for (int i = subject + 1; i < 9; i++) {
        final Offset o = offsetOf(tester, 'p$i');
        expect(o.dx, 0);
        expect(o.dy, greaterThan(0), reason: 'p$i is below the subject');
        expect(o.dy.abs(), greaterThan(previous), reason: 'p$i farther');
        previous = o.dy.abs();
      }
    }

    void expectPlain(WidgetTester tester) {
      for (int i = 0; i < 9; i++) {
        expect(
          offsetOf(tester, 'p$i'),
          offsetMoreOrLessEquals(const Offset(0, -0.1), epsilon: eps),
          reason: 'p$i exits as a plain element (up)',
        );
      }
    }

    testWidgets('tapping item 4 of 9 parts the list around it', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, partingList());
      await tester.pumpAndSettle();
      await tester.tap(find.text('p4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));
      // Nearer siblings start first.
      expect(opacityOf(tester, 'p3'), lessThan(opacityOf(tester, 'p0')));
      expect(opacityOf(tester, 'p5'), lessThan(opacityOf(tester, 'p8')));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(offsetOf(tester, 'p4'), Offset.zero);
        expect(opacityOf(tester, 'p4'), 1.0);
      }
      await tester.pumpAndSettle();
      expectParted(tester, subject: 4);
      // Exit vector: distance 0.6 grown by up to distanceGrowth with f.
      expect(offsetOf(tester, 'p3').dy, moreOrLessEquals(-0.6 * 1.05));
      expect(offsetOf(tester, 'p8').dy, moreOrLessEquals(0.6 * 1.2));
    });

    testWidgets('uncover brings the parted siblings back to rest', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        partingList(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('p4'));
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Still parted, part-way back (S = 0.5, inside the uncover slice).
      expect(offsetOf(tester, 'p0').dy, lessThan(0));
      expect(offsetOf(tester, 'p8').dy, greaterThan(0));
      await tester.pumpAndSettle();
      for (int i = 0; i < 9; i++) {
        expect(offsetOf(tester, 'p$i'), Offset.zero);
        expect(opacityOf(tester, 'p$i'), 1.0);
      }
    });

    testWidgets('a 3-column grid parts same-row cells sideways', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        Builder(
          builder:
              (BuildContext context) => GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 2,
                children: <Widget>[
                  for (int i = 0; i < 9; i++)
                    CnRouteAnimation(
                      key: ValueKey<String>('g$i'),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => pushBlank(context),
                        child: Center(child: Text('g$i')),
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
      final Offset left = offsetOf(tester, 'g3');
      final Offset right = offsetOf(tester, 'g5');
      expect(left.dx, lessThan(0));
      expect(left.dy, 0);
      expect(right.dx, greaterThan(0));
      expect(right.dy, 0);
      for (final int i in <int>[0, 1, 2]) {
        expect(offsetOf(tester, 'g$i').dy, lessThan(0));
        expect(offsetOf(tester, 'g$i').dx, 0);
      }
      for (final int i in <int>[6, 7, 8]) {
        expect(offsetOf(tester, 'g$i').dy, greaterThan(0));
        expect(offsetOf(tester, 'g$i').dx, 0);
      }
    });

    testWidgets('subject: false keeps a tapped item from being the subject', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, partingList(subject: const <int, bool>{4: false}));
      await tester.pumpAndSettle();
      await tester.tap(find.text('p4'));
      await tester.pumpAndSettle();
      expectPlain(tester);
    });

    testWidgets('select() marks the subject without a pointer', (
      WidgetTester tester,
    ) async {
      final GlobalKey key4 = GlobalKey();
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        partingList(navigateOnTap: false, key4: key4),
      );
      await tester.pumpAndSettle();
      CnRouteChoreography.select(key4.currentContext!);
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      expectParted(tester, subject: 4);
    });

    testWidgets('disposing a selected element clears the stored selection', (
      WidgetTester tester,
    ) async {
      final GlobalKey keyA = GlobalKey();
      final GlobalKey keyB = GlobalKey();
      bool showA = true;
      bool showB = true;
      late StateSetter setPage;
      late ModalRoute<dynamic> route;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                setPage = setState;
                route = ModalRoute.of(context)!;
                return Column(
                  children: <Widget>[
                    if (showA)
                      CnRouteAnimation(child: SizedBox(key: keyA, height: 50)),
                    if (showB)
                      CnRouteAnimation(child: SizedBox(key: keyB, height: 50)),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      CnRouteChoreography.select(keyA.currentContext!);
      final CnRouteRecord record = CnRouteRecord.maybeOf(route)!;
      expect(record.hasSelection, isTrue);
      // Disposing another element keeps A's selection.
      setPage(() => showB = false);
      await tester.pump();
      expect(record.hasSelection, isTrue);
      // Disposing the selected element releases it.
      setPage(() => showA = false);
      await tester.pump();
      expect(record.hasSelection, isFalse);
    });

    testWidgets('subject: true marks the subject; select() beats it', (
      WidgetTester tester,
    ) async {
      final GlobalKey key4 = GlobalKey();
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        partingList(
          navigateOnTap: false,
          subject: const <int, bool>{2: true},
          key4: key4,
        ),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      expectParted(tester, subject: 2);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      CnRouteChoreography.select(key4.currentContext!);
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      expectParted(tester, subject: 4);
    });

    testWidgets(
      'a pointer-down older than the window does not mark a subject',
      (WidgetTester tester) async {
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          partingList(navigateOnTap: false),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('p4'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        nav.currentState!.push(
          CnPageRoute<void>(builder: (_) => const SizedBox()),
        );
        await tester.pumpAndSettle();
        expectPlain(tester);
      },
    );

    testWidgets('a pointer-down within the window marks the subject', (
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        partingList(navigateOnTap: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('p4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      expectParted(tester, subject: 4);
    });

    testWidgets('subjectDetection off: no parting', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        CnRouteChoreography(
          subjectDetection: CnSubjectDetection.off,
          child: partingList(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('p4'));
      await tester.pumpAndSettle();
      expectPlain(tester);
    });

    testWidgets('an item built mid-transition parts from the cached subject', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<int> count = ValueNotifier<int>(9);
      addTearDown(count.dispose);
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: count,
          builder:
              (BuildContext context, int n, _) => ListView.builder(
                itemCount: n,
                itemExtent: 60,
                itemBuilder:
                    (BuildContext context, int i) => CnRouteAnimation(
                      key: ValueKey<String>('p$i'),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => pushBlank(context),
                        child: SizedBox(height: 60, child: Text('p$i')),
                      ),
                    ),
              ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('p4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      count.value = 10;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expectParted(tester, subject: 4);
      expect(offsetOf(tester, 'p9').dy, greaterThan(offsetOf(tester, 'p8').dy));
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      for (int i = 0; i < 10; i++) {
        expect(offsetOf(tester, 'p$i'), Offset.zero);
      }
    });

    testWidgets('RTL: same-row cells still part away from the subject', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder:
                (BuildContext context) => GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  children: <Widget>[
                    for (int i = 0; i < 9; i++)
                      CnRouteAnimation(
                        key: ValueKey<String>('g$i'),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => pushBlank(context),
                          child: Center(child: Text('g$i')),
                        ),
                      ),
                  ],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder text(String label) => find.text(label, skipOffstage: false);
      final double restLeading = tester.getCenter(text('g3')).dx;
      final double restTrailing = tester.getCenter(text('g5')).dx;
      // In RTL the first cell of a row is on the right.
      expect(restLeading, greaterThan(restTrailing));
      await tester.tap(find.text('g4'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(text('g3')).dx, greaterThan(restLeading));
      expect(tester.getCenter(text('g5')).dx, lessThan(restTrailing));
    });

    testWidgets('builder: reports subject and sibling roles', (
      WidgetTester tester,
    ) async {
      final Map<String, CnElementProgress> last = <String, CnElementProgress>{};
      await pumpApp(
        tester,
        Builder(
          builder:
              (BuildContext context) => page(<Widget>[
                for (final String label in <String>['b0', 'b1', 'b2'])
                  CnRouteAnimation(
                    key: ValueKey<String>(label),
                    builder: (_, CnElementProgress progress, Widget? child) {
                      last[label] = progress;
                      return child!;
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => pushBlank(context),
                      child: SizedBox(height: 60, child: Text(label)),
                    ),
                  ),
              ]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('b1'));
      await tester.pumpAndSettle();
      expect(last['b1']!.role, CnElementRole.subject);
      expect(last['b1']!.partingDirection, Offset.zero);
      expect(last['b0']!.role, CnElementRole.sibling);
      expect(last['b0']!.partingDirection, const Offset(0, -1));
      expect(last['b2']!.role, CnElementRole.sibling);
      expect(last['b2']!.partingDirection, const Offset(0, 1));
      expect(last['b0']!.covered, 1.0);
    });
  });

  group('interactive back (§4 swipe-back rows)', () {
    testWidgets('predictive back on this page scrubs the exit curve; the page '
        'below follows; cancel and commit', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        page(<Widget>[item('h')]),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => page(<Widget>[item('t')])),
      );
      await tester.pumpAndSettle();
      final ModalRoute<Object?> top = routeOf(tester, 't');
      final ModalRoute<Object?> home = routeOf(tester, 'h');

      void check() {
        final double a = top.animation!.value;
        // Exit curve whatever the status: forward while dragging and
        // cancelling, reverse after commit.
        expect(
          opacityOf(tester, 't'),
          moreOrLessEquals(shownLeaving(a), epsilon: eps),
        );
        final double s = home.secondaryAnimation!.value;
        expect(s, moreOrLessEquals(a, epsilon: eps));
        // The cover left 1, so the uncover slice applies both ways, while
        // dragging and while a cancel climbs back to 1.
        expect(
          opacityOf(tester, 'h'),
          moreOrLessEquals(1 - uncoveredAt(s), epsilon: eps),
        );
      }

      top.handleStartBackGesture(progress: 0.95);
      await tester.pump();
      expect(top.animation!.status, AnimationStatus.forward);
      check();
      expect(opacityOf(tester, 't'), lessThan(1.0));
      top.handleUpdateBackGestureProgress(progress: 0.8);
      await tester.pump();
      expect(top.animation!.value, moreOrLessEquals(0.8));
      check();
      // The entrance curve would give a different value here.
      expect(
        (opacityOf(tester, 't') - shownEntering(0.8)).abs(),
        greaterThan(0.05),
      );
      // The page below starts to return once the cover drops under the
      // uncover slice's end.
      top.handleUpdateBackGestureProgress(progress: 0.3);
      await tester.pump();
      check();
      expect(opacityOf(tester, 'h'), greaterThan(0.0));
      expect(opacityOf(tester, 't'), 0.0);

      top.handleCancelBackGesture();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        check();
      }
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 't'), 1.0);
      expect(opacityOf(tester, 'h'), 0.0);

      top.handleStartBackGesture(progress: 0.9);
      top.handleUpdateBackGestureProgress(progress: 0.75);
      await tester.pump();
      check();
      top.handleCommitBackGesture();
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (!top.isActive) break;
        expect(top.animation!.status, AnimationStatus.reverse);
        check();
      }
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'h'), 1.0);
      expect(offsetOf(tester, 'h'), Offset.zero);
    });

    testWidgets('iOS swipe-back: parted siblings return smoothly with the '
        'finger', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        Builder(
          builder:
              (BuildContext context) => page(<Widget>[
                for (int i = 0; i < 5; i++)
                  CnRouteAnimation(
                    key: ValueKey<String>('s$i'),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SizedBox(),
                            ),
                          ),
                      child: SizedBox(height: 60, child: Text('s$i')),
                    ),
                  ),
              ]),
        ),
        theme: ThemeData(platform: TargetPlatform.iOS),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('s2'));
      await tester.pumpAndSettle();
      final ModalRoute<Object?> home = routeOf(tester, 's0');
      expect(home.secondaryAnimation!.value, 1.0);
      final double parted = offsetOf(tester, 's0').dy;
      expect(parted, lessThan(0));
      expect(offsetOf(tester, 's4').dy, greaterThan(0));
      expect(offsetOf(tester, 's2'), Offset.zero);

      final TestGesture gesture = await tester.startGesture(
        const Offset(5, 300),
      );
      await tester.pump();
      final List<double> samples = <double>[];
      // 20 x 25 px: steps small enough that the per-frame bound below
      // measures continuity, not the finger's step size.
      for (final double dx in List<double>.filled(20, 25)) {
        await gesture.moveBy(Offset(dx, 0));
        await tester.pump();
        expect(nav.currentState!.userGestureInProgress, isTrue);
        final double s = home.secondaryAnimation!.value;
        expect(s, lessThan(1.0));
        expect(offsetOf(tester, 's2'), Offset.zero);
        samples.add(offsetOf(tester, 's0').dy);
      }
      await gesture.up();
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        samples.add(offsetOf(tester, 's0').dy);
      }
      await tester.pumpAndSettle();
      samples.add(offsetOf(tester, 's0').dy);
      // Monotonic return towards rest, no discontinuity.
      expect(
        samples.where((double dy) => dy > parted + eps && dy < -eps).length,
        greaterThanOrEqualTo(3),
        reason: 'the return is spread over several frames',
      );
      double previous = parted;
      for (final double dy in samples) {
        expect(dy, greaterThanOrEqualTo(previous - eps));
        expect((dy - previous).abs(), lessThan(0.25));
        previous = dy;
      }
      expect(offsetOf(tester, 's0'), Offset.zero);
      expect(offsetOf(tester, 's4'), Offset.zero);
      expect(opacityOf(tester, 's4'), 1.0);
    });
  });
}

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
  Widget build(BuildContext context) => const SizedBox(height: 10);
}
