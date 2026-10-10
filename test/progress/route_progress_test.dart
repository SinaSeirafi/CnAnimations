import 'package:cn_animations/src/progress/route_progress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for an element: binds once, the way CnRouteAnimation will.
class _Binder extends StatefulWidget {
  const _Binder(this.label, this.log, {super.key, this.progress, this.cover});

  final String label;
  final Map<String, _BinderState> log;
  final Animation<double>? progress;
  final Animation<double>? cover;

  @override
  State<_Binder> createState() => _BinderState();
}

class _BinderState extends State<_Binder> {
  late CnRouteProgress progress;
  CnMountKind? kind;
  double? primaryAtBind;
  bool? offstageAtBind;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    progress = CnRouteProgress.of(
      context,
      progress: widget.progress,
      coverProgress: widget.cover,
    );
    if (kind == null) {
      primaryAtBind = progress.primary?.value;
      offstageAtBind = progress.route?.offstage;
      kind = progress.classifyMount();
    }
    widget.log[widget.label] = this;
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

/// A State that owns the timed fallback controller.
class _FallbackOwner extends StatefulWidget {
  const _FallbackOwner({super.key});

  @override
  State<_FallbackOwner> createState() => _FallbackOwnerState();
}

class _FallbackOwnerState extends State<_FallbackOwner>
    with SingleTickerProviderStateMixin, CnTimedFallbackMixin<_FallbackOwner> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Records AnimationController creations and disposals.
class _ControllerTracker {
  final List<Object> created = <Object>[];
  final Set<Object> disposed = <Object>{};

  void _listener(ObjectEvent event) {
    if (event is ObjectCreated && event.className == 'AnimationController') {
      created.add(event.object);
    } else if (event is ObjectDisposed) {
      disposed.add(event.object);
    }
  }

  void start() => FlutterMemoryAllocations.instance.addListener(_listener);
  void stop() => FlutterMemoryAllocations.instance.removeListener(_listener);
}

/// A page whose list of binders can grow on later frames.
class _GrowingPage extends StatelessWidget {
  const _GrowingPage(this.labels, this.log);

  final ValueNotifier<List<String>> labels;
  final Map<String, _BinderState> log;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: labels,
      builder: (context, value, _) => Column(
        children: [for (final l in value) _Binder(l, log, key: ValueKey(l))],
      ),
    );
  }
}

