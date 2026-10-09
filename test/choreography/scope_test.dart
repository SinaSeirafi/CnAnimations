import 'package:cn_animations/src/choreography/cn_route_choreography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the resolved data on every build.
class _Probe extends StatelessWidget {
  const _Probe(this.onBuild);
  final void Function(CnRouteChoreographyData data) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(CnRouteChoreography.of(context));
    return const SizedBox();
  }
}

/// Stand-in for the element widget's State: the hook `select()` looks for.
class _FakeTarget extends StatefulWidget {
  const _FakeTarget({required this.name, required this.log, this.child});
  final String name;
  final List<String> log;
  final Widget? child;

  @override
  State<_FakeTarget> createState() => _FakeTargetState();
}

class _FakeTargetState extends State<_FakeTarget>
    implements CnRouteSubjectTarget {
  @override
  void selectAsSubject() => widget.log.add(widget.name);

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox();
}

void main() {
  group('CnRouteChoreography.of', () {
    testWidgets('returns the built-in defaults with no scope', (tester) async {
      late CnRouteChoreographyData data;
      await tester.pumpWidget(_Probe((d) => data = d));

      expect(data, CnRouteChoreographyData.fallback);
      expect(data.timing, CnRouteTiming.standard);
      expect(data.parting, const CnPartingSpec());
      expect(data.scrollReveal, CnScrollReveal.off);
      expect(data.scrollReveal.enabled, isFalse);
      expect(data.respectReducedMotion, isTrue);
      expect(data.reducedMotionMode, CnReducedMotionMode.fadeOnly);
      expect(data.axis, Axis.vertical);
      expect(data.subjectDetection, CnSubjectDetection.pointer);
      expect(data.progress, isNull);
      expect(data.coverProgress, isNull);
    });

    test('pending-decision defaults are the recommended values', () {
      expect(kCnDefaultReducedMotionMode, CnReducedMotionMode.fadeOnly);
      expect(kCnDefaultSubjectDetection, CnSubjectDetection.pointer);
      expect(kCnPointerSubjectWindow, const Duration(milliseconds: 700));
      expect(kCnDefaultRespectReducedMotion, isTrue);
    });

    testWidgets('merges nested scopes field-by-field, inner non-null wins', (
      tester,
    ) async {
      final outerProgress = AlwaysStoppedAnimation<double>(0.5);
      final innerCover = AlwaysStoppedAnimation<double>(0.25);
      const outerTiming = CnRouteTiming(exitStagger: 0.08);
      const innerTiming = CnRouteTiming(enterStagger: 0.1);
      late CnRouteChoreographyData data;

      await tester.pumpWidget(
        CnRouteChoreography(
          timing: outerTiming,
          respectReducedMotion: false,
          axis: Axis.horizontal,
          progress: outerProgress,
          subjectDetection: CnSubjectDetection.manual,
          child: CnRouteChoreography(
            // Unset fields here must inherit from the outer scope.
            child: CnRouteChoreography(
              timing: innerTiming,
              reducedMotionMode: CnReducedMotionMode.none,
              coverProgress: innerCover,
              subjectDetection: CnSubjectDetection.off,
              child: _Probe((d) => data = d),
            ),
          ),
        ),
      );

      expect(data.timing, innerTiming); // inner wins
      expect(data.respectReducedMotion, isFalse); // from outer
      expect(data.axis, Axis.horizontal); // from outer
      expect(data.progress, same(outerProgress)); // from outer
      expect(data.coverProgress, same(innerCover)); // inner only
      expect(data.reducedMotionMode, CnReducedMotionMode.none); // inner only
      expect(data.subjectDetection, CnSubjectDetection.off); // inner wins
      expect(data.parting, const CnPartingSpec()); // default
      expect(data.scrollReveal, CnScrollReveal.off); // default
    });

    testWidgets(
        'a change to an outer scope rebuilds dependents below an '
        'inner scope', (tester) async {
      final reveal = ValueNotifier<CnScrollReveal?>(null);
      final seen = <CnScrollReveal>[];
      final probe = _Probe((d) => seen.add(d.scrollReveal));

      await tester.pumpWidget(
        ValueListenableBuilder<CnScrollReveal?>(
          valueListenable: reveal,
          builder: (context, value, child) =>
              CnRouteChoreography(scrollReveal: value, child: child!),
          child: CnRouteChoreography(axis: Axis.vertical, child: probe),
        ),
      );
      expect(seen, [CnScrollReveal.off]);

      reveal.value = const CnScrollReveal();
      await tester.pump();
      expect(seen, [CnScrollReveal.off, const CnScrollReveal()]);
      expect(seen.last.enabled, isTrue);
    });

    testWidgets('an equal configuration does not notify dependents', (
      tester,
    ) async {
      var builds = 0;
      final probe = _Probe((_) => builds++);
      Widget tree() => CnRouteChoreography(
            // Non-const but equal values each rebuild.
            timing: CnRouteTiming(exit: Interval(0.0, 0.3)),
            parting: CnPartingSpec(distance: Offset(0, 0.5)),
            scrollReveal: CnScrollReveal(offset: Offset(0, 0.2)),
            child: probe,
          );

      await tester.pumpWidget(tree());
      await tester.pumpWidget(tree());
      expect(builds, 1);
    });

    testWidgets('a scope in MaterialApp.builder reaches elements inside routes',
        (
      tester,
    ) async {
      late CnRouteChoreographyData data;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => CnRouteChoreography(
            timing: const CnRouteTiming(exitStagger: 0.08),
            child: child!,
          ),
          home: _Probe((d) => data = d),
        ),
      );
      expect(data.timing.exitStagger, 0.08);
    });
  });

  group('reducedMotionFor', () {
    const scopeOn = CnRouteChoreographyData();
    const scopeOff = CnRouteChoreographyData(
      respectReducedMotion: false,
      reducedMotionMode: CnReducedMotionMode.none,
    );

    test('null when animations are not disabled', () {
      expect(scopeOn.reducedMotionFor(disableAnimations: false), isNull);
    });

    test('default respects reduced motion with fadeOnly', () {
      expect(
        scopeOn.reducedMotionFor(disableAnimations: true),
        CnReducedMotionMode.fadeOnly,
      );
    });

    test('scope value applies when the widget does not override', () {
      expect(scopeOff.reducedMotionFor(disableAnimations: true), isNull);
    });

    test('widget override beats the scope', () {
      expect(
        scopeOn.reducedMotionFor(
          disableAnimations: true,
          respectReducedMotion: false,
        ),
        isNull,
      );
      expect(
        scopeOff.reducedMotionFor(
          disableAnimations: true,
          respectReducedMotion: true,
        ),
        CnReducedMotionMode.none,
      );
      expect(
        scopeOff.reducedMotionFor(
          disableAnimations: true,
          respectReducedMotion: true,
          reducedMotionMode: CnReducedMotionMode.fadeOnly,
        ),
        CnReducedMotionMode.fadeOnly,
      );
    });
  });

  group('CnRouteChoreography.select', () {
    testWidgets('marks the nearest element above the context', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _FakeTarget(
          name: 'outer',
          log: log,
          child: _FakeTarget(
            name: 'inner',
            log: log,
            child: const Padding(
              padding: EdgeInsets.zero,
              child: SizedBox(key: Key('leaf')),
            ),
          ),
        ),
      );

      CnRouteChoreography.select(tester.element(find.byKey(const Key('leaf'))));
      expect(log, ['inner']);
    });

    testWidgets('accepts the element\'s own context', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _FakeTarget(
          name: 'outer',
          log: log,
          child: _FakeTarget(name: 'inner', log: log),
        ),
      );

      final inner = find.byWidgetPredicate(
        (w) => w is _FakeTarget && w.name == 'inner',
      );
      CnRouteChoreography.select(tester.element(inner));
      expect(log, ['inner']);
    });

    testWidgets('throws in debug when there is no element above', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox(key: Key('alone')));
      expect(
        () => CnRouteChoreography.select(
          tester.element(find.byKey(const Key('alone'))),
        ),
        throwsFlutterError,
      );
    });
  });

  group('value types', () {
    test('CnRouteTiming defaults, copyWith and equality', () {
      const t = CnRouteTiming.standard;
      expect(t.exit.begin, 0.0);
      expect(t.exit.end, 0.35);
      expect(t.enter.begin, 0.35);
      expect(t.enter.end, 1.0);
      expect(t.exitStagger, 0.12);
      expect(t.enterStagger, 0.25);
      expect(t.exitCurve, Curves.easeIn);
      expect(t.enterCurve, Curves.easeOutCubic);
      expect(t.fallbackDuration, const Duration(milliseconds: 300));

      expect(t.copyWith(), t);
      expect(t.copyWith().hashCode, t.hashCode);
      // Non-const Interval with equal fields is still equal.
      expect(t.copyWith(exit: Interval(0.0, 0.35)), t);
      final changed = t.copyWith(exitStagger: 0.08);
      expect(changed.exitStagger, 0.08);
      expect(changed.enterStagger, 0.25);
      expect(changed, isNot(t));
    });

    test('CnPartingSpec defaults and equality', () {
      const p = CnPartingSpec();
      expect(p.distance, const Offset(0, 0.6));
      expect(p.distanceGrowth, 0.5);
      expect(p.fadeSiblings, isTrue);
      expect(p.subject, CnSubjectBehavior.stay);
      expect(
        const CnPartingSpec(subject: CnSubjectBehavior.grow),
        isNot(p),
      );
    });

    test('CnScrollReveal on/off', () {
      const on = CnScrollReveal();
      expect(on.enabled, isTrue);
      expect(on.offset, const Offset(0, 0.1));
      expect(on.once, isTrue);
      expect(on.duration, isNull);
      expect(on.curve, isNull);
      expect(CnScrollReveal.off.enabled, isFalse);
      expect(CnScrollReveal.off, isNot(on));
    });
  });
}
