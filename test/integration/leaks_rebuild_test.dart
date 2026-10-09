// Leaks and mid-transition rebuilds (design §8 "Leaks" and "Mid-transition
// rebuild", §5 "Lists rebuilt mid-transition").
//
// The leak check counts disposables through FlutterMemoryAllocations
// (AnimationController, CurvedAnimation, ChangeNotifier, ...). The page
// record is an Expando keyed by the route, so it cannot be counted from a
// test; its weakness is a Dart guarantee and a strict GC check is not
// possible in flutter_test (best effort, as the design says).
import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Keyed 60 px elements for [ids]; a tap pushes a detail page with its own
/// elements. Keys keep each element's State when the set is filtered.
Widget filteredPage(ValueNotifier<List<int>> ids, Install install) =>
    ValueListenableBuilder<List<int>>(
      valueListenable: ids,
      builder: (BuildContext context, List<int> list, _) => column(<Widget>[
        for (final int i in list)
          item(
            'p$i',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                routeFor<void>(
                  install,
                  (_) => column(<Widget>[item('d0'), item('d1')]),
                ),
              ),
              child: SizedBox(height: 60, child: Text('p$i')),
            ),
          ),
      ]),
    );

Map<String, int> liveCounts(AllocationTracker tracker) => <String, int>{
      for (final String className in tracker.created.keys)
        className: tracker.live(className).length,
    };

