// Regression tests for the two slice-H P0 bugs: Android predictive back and
// the iOS edge swipe-back must reach a page shown by the fade-through
// (CnPageRoute, or MaterialPageRoute under the theme builder), move the
// route's progress with the finger, and commit or cancel correctly.
import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Install { cnPageRoute, themeOverMaterial }

/// No stagger, so element values are exact functions of route progress.
const CnRouteTiming _flat = CnRouteTiming(exitStagger: 0, enterStagger: 0);

PageRoute<void> _route(
  _Install install,
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) => switch (install) {
  _Install.cnPageRoute => CnPageRoute<void>(
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  ),
  _Install.themeOverMaterial => MaterialPageRoute<void>(
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  ),
};

/// CnPageRoute must work under the stock theme; the theme install puts the
/// fade-through on every platform.
ThemeData _theme(_Install install, TargetPlatform platform) =>
    switch (install) {
      _Install.cnPageRoute => ThemeData(platform: platform),
      _Install.themeOverMaterial => ThemeData(
        platform: platform,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            for (final TargetPlatform p in TargetPlatform.values)
              p: const CnFadeThroughPageTransitionsBuilder(),
          },
        ),
      ),
    };

/// A plain choreographed element.
Widget _element(String label) => CnRouteAnimation(
  key: ValueKey<String>(label),
  timing: _flat,
  child: SizedBox(height: 100, child: Text(label)),
);

/// The element's own opacity (offstage included: a covered page is offstage).
double _opacity(WidgetTester t, String label) => t
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byKey(ValueKey<String>(label), skipOffstage: false),
            matching: find.byType(FadeTransition, skipOffstage: false),
          )
          .first,
    )
    .opacity
    .value;

ModalRoute<Object?> _routeOf(WidgetTester t, String label) => ModalRoute.of(
  t.element(find.byKey(ValueKey<String>(label), skipOffstage: false)),
)!;

class _Stack {
  _Stack(this.nav, this.below, this.top);
  final NavigatorState nav;
  final ModalRoute<Object?> below;
  final ModalRoute<Object?> top;
}

/// Pumps an app on [platform] and pushes two pages with [install]: 'below'
/// (element 'b') and 'top' (element 't', wrapped by [wrapTop]).
Future<_Stack> _twoPages(
  WidgetTester t,
  _Install install, {
  TargetPlatform platform = TargetPlatform.android,
  bool fullscreenDialog = false,
  Widget Function(Widget page)? wrapTop,
  TransitionBuilder? appBuilder,
}) async {
  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  await t.pumpWidget(
    MaterialApp(
      navigatorKey: key,
      theme: _theme(install, platform),
      builder: appBuilder,
      home: const SizedBox(),
    ),
  );
  key.currentState!.push(_route(install, (_) => _element('b')));
  await t.pumpAndSettle();
  final Widget top = _element('t');
  key.currentState!.push(
    _route(
      install,
      (_) => wrapTop == null ? top : wrapTop(top),
      fullscreenDialog: fullscreenDialog,
    ),
  );
  await t.pumpAndSettle();
  final _Stack stack = _Stack(
    key.currentState!,
    _routeOf(t, 'b'),
    _routeOf(t, 't'),
  );
  expect(stack.top.isCurrent, isTrue);
  expect(stack.top.animation!.value, 1.0);
  return stack;
}

/// Sends a system predictive-back message on the real channel, as the
/// Android engine does. [button] sends the back-button form (no touch).
Future<void> _backGesture(
  WidgetTester t,
  String method, {
  double progress = 0.0,
  bool button = false,
}) async {
  final bool hasArgs =
      method == 'startBackGesture' || method == 'updateBackGestureProgress';
  final ByteData message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(
      method,
      hasArgs
          ? <String, Object?>{
              'touchOffset': button ? null : <double>[5.0, 300.0],
              'progress': progress,
              'swipeEdge': 0,
            }
          : null,
    ),
  );
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (ByteData? _) {},
  );
  await t.pump();
}

