# Slice R (v1/slice-r): 1.0.0 removals

Removed: CnRouteAwareAnimation, RouteAwareWidget (+ .routeObserver), top-level routeObserver, CnFade.durationInMilliseconds, CnSlide.reverseControllerValue, `timing` on CnFadeThroughPageTransitionsBuilder and CnPageRoute.

Files deleted: lib/cn_route_aware_animation.dart, lib/route_aware_widget.dart, test/route_aware_test.dart, test/barrel_export_test.dart (only tested the routeObserver clash), test/support/app_routes.dart (only used by it). Also removed tests: CnFade durationInMilliseconds, deprecated timing group, 2 README snippet tests.

example/ had no usage of the removed names. exports_test: dropped removed types, added a negative test (no route_aware export, files gone).

Tests: root 289 -> 268; example 7. Analyze clean (root, example); apk debug builds; dry-run 0 warnings (after commit).

Left for later: CHANGELOG 0.9.0 entry still mentions the symbols as history (intended). Not tagged, not pushed.
