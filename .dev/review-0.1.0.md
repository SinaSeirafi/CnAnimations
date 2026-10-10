# Review: cn_animations 65182fb (0.1.0)

Scope: `git show 65182fb` (base 0f3b9bd), full post-change `lib/` and `test/`. Probes ran on a copy in `scratchpad/review-probe/` (`test/probe_test.dart`). The worktree was not touched.

Lower bounds verified: `CurvedAnimation.dispose` exists since Flutter 2.5, and `MediaQuery.maybeDisableAnimationsOf` since 3.10.0, so `flutter: ">=3.10.0"` is correct.

## F1. New barrel export causes compile errors for apps that define their own `routeObserver` or `RouteAwareWidget` (med, CONFIRMED)

- **Where:** `lib/cn_animations.dart:7` (`export 'route_aware_widget.dart';`) together with `lib/route_aware_widget.dart:6`, the deprecated top-level `routeObserver`.
- **Defect:** `package:cn_animations/cn_animations.dart` now exports two very common names: a top-level `routeObserver` and the class `RouteAwareWidget`. These are also the exact names used in Flutter's own `RouteObserver` API docs example. An app that declares either name in another library and imports both libraries gets an `ambiguous_import` compile error.
- **Scenario:** `routes.dart` declares `final routeObserver = RouteObserver<ModalRoute<void>>();`, and `main.dart` imports both `routes.dart` and `cn_animations.dart`. The upgrade from 0.0.3 then fails to compile. In the probe, `dart analyze` reported: "The name 'routeObserver' is defined in the libraries 'package:cn_animations/route_aware_widget.dart (via package:cn_animations/cn_animations.dart)' and ...user_routes.dart - ambiguous_import".
- **Why it matters:** this breaks the owner's non-breaking requirement, and the CHANGELOG lists the export only as an improvement.
- **Fix:** use `export 'route_aware_widget.dart' hide routeObserver;`, because the deprecated getter only needs to stay reachable through its old import path. Add a CHANGELOG note that `RouteAwareWidget` is now exported from the barrel and can collide with an app's own class of that name (fix with `hide` or `as`).

## F2. Under reduced motion, CnFade, CnSlide and CnScale ignore an external `controller` and always show the "final" value (high, CONFIRMED by probe P1)

- **Where:** `lib/cn_fade.dart:47-50`, `lib/cn_slide.dart:55-58`, `lib/cn_scale.dart:42-45`. Each `build` swaps in `AlwaysStoppedAnimation(_finalValue)` whenever `_reduceMotion` is true, without checking `widget.controller`.
- **Defect:** with an external controller, the app owns the widget's state: a show/hide toggle, a fade-out on dismiss, a staggered list. Under reduced motion, that state is thrown away and replaced by a constant `forward ? end : begin`.
- **Scenario:** an app hides a banner with `CnFade(controller: c)` and calls `c.reverse()` (or holds `c.value = 0`). With "Remove animations" on (Android accessibility, or animator scale 0 on dev and test emulators), the banner stays at opacity 1 and never hides. The reverse case also happens: an element the app meant to show stays at 0 when the configuration is `forward: false`. The probe set `c.value = 0` with `disableAnimations: true` and read FadeTransition opacity 1.0.
- **CHANGELOG gap:** the CHANGELOG says widgets "show their final state immediately", which reads as skipping the tween. It does not say that controller-driven state is overridden.
- **Fix:** when `widget.controller != null`, keep honoring the controller's value and only snap the internal controller. If snapping is still wanted, snap to the controller's target (for example, its `status` / `value` when it settles), not a fixed end. At minimum, document this and add a test that pins the chosen behavior.

## F3. Turning reduced motion on or off at runtime remounts the CnRouteAwareAnimation child and replays the push animation (med, CONFIRMED by probe P2)

