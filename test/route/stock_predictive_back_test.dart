// Regression: CnRouteAnimation elements under Flutter's stock
// PredictiveBackPageTransitionsBuilder, driven through the system channel.
//
// On Flutter 3.35+ (flutter/flutter#154718) a committed predictive back pops
// the route and restarts its reverse from 1.0, so the route's animation and
// the page below's secondary animation jump from the release value back to
// 1.0. Without the element's reverse-restart guard the parted elements on
// the page below snap to fully covered (and the top page's elements to fully
// shown) and replay. These tests assert that every value moves one way after
// the commit, on every SDK.
import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration/support.dart';

const List<String> _below = <String>['s0', 's1', 's2', 's3', 's4'];

ThemeData _stockTheme() => ThemeData(
  platform: TargetPlatform.android,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    },
  ),
);

Route<void> _detailRoute(String label) =>
    MaterialPageRoute<void>(builder: (_) => column(<Widget>[item(label)]));

Widget _listPage() => Builder(
  builder:
      (BuildContext context) => column(<Widget>[
        for (int i = 0; i < 5; i++)
          CnRouteAnimation(
            key: ValueKey<String>('s$i'),
            timing: flat,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(_detailRoute('t')),
              child: SizedBox(height: 60, child: Text('s$i')),
            ),
          ),
      ]),
);

/// One frame of every element: |slide| and opacity.
class _Frame {
  _Frame(WidgetTester tester, Iterable<String> labels)
    : dy = <String, double>{
        for (final String l in labels)
          if (exists(l)) l: offsetOf(tester, l).dy.abs(),
      },
      opacity = <String, double>{
        for (final String l in labels)
          if (exists(l)) l: opacityOf(tester, l),
      };

  final Map<String, double> dy;
  final Map<String, double> opacity;
}

/// Pushes the list page, then the detail page 't' (by tapping s2 when
/// [tapSubject], else by a plain push), and settles.
Future<GlobalKey<NavigatorState>> _pumpDetail(
  WidgetTester tester, {
  required bool tapSubject,
}) async {
  final GlobalKey<NavigatorState> nav = await pumpApp(
    tester,
    const SizedBox(),
    theme: _stockTheme(),
  );
  nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => _listPage()));
  await tester.pumpAndSettle();
  if (tapSubject) {
    await tester.tap(find.text('s2'));
  } else {
    nav.currentState!.push(_detailRoute('t'));
  }
  await tester.pumpAndSettle();
  return nav;
}

