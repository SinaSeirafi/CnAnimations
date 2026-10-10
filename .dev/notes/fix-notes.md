# cn_animations fix notes

## Step 1 - orientation (done)
- Worktree clean on fix/route-aware-regressions @ 0f3b9bd.
- Main checkout has 3 modified files: README.md, example/lib/main.dart, lib/route_aware_widget.dart (owner WIP: static RouteAwareWidget.routeObserver). Read-only diff inspected; not touched.
- Read all lib/, example/lib/, README, CHANGELOG, pubspecs.

## Step 2 - design decisions
- Bug 3 (StreamController): plain `setState` is NOT safe here. `onPush` fires from
  RouteAwareWidget.didChangeDependencies while CnRouteAwareAnimation is the current build
  target, after ComponentElement.performRebuild cleared its dirty flag. setState then
  re-dirties it and `Element.rebuild`'s `assert(!_dirty)` fails. Happens for real when
  values are "next" (after any push/pop round trip) and `animate` is toggled off/on.
  Decision: hold `_AnimationValues` in a state-owned `ValueNotifier` read by a
  `ValueListenableBuilder` below RouteAwareWidget (listener sits below the build target,
  so notifying during build is legal; on a fresh mount the builder reads the value
  later). Deviation from the brief's literal "setState"; reason recorded here.
- Bug 5: external -> null starts internal controller exactly like initState (delay timer,
  then forward). If the internal controller already completed earlier, forward is a no-op.
- Reduced motion: basic widgets render AlwaysStoppedAnimation(final tween value) in build
  (covers external controllers too); internal timer jumps controller to 1 instead of
  forward. CnRouteAwareAnimation returns child as-is (fully shown), same path as animate:false.
- pubspec flutter lower bound must rise to >=3.10.0 (MediaQuery.maybeDisableAnimationsOf).

## Step 3 - lib edits
- route_aware_widget.dart: static RouteAwareWidget.routeObserver + deprecated top-level getter
  (same instance); VoidCallback?; PageRoute subscribe / else didPush once per route; route
  change -> unsubscribe + resubscribe; no try/catch.
- cn_fade/cn_slide/cn_scale: Timer delay (cancelled in dispose), CurvedAnimation disposed on
  replace + dispose, duration synced in didUpdateWidget, external->null restarts internal,
  reduced motion, curly braces, explicit return types. CnScale always forward().
  CnSlide Interval(intervalBegin, intervalEnd). CnFade durationInMilliseconds honored + deprecated.
- cn_route_aware_animation.dart: ValueNotifier values, cancellable Timers (cancel on each event
  + dispose), initial controller value 1 when showPush false, onPush-not-played -> shown,
  durations synced, reduced motion returns child.
- Export route_aware_widget.dart; `library;`; super.key everywhere (lint use_super_parameters
  under flutter_lints 6; source-compatible).
- pubspec 0.1.0, sdk >=3.0.0 <4.0.0, flutter >=3.10.0, flutter_lints ^6.0.0 (resolves on
  Dart 3.8.1), description 126 chars, template comments stripped. Example sdk + lints bumped
  (example/pubspec.lock regenerated).
- flutter analyze clean at root and example after edits.

## Step 4 - basic tests pass (19/19 in test/basic_animations_test.dart)
- pump() without a duration does not fire Timer(Duration.zero) under fake async; tests pump 1ms.