void main() {
  for (final Install install in Install.values) {
    group(install.name, () {
      testWidgets(
          'five push / part / dialog / scroll-reveal / pop cycles leave no '
          'live disposables behind', (WidgetTester tester) async {
        final AllocationTracker tracker = AllocationTracker()..start();
        addTearDown(tracker.stop);
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          const SizedBox(),
          theme: themeFor(install),
          builder: (_, Widget? child) => CnRouteChoreography(
            scrollReveal: const CnScrollReveal(),
            child: child!,
          ),
        );
        await tester.pumpAndSettle();

        Future<void> cycle() async {
          final ScrollController scroll = ScrollController();
          nav.currentState!.push(
            routeFor<void>(
              install,
              (BuildContext context) => ListView.builder(
                controller: scroll,
                itemCount: 40,
                itemExtent: 100,
                itemBuilder: (BuildContext context, int i) => item(
                  'L$i',
                  timing: null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                      routeFor<void>(
                        install,
                        (_) => column(<Widget>[item('d0'), item('d1')]),
                      ),
                    ),
                    child: SizedBox(height: 100, child: Text('L$i')),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Late mounts with scroll reveal create timed controllers.
          scroll.jumpTo(800);
          await tester.pump();
          expect(opacityOf(tester, 'L13'), lessThan(1.0));
          await tester.pumpAndSettle();
          // Part around a tapped item, interrupt the detail push halfway.
          await tester.tap(find.text('L10'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));
          nav.currentState!.pop();
          await tester.pumpAndSettle();
          showDialog<void>(
            context: tester.element(find.text('L10')),
            builder: (_) => const AlertDialog(title: Text('dialog')),
          );
          await tester.pumpAndSettle();
          nav.currentState!.pop();
          await tester.pumpAndSettle();
          nav.currentState!.pop();
          await tester.pumpAndSettle();
          expect(exists('L10'), isFalse);
          scroll.dispose();
        }

        await cycle(); // warm-up: lazily created framework objects settle
        final Map<String, int> baseline = liveCounts(tracker);
        final int createdBefore =
            tracker.created['AnimationController']!.length;
        for (int i = 0; i < 5; i++) {
          await cycle();
        }
        expect(tester.takeException(), isNull);
        // The cycles did allocate (the tracker sees them) ...
        expect(
          tracker.created['AnimationController']!.length,
          greaterThan(createdBefore + 5),
        );
        // ... and every class is back to the baseline.
        final Map<String, int> after = liveCounts(tracker);
        for (final MapEntry<String, int> entry in after.entries) {
          expect(
            entry.value,
            lessThanOrEqualTo(baseline[entry.key] ?? 0),
            reason: '${entry.key}: ${entry.value} live after 5 cycles, '
                '${baseline[entry.key] ?? 0} before',
          );
        }
        final Iterable<AnimationController> fallbacks = tracker
            .live('AnimationController')
            .whereType<AnimationController>()
            .where(
                (AnimationController c) => c.debugLabel == 'CnTimedFallback');
        expect(fallbacks, isEmpty, reason: 'timed fallback controllers');
      });

      testWidgets(
          'the list is filtered mid-cover, removing the subject: no '
          'exception, siblings keep their vectors, all rest after the pop',
          (WidgetTester tester) async {
        final ValueNotifier<List<int>> ids = ValueNotifier<List<int>>(
          <int>[for (int i = 0; i < 9; i++) i],
        );
        addTearDown(ids.dispose);
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          const SizedBox(),
          theme: themeFor(install),
        );
        nav.currentState!.push(
          routeFor<void>(install, (_) => filteredPage(ids, install)),
        );
        await tester.pumpAndSettle();
        final ModalRoute<Object?> page = routeOf(tester, 'p0');
        await tester.tap(find.text('p4'));
        await tester.pump();
        while (page.secondaryAnimation!.value < 0.3) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(offsetOf(tester, 'p3').dy, lessThan(0));
        expect(offsetOf(tester, 'p5').dy, greaterThan(0));
        // Odd items only: the subject (p4) is gone, p5 and p7 move up in
        // the layout but keep the direction chosen at segment start.
        ids.value = <int>[1, 3, 5, 7];
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(exists('p4'), isFalse);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(page.secondaryAnimation!.value, 1.0);
        for (final int i in <int>[1, 3]) {
          expect(offsetOf(tester, 'p$i').dy, lessThan(0), reason: 'p$i');
          expect(opacityOf(tester, 'p$i'), 0.0, reason: 'p$i');
        }
        for (final int i in <int>[5, 7]) {
          expect(offsetOf(tester, 'p$i').dy, greaterThan(0), reason: 'p$i');
          expect(opacityOf(tester, 'p$i'), 0.0, reason: 'p$i');
        }

        nav.currentState!.pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final int i in <int>[1, 3, 5, 7]) {
          expect(offsetOf(tester, 'p$i'), Offset.zero, reason: 'p$i');
          expect(opacityOf(tester, 'p$i'), 1.0, reason: 'p$i');
        }
      });

      testWidgets(
          'the list is replaced mid-push (A = 0.3): new and kept elements '
          'follow the route and all rest when it completes',
          (WidgetTester tester) async {
        final ValueNotifier<List<int>> ids = ValueNotifier<List<int>>(
          <int>[0, 1, 2, 3],
        );
        addTearDown(ids.dispose);
        final GlobalKey<NavigatorState> nav = await pumpApp(
          tester,
          const SizedBox(),
          theme: themeFor(install),
        );
        nav.currentState!.push(
          routeFor<void>(install, (_) => filteredPage(ids, install)),
        );
        await tester.pump();
        final ModalRoute<Object?> page = routeOf(tester, 'p0');
        while (page.animation!.value < 0.3) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        ids.value = <int>[1, 3, 10, 11];
        await tester.pump();
        expect(tester.takeException(), isNull);
        // Kept and new elements follow the same progress (flat timing).
        while (!page.animation!.isCompleted) {
          final double shown = shownEntering(page.animation!.value);
          for (final int i in <int>[1, 3, 10, 11]) {
            expect(
                opacityOf(tester, 'p$i'), moreOrLessEquals(shown, epsilon: eps),
                reason: 'p$i');
          }
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump();
        for (final int i in <int>[1, 3, 10, 11]) {
          expect(opacityOf(tester, 'p$i'), 1.0, reason: 'p$i');
          expect(offsetOf(tester, 'p$i'), Offset.zero, reason: 'p$i');
        }
        expect(tester.takeException(), isNull);
      });
    });
  }
}