- **Where:** `lib/cn_route_aware_animation.dart:114-122`. When reduced motion is on, `build` returns `widget.child` directly. Otherwise it returns `RouteAwareWidget > ValueListenableBuilder > CnFade > CnSlide > child`.
- **Defect:** a change to `MediaQuery.disableAnimations` changes the tree shape, so:
  - every element under the child is thrown away and rebuilt, and its state is lost;
  - in the reduced-motion-off direction, the new `RouteAwareWidget` subscribes, gets `didPush`, and fades and slides the content in again from opacity 0.
- **Scenario:** a user opens system settings, toggles "Remove animations", and returns. Every screen built with CnRouteAwareAnimation loses the state in its child: TextField contents, scroll offsets, expanded tiles. Covered pages below the top route also replay their push animation while hidden. The probe found:
  - a `_Counter` State inside the child was a new instance after each toggle (n reset from 5 to 0);
  - opacity was 0.0 right after reduced motion was turned off.
- **Background:** `animate` already had the same tree-shape problem in 0.0.x. This commit adds a new, user-driven trigger that the app does not control, and nothing tests it.
- **Fix:** keep one tree shape in both modes. Always build the `RouteAwareWidget` and transitions, and under reduced motion jump the controllers to their end values instead of animating, or skip transitions with `AlwaysStoppedAnimation`. Any snap target must follow the controller direction: for "next" values after `popNext`, the fixed `forward ? fadeEnd : fadeStart` gives opacity 0. Add a toggle test that checks child State identity.

## F4. `showPushNext: true` with `showPopNext: false` leaves the child invisible after returning to the page (med, CONFIRMED by probe P3; already present in 0.0.3)

- **Where:** `lib/cn_route_aware_animation.dart:139-150`. `onPushNext` animates to the "next" end state, which is opacity `fadeStartSamePage` (0 by default). `onPopNext` does nothing when `showPopNext` is false.
- **Defect:** no event ever brings the page back from the faded-out, slid-off state.
- **Scenario:** a developer wants an exit flourish but no re-entry animation, so they set `CnRouteAwareAnimation(showPopNext: false, ...)`. They push a page, then pop it. The original page's content stays at opacity 0 permanently. The probe read opacity 0.0 after push and pop with `showPopNext: false`.
- **Why it belongs in this review:** this is exactly the "child left invisible with no animation coming" class that the commit sets out to close (compare the `_controllersShown` fix for `showPush: false`). It was missed here and has no test. The same asymmetry applies to `showPop` vs `showPush` only for the leaving page, which is harmless.
- **Fix:** in `onPopNext`, when `showPopNext` is false, call `_controllersShown()` (emit same values, controllers at 1) instead of doing nothing. Add the round-trip test.

## F5. Under reduced motion, CnRouteAwareAnimation ignores a custom "shown" state (`fadeEndSamePage`, `endSamePage`) (low, PLAUSIBLE from reading)

- **Where:** `lib/cn_route_aware_animation.dart:119-121` returns `widget.child` with no transform.
- **Defect:** the end state is set back to opacity 1 and offset 0. A widget configured to rest at, for example, `fadeEndSamePage: 0.6` or `endSamePage: Offset(0.2, 0)` shows differently when reduced motion is on.
- **Scenario:** a watermark or deliberately dimmed hint row built as `CnRouteAwareAnimation(fadeEndSamePage: 0.4)` renders fully opaque for reduced-motion users. The CHANGELOG says "final state", which this is not.
- **Fix:** under reduced motion, render the same-page end values statically (Opacity / FractionalTranslation, or `AlwaysStoppedAnimation`), keeping the tree shape from F3. Alternatively, document that reduced motion shows the child untransformed.

## F6. Two CHANGELOG fix statements claim more than the code does (low, PLAUSIBLE from reading)

