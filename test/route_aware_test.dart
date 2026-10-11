// ignore_for_file: deprecated_member_use_from_same_package
import 'package:cn_animations/cn_animations.dart';
import 'package:cn_animations/route_aware_widget.dart' as legacy;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const Key _raKey = Key('route-aware');

/// [reduceMotion], when given, drives `disableAnimations` at runtime and
/// overrides [disableAnimations].
Widget _app(
  GlobalKey<NavigatorState> navigatorKey,
  Widget home, {
  bool disableAnimations = false,
  ValueNotifier<bool>? reduceMotion,
}) {
  Widget withMotion(BuildContext context, bool disable, Widget child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disable),
      child: child,
    );
  }

  return MaterialApp(
    navigatorKey: navigatorKey,
    navigatorObservers: [RouteAwareWidget.routeObserver],
    builder:
        (context, child) =>
            reduceMotion == null
                ? withMotion(context, disableAnimations, child!)
                : ValueListenableBuilder<bool>(
                  valueListenable: reduceMotion,
                  builder:
                      (context, value, _) => withMotion(context, value, child!),
                ),
    home: home,
  );
}

/// Keeps its State across rebuilds, so tests can detect a remount.
class _Stateful extends StatefulWidget {
  const _Stateful();

  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  Widget build(BuildContext context) => const Text('stateful');
}

/// A page route without a transition, so timings are exact. Not opaque, so
/// the page below stays onstage and its tickers keep running.
Route<void> _plainRoute() {
  return PageRouteBuilder<void>(
    pageBuilder:
        (context, animation, secondaryAnimation) => const Text('next page'),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    opaque: false,
  );
}

Finder _inside(Key key, Type type) => find.descendant(
  of: find.byKey(key, skipOffstage: false),
  matching: find.byType(type, skipOffstage: false),
);

double _raOpacity(WidgetTester tester, [Key key = _raKey]) =>
    tester
        .widget<FadeTransition>(_inside(key, FadeTransition).first)
        .opacity
        .value;

Offset _raOffset(WidgetTester tester, [Key key = _raKey]) =>
    tester
        .widget<SlideTransition>(_inside(key, SlideTransition).first)
        .position
        .value;

