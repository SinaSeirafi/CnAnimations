import 'dart:io';

import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Positives: referencing each type as a type literal compiles only if the
  // barrel exports it.
  test('public symbols resolve through the barrel', () {
    final List<Type> types = <Type>[
      CnFade,
      CnSlide,
      CnScale,
      CnDirectionalCurvedAnimation,
      CnRouteTiming,
      CnReducedMotionMode,
      CnSubjectDetection,
      CnSubjectBehavior,
      CnPartingSpec,
      CnScrollReveal,
      CnRouteChoreographyData,
      CnRouteChoreography,
      CnFadeThroughPageTransitionsBuilder,
      CnPageRoute,
      CnRouteAnimation,
      CnElementProgress,
      CnElementRole,
    ];
    expect(types, everyElement(isNotNull));
    expect(CnRouteTiming.standard, isA<CnRouteTiming>());
    // Typedef and enum values.
    Widget builder(BuildContext c, CnElementProgress p, Widget? w) =>
        w ?? const SizedBox();
    final CnRouteAnimationBuilder typed = builder;
    expect(typed, isNotNull);
    expect(
      CnElementRole.values,
      containsAll(<CnElementRole>[
        CnElementRole.subject,
        CnElementRole.sibling,
        CnElementRole.plain,
      ]),
    );
    expect(CnElementProgress.rest.shown, 1.0);
    expect(CnReducedMotionMode.values, hasLength(2));
    expect(CnSubjectDetection.values, hasLength(3));
    expect(CnSubjectBehavior.values, hasLength(3));
    expect(CnScrollReveal.off.enabled, isFalse);
    expect(
      CnDirectionalCurvedAnimation(
        const AlwaysStoppedAnimation<double>(0.5),
        enter: Curves.linear,
        exit: Curves.linear,
      ).value,
      0.5,
    );
  });

  // Negatives: internal symbols cannot be probed at compile time without an
  // analyzer, so the barrel's export list is read as text.
  test('internal files and symbols are not exported', () {
    final String barrel = File('lib/cn_animations.dart').readAsStringSync();
    final String code = barrel
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code, isNot(contains('route_progress.dart')));
    expect(code, isNot(contains('geometry.dart')));
    expect(code, isNot(contains('CnRouteSubjectTarget')));
    expect(code, isNot(contains('kCn')));
    expect(code, isNot(contains('hide')));
  });

  // The 0.9.0 deprecated symbols were removed in 1.0.0.
  test('removed route-aware files are not exported', () {
    final String barrel = File('lib/cn_animations.dart').readAsStringSync();
    expect(barrel, isNot(contains('route_aware')));
    expect(File('lib/route_aware_widget.dart').existsSync(), isFalse);
    expect(File('lib/cn_route_aware_animation.dart').existsSync(), isFalse);
  });
}
