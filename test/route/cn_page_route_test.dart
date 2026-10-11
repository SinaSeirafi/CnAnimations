import 'package:cn_animations/src/choreography/cn_route_choreography.dart';
import 'package:cn_animations/src/route/cn_fade_through_page_transitions_builder.dart';
import 'package:cn_animations/src/route/cn_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the ModalRoute of the page it sits in.
class _Probe extends StatelessWidget {
  const _Probe(this.rec, {this.label = 'page'});
  final _Rec rec;
  final String label;
  @override
  Widget build(BuildContext context) {
    rec.route = ModalRoute.of(context);
    return Text(label);
  }
}

class _Rec {
  ModalRoute<dynamic>? route;
  Animation<double> get secondary => route!.secondaryAnimation!;
}

const _ms = Duration(milliseconds: 100);

Future<void> _pumpFrames(WidgetTester t, {int frames = 3}) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

double _opacityOf(WidgetTester t, String label) {
  final f = find.ancestor(
    of: find.text(label),
    matching: find.byType(FadeTransition),
  );
  return t.widget<FadeTransition>(f.first).opacity.value;
}

Future<GlobalKey<NavigatorState>> _app(
  WidgetTester t,
  _Rec home, {
  ThemeData? theme,
}) async {
  final nav = GlobalKey<NavigatorState>();
  await t.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      theme: theme,
      home: _Probe(home, label: 'home'),
    ),
  );
  return nav;
}

