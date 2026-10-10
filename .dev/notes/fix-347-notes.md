# Fix: CI failure on Flutter 3.47.7

Branch `fix/flutter-347`. CI run 38082388674 (PR #1) failed one test on the
latest stable, 3.47.7: `test/progress/directional_curve_test.dart:250`,
Expected 'exit', Actual 'rest'. Reproduced locally with a 3.47.7 clone.

## Root cause

flutter/flutter#154718 ("Shared element transition for predictive back",
commit 0b9225afdf, 2025-05-19, first in 3.35) changed
`TransitionRoute._handleDragEnd` in `packages/flutter/lib/src/widgets/routes.dart`:

- Commit: was `animateBack(0.0)` from the drag value (duration
  `lerpDouble(0, 800, value)` ms, `fastLinearToSlowEaseIn`). Now
  `_controller!.reverse(from: _controller!.upperBound)`: the controller
  jumps to 1.0 and plays the whole reverse.
- Cancel: was `animateTo(1.0)` over `min(lerpDouble(800, 0, value), 300)` ms,
  `fastLinearToSlowEaseIn`. Now a linear `forward()` (continuous).

Flutter's own `PredictiveBackPageTransitionsBuilder` hides the jump: it now
tracks a private `_PredictiveBackPhase` and remaps its animations on commit.

What it meant for us (category b, a real behaviour difference):
`CnBackGestureDetector` forwarded commit to `route.handleCommitBackGesture()`.
On 3.35+ a committed predictive back snapped the page back to fully shown
(and re-parted the page below's elements, which follow the secondary
animation) before fading it out over the full 400 ms. The failing unit test
saw the 1.0 frame as 'rest'. The integration and detector tests missed it:
their commit loops ran `while (route.isActive)`, and a popped route is no
longer active, so they never sampled after the commit; their continuity
bound is relative to the route's own change, so a route jump passes.

## Fix

- `lib/src/route/cn_back_gesture_detector.dart`: commit and cancel no longer
  call the route's `handleCommitBackGesture` / `handleCancelBackGesture`.
  `_settlePredictive` settles from the release point with the 3.29–3.32
  timings and curve, then releases the navigator's user-gesture flag when the
  controller settles (`_stopUserGestureWhenSettled`, now shared with the iOS
  edge swipe). Start and update still go through the route (unchanged since
  3.29). Same behaviour on every SDK, no version check.
- `directional_curve_test.dart`: the route-level test accepts both commit
  contracts (a frame at 1.0 is rest; every frame between rests is exit).
- `cn_back_gesture_test.dart` and `interactive_back_test.dart`: the commit
  goes through the system channel (the detector), is sampled until the
  animation is dismissed, and must only fall. These fail on 3.47.7 without
  the lib fix (6 failures) and pass with it.
- New test: one handler per gesture (route-level start/update counted once,
  no route-level commit/cancel, exactly one pop), with Flutter's stock
  predictive-back builder on the page below.

## Other 3.35+/3.47 differences checked

- Observer wiring unchanged: `_PredictiveBackGestureDetector` still calls
  `route.handleStartBackGesture(progress: 1 - backEvent.progress)` and the
  same for update, so our `1 - progress` mapping holds. `handleStart`/`Update`
  in `routes.dart` are identical in 3.32.7 and 3.47.7.
- Flutter adds no back-gesture observer to every PageRoute. Only
  `PredictiveBackPageTransitionsBuilder` and the new
  `PredictiveBackFullscreenPageTransitionsBuilder` register one, and only for
  routes they build. Neither wraps a CnPageRoute or a theme-installed page.
- `WidgetsBinding` (same commit) now dispatches a back gesture to every
  observer that claims it; 3.32 stopped at the first. Two claimants for one
  gesture (for example nested navigators, each with a current page) would now
  both handle it. This applies to Flutter's stock detector too; not changed.
- The default Android page transition is now
  `PredictiveBackPageTransitionsBuilder` (3.32: Zoom).
- `ModalRoute.popGestureEnabled` no longer refuses while the secondary
  animation runs or while a gesture is in progress. Our detector and
  Cupertino both follow `popGestureEnabled`, so they match the stock routes
  on each SDK; not changed.
- Not fixed, outside the detector: pages using Flutter's stock predictive
  back builder (the 'control' install) get the 3.35+ restart from 1.0 on
  commit, so `CnRouteAnimation` elements on the page below jump back to
  parted at commit and replay the uncover. Flutter only remaps its own page.
  (From reading the sources; no test covers this path.)

## Verified

Commit 6e473a0, one full run per SDK (270 tests each):

| SDK | `flutter test` | `flutter analyze` root / example |
| --- | --- | --- |
| 3.47.7 (clone) | all passed | no issues / no issues |
| 3.32.7 (global) | all passed | no issues / no issues |
| 3.29.0 (clone) | all passed | not run |