void main() {
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() => navigatorKey = GlobalKey<NavigatorState>());

  NavigatorState navigator() => navigatorKey.currentState!;

  test('deprecated top-level routeObserver is the same instance', () {
    // Reachable only through its old import path, not the barrel.
    expect(
      identical(legacy.routeObserver, RouteAwareWidget.routeObserver),
      isTrue,
    );
  });

  testWidgets('bug 1: showPush: false renders the child fully visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        navigatorKey,
        const CnRouteAwareAnimation(
          key: _raKey,
          showPush: false,
          child: Text('A'),
        ),
      ),
    );
    expect(_raOpacity(tester), 1);
    expect(_raOffset(tester), Offset.zero);

    await tester.pumpAndSettle();
    expect(_raOpacity(tester), 1);
  });

  group('bug 2: non-page routes', () {
    const Key dialogKey = Key('in-dialog');

    testWidgets('child inside a dialog becomes visible, '
        'and the page below gets no pushNext', (tester) async {
      await tester.pumpWidget(
        _app(
          navigatorKey,
          const CnRouteAwareAnimation(key: _raKey, child: Text('page')),
        ),
      );
      await tester.pumpAndSettle();

      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder:
            (_) => const CnRouteAwareAnimation(
              key: dialogKey,
              child: Text('dialog'),
            ),
      );
      await tester.pumpAndSettle();

      expect(_raOpacity(tester, dialogKey), 1);
      expect(_raOffset(tester, dialogKey), Offset.zero);
      expect(_raOpacity(tester), 1);
      expect(_raOffset(tester), Offset.zero);
    });

    testWidgets('child inside a bottom sheet becomes visible', (tester) async {
      await tester.pumpWidget(_app(navigatorKey, const Scaffold()));

      showModalBottomSheet<void>(
        context: navigatorKey.currentContext!,
        builder:
            (_) => const CnRouteAwareAnimation(
              key: dialogKey,
              child: Text('sheet'),
            ),
      );
      await tester.pumpAndSettle();

      expect(_raOpacity(tester, dialogKey), 1);
    });

    testWidgets('RouteAwareWidget calls onPush once inside a dialog', (
      tester,
    ) async {
      int pushes = 0;
      await tester.pumpWidget(_app(navigatorKey, const Scaffold()));

      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder:
            (_) => RouteAwareWidget(
              onPush: () => pushes++,
              child: const Text('dialog'),
            ),
      );
      await tester.pumpAndSettle();
      expect(pushes, 1);

      // Covering and uncovering the dialog changes its route status, which
      // re-runs didChangeDependencies.
      navigator().push(_plainRoute());
      await tester.pumpAndSettle();
      navigator().pop();
      await tester.pumpAndSettle();
      expect(pushes, 1);
    });
  });

  testWidgets('bug 3: toggling animate off and on does not throw', (
    tester,
  ) async {
    final ValueNotifier<bool> animate = ValueNotifier<bool>(true);
    addTearDown(animate.dispose);

    await tester.pumpWidget(
      _app(
        navigatorKey,
        ValueListenableBuilder<bool>(
          valueListenable: animate,
          builder:
              (context, value, _) => CnRouteAwareAnimation(
                key: _raKey,
                animate: value,
                child: const Text('A'),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A push/pop round trip leaves the next-page values active, so the
    // remount below has to switch values while the tree is building.
    navigator().push(_plainRoute());
    await tester.pumpAndSettle();
    navigator().pop();
    await tester.pumpAndSettle();

    animate.value = false;
    await tester.pump();
    animate.value = true;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_raOpacity(tester), 1);
    expect(_raOffset(tester), Offset.zero);
  });

  testWidgets('bug 6: fade and slide duration changes are applied', (
    tester,
  ) async {
    final ValueNotifier<Duration> duration = ValueNotifier<Duration>(
      const Duration(seconds: 2),
    );
    addTearDown(duration.dispose);

    await tester.pumpWidget(
      _app(
        navigatorKey,
        ValueListenableBuilder<Duration>(
          valueListenable: duration,
          builder:
              (context, value, _) => CnRouteAwareAnimation(
                key: _raKey,
                showPush: false,
                fadeDuration: value,
                slideDuration: value,
                child: const Text('A'),
              ),
        ),
      ),
    );
    duration.value = const Duration(milliseconds: 100);
    await tester.pumpAndSettle();

    navigator().push(_plainRoute()); // pushNext: animates out
    await tester.pump(const Duration(milliseconds: 1)); // zero delays fire
    await tester.pump(const Duration(milliseconds: 150));

    expect(_raOpacity(tester), 0);
    expect(_raOffset(tester), const Offset(0, -0.1));
  });

  group('pushNext / popNext round trips end visible', () {
    Future<void> roundTrip(WidgetTester tester, Widget animation) async {
      await tester.pumpWidget(_app(navigatorKey, animation));
      await tester.pumpAndSettle();

      navigator().push(_plainRoute());
      await tester.pumpAndSettle();
      expect(_raOpacity(tester), 0);

      navigator().pop();
      await tester.pumpAndSettle();
    }

    testWidgets('showPopNext: false shows the page again without animating', (
      tester,
    ) async {
      await roundTrip(
        tester,
        const CnRouteAwareAnimation(
          key: _raKey,
          showPopNext: false,
          child: Text('A'),
        ),
      );
      expect(_raOpacity(tester), 1);
      expect(_raOffset(tester), Offset.zero);
    });

    testWidgets('showPush: false', (tester) async {
      await roundTrip(
        tester,
        const CnRouteAwareAnimation(
          key: _raKey,
          showPush: false,
          child: Text('A'),
        ),
      );
      expect(_raOpacity(tester), 1);
      expect(_raOffset(tester), Offset.zero);
    });
  });

  testWidgets('RouteAwareWidget resubscribes when moved to another route', (
    tester,
  ) async {
    final ValueNotifier<bool> onFirstRoute = ValueNotifier<bool>(true);
    addTearDown(onFirstRoute.dispose);
    final GlobalKey routeAwareKey = GlobalKey();
    int pushes = 0;
    int pushNexts = 0;

    Widget routeAware() => RouteAwareWidget(
      key: routeAwareKey,
      onPush: () => pushes++,
      onPushNext: () => pushNexts++,
      child: const Text('ra'),
    );

    await tester.pumpWidget(
      _app(
        navigatorKey,
        ValueListenableBuilder<bool>(
          valueListenable: onFirstRoute,
          builder:
              (context, first, _) => first ? routeAware() : const SizedBox(),
        ),
      ),
    );
    navigator().push(
      PageRouteBuilder<void>(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                ValueListenableBuilder<bool>(
                  valueListenable: onFirstRoute,
                  builder:
                      (context, first, _) =>
                          first ? const SizedBox() : routeAware(),
                ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        opaque: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(pushes, 1);
    expect(pushNexts, 1);

    // Reparent into the second route in one frame.
    onFirstRoute.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(pushes, 2);

    // Only the new route's events arrive now.
    navigator().push(_plainRoute());
    await tester.pumpAndSettle();
    expect(pushNexts, 2);
  });

  group('bug 8: delayed route callbacks', () {
    testWidgets('a newer event cancels the pending callbacks of older ones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          navigatorKey,
          const CnRouteAwareAnimation(
            key: _raKey,
            showPush: false,
            showSlideAnimation: false,
            fadeDelayInMilliseconds: 200,
            fadeDuration: Duration(milliseconds: 100),
            child: Text('A'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      navigator().push(_plainRoute()); // t=0: pushNext, forward at 200
      await tester.pump(const Duration(milliseconds: 50));
      navigator().pop(); // t=50: popNext, reverse at 250
      await tester.pump(const Duration(milliseconds: 50));
      navigator().push(_plainRoute()); // t=100: pushNext, forward at 300
      // Step through t=200 so a stale callback, if any, gets to tick.
      await tester.pump(const Duration(milliseconds: 110));
      await tester.pump(const Duration(milliseconds: 30));

      // t=240: only the last event's callback may run, and not before t=300.
      expect(_raOpacity(tester), 1);

      await tester.pumpAndSettle();
      expect(_raOpacity(tester), 0);
    });

    testWidgets('pending callbacks are cancelled on dispose', (tester) async {
      // The test harness fails if a Timer is still pending after the tree
      // is disposed.
      await tester.pumpWidget(
        _app(
          navigatorKey,
          const CnRouteAwareAnimation(
            fadeDelayInMilliseconds: 1000,
            slideDelayInMilliseconds: 1000,
            child: Text('A'),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('reduced motion', () {
    testWidgets('respected by default: push shows the end state at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          navigatorKey,
          const CnRouteAwareAnimation(key: _raKey, child: Text('A')),
          disableAnimations: true,
        ),
      );

      expect(_raOpacity(tester), 1);
      expect(_raOffset(tester), Offset.zero);
      expect(effectiveOpacity(tester, find.text('A')), 1);
    });

    testWidgets('a custom resting state (fadeEndSamePage) is honored', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          navigatorKey,
          const CnRouteAwareAnimation(
            key: _raKey,
            fadeEndSamePage: 0.4,
            child: Text('A'),
          ),
          disableAnimations: true,
        ),
      );

      expect(_raOpacity(tester), 0.4);
    });

    testWidgets('pushNext snaps to the next values, popNext snaps back', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          navigatorKey,
          const CnRouteAwareAnimation(key: _raKey, child: Text('A')),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      navigator().push(_plainRoute());
      await tester.pump();
      expect(_raOpacity(tester), 0);
      expect(_raOffset(tester), const Offset(0, -0.1));

      navigator().pop();
      await tester.pump();
      expect(_raOpacity(tester), 1);
      expect(_raOffset(tester), Offset.zero);
    });

    testWidgets(
      'toggling at runtime keeps the child State and does not replay',
      (tester) async {
        final ValueNotifier<bool> reduceMotion = ValueNotifier<bool>(false);
        addTearDown(reduceMotion.dispose);

        await tester.pumpWidget(
          _app(
            navigatorKey,
            const CnRouteAwareAnimation(key: _raKey, child: _Stateful()),
            reduceMotion: reduceMotion,
          ),
        );
        await tester.pumpAndSettle();
        final State before = tester.state(find.byType(_Stateful));

        reduceMotion.value = true;
        await tester.pump();
        expect(tester.state(find.byType(_Stateful)), same(before));
        expect(_raOpacity(tester), 1);

        reduceMotion.value = false;
        await tester.pump();
        expect(tester.state(find.byType(_Stateful)), same(before));
        expect(_raOpacity(tester), 1);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets('respectReducedMotion: false animates anyway', (tester) async {
      await tester.pumpWidget(
        _app(
          navigatorKey,
          const CnRouteAwareAnimation(
            key: _raKey,
            respectReducedMotion: false,
            child: Text('A'),
          ),
          disableAnimations: true,
        ),
      );
      expect(_raOpacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 1)); // zero delays fire
      await tester.pump(const Duration(milliseconds: 150));
      expect(_raOpacity(tester), allOf(greaterThan(0), lessThan(1)));

      await tester.pumpAndSettle();
      expect(_raOpacity(tester), 1);
    });
  });
}