void main() {
  group('source resolution', () {
    testWidgets('primary and cover come from the ModalRoute', (tester) async {
      final log = <String, _BinderState>{};
      await tester.pumpWidget(MaterialApp(home: _Binder('a', log)));

      final route = ModalRoute.of(tester.element(find.byType(_Binder)))!;
      final p = log['a']!.progress;
      expect(p.route, same(route));
      expect(p.primary, same(route.animation));
      expect(p.cover, same(route.secondaryAnimation));
      expect(p.recordKey, same(route));
    });

    testWidgets('scope overrides win over the route', (tester) async {
      final log = <String, _BinderState>{};
      const progress = AlwaysStoppedAnimation<double>(0.5);
      const cover = AlwaysStoppedAnimation<double>(0.0);
      await tester.pumpWidget(
        MaterialApp(
          home: _Binder('a', log, progress: progress, cover: cover),
        ),
      );

      final p = log['a']!.progress;
      expect(p.route, isNotNull);
      expect(p.primary, same(progress));
      expect(p.cover, same(cover));
      expect(p.recordKey, same(p.route), reason: 'record stays per route');
    });

    testWidgets('no route and no overrides: nothing to follow', (tester) async {
      final log = <String, _BinderState>{};
      await tester.pumpWidget(_Binder('a', log));

      final state = log['a']!;
      expect(state.progress.route, isNull);
      expect(state.progress.primary, isNull);
      expect(state.progress.cover, isNull);
      expect(state.progress.record, isNull);
      expect(state.kind, CnMountKind.untracked);
    });

    testWidgets('no route with a scope progress keys the record by it', (
      tester,
    ) async {
      final log = <String, _BinderState>{};
      const atRest = AlwaysStoppedAnimation<double>(1.0);
      const moving = AlwaysStoppedAnimation<double>(0.3);
      await tester.pumpWidget(
        Column(
          children: [
            _Binder('rest', log, progress: atRest),
            _Binder('moving', log, progress: moving),
          ],
        ),
      );

      expect(log['rest']!.progress.recordKey, same(atRest));
      expect(log['rest']!.kind, CnMountKind.initial);
      expect(log['moving']!.kind, CnMountKind.following);
      expect(log['moving']!.progress.cover, isNull);
    });

    test('equality is identity of route and sources', () {
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final a = ProxyAnimation(kAlwaysCompleteAnimation);
      final p1 = CnRouteProgress.resolve(route: route, progress: a);
      final p2 = CnRouteProgress.resolve(route: route, progress: a);
      expect(p1, p2);
      expect(p1.hashCode, p2.hashCode);
      expect(
        CnRouteProgress.resolve(
          route: route,
          progress: ProxyAnimation(kAlwaysCompleteAnimation),
        ),
        isNot(p1),
        reason: 'an equal-valued but different source is a change',
      );
      expect(CnRouteProgress.resolve(), CnRouteProgress.resolve());
    });
  });

  group('CnRouteRecord', () {
    testWidgets('one record per route, shared by every element on it', (
      tester,
    ) async {
      final log = <String, _BinderState>{};
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Column(children: [_Binder('a', log), _Binder('b', log)]),
        ),
      );
      final recordA = log['a']!.progress.record;
      expect(recordA, isNotNull);
      expect(identical(recordA, log['b']!.progress.record), isTrue);

      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => _Binder('c', log)),
      );
      await tester.pumpAndSettle();
      expect(identical(log['c']!.progress.record, recordA), isFalse);
    });

    test('only an Expando holds records: lookups never create', () {
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final progress = CnRouteProgress.resolve(route: route);
      expect(CnRouteRecord.maybeOf(route), isNull, reason: 'resolve is lazy');

      final record = progress.record!;
      expect(CnRouteRecord.maybeOf(route), same(record));
      expect(CnRouteRecord.of(route), same(record));
      // A new route object never sees an old record. (A strict GC check is
      // not possible in flutter_test; the Expando is weak by language
      // definition and the record holds no reference to its route.)
      final other = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      expect(CnRouteRecord.maybeOf(other), isNull);
    });

    test('cover segment begins once and clears on end', () {
      final record = CnRouteRecord.of(Object());
      expect(record.inCoverSegment, isFalse);
      expect(record.beginCoverSegment(), isTrue);
      expect(record.beginCoverSegment(), isFalse);
      expect(record.coverSegment, 1);
      record.subjectRect = const Rect.fromLTWH(0, 0, 10, 10);
      record.segmentCache['k'] = 1;

      record.endCoverSegment();
      expect(record.inCoverSegment, isFalse);
      expect(record.subject, isNull);
      expect(record.subjectRect, isNull);
      expect(record.segmentCache, isEmpty);
      record.endCoverSegment(); // idempotent

      expect(record.beginCoverSegment(), isTrue);
      expect(record.coverSegment, 2);
    });

    testWidgets('pointer subject expires after the window or when unmounted', (
      tester,
    ) async {
      final log = <String, _BinderState>{};
      final show = ValueNotifier<List<String>>(<String>['a']);
      await tester.pumpWidget(MaterialApp(home: _GrowingPage(show, log)));
      final state = log['a']!;
      final record = state.progress.record!;

      expect(record.pointerSubject(), isNull);
      record.recordPointerDown(state);
      expect(record.lastPointerDown!.timeStamp, isNull);
      expect(record.pointerSubject(), same(state), reason: 'pending = fresh');

      await tester.pump();
      expect(record.lastPointerDown!.timeStamp, isNotNull);
      // The element asks during a frame (the cover source's tick); force
      // frames so the frame clock advances with the fake clock.
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 300));
      expect(record.pointerSubject(), same(state));
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(record.pointerSubject(), isNull, reason: '800 ms > 700 ms');

      record.recordPointerDown(state);
      await tester.pump();
      show.value = <String>[];
      await tester.pump();
      expect(record.pointerSubject(), isNull, reason: 'owner unmounted');
    });

    testWidgets('select() hands its context to the next resolution once', (
      tester,
    ) async {
      final log = <String, _BinderState>{};
      await tester.pumpWidget(MaterialApp(home: _Binder('a', log)));
      final state = log['a']!;
      final record = state.progress.record!;

      expect(record.takeSelection(), isNull);
      record.select(state.context);
      expect(record.takeSelection(), same(state.context));
      expect(record.takeSelection(), isNull);
    });
  });

  group('initial vs late mounts', () {
    testWidgets('first route: same-frame mounts are initial, later are late', (
      tester,
    ) async {
      final log = <String, _BinderState>{};
      final labels = ValueNotifier<List<String>>(<String>['a', 'b']);
      await tester.pumpWidget(MaterialApp(home: _GrowingPage(labels, log)));

      expect(log['a']!.progress.primary!.value, 1.0, reason: 'didAdd');
      expect(log['a']!.kind, CnMountKind.initial);
      expect(log['b']!.kind, CnMountKind.initial);

      labels.value = <String>['a', 'b', 'c'];
      await tester.pump();
      expect(log['c']!.kind, CnMountKind.late);
    });

    testWidgets('pushed with a transition: following, then late', (
      tester,
    ) async {
      final log = <String, _BinderState>{};
      final nav = GlobalKey<NavigatorState>();
      final labels = ValueNotifier<List<String>>(<String>['a']);
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const SizedBox()),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => _GrowingPage(labels, log)),
      );
      await tester.pump();
      // Hero measuring frame: the page is built offstage and its animation
      // reads 1.0, yet the mount must follow progress, not play a timed
      // entrance.
      expect(log['a']!.primaryAtBind, 1.0);
      expect(log['a']!.offstageAtBind, isTrue);
      expect(log['a']!.kind, CnMountKind.following);
      await tester.pump();
      expect(log['a']!.progress.route!.animation!.value, lessThan(1.0));

      await tester.pumpAndSettle();
      labels.value = <String>['a', 'b'];
      await tester.pump();
      expect(log['b']!.progress.primary!.value, 1.0);
      expect(log['b']!.kind, CnMountKind.late);
    });

    testWidgets('zero-duration push: initial on its first frame', (
      tester,
    ) async {
      final log = <String, _BinderState>{};
      final nav = GlobalKey<NavigatorState>();
      final labels = ValueNotifier<List<String>>(<String>['a', 'b']);
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const SizedBox()),
      );
      nav.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => _GrowingPage(labels, log),
        ),
      );
      await tester.pump();
      expect(log['a']!.kind, CnMountKind.initial);
      expect(log['b']!.kind, CnMountKind.initial);

      labels.value = <String>['a', 'b', 'c'];
      await tester.pump();
      expect(log['c']!.kind, CnMountKind.late);
    });
  });

  group('timed fallback controller', () {
    testWidgets('is created lazily and disposed with its owner', (
      tester,
    ) async {
      final tracker = _ControllerTracker()..start();
      addTearDown(tracker.stop);
      final key = GlobalKey<_FallbackOwnerState>();
      await tester.pumpWidget(_FallbackOwner(key: key));

      final owner = key.currentState!;
      expect(owner.timedFallback, isNull);
      expect(tracker.created, isEmpty, reason: 'no controller until asked');

      final controller = owner.ensureTimedFallback(
        duration: const Duration(milliseconds: 300),
      );
      expect(tracker.created, [same(controller)]);
      final again = owner.ensureTimedFallback(
        duration: const Duration(milliseconds: 200),
      );
      expect(again, same(controller));
      expect(controller.duration, const Duration(milliseconds: 200));
      expect(tracker.created, hasLength(1));

      owner.playTimedFallback(duration: const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.value, closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isCompleted, isTrue);

      // Dispose mid-flight: the owner's dispose stops and releases it.
      owner.playTimedFallback(duration: const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      expect(tracker.disposed, contains(controller));
    });

    testWidgets('a zero duration completes synchronously', (tester) async {
      final key = GlobalKey<_FallbackOwnerState>();
      await tester.pumpWidget(_FallbackOwner(key: key));
      final controller = key.currentState!.playTimedFallback(
        duration: Duration.zero,
      );
      expect(controller.isCompleted, isTrue);
    });
  });

  group('staggered slices (design §3.4)', () {
    const exit = Interval(0.0, 0.35);
    const enter = Interval(0.35, 1.0);

    test('exit is delayed and stretched by factor · stagger', () {
      final near = staggeredExitInterval(exit, factor: 0, stagger: 0.12);
      expect([near.begin, near.end], [0.0, 0.35]);
      final far = staggeredExitInterval(
        exit,
        factor: 1,
        stagger: 0.12,
        curve: Curves.easeIn,
      );
      expect(far.begin, closeTo(0.12, 1e-12));
      expect(far.end, closeTo(0.47, 1e-12));
      expect(far.curve, Curves.easeIn);
    });

    test('enter is delayed with its end pinned to 1', () {
      final far = staggeredEnterInterval(enter, factor: 1, stagger: 0.25);
      expect(far.begin, closeTo(0.6, 1e-12));
      expect(far.end, 1.0);
      final half = staggeredEnterInterval(enter, factor: 0.5, stagger: 0.25);
      expect(half.begin, closeTo(0.475, 1e-12));
    });

    test('factor is clamped and slices stay inside [0, 1]', () {
      final over = staggeredExitInterval(
        const Interval(0.8, 0.95),
        factor: 3,
        stagger: 0.5,
      );
      expect(over.end, 1.0);
      expect(over.begin, lessThanOrEqualTo(over.end));
      final under = staggeredEnterInterval(enter, factor: -1, stagger: 0.25);
      expect(under.begin, 0.35);
      final pinned = staggeredEnterInterval(
        const Interval(0.9, 1.0),
        factor: 1,
        stagger: 0.5,
      );
      expect([pinned.begin, pinned.end], [1.0, 1.0]);
    });
  });
}