/// Starts a system back gesture and drags it to progress 0.5.
Future<void> _dragToHalf(WidgetTester tester) async {
  await sendBackGesture(tester, 'startBackGesture');
  await tester.pump(const Duration(milliseconds: 16));
  for (int i = 1; i <= 10; i++) {
    await sendBackGesture(
      tester,
      'updateBackGestureProgress',
      progress: 0.05 * i,
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Samples the last drag frame, sends [method] and pumps the release frame.
/// The returned list holds the drag frame; append the samples after it.
Future<List<_Frame>> _release(
  WidgetTester tester,
  String method,
  Iterable<String> labels,
) async {
  final _Frame drag = _Frame(tester, labels);
  await sendBackGesture(tester, method);
  await tester.pump();
  return <_Frame>[drag];
}

/// Samples every 16 ms until [done], starting with the current frame.
Future<List<_Frame>> _sampleUntil(
  WidgetTester tester,
  Iterable<String> labels,
  bool Function() done,
) async {
  final List<_Frame> frames = <_Frame>[_Frame(tester, labels)];
  for (int i = 0; i < 120 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
    frames.add(_Frame(tester, labels));
  }
  return frames;
}

/// Asserts [values] of [label] never move against [direction] (+1 rising,
/// -1 falling) between consecutive frames.
void _expectMonotonic(
  List<_Frame> frames,
  String label,
  Map<String, double> Function(_Frame) read,
  int direction, {
  required String what,
}) {
  final List<double> values = <double>[
    for (final _Frame f in frames)
      if (read(f).containsKey(label)) read(f)[label]!,
  ];
  for (int i = 1; i < values.length; i++) {
    expect(
      (values[i] - values[i - 1]) * direction,
      greaterThanOrEqualTo(-eps),
      reason:
          '$label $what moved the wrong way between frame ${i - 1} '
          '(${values[i - 1]}) and $i (${values[i]}); all: $values',
    );
  }
}

/// Asserts [label]'s values move with [direction] (+1 rising, -1 falling)
/// up to one turn, then against it: a single change of direction, as when a
/// reverse is interrupted by a push.
void _expectOneTurn(
  List<_Frame> frames,
  String label,
  Map<String, double> Function(_Frame) read,
  int direction, {
  required String what,
}) {
  final List<double> values = <double>[
    for (final _Frame f in frames)
      if (read(f).containsKey(label)) read(f)[label]!,
  ];
  int sign = direction;
  for (int i = 1; i < values.length; i++) {
    final double step = (values[i] - values[i - 1]) * sign;
    if (step < -eps && sign == direction) sign = -direction;
    expect(
      (values[i] - values[i - 1]) * sign,
      greaterThanOrEqualTo(-eps),
      reason:
          '$label $what turned twice by frame $i (${values[i]}); '
          'all: $values',
    );
  }
}

Map<String, double> _dy(_Frame f) => f.dy;
Map<String, double> _opacity(_Frame f) => f.opacity;

/// Commit: the page below only uncovers, the top page only leaves.
void _expectCommitMonotonic(List<_Frame> frames) {
  for (final String l in _below) {
    _expectMonotonic(frames, l, _dy, -1, what: 'slide');
    _expectMonotonic(frames, l, _opacity, 1, what: 'opacity');
  }
  _expectMonotonic(frames, 't', _dy, 1, what: 'slide');
  _expectMonotonic(frames, 't', _opacity, -1, what: 'opacity');
}

void main() {
  for (final bool tapSubject in <bool>[true, false]) {
    final String kind = tapSubject ? 'tapped subject' : 'no subject';

    testWidgets('commit moves every element one way ($kind)', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(tester, tapSubject: tapSubject);
      final ModalRoute<Object?> top = routeOf(tester, 't');
      await _dragToHalf(tester);
      expect(opacityOf(tester, 's0'), inExclusiveRange(0.0, 1.0));
      const List<String> labels = <String>[..._below, 't'];
      final List<_Frame> frames = await _release(
        tester,
        'commitBackGesture',
        labels,
      );
      frames.addAll(
        await _sampleUntil(tester, labels, () => top.animation!.isDismissed),
      );
      expect(top.animation!.isDismissed, isTrue);
      _expectCommitMonotonic(frames);
      await tester.pumpAndSettle();
      for (final String l in _below) {
        expect(opacityOf(tester, l), 1.0);
        expect(offsetOf(tester, l), Offset.zero);
      }
    });

    testWidgets('cancel moves every element one way ($kind)', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(tester, tapSubject: tapSubject);
      final ModalRoute<Object?> top = routeOf(tester, 't');
      await _dragToHalf(tester);
      const List<String> labels = <String>[..._below, 't'];
      final List<_Frame> frames = await _release(
        tester,
        'cancelBackGesture',
        labels,
      );
      frames.addAll(
        await _sampleUntil(tester, labels, () => top.animation!.isCompleted),
      );
      expect(top.animation!.isCompleted, isTrue);
      for (final String l in _below) {
        _expectMonotonic(frames, l, _dy, 1, what: 'slide');
        _expectMonotonic(frames, l, _opacity, -1, what: 'opacity');
      }
      _expectMonotonic(frames, 't', _dy, -1, what: 'slide');
      _expectMonotonic(frames, 't', _opacity, 1, what: 'opacity');
      await tester.pumpAndSettle();
      expect(top.isCurrent, isTrue);
      expect(opacityOf(tester, 't'), 1.0);
      expect(opacityOf(tester, 's0'), 0.0);
    });
  }

  for (final bool settle in <bool>[true, false]) {
    final String when = settle ? 'after a cancel' : 'during a cancel';
    testWidgets('a second gesture $when commits one way', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(tester, tapSubject: true);
      final ModalRoute<Object?> top = routeOf(tester, 't');
      await _dragToHalf(tester);
      await sendBackGesture(tester, 'cancelBackGesture');
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 32));
      }
      expect(top.isCurrent, isTrue);
      await _dragToHalf(tester);
      if (settle) expect(opacityOf(tester, 's0'), inExclusiveRange(0.0, 1.0));
      const List<String> labels = <String>[..._below, 't'];
      final List<_Frame> frames = await _release(
        tester,
        'commitBackGesture',
        labels,
      );
      frames.addAll(
        await _sampleUntil(tester, labels, () => top.animation!.isDismissed),
      );
      expect(top.animation!.isDismissed, isTrue);
      _expectCommitMonotonic(frames);
    });
  }

  testWidgets('a push during the committed reverse turns once', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> nav = await _pumpDetail(
      tester,
      tapSubject: false,
    );
    await _dragToHalf(tester);
    final List<_Frame> frames = await _release(
      tester,
      'commitBackGesture',
      _below,
    );
    frames.add(_Frame(tester, _below));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      frames.add(_Frame(tester, _below));
    }
    nav.currentState!.push(_detailRoute('c'));
    final ModalRoute<Object?> list = routeOf(tester, 's0');
    frames.addAll(
      await _sampleUntil(
        tester,
        _below,
        () =>
            list.secondaryAnimation!.isCompleted &&
            !list.secondaryAnimation!.isAnimating,
      ),
    );
    for (final String l in _below) {
      _expectOneTurn(frames, l, _dy, -1, what: 'slide');
      _expectOneTurn(frames, l, _opacity, 1, what: 'opacity');
    }
    await tester.pumpAndSettle();
    expect(opacityOf(tester, 's0'), 0.0);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('routes removed during the committed reverse dispose cleanly', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> nav = await _pumpDetail(
      tester,
      tapSubject: true,
    );
    await _dragToHalf(tester);
    await sendBackGesture(tester, 'commitBackGesture');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    nav.currentState!.pushAndRemoveUntil(
      _detailRoute('z'),
      (Route<dynamic> _) => false,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(exists('s0'), isFalse);
    expect(exists('t'), isFalse);
    expect(opacityOf(tester, 'z'), 1.0);
  });

  testWidgets('a plain pop follows the route exactly', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> nav = await _pumpDetail(
      tester,
      tapSubject: false,
    );
    final ModalRoute<Object?> below = routeOf(tester, 's0');
    final ModalRoute<Object?> top = routeOf(tester, 't');
    nav.currentState!.pop();
    await tester.pump();
    int frames = 0;
    while (!top.animation!.isDismissed && frames++ < 120) {
      expect(
        opacityOf(tester, 's0'),
        closeTo(1.0 - uncoveredAt(below.secondaryAnimation!.value), eps),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(top.animation!.isDismissed, isTrue);
    expect(opacityOf(tester, 's0'), 1.0);
  });
}
