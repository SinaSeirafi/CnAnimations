// Overlays and secondaryAnimation (design §4 dialog rows, §5 "Dialogs and
// sheets", §5 generic-type quirk; README "Routes": dialogs, bottom sheets
// and full-screen dialogs do not cover the page, so elements stay).
//
// Each overlay kind is opened from a tap inside an element (the realistic
// case: the pointer-down is recorded, but nothing must part) over three
// page kinds. The counter-tests pin the documented cases where a route over
// the page does cover it.
import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

enum PageKind { materialWithTheme, pageRouteBuilder, cnPageRoute }

Route<T> pageRoute<T>(PageKind kind, WidgetBuilder builder) {
  switch (kind) {
    case PageKind.materialWithTheme:
      return MaterialPageRoute<T>(builder: builder);
    case PageKind.pageRouteBuilder:
      return PageRouteBuilder<T>(
        pageBuilder: (BuildContext context, _, __) => builder(context),
      );
    case PageKind.cnPageRoute:
      return CnPageRoute<T>(builder: builder);
  }
}

/// The overlay kinds of design §8, each opened from [context].
final Map<String, void Function(BuildContext context)> overlays =
    <String, void Function(BuildContext context)>{
  'showDialog': (BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('overlay')),
      ),
  'showGeneralDialog': (BuildContext context) => showGeneralDialog<void>(
        context: context,
        pageBuilder: (_, __, ___) => const Center(child: Text('overlay')),
      ),
  'showModalBottomSheet': (BuildContext context) => showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 200, child: Text('overlay')),
      ),
  'showCupertinoDialog': (BuildContext context) => showCupertinoDialog<void>(
        context: context,
        builder: (_) => const CupertinoAlertDialog(title: Text('overlay')),
      ),
  'showCupertinoModalPopup': (BuildContext context) =>
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => const SizedBox(height: 200, child: Text('overlay')),
      ),
  'fullscreenDialog': (BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const Scaffold(body: Text('overlay')),
        ),
      ),
};

/// Three elements; tapping 'e1' runs [onTap]. 'e2' reports its progress.
Widget overlayPage(ProgressLog log, void Function(BuildContext) onTap) =>
    Builder(
      builder: (BuildContext context) => column(<Widget>[
        item('e0'),
        item(
          'e1',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(context),
            child: const SizedBox(height: 100, child: Text('open')),
          ),
        ),
        item('e2', builder: log.builder),
      ]),
    );

/// The theme form needs the theme; the other two run on the stock theme.
ThemeData pageTheme(PageKind kind) => kind == PageKind.materialWithTheme
    ? fadeThroughTheme()
    : ThemeData(platform: TargetPlatform.android);

/// Pushes [page] with [kind] and settles it.
Future<GlobalKey<NavigatorState>> pushPage(
  WidgetTester tester,
  PageKind kind,
  WidgetBuilder page,
) async {
  final GlobalKey<NavigatorState> nav = await pumpApp(
    tester,
    const SizedBox(),
    theme: pageTheme(kind),
  );
  nav.currentState!.push(pageRoute<void>(kind, page));
  await tester.pumpAndSettle();
  return nav;
}

void expectAtRest(WidgetTester tester, ProgressLog log, {String? reason}) {
  expect(routeOf(tester, 'e0').secondaryAnimation!.isDismissed, isTrue,
      reason: reason);
  for (final String label in <String>['e0', 'e1']) {
    expect(opacityOf(tester, label), 1.0, reason: '$label ${reason ?? ''}');
    expect(offsetOf(tester, label), Offset.zero,
        reason: '$label ${reason ?? ''}');
  }
  expect(log.last, CnElementProgress.rest, reason: 'e2 ${reason ?? ''}');
}

