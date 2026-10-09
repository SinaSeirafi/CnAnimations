import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_routes.dart';

void main() {
  // Compiles only if the barrel does not export the deprecated top-level
  // routeObserver, which would make this name ambiguous.
  test('an app-level routeObserver does not clash with the barrel', () {
    expect(routeObserver, isA<RouteObserver<ModalRoute<void>>>());
    expect(identical(routeObserver, RouteAwareWidget.routeObserver), isFalse);
  });
}
