// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:io';

import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/animation.dart';
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
      CnRouteAwareAnimation,
      RouteAwareWidget,
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
    ];
    expect(types, everyElement(isNotNull));
    expect(CnRouteTiming.standard, isA<CnRouteTiming>());
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
    expect(code, contains('hide routeObserver'));
  });
}
