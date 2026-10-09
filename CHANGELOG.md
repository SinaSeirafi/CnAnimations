## 0.1.0
Fixes
* `CnRouteAwareAnimation(showPush: false)` was invisible (regression in 0.0.3). When the push animation is not played, the child is now fully shown.
* `CnRouteAwareAnimation` inside a dialog or bottom sheet was invisible. Non-page routes now count as pushed once.
* Toggling `animate` (or all `show*` flags) off and back on threw `Bad state: Stream has already been listened to`.
* `CnScale(forward: false)` did not animate. It now animates from `end` to `begin`, like `CnFade` and `CnSlide`.
* Removing an external `controller` (switching it to null) left `CnFade`, `CnSlide` and `CnScale` stuck at the start value. The internal controller now plays, as on first build.
* `duration` changes after the first build are applied (`CnFade`, `CnSlide`, `CnScale`, and `fadeDuration` / `slideDuration` of `CnRouteAwareAnimation`).
* `CurvedAnimation`s are disposed (they leaked listeners on the controller).
* Delayed callbacks are cancellable timers: a new navigation event cancels pending ones, so they cannot run out of order, and all are cancelled on dispose.

Improvements
* Reduced motion: when the platform asks to disable animations, widgets show their final state immediately. Opt out per widget with `respectReducedMotion: false`.
* `route_aware_widget.dart` is exported from `package:cn_animations/cn_animations.dart`.
* New `RouteAwareWidget.routeObserver`. Use it in `navigatorObservers`.
* `CnSlide.intervalBegin` / `intervalEnd` now work.
* `CnFade.durationInMilliseconds` is honored (overrides `duration`).
* `RouteAwareWidget` callbacks are typed `VoidCallback?`.
* Requires Dart 3 and Flutter 3.10 or newer.

Deprecations
* Top-level `routeObserver`: use `RouteAwareWidget.routeObserver` (same instance).
* `CnFade.durationInMilliseconds`: use `duration`.
* `CnSlide.reverseControllerValue`: has no effect.

## 0.0.3
* Bug fix
* Adding Route Aware Animation example

## 0.0.2
* Updating README and GIFs

## 0.0.1
* Initial release
* Basic Animations (Fade, Slide, Scale)
* Route Aware Animation (Fade and Slide triggered by navigation)
* Route Aware Widget
