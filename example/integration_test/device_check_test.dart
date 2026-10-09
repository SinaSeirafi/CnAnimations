// On-device check of the 0.9.0 route choreography (STATUS step 7), run on a
// real engine: `flutter test integration_test -d <device>`.
//
// It drives the real example app. Touches are synthesized by the test, but on
// iOS the edge swipe-back is implemented in Flutter (CnBackGestureDetector),
// so a synthesized drag goes through the same recognizer and route code a
// finger would. Every check prints `CNREPORT` lines with the measured values.
//
// iOS only: on Android the back gesture comes from the system (predictive
// back), which a synthesized drag cannot produce, so the suite skips there.
import 'dart:io' show Platform;

import 'package:cn_animations/cn_animations.dart';
import 'package:example/main.dart';
import 'package:example/pages/detail_page.dart';
import 'package:example/restart_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'device_check_support.dart';

/// The two ways the example installs the fade-through.
enum Install { themeMaterial, cnPageRoute }

/// How the detail page is opened: a tap on item 3 (item 3 becomes the
/// subject, its siblings part) or a push with no pointer-down (no subject:
/// every item takes the plain exit, `exitOffset` = -`enterOffset`).
enum Open { tapped, programmatic }

const int subjectIndex = 3;
const List<String> topLabels = <String>[
  'detail-paragraph-0',
  'detail-paragraph-1',
  'detail-paragraph-2',
];

/// Visible means more than 5 % opacity reaches the screen.
const double visibleThreshold = 0.05;

/// R6 (uncover slice): a point is dead when neither page's elements reach
/// 1 % opacity on screen, the measure of `test/route/uncover_gap_test.dart`.
const double deadThreshold = 0.01;

/// The zero-width boundary left by the default uncover slice: the top
/// element has just finished leaving (A = 0.65) and the element below has
/// not started to return (`uncover` = Interval(0.3, 0.65) of S = A).
const double uncoverBoundary = 0.65;

/// One scrub step (4 px of a 402 px wide screen) in route progress.
const double boundaryTolerance = 0.011;

/// Asserts the R6 fix: no sample where neither page's elements are visible,
/// except at most one sample at the boundary. Returns the dead progresses.
List<double> expectNoDeadZone(
  String name,
  List<({double a, double top, double below})> samples,
) {
  final List<double> dead = <double>[
    for (final ({double a, double top, double below}) e in samples)
      if (e.top < deadThreshold && e.below < deadThreshold) e.a,
  ];
  expect(dead.length, lessThanOrEqualTo(1),
      reason: '$name: dead samples at A = $dead');
  for (final double a in dead) {
    expect((a - uncoverBoundary).abs(), lessThanOrEqualTo(boundaryTolerance),
        reason: '$name: dead sample away from the boundary, A = $a');
  }
  return dead;
}

