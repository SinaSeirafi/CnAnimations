import 'package:cn_animations/src/choreography/cn_route_choreography.dart';
import 'package:cn_animations/src/choreography/geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Item [i] of a vertical list with 100 px items in a 400 px wide viewport.
Rect _row(int i) => Rect.fromLTWH(0, i * 100.0, 400, 100);

/// Cell of a 100 px grid.
Rect _cell(int row, int col) =>
    Rect.fromLTWH(col * 100.0, row * 100.0, 100, 100);

/// Item [i] of a horizontal list with 100 px items in a 100 px tall viewport.
Rect _col(int i) => Rect.fromLTWH(i * 100.0, 0, 100, 100);

const Rect _listViewport = Rect.fromLTWH(0, 0, 400, 600);

void main() {
  group('cnPlacement, vertical list', () {
    test('without a subject: anchored at the viewport top, no direction', () {
      final first = cnPlacement(element: _row(0), viewport: _listViewport);
      final last = cnPlacement(element: _row(5), viewport: _listViewport);

      expect(first.onScreen, isTrue);
      expect(first.f, closeTo(50 / 600, 1e-9));
      expect(first.direction, Offset.zero);
      expect(last.onScreen, isTrue);
      expect(last.f, closeTo(550 / 600, 1e-9));
      expect(last.direction, Offset.zero);
    });

    test('items above the subject part up, items below part down, nearer '
        'ones first', () {
      final subject = _row(4);
      CnPlacement at(int i) => cnPlacement(
        element: _row(i),
        viewport: _listViewport,
        subject: subject,
      );

      expect(at(3).direction, const Offset(0, -1));
      expect(at(0).direction, const Offset(0, -1));
      expect(at(5).direction, const Offset(0, 1));
      expect(at(3).f, closeTo(100 / 600, 1e-9));
      expect(at(0).f, closeTo(400 / 600, 1e-9));
      expect(at(5).f, closeTo(100 / 600, 1e-9));
      expect(at(3).f, lessThan(at(2).f));
      expect(at(2).f, lessThan(at(1).f));
    });

    test('the subject itself gets no direction and f == 0', () {
      final p = cnPlacement(
        element: _row(4),
        viewport: _listViewport,
        subject: _row(4),
      );
      expect(p.direction, Offset.zero);
      expect(p.f, 0);
    });

    test('off-screen cache-extent items: onScreen false, f == 1', () {
      // 600 px viewport, 100 px items: rows 6..8 are built for the cache
      // extent but not visible. Row 6 only touches the bottom edge.
      for (final i in [6, 7, 8]) {
        final plain = cnPlacement(element: _row(i), viewport: _listViewport);
        final parted = cnPlacement(
          element: _row(i),
          viewport: _listViewport,
          subject: _row(4),
        );
        expect(plain.onScreen, isFalse, reason: 'row $i');
        expect(plain.f, 1, reason: 'row $i');
        expect(parted.onScreen, isFalse, reason: 'row $i');
        expect(parted.f, 1, reason: 'row $i');
        // Still parts the right way if scrolled into view mid-transition.
        expect(parted.direction, const Offset(0, 1), reason: 'row $i');
      }
      // Above the viewport too.
      final above = cnPlacement(element: _row(-1), viewport: _listViewport);
      expect(above.onScreen, isFalse);
      expect(above.f, 1);
    });

    test('a partially visible item is on screen', () {
      final p = cnPlacement(
        element: const Rect.fromLTWH(0, 550, 400, 100),
        viewport: _listViewport,
      );
      expect(p.onScreen, isTrue);
      expect(p.f, closeTo(600 / 600, 1e-9));
    });
  });

  group('cnPlacement, grid', () {
    const viewport = Rect.fromLTWH(0, 0, 300, 600);
    final subject = _cell(1, 1);
    CnPlacement at(int r, int c, {TextDirection dir = TextDirection.ltr}) =>
        cnPlacement(
          element: _cell(r, c),
          viewport: viewport,
          subject: subject,
          textDirection: dir,
        );

    test('same-row cells part along the cross axis', () {
      expect(at(1, 0).direction, const Offset(-1, 0));
      expect(at(1, 2).direction, const Offset(1, 0));
      expect(at(1, 0).f, 0);
      expect(at(1, 1).direction, Offset.zero);
    });

    test('other rows part along the main axis, diagonals included', () {
      expect(at(0, 1).direction, const Offset(0, -1));
      expect(at(0, 0).direction, const Offset(0, -1));
      expect(at(2, 2).direction, const Offset(0, 1));
    });

    test('RTL flips the cross-axis direction (logical, reading order)', () {
      const rtl = TextDirection.rtl;
      // Physically right of the subject = before it in RTL reading order.
      expect(at(1, 2, dir: rtl).direction, const Offset(-1, 0));
      expect(at(1, 0, dir: rtl).direction, const Offset(1, 0));
      // Vertical parting is direction-free.
      expect(at(0, 1, dir: rtl).direction, const Offset(0, -1));
      expect(at(2, 0, dir: rtl).direction, const Offset(0, 1));
    });
  });

  group('cnPlacement, horizontal axis', () {
    const viewport = Rect.fromLTWH(0, 0, 600, 100);

    test('LTR: anchored at the left edge, parts along x', () {
      final first = cnPlacement(
        element: _col(0),
        viewport: viewport,
        axis: Axis.horizontal,
      );
      expect(first.f, closeTo(50 / 600, 1e-9));
      expect(first.direction, Offset.zero);

      CnPlacement at(int i) => cnPlacement(
        element: _col(i),
        viewport: viewport,
        axis: Axis.horizontal,
        subject: _col(2),
      );
      expect(at(1).direction, const Offset(-1, 0));
      expect(at(3).direction, const Offset(1, 0));
      expect(at(0).f, closeTo(200 / 600, 1e-9));
      expect(at(6).onScreen, isFalse);
      expect(at(6).f, 1);
    });

    test('RTL: anchored at the right edge, before/after in reading order', () {
      const rtl = TextDirection.rtl;
      final rightmost = cnPlacement(
        element: _col(5),
        viewport: viewport,
        axis: Axis.horizontal,
        textDirection: rtl,
      );
      final leftmost = cnPlacement(
        element: _col(0),
        viewport: viewport,
        axis: Axis.horizontal,
        textDirection: rtl,
      );
      expect(rightmost.f, closeTo(50 / 600, 1e-9));
      expect(leftmost.f, closeTo(550 / 600, 1e-9));

      CnPlacement at(int i) => cnPlacement(
        element: _col(i),
        viewport: viewport,
        axis: Axis.horizontal,
        subject: _col(2),
        textDirection: rtl,
      );
      // Physically left of the subject = after it in RTL.
      expect(at(1).direction, const Offset(1, 0));
      expect(at(3).direction, const Offset(-1, 0));
    });

    test('same-column items of a horizontal grid part along y', () {
      final p = cnPlacement(
        element: const Rect.fromLTWH(200, 50, 100, 50),
        viewport: viewport,
        axis: Axis.horizontal,
        subject: const Rect.fromLTWH(200, 0, 100, 50),
        textDirection: TextDirection.rtl,
      );
      expect(p.direction, const Offset(0, 1));
    });
  });

  group('staggered slices', () {
    const t = CnRouteTiming.standard;

    test('exit slice shifts by f·exitStagger and uses exitCurve', () {
      final near = cnStaggeredExit(t, 0);
      final far = cnStaggeredExit(t, 1);
      expect(near.begin, 0.0);
      expect(near.end, 0.35);
      expect(far.begin, closeTo(0.12, 1e-9));
      expect(far.end, closeTo(0.47, 1e-9));
      expect(far.curve, Curves.easeIn);
    });

    test('uncover slice shifts like the exit slice and uses exitCurve', () {
      final near = cnStaggeredUncover(t, 0);
      final far = cnStaggeredUncover(t, 1);
      expect(near.begin, 0.3);
      expect(near.end, 0.65);
      expect(far.begin, closeTo(0.42, 1e-9));
      expect(far.end, closeTo(0.77, 1e-9));
      expect(far.curve, Curves.easeIn);
      // uncover: exit reproduces the pre-0.9.0 behaviour (exit replayed).
      final replay = t.copyWith(uncover: t.exit);
      expect(
        cnStaggeredUncover(replay, 0.5).begin,
        cnStaggeredExit(replay, 0.5).begin,
      );
      expect(
        cnStaggeredUncover(replay, 0.5).end,
        cnStaggeredExit(replay, 0.5).end,
      );
    });

    test('enter slice shifts its start and pins its end to 1', () {
      final near = cnStaggeredEnter(t, 0);
      final far = cnStaggeredEnter(t, 1);
      expect(near.begin, 0.35);
      expect(far.begin, closeTo(0.6, 1e-9));
      expect(near.end, 1.0);
      expect(far.end, 1.0);
      expect(far.curve, Curves.easeOutCubic);
    });

    test('curved exit / enter / uncover Intervals assert (their curve is '
        'ignored)', () {
      final curvedExit = CnRouteTiming(
        exit: Interval(0.0, 0.35, curve: Curves.easeOut),
      );
      final curvedUncover = CnRouteTiming(
        uncover: Interval(0.3, 0.65, curve: Curves.easeOut),
      );
      final curvedEnter = CnRouteTiming(
        enter: Interval(0.35, 1.0, curve: Curves.easeIn),
      );
      Matcher assertsWithHint = throwsA(
        isA<AssertionError>().having(
          (e) => e.message,
          'message',
          contains('Set exitCurve / enterCurve instead'),
        ),
      );
      expect(() => cnStaggeredExit(curvedExit, 0), assertsWithHint);
      expect(() => cnStaggeredEnter(curvedExit, 0), assertsWithHint);
      expect(() => cnStaggeredExit(curvedEnter, 0), assertsWithHint);
      expect(() => cnStaggeredEnter(curvedEnter, 0), assertsWithHint);
      expect(() => cnStaggeredUncover(curvedExit, 0), assertsWithHint);
      expect(() => cnStaggeredUncover(curvedUncover, 0), assertsWithHint);
      expect(() => cnStaggeredExit(curvedUncover, 0), assertsWithHint);
      expect(() => cnStaggeredEnter(curvedUncover, 0), assertsWithHint);
      // Linear Intervals (the default curve) pass.
      final linear = CnRouteTiming(exit: Interval(0.1, 0.4));
      expect(cnStaggeredExit(linear, 0).begin, 0.1);
    });

    test('stagger is bounded by geometry, not list length', () {
      // 200 rows; whatever the index, the start never exceeds the bound and
      // every slice is complete at progress 1.
      for (var i = 0; i < 200; i++) {
        final f = cnPlacement(element: _row(i), viewport: _listViewport).f;
        final exit = cnStaggeredExit(t, f);
        final enter = cnStaggeredEnter(t, f);
        final uncover = cnStaggeredUncover(t, f);
        expect(exit.begin, lessThanOrEqualTo(t.exit.begin + t.exitStagger));
        expect(
          uncover.end,
          lessThanOrEqualTo(t.uncover.end + t.exitStagger + 1e-9),
        );
        expect(uncover.transform(1.0), 1.0);
        expect(uncover.transform(0.0), 0.0);
        expect(enter.begin, lessThanOrEqualTo(t.enter.begin + t.enterStagger));
        expect(enter.transform(1.0), 1.0);
        expect(exit.transform(1.0), 1.0);
      }
    });

    test('slices are clamped to 1', () {
      const late = CnRouteTiming(
        exit: Interval(0.5, 0.95),
        uncover: Interval(0.6, 0.9),
        enter: Interval(0.9, 1.0),
        exitStagger: 0.2,
        enterStagger: 0.2,
      );
      final exit = cnStaggeredExit(late, 1);
      final enter = cnStaggeredEnter(late, 1);
      expect(exit.begin, closeTo(0.7, 1e-9));
      expect(exit.end, 1.0);
      final uncover = cnStaggeredUncover(late, 1);
      expect(uncover.begin, closeTo(0.8, 1e-9));
      expect(uncover.end, 1.0);
      expect(enter.begin, 1.0);
      expect(enter.end, 1.0);
    });
  });

  group('cnPartingOffset', () {
    const spec = CnPartingSpec();

    test('scales distance by direction and grows with f', () {
      expect(
        cnPartingOffset(spec, const Offset(0, 1), 0),
        const Offset(0, 0.6),
      );
      final far = cnPartingOffset(spec, const Offset(0, -1), 1);
      expect(far.dx, 0);
      expect(far.dy, closeTo(-0.9, 1e-9));
    });

    test('the default distance also parts along x', () {
      final p = cnPartingOffset(spec, const Offset(-1, 0), 0);
      expect(p.dx, closeTo(-0.6, 1e-9));
      expect(p.dy, 0);
    });

    test('an explicit x component is used for x parting', () {
      const custom = CnPartingSpec(distance: Offset(0.3, 0.6));
      expect(
        cnPartingOffset(custom, const Offset(1, 0), 0),
        const Offset(0.3, 0),
      );
    });

    test('zero direction gives zero', () {
      expect(cnPartingOffset(spec, Offset.zero, 1), Offset.zero);
    });
  });

  group('render lookups', () {
    testWidgets('ListView.builder: cache-extent items are built but off '
        'screen', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: 200,
                  itemExtent: 100,
                  itemBuilder: (context, i) => SizedBox(key: ValueKey(i)),
                ),
              ),
            ),
          ),
        ),
      );

      final screen =
          Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
      RenderBox box(int i) => tester.renderObject<RenderBox>(
        find.byKey(ValueKey(i), skipOffstage: false),
      );

      final viewport = cnViewportRect(box(0), screen: screen);
      expect(viewport, Rect.fromLTWH(0, 100, screen.width, 300));

      expect(cnGlobalRect(box(1)), Rect.fromLTWH(0, 200, screen.width, 100));

      // Rows 3.. are built for the cache extent but lie outside the viewport.
      expect(
        find.byKey(const ValueKey(4), skipOffstage: false),
        findsOneWidget,
      );
      for (final i in [3, 4]) {
        final p = cnPlacement(
          element: cnGlobalRect(box(i)),
          viewport: viewport,
        );
        expect(p.onScreen, isFalse, reason: 'row $i');
        expect(p.f, 1, reason: 'row $i');
      }
      final visible = cnPlacement(
        element: cnGlobalRect(box(2)),
        viewport: viewport,
      );
      expect(visible.onScreen, isTrue);
      expect(visible.f, closeTo(250 / 300, 1e-9));
    });

    testWidgets('no viewport: the screen is used', (tester) async {
      await tester.pumpWidget(const SizedBox(key: Key('plain'), width: 10));
      const screen = Rect.fromLTWH(0, 0, 123, 456);
      expect(
        cnViewportRect(
          tester.renderObject(find.byKey(const Key('plain'))),
          screen: screen,
        ),
        screen,
      );
    });
  });
}