void main() {
  group('CnFadeThroughPageTransitionsBuilder', () {
    testWidgets('fades in over [0.3, 1] on push and out over [0.6, 1] on pop', (
      t,
    ) async {
      final home = _Rec();
      final nav = await _app(t, home);
      nav.currentState!.push(CnPageRoute<void>(builder: (_) => _Probe(_Rec())));
      await t.pump(); // route installed, ticker starts
      await t.pump(_ms); // progress 0.25
      expect(_opacityOf(t, 'page'), 0.0);
      await t.pump(_ms); // progress 0.5 -> (0.5-0.3)/0.7
      expect(_opacityOf(t, 'page'), closeTo(0.2 / 0.7, 0.02));
      await t.pumpAndSettle();
      expect(_opacityOf(t, 'page'), 1.0);

      nav.currentState!.pop();
      await t.pump();
      await t.pump(_ms); // progress 0.75 -> (0.75-0.6)/0.4
      expect(_opacityOf(t, 'page'), closeTo(0.375, 0.02));
      await t.pump(_ms); // progress 0.5 -> gone
      expect(_opacityOf(t, 'page'), 0.0);
    });

    testWidgets('delegatedTransition is non-null and returns its child', (
      t,
    ) async {
      const builder = CnFadeThroughPageTransitionsBuilder();
      expect(builder.delegatedTransition, isNotNull);
      await t.pumpWidget(const SizedBox());
      const child = SizedBox();
      const anim = AlwaysStoppedAnimation<double>(0);
      final result = builder.delegatedTransition!(
        t.element(find.byType(SizedBox)),
        anim,
        anim,
        false,
        child,
      );
      expect(identical(result, child), isTrue);
    });

    test('durations are 400 ms both ways', () {
      const builder = CnFadeThroughPageTransitionsBuilder();
      expect(builder.transitionDuration, const Duration(milliseconds: 400));
      expect(
        builder.reverseTransitionDuration,
        const Duration(milliseconds: 400),
      );
      final route = CnPageRoute<void>(builder: (_) => const SizedBox());
      expect(route.transitionDuration, const Duration(milliseconds: 400));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 400),
      );
    });

    testWidgets(
      'installed via pageTransitionsTheme, a MaterialPageRoute uses it',
      (t) async {
        final home = _Rec();
        final nav = await _app(
          t,
          home,
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CnFadeThroughPageTransitionsBuilder(),
              },
            ),
          ),
        );
        final route = MaterialPageRoute<void>(builder: (_) => _Probe(_Rec()));
        nav.currentState!.push(route);
        await t.pump();
        expect(route.transitionDuration, const Duration(milliseconds: 400));
        await t.pump(_ms);
        expect(_opacityOf(t, 'page'), 0.0);
        await t.pump(_ms);
        expect(_opacityOf(t, 'page'), closeTo(0.2 / 0.7, 0.02));
        // The page below runs its secondary animation (delegated transition).
        expect(home.secondary.value, greaterThan(0));
      },
    );
  });

  group('CnPageRoute covering behaviour', () {
    testWidgets('MaterialPageRoute<int> beneath CnPageRoute<void> drives its '
        'secondaryAnimation', (t) async {
      final home = _Rec();
      final below = _Rec();
      final nav = await _app(t, home);
      nav.currentState!.push(
        MaterialPageRoute<int>(builder: (_) => _Probe(below)),
      );
      await t.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await _pumpFrames(t);
      expect(below.secondary.value, greaterThan(0));
      await t.pumpAndSettle();
      expect(below.secondary.value, 1.0);
    });

    testWidgets('MaterialPageRoute<dynamic> and a PageRouteBuilder below also '
        'animate under CnPageRoute', (t) async {
      final home = _Rec();
      final nav = await _app(t, home);
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await _pumpFrames(t);
      expect(home.secondary.value, greaterThan(0));
      await t.pumpAndSettle();
      nav.currentState!.pop();
      await t.pumpAndSettle();

      final prb = _Rec();
      nav.currentState!.push(
        PageRouteBuilder<void>(pageBuilder: (_, _, _) => _Probe(prb)),
      );
      await t.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await _pumpFrames(t);
      // PageRouteBuilder uses PageRoute.canTransitionTo: any opaque PageRoute.
      expect(prb.secondary.value, greaterThan(0));
    });

    testWidgets('CnPageRoute under another CnPageRoute animates', (t) async {
      final home = _Rec();
      final cn = _Rec();
      final nav = await _app(t, home);
      nav.currentState!.push(CnPageRoute<void>(builder: (_) => _Probe(cn)));
      await t.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await _pumpFrames(t);
      expect(cn.secondary.value, greaterThan(0));
    });

    testWidgets('PageRouteBuilder(opaque: false) does not cover a CnPageRoute '
        'page', (t) async {
      final home = _Rec();
      final cn = _Rec();
      final nav = await _app(t, home);
      nav.currentState!.push(CnPageRoute<void>(builder: (_) => _Probe(cn)));
      await t.pumpAndSettle();
      nav.currentState!.push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, _, _) => const SizedBox(),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      await _pumpFrames(t);
      expect(cn.secondary.value, 0.0);
      expect(cn.secondary.isDismissed, isTrue);
    });

    testWidgets('fullscreenDialog routes do not cover a CnPageRoute page', (
      t,
    ) async {
      final home = _Rec();
      final cn = _Rec();
      final nav = await _app(t, home);
      nav.currentState!.push(CnPageRoute<void>(builder: (_) => _Probe(cn)));
      await t.pumpAndSettle();
      nav.currentState!.push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const SizedBox(),
        ),
      );
      await _pumpFrames(t);
      expect(cn.secondary.value, 0.0);
      await t.pumpAndSettle();
      nav.currentState!.pop();
      await t.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const SizedBox(),
        ),
      );
      await _pumpFrames(t);
      expect(cn.secondary.value, 0.0);
    });

    testWidgets('dialogs and sheets do not cover a CnPageRoute page', (
      t,
    ) async {
      final home = _Rec();
      final cn = _Rec();
      final nav = await _app(t, home);
      nav.currentState!.push(CnPageRoute<void>(builder: (_) => _Probe(cn)));
      await t.pumpAndSettle();
      final ctx = cn.route!.subtreeContext!;

      showDialog<void>(
        context: ctx,
        builder: (_) => const AlertDialog(title: Text('d')),
      );
      await _pumpFrames(t);
      expect(cn.secondary.value, 0.0);
      nav.currentState!.pop();
      await t.pumpAndSettle();

      showGeneralDialog<void>(
        context: ctx,
        pageBuilder: (_, _, _) => const Text('g'),
      );
      await _pumpFrames(t);
      expect(cn.secondary.value, 0.0);
      nav.currentState!.pop();
      await t.pumpAndSettle();

      showModalBottomSheet<void>(
        context: ctx,
        builder: (_) => const SizedBox(height: 100),
      );
      await _pumpFrames(t);
      expect(cn.secondary.value, 0.0);
    });
  });

  // Review R8: `timing` never did anything on the routes. It is deprecated
  // in 0.9.0 and removed in 1.0.0; this group pins the deprecated surface
  // and goes with it.
  group('deprecated timing parameter', () {
    test('still accepted and stored, with no effect on the transition', () {
      expect(
        // ignore: deprecated_member_use_from_same_package
        const CnFadeThroughPageTransitionsBuilder().timing,
        CnRouteTiming.standard,
      );
      final route = CnPageRoute<void>(builder: (_) => const SizedBox());
      // ignore: deprecated_member_use_from_same_package
      expect(route.timing, CnRouteTiming.standard);
      const custom = CnRouteTiming(exitStagger: 0.5);
      final r2 = CnPageRoute<void>(
        builder: (_) => const SizedBox(),
        // ignore: deprecated_member_use_from_same_package
        timing: custom,
      );
      // ignore: deprecated_member_use_from_same_package
      expect(r2.timing, same(custom));
      expect(r2.transitionDuration, route.transitionDuration);
      expect(r2.reverseTransitionDuration, route.reverseTransitionDuration);
    });
  });

  group('debugLabel', () {
    test('appends the route name only when there is one', () {
      final unnamed = CnPageRoute<void>(builder: (_) => const SizedBox());
      expect(unnamed.debugLabel, 'CnPageRoute<void>');
      final named = CnPageRoute<void>(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/detail'),
      );
      expect(named.debugLabel, 'CnPageRoute<void>(/detail)');
    });
  });
}