/// Counts the predictive-back calls a route receives, to catch a gesture
/// handled by more than one observer (Flutter 3.35+ dispatches it to every
/// observer that claims it, where 3.32 stopped at the first).
mixin _CountsBackGesture<T> on TransitionRoute<T> {
  int starts = 0;
  int updates = 0;
  int routeCommits = 0;
  int routeCancels = 0;

  @override
  void handleStartBackGesture({double progress = 0.0}) {
    starts++;
    super.handleStartBackGesture(progress: progress);
  }

  @override
  void handleUpdateBackGestureProgress({required double progress}) {
    updates++;
    super.handleUpdateBackGestureProgress(progress: progress);
  }

  @override
  void handleCommitBackGesture() {
    routeCommits++;
    super.handleCommitBackGesture();
  }

  @override
  void handleCancelBackGesture() {
    routeCancels++;
    super.handleCancelBackGesture();
  }
}

class _CountingCnPageRoute extends CnPageRoute<void>
    with _CountsBackGesture<void> {
  _CountingCnPageRoute({required super.builder});
}

class _CountingMaterialPageRoute extends MaterialPageRoute<void>
    with _CountsBackGesture<void> {
  _CountingMaterialPageRoute({required super.builder});
}

class _PopCounter extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

void main() {
  for (final _Install install in _Install.values) {
    group('Android predictive back, ${install.name}', () {
      testWidgets(
        'the system gesture scrubs the route and the elements, and commit '
        'pops',
        (WidgetTester t) async {
          final _Stack s = await _twoPages(t, install);
          final double covered = _opacity(t, 'b');

          await _backGesture(t, 'startBackGesture');
          expect(s.nav.userGestureInProgress, isTrue);
          await _backGesture(t, 'updateBackGestureProgress', progress: 0.4);
          expect(s.top.animation!.value, moreOrLessEquals(0.6));
          expect(s.top.animation!.status, AnimationStatus.forward);
          expect(s.below.secondaryAnimation!.value, moreOrLessEquals(0.6));
          await _backGesture(t, 'updateBackGestureProgress', progress: 0.7);
          expect(s.top.animation!.value, moreOrLessEquals(0.3));
          // The page below's element follows the finger out of its exit slice.
          expect(_opacity(t, 'b'), greaterThan(covered));
          // The top page leaves on its fade-out window: gone below 0.6.
          expect(_opacity(t, 't'), lessThan(1.0));

          final double released = s.top.animation!.value;
          final double releasedOpacity = _opacity(t, 't');
          await _backGesture(t, 'commitBackGesture');
          expect(s.top.animation!.status, AnimationStatus.reverse);
          // The pop continues from where the finger let go: the page never
          // comes back (Flutter 3.35+ restarts the route's own commit from
          // 1.0, which the detector must not inherit).
          double last = released;
          double lastOpacity = releasedOpacity;
          // A popped route is no longer active; follow its animation instead.
          while (!s.top.animation!.isDismissed) {
            final double v = s.top.animation!.value;
            expect(v, lessThanOrEqualTo(last + 1e-9), reason: 'pops one way');
            final double o = _opacity(t, 't');
            expect(o, lessThanOrEqualTo(lastOpacity + 1e-9));
            last = v;
            lastOpacity = o;
            await t.pump(const Duration(milliseconds: 16));
          }
          await t.pumpAndSettle();
          expect(s.top.isActive, isFalse);
          expect(s.below.isCurrent, isTrue);
          expect(s.below.secondaryAnimation!.value, 0.0);
          expect(_opacity(t, 'b'), 1.0);
          expect(s.nav.userGestureInProgress, isFalse);
        },
      );

      testWidgets('cancel settles back to the covering state', (
        WidgetTester t,
      ) async {
        final _Stack s = await _twoPages(t, install);
        final double covered = _opacity(t, 'b');
        await _backGesture(t, 'startBackGesture');
        await _backGesture(t, 'updateBackGestureProgress', progress: 0.8);
        expect(s.top.animation!.value, moreOrLessEquals(0.2));

        await _backGesture(t, 'cancelBackGesture');
        double last = s.top.animation!.value;
        for (int i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 16));
          final double v = s.top.animation!.value;
          expect(v, greaterThanOrEqualTo(last), reason: 'settles one way');
          last = v;
        }
        await t.pumpAndSettle();
        expect(s.top.isCurrent, isTrue);
        expect(s.top.animation!.value, 1.0);
        expect(s.below.secondaryAnimation!.value, 1.0);
        expect(_opacity(t, 'b'), covered);
        expect(_opacity(t, 't'), 1.0);
        expect(s.nav.userGestureInProgress, isFalse);
      });

      testWidgets(
        'PopScope(canPop: false) refuses the gesture; commit asks the '
        'PopScope instead of popping',
        (WidgetTester t) async {
          int refused = 0;
          final _Stack s = await _twoPages(
            t,
            install,
            wrapTop: (Widget page) => PopScope<Object?>(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? _) {
                if (!didPop) refused++;
              },
              child: page,
            ),
          );
          await _backGesture(t, 'startBackGesture');
          await _backGesture(t, 'updateBackGestureProgress', progress: 0.7);
          expect(s.top.animation!.value, 1.0);
          expect(s.nav.userGestureInProgress, isFalse);
          await _backGesture(t, 'commitBackGesture');
          await t.pumpAndSettle();
          expect(s.top.isCurrent, isTrue);
          expect(refused, 1);
        },
      );

      testWidgets(
        'a route that is not current does not claim the gesture (a dialog '
        'above gets the plain pop)',
        (WidgetTester t) async {
          final _Stack s = await _twoPages(t, install);
          showDialog<void>(
            context: s.nav.context,
            builder: (_) => const Text('dialog'),
          );
          await t.pumpAndSettle();
          expect(s.top.isCurrent, isFalse);
          await _backGesture(t, 'startBackGesture');
          await _backGesture(t, 'updateBackGestureProgress', progress: 0.7);
          expect(s.top.animation!.value, 1.0);
          await _backGesture(t, 'commitBackGesture');
          await t.pumpAndSettle();
          expect(find.text('dialog'), findsNothing);
          expect(s.top.isCurrent, isTrue);
          expect(s.top.animation!.value, 1.0);
        },
      );

      testWidgets(
        'the back-button form of the message is left to the plain pop',
        (WidgetTester t) async {
          final _Stack s = await _twoPages(t, install);
          await _backGesture(t, 'startBackGesture', button: true);
          expect(s.nav.userGestureInProgress, isFalse);
          expect(s.top.animation!.value, 1.0);
        },
      );

      testWidgets(
        'removing the route mid-gesture releases the navigator gesture flag',
        (WidgetTester t) async {
          final _Stack s = await _twoPages(t, install);
          await _backGesture(t, 'startBackGesture');
          await _backGesture(t, 'updateBackGestureProgress', progress: 0.5);
          expect(s.nav.userGestureInProgress, isTrue);
          s.nav.removeRoute(s.top);
          await t.pumpAndSettle();
          expect(s.below.isCurrent, isTrue);
          expect(s.nav.userGestureInProgress, isFalse);
          // A late cancel from the system is then a no-op.
          await _backGesture(t, 'cancelBackGesture');
          await t.pumpAndSettle();
          expect(s.below.isCurrent, isTrue);
        },
      );
    });
  }

  for (final _Install install in _Install.values) {
    testWidgets(
      'one handler per gesture: Flutter adds no observer of its own to the '
      'page, and the stock detector of the page below stays out, '
      '${install.name}',
      (WidgetTester t) async {
        final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
        final _PopCounter pops = _PopCounter();
        await t.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            navigatorObservers: <NavigatorObserver>[pops],
            // The CnPageRoute install sits over Flutter's predictive-back
            // builder, so the page below carries Flutter's own detector.
            theme: install == _Install.cnPageRoute
                ? ThemeData(
                    platform: TargetPlatform.android,
                    pageTransitionsTheme: const PageTransitionsTheme(
                      builders: <TargetPlatform, PageTransitionsBuilder>{
                        TargetPlatform.android:
                            PredictiveBackPageTransitionsBuilder(),
                      },
                    ),
                  )
                : _theme(install, TargetPlatform.android),
            home: const SizedBox(),
          ),
        );
        key.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => _element('b')),
        );
        await t.pumpAndSettle();
        final _CountsBackGesture<void> top = switch (install) {
          _Install.cnPageRoute => _CountingCnPageRoute(
            builder: (_) => _element('t'),
          ),
          _Install.themeOverMaterial => _CountingMaterialPageRoute(
            builder: (_) => _element('t'),
          ),
        };
        key.currentState!.push(top);
        await t.pumpAndSettle();
        expect(pops.pops, 0);

        await _backGesture(t, 'startBackGesture');
        await _backGesture(t, 'updateBackGestureProgress', progress: 0.4);
        await _backGesture(t, 'cancelBackGesture');
        await t.pumpAndSettle();
        expect(top.isCurrent, isTrue);

        await _backGesture(t, 'startBackGesture');
        await _backGesture(t, 'updateBackGestureProgress', progress: 0.6);
        await _backGesture(t, 'commitBackGesture');
        await t.pumpAndSettle();

        expect(top.starts, 2);
        expect(top.updates, 2);
        // The detector settles the release itself (see _settlePredictive).
        expect(top.routeCommits, 0);
        expect(top.routeCancels, 0);
        expect(pops.pops, 1);
        expect(key.currentState!.canPop(), isTrue, reason: "'b' remains");
        expect(key.currentState!.userGestureInProgress, isFalse);
      },
    );
  }

  /// Drags from [from] by [steps] moves of [step], pumping after each.
  Future<TestGesture> drag(
    WidgetTester t,
    Offset from,
    Offset step, {
    int steps = 3,
  }) async {
    final TestGesture g = await t.startGesture(from);
    await t.pump();
    for (int i = 0; i < steps; i++) {
      await g.moveBy(step);
      await t.pump();
    }
    return g;
  }

  for (final _Install install in _Install.values) {
    group('iOS edge swipe-back, ${install.name}', () {
      testWidgets(
        'an edge drag scrubs the route and the elements; releasing past '
        'half pops',
        (WidgetTester t) async {
          final _Stack s = await _twoPages(
            t,
            install,
            platform: TargetPlatform.iOS,
          );
          final double covered = _opacity(t, 'b');
          final TestGesture g = await drag(
            t,
            const Offset(5, 300),
            const Offset(200, 0),
          );
          expect(s.nav.userGestureInProgress, isTrue);
          final double a = s.top.animation!.value;
          expect(a, inExclusiveRange(0.0, 0.5));
          expect(s.top.animation!.status, AnimationStatus.forward);
          expect(s.below.secondaryAnimation!.value, moreOrLessEquals(a));
          expect(_opacity(t, 'b'), greaterThan(covered));

          // Back toward the edge a little: the route follows the finger.
          await g.moveBy(const Offset(-80, 0));
          await t.pump();
          expect(s.top.animation!.value, moreOrLessEquals(a + 80 / 800));

          await g.up();
          await t.pump();
          expect(s.top.animation!.status, AnimationStatus.reverse);
          await t.pumpAndSettle();
          expect(s.top.isActive, isFalse);
          expect(s.below.isCurrent, isTrue);
          expect(_opacity(t, 'b'), 1.0);
          expect(s.nav.userGestureInProgress, isFalse);
        },
      );

      testWidgets('releasing before half settles back', (WidgetTester t) async {
        final _Stack s = await _twoPages(
          t,
          install,
          platform: TargetPlatform.iOS,
        );
        final double covered = _opacity(t, 'b');
        final TestGesture g = await drag(
          t,
          const Offset(5, 300),
          const Offset(40, 0),
        );
        expect(s.top.animation!.value, inExclusiveRange(0.5, 1.0));
        await g.up();
        await t.pumpAndSettle();
        expect(s.top.isCurrent, isTrue);
        expect(s.top.animation!.value, 1.0);
        expect(s.below.secondaryAnimation!.value, 1.0);
        expect(_opacity(t, 'b'), covered);
        expect(s.nav.userGestureInProgress, isFalse);
      });

      testWidgets('a cancelled pointer mid-drag settles back', (
        WidgetTester t,
      ) async {
        final _Stack s = await _twoPages(
          t,
          install,
          platform: TargetPlatform.iOS,
        );
        final TestGesture g = await drag(
          t,
          const Offset(5, 300),
          const Offset(50, 0),
        );
        expect(s.top.animation!.value, lessThan(1.0));
        await g.cancel();
        await t.pumpAndSettle();
        expect(s.top.isCurrent, isTrue);
        expect(s.top.animation!.value, 1.0);
        expect(s.nav.userGestureInProgress, isFalse);
      });

      testWidgets('a drag that starts away from the edge does nothing', (
        WidgetTester t,
      ) async {
        final _Stack s = await _twoPages(
          t,
          install,
          platform: TargetPlatform.iOS,
        );
        final TestGesture g = await drag(
          t,
          const Offset(100, 300),
          const Offset(200, 0),
        );
        expect(s.nav.userGestureInProgress, isFalse);
        expect(s.top.animation!.value, 1.0);
        await g.up();
        await t.pumpAndSettle();
        expect(s.top.isCurrent, isTrue);
      });

      testWidgets(
        'fullscreenDialog routes have no edge swipe, as in Cupertino',
        (WidgetTester t) async {
          final _Stack s = await _twoPages(
            t,
            install,
            platform: TargetPlatform.iOS,
            fullscreenDialog: true,
          );
          final TestGesture g = await drag(
            t,
            const Offset(5, 300),
            const Offset(200, 0),
          );
          expect(s.nav.userGestureInProgress, isFalse);
          expect(s.top.animation!.value, 1.0);
          await g.up();
          await t.pumpAndSettle();
          expect(s.top.isCurrent, isTrue);
        },
      );

      testWidgets('PopScope(canPop: false) refuses the swipe', (
        WidgetTester t,
      ) async {
        final _Stack s = await _twoPages(
          t,
          install,
          platform: TargetPlatform.iOS,
          wrapTop: (Widget page) =>
              PopScope<Object?>(canPop: false, child: page),
        );
        final TestGesture g = await drag(
          t,
          const Offset(5, 300),
          const Offset(200, 0),
        );
        expect(s.nav.userGestureInProgress, isFalse);
        expect(s.top.animation!.value, 1.0);
        await g.up();
        await t.pumpAndSettle();
        expect(s.top.isCurrent, isTrue);
      });

      testWidgets('no edge swipe on Android (the system gesture is used)', (
        WidgetTester t,
      ) async {
        final _Stack s = await _twoPages(t, install);
        final TestGesture g = await drag(
          t,
          const Offset(5, 300),
          const Offset(200, 0),
        );
        expect(s.nav.userGestureInProgress, isFalse);
        expect(s.top.animation!.value, 1.0);
        await g.up();
        await t.pumpAndSettle();
        expect(s.top.isCurrent, isTrue);
      });

      testWidgets('right-to-left: the swipe starts at the right edge', (
        WidgetTester t,
      ) async {
        final _Stack s = await _twoPages(
          t,
          install,
          platform: TargetPlatform.iOS,
          appBuilder: (BuildContext context, Widget? child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
        );
        final TestGesture g = await drag(
          t,
          const Offset(795, 300),
          const Offset(-200, 0),
        );
        expect(s.nav.userGestureInProgress, isTrue);
        expect(s.top.animation!.value, inExclusiveRange(0.0, 0.5));
        await g.up();
        await t.pumpAndSettle();
        expect(s.below.isCurrent, isTrue);
      });

      testWidgets(
        'a route pushed above mid-drag: release settles this route back '
        'to fully shown',
        (WidgetTester t) async {
          final _Stack s = await _twoPages(
            t,
            install,
            platform: TargetPlatform.iOS,
          );
          final TestGesture g = await drag(
            t,
            const Offset(5, 300),
            const Offset(100, 0),
          );
          expect(s.top.animation!.value, lessThan(1.0));
          s.nav.push(_route(install, (_) => _element('third')));
          await t.pump();
          expect(s.top.isCurrent, isFalse);
          await g.up();
          await t.pumpAndSettle();
          expect(s.top.isActive, isTrue);
          expect(s.top.animation!.value, 1.0);
          expect(s.nav.userGestureInProgress, isFalse);
          s.nav.pop();
          await t.pumpAndSettle();
          expect(s.top.isCurrent, isTrue);
          expect(_opacity(t, 't'), 1.0);
        },
      );

      testWidgets('a programmatic pop mid-drag finishes the pop cleanly', (
        WidgetTester t,
      ) async {
        final _Stack s = await _twoPages(
          t,
          install,
          platform: TargetPlatform.iOS,
        );
        final TestGesture g = await drag(
          t,
          const Offset(5, 300),
          const Offset(50, 0),
        );
        s.nav.pop();
        await t.pump();
        await g.up();
        await t.pumpAndSettle();
        expect(s.top.isActive, isFalse);
        expect(s.below.isCurrent, isTrue);
        expect(s.nav.userGestureInProgress, isFalse);
      });
    });
  }
}