## Mid-task owner decision (coordinator message)
- Reduced motion must be configurable: per-widget `bool respectReducedMotion = true` on CnFade,
  CnSlide, CnScale, CnRouteAwareAnimation. false = animate regardless. No global config widget
  (next version's design pass). Test each value. Mention in CHANGELOG.
- CnRouteAwareAnimation forwards its value to the inner CnFade/CnSlide so opt-out reaches them.

## Step 5 - tests on fixed code: 31/31 pass (root)
- Gotcha: route used to trigger pushNext must be non-opaque (or have a transition); an opaque
  zero-duration route puts the page below offstage, where TickerMode mutes its controllers.
- Next: verify each test fails on original lib (copy in scratchpad + compile-only shim).

## Step 6 - fail-on-original verification
- Method: copy of the package in scratchpad/orig-check with lib/ restored from 0f3b9bd plus a
  compile-only shim (export route_aware_widget.dart; static RouteAwareWidget.routeObserver getter
  returning the old top-level instance; an unused `respectReducedMotion` field/param on the four
  widgets). No behavior changes in the shim.
- Result: 28 of 31 root tests fail on the original; all 31 pass on the fix.
- The 3 that pass on the original, by design: deprecated-getter identity (API guard), and the two
  `respectReducedMotion: false` opt-out tests (original never honored reduced motion, so
  "animates anyway" is its normal behavior; these pin the new opt-out, not a bug).
- The bug-8 ordering test initially passed on the original: fake clock elapses a whole pump at
  once, so a stale forward() fired inside the pump never ticked. Fixed by stepping through t=200
  (pump 110ms, then 30ms). Original now shows opacity 0.81 at t=240; fix keeps 1.0.

## Step 7 - example test (example/test/home_page_test.dart)
- 2 tests pass on the fix. Launch test fails on the original (opacity 0.0). Round-trip test
  passes on the original too (popNext reverses to visible) - it is a guard, not a bug pin.
- Used a 800x1200 test surface; example layout left unchanged (no SingleChildScrollView).

## Step 8 - docs + commit (done)
- CHANGELOG: 0.1.0 entry (fixes, improvements incl. respectReducedMotion, deprecations);
  0.0.2 line "Updating README and GIFs" inferred from commits 96feb2a/4ce767f/de4a544.
- README: template comment removed, GIFs -> raw.githubusercontent.com (filenames stay encoded),
  setup snippet uses import + RouteAwareWidget.routeObserver. Owner's other WIP README change
  (moving "Requires setup." above the GIF) not adopted - not in brief.
- Commit 65182fb on fix/route-aware-regressions. Final: analyze clean root + example;
  root 31/31, example 2/2. Main checkout still shows its 3 modified files. Nothing pushed.

## Not done / follow-ups
- Route-change resubscribe path in RouteAwareWidget has no test (needs GlobalKey reparenting
  across routes); implemented only.
- _AnimationValues is captured at event time (stale if beginSamePage etc. change later), same as
  before; not in scope.
- Example Column still overflows on small screens (test uses 800x1200 surface instead).

# Follow-up: review-0.1.0.md findings (coordinator decisions F1-F7)
## Step R1 - plan
- F2: basic widgets snap only the internal controller; external controller always rendered.
- F3+F5: CnRouteAwareAnimation keeps one tree; under reduced motion events jump controllers
  (forward->1, reverse->0). Inner CnFade/CnSlide no longer get respectReducedMotion (moot, F2).
- F1: export ... hide routeObserver; regression test = helper lib declaring its own routeObserver.
- F4: onPopNext with showPopNext false -> _controllersShown().
- F6 CHANGELOG rewording; F7 drop vacuous assert, add P5 resubscribe test.
## Step R2 - lib edits done
- F2 in cn_fade/slide/scale (`_snapToEnd` = internal controller && reduce motion), dartdoc.
- F3/F5/F4 in cn_route_aware_animation (one tree; `_reduceMotion` read in build; forward->1,
  reverse->0 jumps; showPopNext false -> _controllersShown; inner pass-through removed).
- F1 barrel `hide routeObserver`. (A perl multi-substitution mangled the RA file once; restored
  from HEAD with git checkout of my own committed file and redid with Edit.)
## Step R3 - tests
- Root 39/39 pass, example 2/2, analyze clean both. Vacuous hasScheduledFrame assert removed
  (the remaining one at line ~228 runs after the delay and is meaningful).
- New tests vs 65182fb lib (git stash push -- lib): FAIL on 65182fb: F2 external controller,
  F4 showPopNext:false round trip, RA reduced-motion default end state, fadeEndSamePage 0.4,
  pushNext/popNext snaps, runtime toggle keeps State, barrel_export_test (compile error).
- PASS on 65182fb (coverage guards the coordinator asked for; behavior already correct there):
  showPush:false round trip, RouteAwareWidget resubscribe (reviewer P5).
- Identity test now reads the deprecated getter via `package:cn_animations/route_aware_widget.dart`.
## Step R4 - commit (done)
- CHANGELOG: F1 collision note + barrel hides deprecated getter; F2/F3/F5 reduced-motion wording;
  F4 bullet; F6 rewording ("if it has not already completed", "applied to the next run").
- Commit 2b3ee71. Analyze clean root + example; root 39/39, example 2/2.
  Main checkout still shows its 3 modified files. Nothing pushed.
