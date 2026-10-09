# Slice C2 notes

Running notes (C2, 2026-10-09). Owns lib/src/route/** and test/route/** only.

## Approach
- One internal widget, `CnBackGestureDetector` (lib/src/route/cn_back_gesture_detector.dart, not exported), sits inside the fade-through for both installs (the theme builder and `CnPageRoute`, which forwards to the builder). It adds the platform input that Flutter's stock builders carry and the fade-through lacked. Visuals are unchanged: the gestures only move the route's own `animation`, which the fade-through and the elements already follow.
- Android: the widget is a `WidgetsBindingObserver`, reproducing `PredictiveBackPageTransitionsBuilder`'s private `_PredictiveBackGestureDetector` wiring. It claims `flutter/backgesture` when the route is current and `popGestureEnabled`, and forwards start/update/commit/cancel to the public `PredictiveBackRoute` API on the route (`handleStartBackGesture(progress: 1 - p)` etc.).
- iOS and macOS (theme platform): an edge strip like `_CupertinoBackGestureDetector` (20 px or the start-side safe-area padding, RTL-aware) feeds a `HorizontalDragGestureRecognizer` into a reproduction of `_CupertinoBackGestureController`: the finger sets the route controller, release flings or settles by velocity and position over 350 ms `fastEaseInToSlowEaseOut`, and pops through `navigator.pop()`.
- Why not delegate through the public builders: `PredictiveBackPageTransitionsBuilder.buildTransitions` always wraps the child in its own visuals (Zoom at rest, the predictive-back shift and scale during a gesture), and no constant animation pair makes both branches the identity. `CupertinoRouteTransitionMixin.buildPageTransitions` would need constant animations too, and then still paints the Cupertino edge shadow at the page's start edge, which shows in split or nested layouts.

## H repro file against the fix (scratch copy, not committed)
- With `--dart-define=RUN_BUGS=true`, H's file as-is: 7 pass, 4 fail. In all 4 the route-level checks now pass (top `animation` < 1; `userGestureInProgress` true on iOS). The failing line is the sibling check `offsetOf('s0').dy > parted0.dy`.
- Cause: a calibration error in the repro, not the fix. Those tests use flat timing, whose exit slice is `Interval(0.0, 0.35)` of `S`. Android progress 0.5 gives `S` = 0.5, and the 3 x 100 px iOS drag gives `S` of about 0.63. Both are still fully covered, so the sibling cannot move yet. H's own control test uses progress 0.7 for this reason.
- With progress 0.7 (as in the control) and a 3 x 200 px drag, all 11 pass. **For H when un-skipping:** make those two changes in `interactive_back_test.dart`.

## Flutter internals relied on (3.32.7)
- `WidgetsBinding` dispatches `startBackGesture` to observers in registration order; the first that returns true owns the rest of the gesture. With no owner, `commitBackGesture` falls back to `handlePopRoute` (binding.dart ~935-975). `removeObserver` clears the owner.
- `TransitionRoute.handleStartBackGesture/Update/Commit/Cancel` (public, routes.dart ~563-640): set the controller value, `didStartUserGesture`, settle with `fastLinearToSlowEaseIn` and release the user-gesture flag when the settle ends. The Android path uses only these.
- `ModalRoute.popGestureEnabled` (public): false for the first route, `willHandlePopInternally`, `PopScope(canPop: false)` or a scoped will-pop callback, a route still animating, or a gesture already in progress. Both paths gate on it plus `isCurrent`.
- `TransitionRoute.controller` is `@protected`. The iOS path reads it with one `// ignore: invalid_use_of_protected_member`, exactly as `CupertinoRouteTransitionMixin._startPopGesture` does ("protected access"). It is needed to settle a released drag with Cupertino's 350 ms `fastEaseInToSlowEaseOut` and to handle a route that is no longer current at release.
- Cupertino constants reproduced: 20 px edge (or start-side safe-area padding), fling at 1 page width/s, 350 ms settle, release past half pops.
- `PredictiveBackEvent` comes from `package:flutter/services.dart` (not re-exported by material).

## Edge cases
Covered by test/route/cn_back_gesture_test.dart (32 tests, each for CnPageRoute and for MaterialPageRoute under the theme builder). Without the fix, 16 of them fail; the other 16 are refusal guards that pass either way.
- Android: the system channel scrubs `A` and `S` and an element on the page below; commit pops (status flips to reverse); cancel settles back monotonically; `PopScope(canPop: false)` refuses, and commit reaches the PopScope as a refused pop; a route that is not current (dialog above) does not claim, so the dialog gets the plain pop; the back-button form is not claimed; removing the route mid-gesture releases `userGestureInProgress`.
- iOS: an edge drag scrubs and follows the finger both ways; release past half pops, before half settles back; a cancelled pointer settles back; a drag away from the edge, a `fullscreenDialog` route, `PopScope(canPop: false)`, and an Android theme platform all get no swipe; RTL starts at the right edge; a route pushed above mid-drag settles this route back to 1; a programmatic pop mid-drag finishes cleanly.

Not covered:
- Nested navigators: as with the stock builder, the first registered observer whose route is current and `popGestureEnabled` wins the Android gesture. Usually that is the outer page, unless the outer page is the first route. This matches Flutter, not a per-navigator choice. On iOS the innermost page's edge strip should win, because it is first in hit-test order (as with Cupertino). Not tested.
- Android: a route pushed above mid-gesture leaves this route at the scrubbed value. The public route API ignores updates and settles when the route is not current. This is the same as Flutter's own `PredictiveBackPageTransitionsBuilder`.
- Real devices: Android 14+ needs `android:enableOnBackInvokedCallback="true"` for the system to send predictive-back events. Neither path was tried on a device.
- Theme platform drives the iOS strip (iOS and macOS, as in the default theme map). The Android observer is registered on every platform; the engine only sends the channel on Android.
- pubspec still says `flutter: ">=3.10.0"`, but this slice (and `delegatedTransition`, which predates it) needs much newer APIs. Out of scope (pubspec is not mine); flag for the release slice.

## Verification (2026-10-09)
- `flutter analyze` at the root: only the 5 existing example deprecation infos.
- `flutter test` at the root: 196 passed.
- H's `interactive_back_test.dart` and `support.dart` were copied into a scratch test/integration/ and run with `--dart-define=RUN_BUGS=true`. As-is: 7 passed, 4 failed (the calibration issue above). With progress 0.7 and 200 px steps: 11 of 11 passed. The scratch copies were deleted afterwards.