void main() {
  group('overlays do not cover the page', () {
    for (final PageKind kind in PageKind.values) {
      for (final MapEntry<String, void Function(BuildContext)> overlay
          in overlays.entries) {
        testWidgets('${overlay.key} over a ${kind.name} page',
            (WidgetTester tester) async {
          final ProgressLog log = ProgressLog();
          final GlobalKey<NavigatorState> nav = await pushPage(
            tester,
            kind,
            (_) => overlayPage(log, overlay.value),
          );
          expectAtRest(tester, log, reason: 'before');
          await tester.tap(find.text('open'));
          for (int i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            expectAtRest(tester, log, reason: 'frame $i');
          }
          await tester.pumpAndSettle();
          expect(find.text('overlay'), findsOneWidget);
          expectAtRest(tester, log, reason: 'overlay open');
          nav.currentState!.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expectAtRest(tester, log, reason: 'closing');
          await tester.pumpAndSettle();
          expect(find.text('overlay'), findsNothing);
          expectAtRest(tester, log, reason: 'closed');
        });
      }
    }
  });

  group('counter-tests: non-opaque routes and the generic quirk', () {
    Route<void> transparent() => PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, __, ___) => const Center(child: Text('overlay')),
        );

    /// Plain elements fully covered: at the mirrored exit offset, faded out.
    void expectCovered(WidgetTester tester, ProgressLog log) {
      expect(routeOf(tester, 'e0').secondaryAnimation!.value, 1.0);
      expect(opacityOf(tester, 'e0'), 0.0);
      expect(offsetOf(tester, 'e0'), const Offset(0, -0.1));
      expect(log.last!.covered, 1.0);
    }

    testWidgets(
        'PageRouteBuilder(opaque: false) over a PageRouteBuilder page covers '
        'it (PageRoute.canTransitionTo only checks `is PageRoute`, §5)',
        (WidgetTester tester) async {
      final ProgressLog log = ProgressLog();
      final GlobalKey<NavigatorState> nav = await pushPage(
        tester,
        PageKind.pageRouteBuilder,
        (_) => overlayPage(log, (_) {}),
      );
      nav.currentState!.push(transparent());
      await tester.pumpAndSettle();
      expectCovered(tester, log);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expectAtRest(tester, log);
    });

    // Design §8 expected this case to cover. It does not: the Material
    // mixin's canTransitionTo accepts only Material routes or routes with a
    // delegatedTransition, and a PageRouteBuilder has neither. This matches
    // the README ("non-opaque routes do not cover the page").
    testWidgets(
        'PageRouteBuilder(opaque: false) over a MaterialPageRoute page (theme '
        'form) does not cover it', (WidgetTester tester) async {
      final ProgressLog log = ProgressLog();
      final GlobalKey<NavigatorState> nav = await pushPage(
        tester,
        PageKind.materialWithTheme,
        (_) => overlayPage(log, (_) {}),
      );
      nav.currentState!.push(transparent());
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expectAtRest(tester, log, reason: 'frame $i');
      }
      await tester.pumpAndSettle();
      expect(find.text('overlay'), findsOneWidget);
      expectAtRest(tester, log);
    });

    testWidgets(
        'PageRouteBuilder(opaque: false) over a CnPageRoute page does '
        'not cover it', (WidgetTester tester) async {
      final ProgressLog log = ProgressLog();
      final GlobalKey<NavigatorState> nav = await pushPage(
        tester,
        PageKind.cnPageRoute,
        (_) => overlayPage(log, (_) {}),
      );
      nav.currentState!.push(transparent());
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expectAtRest(tester, log, reason: 'frame $i');
      }
      await tester.pumpAndSettle();
      expect(find.text('overlay'), findsOneWidget);
      expectAtRest(tester, log);
    });

    testWidgets(
        'generic quirk: MaterialPageRoute<int> page under CnPageRoute<void> '
        'is covered', (WidgetTester tester) async {
      final ProgressLog log = ProgressLog();
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
        theme: ThemeData(platform: TargetPlatform.android),
      );
      nav.currentState!.push(
        MaterialPageRoute<int>(builder: (_) => overlayPage(log, (_) {})),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        CnPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      expectCovered(tester, log);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expectAtRest(tester, log);
    });

    testWidgets(
        'generic quirk guard: MaterialPageRoute<int> page under a bare '
        'PageRouteBuilder<void> is not covered', (WidgetTester tester) async {
      final ProgressLog log = ProgressLog();
      final GlobalKey<NavigatorState> nav = await pumpApp(
        tester,
        const SizedBox(),
        theme: ThemeData(platform: TargetPlatform.android),
      );
      nav.currentState!.push(
        MaterialPageRoute<int>(builder: (_) => overlayPage(log, (_) {})),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        PageRouteBuilder<void>(pageBuilder: (_, __, ___) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      expectAtRest(tester, log);
    });
  });
}
