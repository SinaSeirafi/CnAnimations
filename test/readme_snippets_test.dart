// Each README snippet reproduced as compiled code, so README drift breaks the
// build. Keep in sync with README.md.
import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('detail page'));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.child});
  final Widget? child;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: child ?? const Text('home page'));
}

Future<void> pumpApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  const Widget child = Text('child');

  group('basic widgets', () {
    testWidgets('CnFade, CnSlide, CnScale', (tester) async {
      await pumpApp(
        tester,
        Column(
          children: [
            const CnFade(child: child),
            CnSlide(
              begin: const Offset(-0.2, 0),
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 100),
              curve: Curves.easeIn,
              child: child,
            ),
            const CnScale(begin: 0.5, child: child),
          ],
        ),
      );
      expect(find.text('child'), findsNWidgets(3));
    });

    testWidgets('CnScale with controller', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CnScale(begin: 0.5, controller: controller, child: child),
        ),
      );
      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('animation: parameter follows the given animation', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(controller.dispose);
      final Animation<double> animation = controller;
      await tester.pumpWidget(
        MaterialApp(
          home: CnFade(animation: animation, child: child),
        ),
      );
      FadeTransition fade() =>
          tester.widget<FadeTransition>(find.byType(FadeTransition).last);
      expect(fade().opacity.value, 0.0);
      controller.value = 1.0;
      await tester.pump();
      expect(fade().opacity.value, 1.0);
    });
  });

  group('route install', () {
    testWidgets('theme builder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CnFadeThroughPageTransitionsBuilder(),
                TargetPlatform.iOS: CnFadeThroughPageTransitionsBuilder(),
              },
            ),
          ),
          home: const HomePage(),
        ),
      );
      expect(find.text('home page'), findsOneWidget);
    });

    testWidgets('CnPageRoute push', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const HomePage();
            },
          ),
        ),
      );
      Navigator.of(
        ctx,
      ).push(CnPageRoute<void>(builder: (_) => const DetailPage()));
      await tester.pumpAndSettle();
      expect(find.text('detail page'), findsOneWidget);
    });

    testWidgets('deprecated observer install still compiles', (tester) async {
      // ignore: deprecated_member_use_from_same_package
      final observer = RouteAwareWidget.routeObserver;
      await tester.pumpWidget(
        MaterialApp(navigatorObservers: [observer], home: const HomePage()),
      );
      expect(find.text('home page'), findsOneWidget);
    });
  });

  group('CnRouteAnimation', () {
    testWidgets('minimal', (tester) async {
      await pumpApp(
        tester,
        const CnRouteAnimation(
          child: Card(child: ListTile(title: Text('Item'))),
        ),
      );
      expect(find.text('Item'), findsOneWidget);
    });

    testWidgets('offsets and scale', (tester) async {
      await pumpApp(
        tester,
        const CnRouteAnimation(
          enterOffset: Offset(0, 0.1),
          exitOffset: Offset(0, -0.1),
          scale: 0.95,
          child: child,
        ),
      );
      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('defaults documented in the README', (tester) async {
      const widget = CnRouteAnimation(child: child);
      expect(widget.enterOffset, const Offset(0, 0.1));
      expect(widget.exitOffset, isNull); // mirrors -enterOffset
      expect(widget.fade, isTrue);
      expect(widget.enabled, isTrue);
      expect(widget.enter, isTrue);
      expect(widget.cover, isTrue);
      expect(widget.respectReducedMotion, isNull);
      expect(widget.reducedMotionMode, isNull);
    });

    testWidgets('builder form', (tester) async {
      CnElementProgress? seen;
      await pumpApp(
        tester,
        CnRouteAnimation(
          builder: (context, progress, child) {
            seen = progress;
            return Opacity(
              opacity: progress.shown * (1 - progress.covered),
              child: child,
            );
          },
          child: child,
        ),
      );
      expect(find.text('child'), findsOneWidget);
      expect(seen, isNotNull);
    });

    testWidgets('list with parting and CnPageRoute push', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, i) => CnRouteAnimation(
                child: ListTile(
                  title: Text('Item $i'),
                  onTap: () => Navigator.of(
                    context,
                  ).push(CnPageRoute<void>(builder: (_) => const DetailPage())),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Item 2'));
      await tester.pumpAndSettle();
      expect(find.text('detail page'), findsOneWidget);
    });

    testWidgets('subject options and select()', (tester) async {
      await pumpApp(
        tester,
        Column(
          children: [
            const CnRouteAnimation(subject: false, child: child),
            CnRouteAnimation(
              subject: true,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => CnRouteChoreography.select(context),
                  child: const Text('select'),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.tap(find.text('select'));
      await tester.pump();
      expect(find.text('select'), findsOneWidget);
    });
  });

  group('CnRouteChoreography', () {
    testWidgets('full scope snippet', (tester) async {
      await pumpApp(
        tester,
        CnRouteChoreography(
          timing: const CnRouteTiming(
            exitCurve: Curves.easeIn,
            enterCurve: Curves.easeOutCubic,
            exitStagger: 0.12,
            enterStagger: 0.25,
          ),
          parting: const CnPartingSpec(
            distance: Offset(0, 0.6),
            subject: CnSubjectBehavior.stay,
          ),
          axis: Axis.vertical,
          subjectDetection: CnSubjectDetection.pointer,
          scrollReveal: const CnScrollReveal(),
          child: const CnRouteAnimation(child: child),
        ),
      );
      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('documented defaults', (tester) async {
      late CnRouteChoreographyData data;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            data = CnRouteChoreography.of(context);
            return child;
          },
        ),
      );
      expect(data.reducedMotionMode, CnReducedMotionMode.fadeOnly);
      expect(data.respectReducedMotion, isTrue);
      expect(data.subjectDetection, CnSubjectDetection.pointer);
      expect(data.timing.fallbackDuration, const Duration(milliseconds: 300));
      expect(data.scrollReveal.enabled, isFalse);
    });

    testWidgets('reduced motion snippets', (tester) async {
      await pumpApp(
        tester,
        Column(
          children: [
            const CnRouteChoreography(
              reducedMotionMode: CnReducedMotionMode.none,
              child: CnRouteAnimation(child: Text('a')),
            ),
            const CnRouteChoreography(
              respectReducedMotion: false,
              child: CnRouteAnimation(
                respectReducedMotion: true,
                child: Text('b'),
              ),
            ),
          ],
        ),
      );
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('reduced motion precedence: widget > scope > default', (
      tester,
    ) async {
      const data = CnRouteChoreographyData();
      expect(
        data.reducedMotionFor(disableAnimations: true),
        CnReducedMotionMode.fadeOnly,
      );
      expect(data.reducedMotionFor(disableAnimations: false), isNull);
      const optOut = CnRouteChoreographyData(respectReducedMotion: false);
      expect(optOut.reducedMotionFor(disableAnimations: true), isNull);
      expect(
        optOut.reducedMotionFor(
          disableAnimations: true,
          respectReducedMotion: true,
        ),
        CnReducedMotionMode.fadeOnly,
      );
      expect(
        data.reducedMotionFor(
          disableAnimations: true,
          respectReducedMotion: false,
        ),
        isNull,
      );
    });

    testWidgets('scope progress drives elements', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(controller.dispose);
      await pumpApp(
        tester,
        CnRouteChoreography(
          progress: controller,
          child: const CnRouteAnimation(child: child),
        ),
      );
      expect(find.text('child'), findsOneWidget);
    });
  });

  group('migration', () {
    testWidgets('after snippet', (tester) async {
      await pumpApp(
        tester,
        const CnRouteAnimation(
          enterOffset: Offset(0, -0.1),
          exitOffset: Offset(0, 0.1),
          child: child,
        ),
      );
      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('before snippet (deprecated) still builds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          // ignore: deprecated_member_use_from_same_package
          navigatorObservers: [RouteAwareWidget.routeObserver],
          home: Scaffold(
            // ignore: deprecated_member_use_from_same_package
            body: CnRouteAwareAnimation(
              beginSamePage: const Offset(0, -0.1),
              endNextPage: const Offset(0, 0.1),
              child: child,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('child'), findsOneWidget);
    });
  });
}