- **Where:** `CHANGELOG.md`, the "Removing an external controller" and "`duration` changes" bullets. The code is `lib/cn_fade.dart:79-87` (and the matching lines in `cn_slide.dart` / `cn_scale.dart`).
- **Defect (a):** "The internal controller now plays, as on first build" is only true if the internal controller never ran. Take a widget mounted with `controller: null`, switched to an external controller, then back to null. Its internal controller already sits at 1, so `forward()` is a no-op and the widget jumps to the end with no animation.
- **Defect (b):** "`duration` changes after the first build are applied" is only true for runs that have not started yet. `AnimationController` fixes the simulation's duration when `forward()` / `reverse()` starts (`animation_controller.dart:654-689`), so a change during a running animation does nothing until the next run. Both tests change the duration before the start.
- **Scenario:** a user changes `duration` while a fade is running, expects the change to take effect from the CHANGELOG wording, and sees no change.
- **Fix:** reword both bullets, for example "the internal controller plays if it has not already completed" and "applied to the next run". The code needs no change.

## F7. Test suite: one vacuous assertion, plus missing tests for the riskiest new paths (low)

- **What holds up:** I spot-checked the tests by reading them against the 0.0.3 code. Each of these asserts something the old code gets wrong, so the 28/31 claim is credible:
  - bug 1 (`showPush: false`, opacity 0 on old code);
  - bug 2 dialog and bottom sheet;
  - bug 3 (the single-subscription StreamBuilder remount throws);
  - bug 5 (the internal controller was never started);
  - bug 6 (the 2 s duration stays);
  - bug 8 dispose (a `Future.delayed` timer is left pending);
  - the `intervalBegin` test.
- **(a) Vacuous assertion:** `test/basic_animations_test.dart:206`, `expect(tester.binding.hasScheduledFrame, isFalse)` right after `pumpWidget`. It runs before CnFade's 10 ms delay timer fires, so it would pass even if reduced motion still started the ticker. The opacity line in the same test and the later "does not tick after the delay" test carry the claim. Fix: remove the line, or move it after `pump(20ms)`.
- **(b) Untested paths:**
  - **Route-change resubscribe in `RouteAwareWidget` (`lib/route_aware_widget.dart:84-97`).** The implementer flagged it as untested. My probe P5 reparented a `GlobalKey`ed RouteAwareWidget from route A to route B in one frame: `onPush` fired a second time, there was no exception, and a later push on top of B delivered exactly one `pushNext`. So it works, but nothing pins it. Recommend adding P5 as a test.
  - **Reduced motion with an external controller (F2), runtime reduced-motion toggle (F3), and `showPopNext: false` round trip (F4).** All three have no tests.
  - **The `showPush: false` + pushNext/popNext round trip.** Only one direction is covered, by the bug 6 test.
- **Other probes, no defect:**
  - **Hot reload (P4).** `reassembleApplication` caused no replay and no scheduled frame; opacity stayed 1.0.
  - **Runtime reduced-motion toggle while a page is covered (P6).** The page ended visible.
  - **Basic widgets toggled into reduced motion mid-animation.** From reading, this is safe: the build shows the final value and the internal controller finishes unseen.

## Checked, no finding

- **ValueNotifier in CnRouteAwareAnimation.** The update happens during `RouteAwareWidget.didChangeDependencies`, and the listener (`ValueListenableBuilder`) sits below the build target, so `markNeedsBuild` is legal. `_AnimationValues.==` prevents redundant notifications. The notifier is disposed after the timers are cancelled.
- **Timers.** Each navigation event cancels the previous `_fadeTimer` / `_slideTimer`. `dispose` cancels them, and callbacks check `mounted`.
- **CurvedAnimation swaps.** The old CurvedAnimation is disposed before rebuild. The `FadeTransition` listener is forwarded to the parent controller and moves over in `AnimatedWidget.didUpdateWidget`, so nothing is left dangling.
- **Non-PageRoute path.** It fires `didPush` once per route. A `null` route (outside any Navigator) is also treated as pushed, which is an improvement over the old `!` + catch.
- **Environment bounds.** `flutter >=3.10.0` is correct for the APIs used.

## Summary

| Severity | Count | Findings |
| --- | --- | --- |
| High | 1 | F2 |
| Med | 3 | F1, F3, F4 |
| Low | 3 | F5, F6, F7 |
