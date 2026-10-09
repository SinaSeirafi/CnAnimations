## 0.9.0
0.9.0 is the migration bridge: it adds the new navigation-driven APIs and keeps the old route-aware widgets as deprecated. `CnRouteAwareAnimation`, `RouteAwareWidget`, `RouteAwareWidget.routeObserver` and the top-level `routeObserver` will be removed in 1.0.0.

Requires Flutter 3.29 / Dart 3.7 or newer.

New
* `CnRouteAnimation`: wraps a page element so it enters with the page, exits when another page covers it and follows swipe-back and predictive-back gestures, driven by route progress and no `RouteObserver`. Parts around the tapped item (pointer detection on by default, 700 ms window; `subject:` and `CnRouteChoreography.select()` override). `enterOffset` defaults to `Offset(0, 0.1)` (from below) and `exitOffset` to `-enterOffset`. Also exports `CnElementProgress`, `CnElementRole` and `CnRouteAnimationBuilder` for the `builder:` form.
* `CnRouteChoreography`: optional scope for app-wide or per-page defaults. Configured with `CnRouteTiming`, `CnPartingSpec`, `CnScrollReveal`, `CnReducedMotionMode`, `CnSubjectDetection` and `CnSubjectBehavior` (all exported). Reduced motion is respected by default (`fadeOnly`); opt out with `respectReducedMotion: false`, or show elements at rest with `reducedMotionMode: none`; precedence is widget, then scope, then default.
* `CnDirectionalCurvedAnimation`: curves a progress value by the rest value (0 or 1) it last left, so the same animation can use different curves going in and coming back.
* `CnRouteTiming.uncover` (default `Interval(0.3, 0.65)` of the cover progress, as long as `exit`): when the page above pops or is dragged back (predictive back, iOS edge swipe), covered elements return over this slice instead of the exit slice played backwards. They start returning as the top page's elements finish leaving, so a pop no longer has a stretch of about a quarter of its length where neither page's elements show. It shares `exitStagger` and `exitCurve` with `exit`; set `uncover:` to the `exit` slice for the old behaviour.
* `CnFadeThroughPageTransitionsBuilder` (for `pageTransitionsTheme`) and `CnPageRoute`: a fade-through route that keeps the page below still while its elements exit. The transition has fixed intervals and runs 400 ms.
* `animation:` parameter on `CnFade`, `CnSlide` and `CnScale` to drive them from an `Animation<double>`. An external `controller:` or `animation:` is never overridden by reduced motion.

Behavior notes
* Element curves come from `CnRouteTiming.exitCurve` / `enterCurve`. Curves set on the `exit` / `enter` / `uncover` `Interval`s are ignored, and assert in debug.
* `CnRouteChoreography.select()` with no `CnRouteAnimation` above it asserts in debug and does nothing in release.
* Route types: Flutter's `MaterialPageRoute<T>.canTransitionTo` compares generic types, so a `MaterialPageRoute<int>` below a route with a different `T` may not receive exits. Prefer the theme builder or `CnPageRoute`, which do not have this quirk. The same applies to a `CupertinoPageRoute<T>` page, and `CnPageRoute` does not fix that case: give the routes matching type arguments or use the theme builder.
* A plain `PageRouteBuilder` over a `MaterialPageRoute` does not drive the lower page's exits; use `CnPageRoute` or the theme builder.

Deprecations (all removed in 1.0.0)
* `CnRouteAwareAnimation`: use `CnRouteAnimation`.
* `RouteAwareWidget`, `RouteAwareWidget.routeObserver` and the top-level `routeObserver`: no longer needed by the package.
* `timing` on `CnFadeThroughPageTransitionsBuilder` and `CnPageRoute`: it has no effect. Element timing comes from `CnRouteChoreography` and `CnRouteAnimation`.

## 0.1.0
Fixes
* `CnRouteAwareAnimation(showPush: false)` was invisible (regression in 0.0.3). When the push animation is not played, the child is now fully shown.
* `CnRouteAwareAnimation` inside a dialog or bottom sheet was invisible. Non-page routes now count as pushed once.
* Toggling `animate` (or all `show*` flags) off and back on threw `Bad state: Stream has already been listened to`.
* `CnScale(forward: false)` did not animate. It now animates from `end` to `begin`, like `CnFade` and `CnSlide`.
* Removing an external `controller` (switching it to null) left `CnFade`, `CnSlide` and `CnScale` stuck at the start value. The internal controller now plays, as on first build, if it has not already completed.
* `duration` changes after the first build are applied to the next run (`CnFade`, `CnSlide`, `CnScale`, and `fadeDuration` / `slideDuration` of `CnRouteAwareAnimation`).
* `CurvedAnimation`s are disposed (they leaked listeners on the controller).
* `CnRouteAwareAnimation(showPopNext: false)` stayed invisible after returning to the page. The page is now shown again, without animating.
* Delayed callbacks are cancellable timers: a new navigation event cancels pending ones, so they cannot run out of order, and all are cancelled on dispose.

Improvements
* Reduced motion: when the platform asks to disable animations, `CnFade`, `CnSlide` and `CnScale` show their final state immediately, and `CnRouteAwareAnimation` jumps to each navigation event's end state instead of animating (custom `fadeEndSamePage` / `endSamePage` are kept, and the child's state survives toggling the setting). An external `controller` is never overridden: the app owns that motion. Opt out per widget with `respectReducedMotion: false`.
* `RouteAwareWidget` is now exported from `package:cn_animations/cn_animations.dart`. If your app has its own class with that name, import with `hide RouteAwareWidget` or use an `as` prefix. The deprecated top-level `routeObserver` is not exported from the barrel; it is still available from `package:cn_animations/route_aware_widget.dart`.
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