String listLabel(int i) => 'list-item-$i';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Every engine frame is drawn, as in the real app; the samplers below read
  // one value set per frame.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  if (!Platform.isIOS) {
    testWidgets('device check (iOS only)', (WidgetTester tester) async {},
        skip: true);
    return;
  }

  Future<void> wait(WidgetTester tester, int ms) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    await tester.pump();
  }

  /// Launches the example and opens the List page through its button.
  Future<void> openList(WidgetTester tester) async {
    await tester.pumpWidget(const RestartWidget(child: ExampleApp()));
    await wait(tester, 1200);
    await tester.tap(find.text('List'));
    await wait(tester, 900);
    expect(find.text('Tap a card, then swipe back.'), findsOneWidget);
  }

  /// List items whose rect is on screen now.
  List<String> visibleListLabels(WidgetTester tester) => <String>[
        for (int i = 0; i < 20; i++)
          if (exists(listLabel(i)) && onScreen(tester, listLabel(i)))
            listLabel(i),
      ];

  /// Opens Detail [subjectIndex] over the list with [install] and [open].
  Future<void> openDetail0(
    WidgetTester tester,
    Install install,
    Open open,
  ) async {
    final NavigatorState nav = Navigator.of(
      tester.element(keyed(listLabel(subjectIndex))),
    );
    if (install == Install.themeMaterial && open == Open.tapped) {
      // The example's own path: ListTile.onTap → MaterialPageRoute.
      await tester.tap(find.text('Item $subjectIndex'));
    } else {
      if (open == Open.tapped) {
        // Pointer-down on the item marks it as the subject (700 ms window)
        // without triggering the ListTile's own push.
        final TestGesture g = await tester.startGesture(
          tester.getCenter(keyed(listLabel(subjectIndex))),
        );
        await g.cancel();
      }
      Widget page(BuildContext _) => const DetailPage(index: subjectIndex);
      nav.push(
        install == Install.cnPageRoute
            ? CnPageRoute<void>(builder: page)
            : MaterialPageRoute<void>(builder: page),
      );
    }
  }

  /// Opacity of the top page itself (its AppBar title has no element fade,
  /// so this is the route's fade-through). 0 once the page is gone.
  double topPageOpacity() {
    final Finder f = find.text('Detail $subjectIndex', skipOffstage: false);
    if (f.evaluate().isEmpty) return 0.0;
    return effectiveOpacityOfElement(f.evaluate().first);
  }

  /// Most visible element of the top page (element fade × page fade).
  double topVisible(WidgetTester tester) {
    double v = 0.0;
    for (final String l in topLabels) {
      if (exists(l)) {
        v = v > effectiveOpacity(tester, l) ? v : effectiveOpacity(tester, l);
      }
    }
    return v;
  }

  /// Most visible element of the page below, occluded by the opaque top page
  /// in proportion to its opacity. [skip] leaves the subject out.
  double belowVisible(
    WidgetTester tester,
    List<String> labels, {
    String? skip,
  }) {
    final double occlusion = 1.0 - topPageOpacity();
    double v = 0.0;
    for (final String l in labels) {
      if (l == skip || !exists(l)) continue;
      final double o = effectiveOpacity(tester, l) * occlusion;
      if (o > v) v = o;
    }
    return v;
  }

  String offs(WidgetTester tester, List<String> labels) => labels
      .map(
        (String l) => exists(l)
            ? '${l.replaceAll('list-item-', '#')}:${f3(offsetOf(tester, l).dy)}/${f3(opacityOf(tester, l))}'
            : '${l.replaceAll('list-item-', '#')}:gone',
      )
      .join(' ');

  /// Edge swipe-back from the left edge through [stops] (finger x as a
  /// fraction of the screen width, in order, may go back), sampling at each
  /// stop, then release. A slow release stops the pointer for 100 ms first
  /// (zero velocity, so only the position decides); a fling moves fast and
  /// lets go at once. Returns the per-stop samples and the settle samples.
  Future<
      ({
        List<
            ({
              double x,
              double a,
              bool gesture,
              Map<String, Offset> off,
              Map<String, double> op,
              double topVis,
              int heroes,
            })> stops,
        List<({Duration t, ({double a, int heroes}) v})> settle,
        Duration releasedAt,
      })> swipe(
    WidgetTester tester, {
    required String name,
    required List<String> below,
    required List<double> stops,
    bool fling = false,
    double? holdAt,
    int holdMs = 1000,
  }) async {
    final ModalRoute<Object?> top = routeOf(tester, topLabels.first);
    final NavigatorState nav = top.navigator!;
    final double width =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final double y = 520;
    Duration t = Duration.zero;
    final int dtMs = fling ? 8 : 16;
    double x = 5;
    final TestGesture g = await tester.createGesture();
    await g.down(Offset(x, y), timeStamp: t);
    final List<
        ({
          double x,
          double a,
          bool gesture,
          Map<String, Offset> off,
          Map<String, double> op,
          double topVis,
          int heroes,
        })> samples = [];
    for (final double stop in stops) {
      final double target = stop * width;
      while ((target - x).abs() > 0.5) {
        final double step = (target - x).clamp(-20.0, 20.0);
        x += step;
        t += Duration(milliseconds: dtMs);
        await g.moveTo(Offset(x, y), timeStamp: t);
        await tester.pump();
      }
      await tester.pump();
      final double a = top.animation!.value;
      samples.add((
        x: x,
        a: a,
        gesture: nav.userGestureInProgress,
        off: <String, Offset>{
          for (final String l in below)
            if (exists(l)) l: offsetOf(tester, l),
        },
        op: <String, double>{
          for (final String l in below)
            if (exists(l)) l: opacityOf(tester, l),
        },
        topVis: topVisible(tester),
        heroes: shuttleRect(tester) == null ? 0 : 1,
      ));
      report(
        '$name stop x=${x.toStringAsFixed(0)}px '
        '(${f3(x / width)}) A=${f3(a)} gesture=${nav.userGestureInProgress} '
        'topVis=${f3(topVisible(tester))} '
        'belowVis=${f3(belowVisible(tester, below))} heroShuttle=${shuttleRect(tester) != null} '
        'below dy/opacity: ${offs(tester, below)}',
      );
      if (holdAt != null && stop == holdAt) {
        report('$name HOLD start wall=${DateTime.now().toIso8601String()}');
        await Future<void>.delayed(Duration(milliseconds: holdMs));
        await tester.pump();
        report(
          '$name HOLD end wall=${DateTime.now().toIso8601String()} '
          'A=${f3(top.animation!.value)}',
        );
      }
    }
    if (!fling) {
      // Stop the pointer: a move after more than 40 ms of stillness gives a
      // zero velocity estimate, so the release is decided by position.
      t += const Duration(milliseconds: 100);
      await g.moveTo(Offset(x + 0.5, y), timeStamp: t);
      await tester.pump();
    } else {
      // The velocity tracker also checks wall-clock time since the last
      // sample (more than 40 ms reads as a stopped pointer), and sampling at
      // the stop above takes longer than that. So the fling ends with a burst
      // of fast moves and the release, with no frame in between.
      for (int i = 0; i < 2; i++) {
        x += 20;
        t += const Duration(milliseconds: 8);
        await g.moveTo(Offset(x, y), timeStamp: t);
      }
      report(
        '$name release burst to x=${x.toStringAsFixed(0)}px '
        '(${f3(x / width)}), A=${f3(top.animation!.value)}, '
        '2500 px/s synthetic',
      );
    }
    final FrameSampler<({double a, int heroes})> settle =
        FrameSampler<({double a, int heroes})>(
      () => (
        a: top.animation!.value,
        heroes: shuttleRect(tester) == null ? 0 : 1,
      ),
    );
    settle.start();
    final Duration releasedAt = tester.binding.currentSystemFrameTimeStamp;
    await g.up(timeStamp: t + Duration(milliseconds: fling ? 8 : 16));
    await wait(tester, 900);
    settle.stop();
    return (stops: samples, settle: settle.samples, releasedAt: releasedAt);
  }

  testWidgets('0 environment', (WidgetTester tester) async {
    await openList(tester);
    final BuildContext ctx = tester.element(find.byType(Scaffold).last);
    final MediaQueryData mq = MediaQuery.of(ctx);
    report(
      'env platform=${Theme.of(ctx).platform} size=${mq.size} '
      'dpr=${mq.devicePixelRatio} padding=${mq.padding} '
      'disableAnimations=${mq.disableAnimations} '
      'displayRefreshRate=${tester.view.display.refreshRate}',
    );
    expect(Theme.of(ctx).platform, TargetPlatform.iOS);
    expect(mq.disableAnimations, isFalse);
  });

  for (final Install install in Install.values) {
    for (final Open open in Open.values) {
      testWidgets('1+2+4 swipe commit, ${install.name}, ${open.name}', (
        WidgetTester tester,
      ) async {
        await openList(tester);
        final List<String> below = visibleListLabels(tester);
        await openDetail0(tester, install, open);
        await wait(tester, 900);
        expect(find.text('Detail $subjectIndex'), findsOneWidget);
        final String name = 'commit/${install.name}/${open.name}';
        final r = await swipe(
          tester,
          name: name,
          below: below,
          // Out to 90 %, back to 60 %, hold at 52 % (A ≈ 0.54, inside the
          // uncover slice S 0.3–0.65, so the page below is partly back),
          // then release past half at 75 %.
          stops: <double>[
            0.1, 0.25, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.6, 0.52, 0.75, //
          ],
          holdAt: 0.52,
        );
        expect(tester.takeException(), isNull);
        final s = r.stops;

        // 1. The swipe reaches the route: progress follows the finger both
        // ways and the navigator reports a user gesture.
        for (int i = 1; i < 8; i++) {
          expect(s[i].a, lessThan(s[i - 1].a), reason: 'A must fall: $name');
        }
        expect(s[8].a, greaterThan(s[7].a), reason: 'A must rise back');
        expect(s[3].a, inInclusiveRange(0.35, 0.65));
        expect(s.every((e) => e.gesture), isTrue);

        // 2. Elements follow the finger: per element, the exit offset shrinks
        // and the own opacity grows as the finger moves right.
        final String subject = listLabel(subjectIndex);
        bool partial = false;
        for (final String l in below) {
          for (int i = 1; i < 8; i++) {
            expect(
              s[i].off[l]!.distance,
              lessThanOrEqualTo(s[i - 1].off[l]!.distance + 1e-6),
              reason: '$l offset must not grow: $name',
            );
            expect(
              s[i].op[l]!,
              greaterThanOrEqualTo(s[i - 1].op[l]! - 1e-6),
              reason: '$l opacity must not fall: $name',
            );
          }
          final double held = s[9].off[l]!.distance;
          if (held > 1e-3 && held < s[0].off[l]!.distance - 1e-3) {
            partial = true;
          }
          // Direction.
          for (final e in s) {
            final Offset o = e.off[l]!;
            expect(o.dx.abs(), lessThan(1e-9), reason: '$l moves vertically');
            if (open == Open.programmatic) {
              expect(
                o.dy,
                lessThanOrEqualTo(1e-9),
                reason: '$l (plain) is covered upwards, returns from above',
              );
            } else if (l == subject) {
              expect(o, Offset.zero, reason: 'the subject stays');
            } else {
              final int i = int.parse(l.split('-').last);
              if (i < subjectIndex) {
                expect(
                  o.dy,
                  lessThanOrEqualTo(1e-9),
                  reason: '$l above parts up',
                );
              } else {
                expect(
                  o.dy,
                  greaterThanOrEqualTo(-1e-9),
                  reason: '$l below parts down',
                );
              }
            }
          }
        }
        expect(
          partial,
          isTrue,
          reason: 'at the 52 % hold some element below is partly returned',
        );
        expect(s[9].topVis, lessThan(1.0));

        // Release past half: the pop commits.
        expect(exists(topLabels.first), isFalse, reason: 'popped: $name');
        expect(find.text('Tap a card, then swipe back.'), findsOneWidget);
        for (final String l in below) {
          expect(opacityOf(tester, l), 1.0);
          expect(offsetOf(tester, l), Offset.zero);
        }
        final int heroesDuringDrag =
            s.map((e) => e.heroes).reduce((a, b) => a > b ? a : b);
        final int heroesDuringSettle = r.settle.isEmpty
            ? 0
            : r.settle.map((e) => e.v.heroes).reduce((a, b) => a > b ? a : b);
        // The example's Hero sets transitionOnUserGestures, so the
        // thumbnail flies with the finger during the swipe.
        expect(heroesDuringDrag, greaterThan(0),
            reason: 'example hero flies during swipe-back: $name');
        final int shuttleStops = s.where((e) => e.heroes > 0).length;
        report(
          '$name RESULT hero shuttle on screen at $shuttleStops/${s.length} '
          'drag stops',
        );
        report(
          '$name RESULT commit settle ${settleTime(r.settle, 0.0)}; '
          'hero flights during drag max=$heroesDuringDrag, '
          'after release max=$heroesDuringSettle',
        );
      });
    }

    testWidgets('1 swipe cancel (early release), ${install.name}', (
      WidgetTester tester,
    ) async {
      await openList(tester);
      final List<String> below = visibleListLabels(tester);
      await openDetail0(tester, install, Open.programmatic);
      await wait(tester, 900);
      final ModalRoute<Object?> top = routeOf(tester, topLabels.first);
      final String name = 'cancel/${install.name}';
      final r = await swipe(
        tester,
        name: name,
        below: below,
        stops: <double>[0.1, 0.2, 0.3, 0.35],
      );
      expect(tester.takeException(), isNull);
      expect(r.stops.last.a, lessThan(0.8));
      expect(top.animation!.value, 1.0);
      expect(top.isCurrent, isTrue);
      expect(top.navigator!.userGestureInProgress, isFalse);
      expect(exists(topLabels.first), isTrue);
      expect(opacityOf(tester, topLabels.first), 1.0);
      report(
        '$name RESULT settled back to A=1 in ${settleTime(r.settle, 1.0)}',
      );
    });

    testWidgets('1 swipe fling at 30 %, ${install.name}', (
      WidgetTester tester,
    ) async {
      await openList(tester);
      final List<String> below = visibleListLabels(tester);
      await openDetail0(tester, install, Open.programmatic);
      await wait(tester, 900);
      final String name = 'fling/${install.name}';
      final r = await swipe(
        tester,
        name: name,
        below: below,
        stops: <double>[0.1, 0.2, 0.3],
        fling: true,
      );
      expect(tester.takeException(), isNull);
      expect(r.stops.last.a, greaterThan(0.5));
      expect(exists(topLabels.first), isFalse, reason: 'fling pops');
      report(
        '$name RESULT fling from A=${f3(r.stops.last.a)} popped in '
        '${settleTime(r.settle, 0.0)}',
      );
    });

    testWidgets('1 fullscreenDialog does not swipe, ${install.name}', (
      WidgetTester tester,
    ) async {
      await openList(tester);
      final NavigatorState nav = Navigator.of(
        tester.element(keyed(listLabel(0))),
      );
      Widget page(BuildContext _) => const DetailPage(index: subjectIndex);
      nav.push(
        install == Install.cnPageRoute
            ? CnPageRoute<void>(builder: page, fullscreenDialog: true)
            : MaterialPageRoute<void>(builder: page, fullscreenDialog: true),
      );
      await wait(tester, 900);
      final ModalRoute<Object?> top = routeOf(tester, topLabels.first);
      final String name = 'fullscreenDialog/${install.name}';
      final r = await swipe(
        tester,
        name: name,
        below: visibleListLabels(tester),
        stops: <double>[0.2, 0.4, 0.6],
      );
      expect(tester.takeException(), isNull);
      for (final e in r.stops) {
        expect(e.a, 1.0, reason: 'no swipe on a fullscreen dialog');
        expect(e.gesture, isFalse);
      }
      expect(top.isCurrent, isTrue);
      report(
        '$name RESULT A stayed 1.0 at x = 20/40/60 %, route still current',
      );
    });

    for (final Open open in Open.values) {
      testWidgets(
          '3+4 push/pop timing and dead zone, ${install.name}, '
          '${open.name}', (WidgetTester tester) async {
        await openList(tester);
        final List<String> below = visibleListLabels(tester);
        final String subject = listLabel(subjectIndex);
        ModalRoute<Object?>? top;
        ({
          double a,
          double topVis,
          double all,
          double sib,
          int heroes,
          Rect? shuttle,
        }) read() {
          if (top == null && exists(topLabels.first)) {
            top = routeOf(tester, topLabels.first);
          }
          return (
            a: top?.animation?.value ?? 0.0,
            topVis: topVisible(tester),
            all: belowVisible(tester, below),
            sib: belowVisible(tester, below, skip: subject),
            heroes: shuttleRect(tester) == null ? 0 : 1,
            shuttle: shuttleRect(tester),
          );
        }

        void analyse(
          String name,
          List<
                  ({
                    Duration t,
                    ({
                      double a,
                      double topVis,
                      double all,
                      double sib,
                      int heroes,
                      Rect? shuttle,
                    }) v,
                  })>
              s,
        ) {
          final Duration t0 = s.first.t;
          for (final e in s) {
            report(
              '$name frame t=${(e.t - t0).inMilliseconds}ms A=${f3(e.v.a)} '
              'top=${f3(e.v.topVis)} belowAll=${f3(e.v.all)} '
              'belowSiblings=${f3(e.v.sib)} heroes=${e.v.heroes} '
              'shuttle=${e.v.shuttle == null ? '-' : '${e.v.shuttle!.width.toStringAsFixed(0)}@${e.v.shuttle!.center.dx.toStringAsFixed(0)},${e.v.shuttle!.center.dy.toStringAsFixed(0)}'}',
            );
          }
          String dead(
            double Function(
              ({
                double a,
                double topVis,
                double all,
                double sib,
                int heroes,
                Rect? shuttle,
              }) v,
            ) belowOf,
          ) {
            int frames = 0;
            int ms = 0;
            double? aFrom, aTo;
            for (int i = 0; i < s.length - 1; i++) {
              final v = s[i].v;
              if (v.topVis < visibleThreshold &&
                  belowOf(v) < visibleThreshold) {
                frames++;
                ms += (s[i + 1].t - s[i].t).inMilliseconds;
                aFrom ??= v.a;
                aTo = v.a;
              }
            }
            return frames == 0
                ? 'none'
                : '$frames frames, $ms ms (A ${f3(aFrom!)} → ${f3(aTo!)})';
          }

          final int flights = s.where((e) => e.v.heroes > 0).length;
          final List<Rect> sh = <Rect>[
            for (final e in s)
              if (e.v.shuttle != null) e.v.shuttle!,
          ];
          report(
            '$name RESULT ${s.length} frames over '
            '${(s.last.t - t0).inMilliseconds} ms; dead zone '
            '(nothing > ${visibleThreshold * 100}% visible) all elements: '
            '${dead((v) => v.all)}; siblings only: ${dead((v) => v.sib)}; '
            'hero flight frames=$flights shuttle width '
            '${sh.isEmpty ? '-' : '${sh.first.width.toStringAsFixed(0)} → ${sh.last.width.toStringAsFixed(0)}'}',
          );
        }

        final String name = 'timing/${install.name}/${open.name}';
        final FrameSampler<
            ({
              double a,
              double topVis,
              double all,
              double sib,
              int heroes,
              Rect? shuttle,
            })> push = FrameSampler(read)..start();
        await openDetail0(tester, install, open);
        await wait(tester, 900);
        push.stop();
        expect(tester.takeException(), isNull);
        expect(
          push.samples.any((e) => e.v.heroes > 0),
          isTrue,
          reason: 'hero flies on push',
        );
        analyse('$name push', push.samples);

        final FrameSampler<
            ({
              double a,
              double topVis,
              double all,
              double sib,
              int heroes,
              Rect? shuttle,
            })> pop = FrameSampler(read)..start();
        await tester.tap(find.byType(BackButton));
        await wait(tester, 900);
        pop.stop();
        expect(tester.takeException(), isNull);
        expect(exists(topLabels.first), isFalse);
        expect(
          pop.samples.any((e) => e.v.heroes > 0),
          isTrue,
          reason: 'hero flies on pop',
        );
        analyse('$name pop', pop.samples);
        final List<double> deadPop = expectNoDeadZone(
            '$name pop', <({double a, double top, double below})>[
          for (final e in pop.samples)
            (a: e.v.a, top: e.v.topVis, below: e.v.all),
        ]);
        report(
            '$name pop RESULT R6 dead frames (both < ${deadThreshold * 100}%): '
            '${deadPop.isEmpty ? 'none' : deadPop.map(f3).join(', ')} '
            'of ${pop.samples.length}');
      });
    }
  }

  for (final Install install in Install.values) {
    for (final Open open in Open.values) {
      testWidgets(
          '3 R6 dead zone by route value (1 % scrub), '
          '${install.name}, ${open.name}', (WidgetTester tester) async {
        await openList(tester);
        final List<String> below = visibleListLabels(tester);
        await openDetail0(tester, install, open);
        await wait(tester, 900);
        final ModalRoute<Object?> top = routeOf(tester, topLabels.first);
        final String subject = listLabel(subjectIndex);
        final double width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final String name = 'R6/${install.name}/${open.name}';
        const double y = 520;
        double x = 5;
        Duration t = Duration.zero;
        final TestGesture g = await tester.createGesture();
        await g.down(Offset(x, y), timeStamp: t);
        double? allFrom, allTo, sibFrom, sibTo;
        final List<String> rows = <String>[];
        final List<({double a, double top, double below})> all1 =
            <({double a, double top, double below})>[];
        final List<({double a, double top, double below})> sib1 =
            <({double a, double top, double below})>[];
        while (x < 0.8 * width) {
          x += 4;
          t += const Duration(milliseconds: 16);
          await g.moveTo(Offset(x, y), timeStamp: t);
          await tester.pump();
          final double a = top.animation!.value;
          final double tv = topVisible(tester);
          final double all = belowVisible(tester, below);
          final double sib = belowVisible(tester, below, skip: subject);
          if (tv < visibleThreshold && all < visibleThreshold) {
            allFrom ??= a;
            allTo = a;
          }
          if (tv < visibleThreshold && sib < visibleThreshold) {
            sibFrom ??= a;
            sibTo = a;
          }
          all1.add((a: a, top: tv, below: all));
          sib1.add((a: a, top: tv, below: sib));
          rows.add('${f3(a)}:${f3(tv)}/${f3(all)}/${f3(sib)}');
        }
        report('$name rows A:top/belowAll/belowSiblings ${rows.join(' ')}');
        String span(double? from, double? to) => from == null
            ? 'none'
            : 'A ${f3(from)} → ${f3(to!)} (ΔA ${f3(from - to)}, '
                '≈ ${((from - to) * 400).toStringAsFixed(0)} ms of a linear '
                '400 ms pop, derived)';
        report(
          '$name RESULT dead zone (top and below both < '
          '${visibleThreshold * 100}%): all elements ${span(allFrom, allTo)}; '
          'siblings only ${span(sibFrom, sibTo)}',
        );
        List<double> deadAt(List<({double a, double top, double below})> v) =>
            <double>[
              for (final e in v)
                if (e.top < deadThreshold && e.below < deadThreshold) e.a,
            ];
        double dimmest(List<({double a, double top, double below})> v) => v
            .map((e) => e.top > e.below ? e.top : e.below)
            .reduce((p, q) => p < q ? p : q);
        report(
          '$name RESULT R6 (both < ${deadThreshold * 100}%) over ${rows.length} '
          'samples A ${f3(all1.first.a)} → ${f3(all1.last.a)}: all elements dead at '
          '${deadAt(all1).isEmpty ? 'none' : deadAt(all1).map(f3).join(', ')}, '
          'dimmest point ${f3(dimmest(all1))}; siblings only dead at '
          '${deadAt(sib1).isEmpty ? 'none' : deadAt(sib1).map(f3).join(', ')}, '
          'dimmest ${f3(dimmest(sib1))}',
        );
        t += const Duration(milliseconds: 100);
        await g.moveTo(Offset(x + 0.5, y), timeStamp: t);
        await g.up(timeStamp: t + const Duration(milliseconds: 16));
        await wait(tester, 900);
        expect(tester.takeException(), isNull);
        expect(exists(topLabels.first), isFalse);
        expectNoDeadZone(name, all1);
      });
    }

    testWidgets(
        '4 Hero with transitionOnUserGestures flies on swipe-back, '
        '${install.name}', (WidgetTester tester) async {
      Widget thumb(double size) => Hero(
            tag: 'gesture-hero',
            transitionOnUserGestures: true,
            child: Container(
              width: size,
              height: size,
              color: Colors.teal,
              child: const Icon(Icons.image_outlined, color: Colors.white),
            ),
          );
      final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: ThemeData(
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {
                for (final TargetPlatform p in TargetPlatform.values)
                  p: const CnFadeThroughPageTransitionsBuilder(),
              },
            ),
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Home')),
            body: Align(alignment: Alignment.topLeft, child: thumb(40)),
          ),
        ),
      );
      await wait(tester, 600);
      Widget page(BuildContext _) => Scaffold(
            appBar: AppBar(title: const Text('Hero detail')),
            body: Column(
              children: <Widget>[
                Center(child: thumb(160)),
                const CnRouteAnimation(
                  key: ValueKey<String>('detail-paragraph-0'),
                  child: Text('Paragraph'),
                ),
              ],
            ),
          );
      nav.currentState!.push(
        install == Install.cnPageRoute
            ? CnPageRoute<void>(builder: page)
            : MaterialPageRoute<void>(builder: page),
      );
      await wait(tester, 900);
      final String name = 'gestureHero/${install.name}';
      final r = await swipe(
        tester,
        name: name,
        below: const <String>[],
        stops: <double>[0.2, 0.4, 0.6, 0.75],
      );
      expect(tester.takeException(), isNull);
      expect(
        r.stops.where((e) => e.heroes > 0).length,
        greaterThan(0),
        reason: 'a gesture-enabled hero flies during the swipe',
      );
      expect(find.text('Hero detail'), findsNothing);
      report(
        '$name RESULT shuttle on screen at '
        '${r.stops.where((e) => e.heroes > 0).length}/${r.stops.length} '
        'drag stops; popped',
      );
    });
  }

  testWidgets(
    '1+4 Replace (CnPageRoute via the example button) then swipe back',
    (WidgetTester tester) async {
      await openList(tester);
      final List<String> below = visibleListLabels(tester);
      await tester.tap(find.text('Item $subjectIndex'));
      await wait(tester, 900);
      await tester.tap(find.text('Replace'));
      await wait(tester, 900);
      expect(find.text('Detail ${subjectIndex + 1}'), findsOneWidget);
      expect(routeOf(tester, topLabels.first), isA<CnPageRoute<void>>());
      final r = await swipe(
        tester,
        name: 'replace',
        below: below,
        stops: <double>[0.2, 0.5, 0.8],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Detail ${subjectIndex + 1}'), findsNothing);
      expect(find.text('Tap a card, then swipe back.'), findsOneWidget);
      report(
        'replace RESULT popped to the list in ${settleTime(r.settle, 0.0)}',
      );
    },
  );
}

/// Time from release to the first frame at the settled value.
String settleTime(
  List<({Duration t, ({double a, int heroes}) v})> s,
  double to,
) {
  if (s.isEmpty) return 'no frames';
  final Duration t0 = s.first.t;
  for (final ({Duration t, ({double a, int heroes}) v}) e in s) {
    if ((e.v.a - to).abs() < 1e-3) {
      return '${(e.t - t0).inMilliseconds} ms over ${s.indexOf(e)} frames';
    }
  }
  return 'not settled (last A=${f3(s.last.v.a)})';
}
