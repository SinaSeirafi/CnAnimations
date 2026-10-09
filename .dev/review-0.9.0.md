# cn_animations 0.9.0: final review

Reviewer: Fable (read-only), 2026-10-09. Tree: `feat/v1-choreography` at fd993cf, Flutter 3.32.7 / Dart 3.8.1.

## Method and scope

Read: `.dev/STATUS.md`, `.dev/design-0.9.md` (owner decisions binding), all `.dev/notes/*.md`, every file under `lib/`, `README.md`, `CHANGELOG.md`, both pubspecs, `example/lib/**`, the test harnesses (`test/integration/support.dart`, `test/route/cn_back_gesture_test.dart`) and the Flutter 3.32.7 sources the route code depends on (`widgets/routes.dart`, `widgets/binding.dart`, `cupertino/route.dart`, `material/page.dart`, `material/page_transitions_theme.dart`, `material/predictive_back_page_transitions_builder.dart`). Version evidence comes from `git log -S` / `git tag --contains` in the Flutter SDK checkout.

Probes ran in a scratch copy of the package (`scratchpad/probe/test/zz_review_probe_test.dart`, not committed). Nothing in the worktree was modified; `git status` is clean apart from this file.

Confidence labels: **probe** = confirmed by running code; **reading** = confirmed by reading the code or the SDK source; **plausible** = reasoned, not demonstrated.

## Summary

| Severity | Count | Ids |
| --- | --- | --- |
| P0 (blocks release) | 0 | — |
| P1 (fix before 0.9.0) | 4 | R1 R2 R3 R4 |
| P2 (fix before 1.0.0) | 6 | R5 R6 R7 R8 R9 R10 |
| P3 (nice to have) | 10 | R11–R20 |

What holds (verified, no finding): progress-driven choreography with no `RouteObserver`; curve lock by the rest state last left (`CnDirectionalCurvedAnimation`), including the status-listener refinement for the Hero measuring frame; pointer subject detection on by default with a 700 ms window; geometry-bounded stagger with `f = 1` off-screen; reduced motion default `fadeOnly`, precedence widget > scope > default, and the basic widgets' external `controller:` / `animation:` never overridden; `enterOffset` default `Offset(0, 0.1)` and `exitOffset` default `-enterOffset`; every deprecation message ends in "removed in 1.0.0"; the migration table maps every `CnRouteAwareAnimation` parameter; the back-gesture wiring (C2) is correct for the cases it claims, the user-gesture flag is released after a settle and a second swipe works (probe E); the publish archive excludes `.dev/` and `build/` (dry run in the worktree).

## Findings

### R1 (P1, reading) pubspec SDK constraints are far below what the code needs

- `pubspec.yaml:7-8`: `sdk: '>=3.0.0 <4.0.0'`, `flutter: ">=3.10.0"`; `CHANGELOG.md` 0.9.0 has no SDK line (0.1.0 said "Requires Dart 3 and Flutter 3.10 or newer").
- Evidence from the Flutter SDK history:
  - `lib/src/route/cn_fade_through_page_transitions_builder.dart:43-53` overrides `PageTransitionsBuilder.transitionDuration`, `reverseTransitionDuration` and `delegatedTransition`. `transitionDuration` / `reverseTransitionDuration` on `PageTransitionsBuilder`, and `MaterialRouteTransitionMixin` reading them, landed in flutter/flutter#158881 (2024-12-06), first stable tag **3.29.0**. On 3.27 the overrides compile only as `override_on_non_overriding_member` warnings and a `MaterialPageRoute` under the theme would run the fade-through at 300 ms, not the documented 400 ms.
  - `DelegatedTransitionBuilder` / `delegatedTransition` (load-bearing per design §3.7): flutter/flutter#150031, first stable **3.27.0**.
  - `PredictiveBackRoute`, `TransitionRoute.handleStartBackGesture` family and `WidgetsBindingObserver.handleStartBackGesture` (`cn_back_gesture_detector.dart:101-127`): flutter/flutter#141373, first stable **3.22.0**.
  - `packages/flutter/pubspec.yaml` at tag 3.29.0 declares `sdk: ^3.7.0-0`, so Flutter 3.29 ships Dart 3.7.
- Fix: `environment: sdk: ^3.7.0` and `flutter: ">=3.29.0"`; add "Requires Flutter 3.29 / Dart 3.7 or newer" to the 0.9.0 CHANGELOG entry and mirror it in `example/pubspec.yaml`. Note `flutter_lints: ^6.0.0` needs Dart ^3.8 (its own pubspec), which only affects `pub get` for contributors on 3.29; either accept or use `^5.0.0`.

### R2 (P1, probe) README and CHANGELOG say a scope `progress:` is never overridden by reduced motion; it is

- `README.md` "Reduced motion": "An external `controller:` or `animation:` (on the basic widgets, or `progress:` on the scope) belongs to your app and is never overridden by reduced motion." `CHANGELOG.md` 0.9.0, `CnRouteChoreography` bullet: "An external `controller:` or `animation:` is never overridden" (the scope has no such parameters; the sentence belongs to the basic widgets).
- Code: `lib/src/choreography/cn_route_animation.dart:282-286` resolves `_reducedMode` from the scope and the widget only; `_offset()` at `:722-723` returns `Offset.zero` under `fadeOnly` and `_scale()` at `:750-751` returns `1.0`, whatever the source. Nothing checks whether the primary source is `scope.progress`.
- Probe A: `CnRouteChoreography(progress: controller)` under `MediaQuery(disableAnimations: true)`, controller at 0.5: element opacity 0.567 (follows progress) but `SlideTransition` dy = 0.0 where the unreduced value would be 0.0433. Translation is dropped, so the claim is false.
- The owner decision covers "an external `controller:` or `animation:`" on the basic widgets. Whether `progress:` / `coverProgress:` on the scope should count as app-owned is a product decision. Fix one of: (a) docs: delete "or `progress:` on the scope" from the README and move the CHANGELOG sentence to the `animation:` bullet; or (b) code: treat elements whose primary source is a scope `progress` as not reduced (one condition in `_reducedMode`), add a test, keep the docs. (a) is the smaller change for 0.9.0.

### R3 (P1, probe) The example's "Open transparent overlay" button demonstrates something that does not happen

- `example/lib/pages/detail_page.dart:81-83`: "A transparent overlay built from a plain PageRouteBuilder does cover this page, so its elements exit. A CnPageRoute (see Replace) does not need this workaround." The detail page is pushed with `MaterialPageRoute` (`detail_page.dart:25-28`) under the fade-through theme.
- Flutter 3.32.7 `material/page.dart:162-180`: `MaterialRouteTransitionMixin.canTransitionTo` returns true only for a `MaterialRouteTransitionMixin` next route or one with a non-null `delegatedTransition`. A bare `PageRouteBuilder` has neither, so the Material page's `secondaryAnimation` stays dismissed. The same is true for a `CnPageRoute` page (`cn_page_route.dart:62-63`, `opaque` check).
- Probe C: `PageRouteBuilder(opaque: false)` over a `MaterialPageRoute` page under the theme: `secondaryAnimation` 0.0 and element opacity 1.0 at 200 ms; over a `CnPageRoute` page: 0.0. `test/integration/overlays_test.dart` already pins this (slice H).
- Fix: either remove the button, or keep it as a counter-demo with a correct comment ("does not cover: neither a theme-installed Material page nor a CnPageRoute lets a plain PageRouteBuilder drive its exits; only a page that is itself a plain PageRouteBuilder would"). Check `example/test/smoke_test.dart` does not assert the old claim (it does not today).

### R4 (P1, reading) The example cannot show Android predictive back: the manifest lacks `enableOnBackInvokedCallback`

- `example/android/app/src/main/AndroidManifest.xml` has no `android:enableOnBackInvokedCallback="true"` on `<application>` (grep count 0). On Android 13+ the system sends the `flutter/backgesture` start/update/commit/cancel messages only when that flag is set; without it the engine falls back to the legacy back button, so the C2 observer (`cn_back_gesture_detector.dart:101-127`) is never called and the owner's device check (STATUS step 7) would wrongly conclude the feature is broken. Slice C2's notes record the requirement; the example was written before C2 and never updated.
- Fix: add the attribute to the example manifest; add one sentence to the README "Routes" section ("Android predictive back needs `android:enableOnBackInvokedCallback="true"` in your manifest, as for Flutter's own predictive-back transition").
- Related release gate (not a code finding): no path has been tried on a device. README, CHANGELOG and the dartdoc of both route classes state swipe-back and predictive back as fact. Keep step 7 before `pub publish`.

### R5 (P2, reading) `meta` is a declared dependency but nothing imports it

- `pubspec.yaml:13`: `meta: ^1.9.0`; CHANGELOG 0.9.0 "Dependencies: Added `meta`." `grep -rn "package:meta\|@internal" lib` finds nothing (slice F added it for `@internal`, which was never applied).
- Fix: remove the dependency and the CHANGELOG line, or apply `@internal` to the package-internal public types in `lib/src/progress/route_progress.dart`, `lib/src/choreography/geometry.dart` and `CnRouteSubjectTarget` / the `kCn*` constants in `cn_route_choreography.dart` (then the dependency is justified and pub.dev's API docs hide them).

### R6 (P2, probe) On pop and during interactive back there is a window where neither page's elements are visible

- Push is continuous: the page below's elements exit over A ∈ [0, 0.35 + f·0.12] while the incoming page fades in from A = 0.3 (`cn_fade_through_page_transitions_builder.dart:35`) and its elements enter from 0.35. Pop is not: the top page's fade-out window is `Interval(0.6, 1.0)` (`:38`), its elements exit over A ∈ [0.65, 1], but the page below's elements only start returning when S < 0.35 + f·0.12 (`cn_route_animation.dart:641`, `_coverSlice` applied as-is to S; `covered` is already 1.0 at S = 0.35 with the `easeIn` interval).
- Probe B (both installs, flat timing, `handleUpdateBackGestureProgress`): at A = S = 0.6, 0.55, 0.5, 0.47, 0.4 the top element's opacity is 0.000 and the element below's opacity is 0.000; the element below reappears only at 0.3 (0.224). So for a quarter of a pop (A ∈ [0.35, 0.6], ~100 ms of 400) and for a quarter of a back-gesture's travel, the user sees only unwrapped chrome (Scaffold, AppBar). Design §3.7 anticipated a gap of 0.47–0.6 ("after the top page has faded") but the real gap is wider because the exit slice ends at 0.35, not 0.47, for the nearest elements.
- This is a feel issue the device check will show (STATUS step 7). Fix options, in order of cost: (a) start the uncover earlier by giving `CnRouteTiming` a separate `uncover` slice (default `Interval(0.25, 0.6)` so the return overlaps the top page's fade), applied in `_Slot.cover` when S is falling; (b) narrow the page fade-out to `Interval(0.4, 1.0)`; (c) accept and document. (a) is additive on a value type and does not break signatures, but changing the default later is a visual change, so decide before 1.0.0.

### R7 (P2, probe + reading) Design text to correct: `PageRouteBuilder(opaque: false)` does not cover a `MaterialPageRoute` page

- `.dev/design-0.9.md` §4 row "`PageRouteBuilder(opaque: false)` over this page | 0→1 (probe B) unless this page is a `CnPageRoute`", §5 first bullet ("`canTransitionTo` only checks `is PageRoute`, so the page below animates"), §8 "Counter-tests: `PageRouteBuilder(opaque: false)` over a `MaterialPageRoute` page *does* cover (documented behavior)", and the verification ledger ("`PageRouteBuilder(opaque: false)` does").
- Flutter 3.32.7 `material/page.dart:162-180`: the Material mixin overrides `PageRoute.canTransitionTo`; the plain `is PageRoute` rule (`widgets/pages.dart:56`) applies only to routes that do not mix in Material or Cupertino, i.e. a `PageRouteBuilder` page. Probe C and `test/integration/overlays_test.dart` confirm. The README already states the real behaviour; the design does not.
- Fix: in the design, change the §4 row to "0→1 only when this page is itself a plain `PageRouteBuilder`; stays 0 under `MaterialPageRoute` (theme or not) and `CnPageRoute`", rewrite the §5 bullet and §8 counter-test accordingly, and fix the ledger line. Also fix the example comment (R3).

### R8 (P2, reading) `timing` on `CnFadeThroughPageTransitionsBuilder` and `CnPageRoute` does nothing

- `cn_fade_through_page_transitions_builder.dart:29-32` and `cn_page_route.dart:40-41`: "Reserved for API parity ... the page transition itself keeps its fixed fade-through intervals and 400 ms duration." The field is never read. CHANGELOG says the same.
- A no-op constructor parameter on two public `const` classes becomes a permanent commitment at 1.0.0 (removing it is breaking; making it do something later changes behaviour for callers who passed it). Fix before 1.0.0: either delete it (1.0.0 is a breaking release anyway) or make it real, e.g. derive the page fade-in start from `timing.exit.end` and the fade-out window from the uncover slice (ties in with R6).

### R9 (P2, reading) `CnRouteTiming.exit` / `enter` are `Interval`s whose `curve` is silently ignored

- `cn_route_choreography.dart:35-37` take `Interval`s; `geometry.dart:92-112` rebuild the slices with `timing.exitCurve` / `enterCurve` and drop `exit.curve` / `enter.curve`. Documented in README, CHANGELOG and dartdoc, but the type invites the mistake (`CnRouteTiming(exit: Interval(0, 0.35, curve: Curves.easeOut))` compiles and does nothing).
- Fix before 1.0.0 (hard to change after): `assert(exit.curve == Curves.linear && enter.curve == Curves.linear, 'Set exitCurve / enterCurve instead')` in the constructor, or replace the two fields with plain `(double begin, double end)` pairs / `exitBegin`, `exitEnd`, `enterBegin` doubles. The assert is non-breaking and can ship in 0.9.0.

### R10 (P2, reading) `subject` means two different things on two public types

- `CnPartingSpec.subject` is a `CnSubjectBehavior` (`cn_route_choreography.dart:165,182`); `CnRouteAnimation.subject` is a `bool?` meaning "force / forbid being the subject" (`cn_route_animation.dart:196`). `CnPartingSpec(subject: ...)` reads as "which element is the subject".
- Fix before 1.0.0: rename `CnPartingSpec.subject` to `subjectBehavior` (and the `CnSubjectBehavior` enum is already named for it). Cheap now, breaking later.

### R11 (P3, reading) The iOS swipe reads `TransitionRoute.controller`, a `@protected` member

- `cn_back_gesture_detector.dart:207-216`: `_EdgeSwipe` takes `route.controller!` under `// ignore: invalid_use_of_protected_member`, exactly as Flutter's own `CupertinoRouteTransitionMixin._startPopGesture` does. The settle it needs (350 ms `fastEaseInToSlowEaseOut`, `cupertino/route.dart:35`) matches Cupertino on 3.32.7 (probe E: ~360 ms), and the "not current at release" branch mirrors `_CupertinoBackGestureController.dragEnd`.
- Risk: a package depends on a protected framework member the framework may rename; the analyzer only warns. Alternative for 1.0.0: drive the drag through the public `PredictiveBackRoute` methods (`handleStartBackGesture` / `handleUpdateBackGestureProgress`, then `handleCommitBackGesture` or `handleCancelBackGesture` after the detector decides by velocity and position). `TransitionRoute._handleDragEnd` (`widgets/routes.dart:595-640`) already handles "not current", pops, settles and releases the user-gesture flag; the only loss is Cupertino's settle timing (Flutter uses `fastLinearToSlowEaseIn`, ≤300 ms / ≤800 ms there). Decide once the device check has shown which feel is wanted.

### R12 (P3, reading) The 700 ms window is defined twice

- `cn_route_choreography.dart:21` `kCnPointerSubjectWindow` (used by `_resolveSubject`, `cn_route_animation.dart:440`) and `route_progress.dart:134` `CnRouteRecord.pointerWindow` (default of `pointerSubject`). Both 700 ms today; two places to change. Keep one (the record's, and pass nothing from the element) or make the element pass the scope's value and expose it as `CnRouteChoreography.subjectWindow` if it is meant to be configurable.

### R13 (P3, reading) `CnSubjectBehavior.grow` is a hard-coded 1.04

- `cn_route_animation.dart:757-760`: `scale *= 1.0 + 0.04 * _covered`. Not configurable, not documented as a number. Add `CnPartingSpec.growScale` (default 1.04) before 1.0.0 or document the constant on the enum value.

### R14 (P3, reading) `CnPageRoute` lacks `MaterialPageRoute` parity and there is no `Page` form

- `cn_page_route.dart:19-29` takes `builder`, `settings`, `fullscreenDialog`, `maintainState`, `backgroundColor`, `timing`. `MaterialPageRoute` also takes `allowSnapshotting`, `barrierDismissible`, `requestFocus`, `traversalEdgeBehavior` and `directionalTraversalEdgeBehavior`. There is no `CnPage` for `Navigator.pages` / `go_router`'s page API; such users must use the theme builder (fine, but undocumented as the recommended path). Adding parameters and a `CnPage` later is non-breaking; mention the theme route as the Navigator 2.0 path in the README now.

### R15 (P3, reading) README theme snippet installs the builder for Android and iOS only

- `README.md` "Getting started" and "Routes": `builders: {TargetPlatform.android: ..., TargetPlatform.iOS: ...}`. On macOS, Linux, Windows and web the theme falls back to Flutter's defaults (Cupertino on macOS, Zoom elsewhere), where the README itself says exits are "mostly invisible". The example installs it for every platform (`example/lib/main.dart:42-45`). Use the `for (final platform in TargetPlatform.values)` form in the README, or say why the two-platform form is shown.

### R16 (P3, probe) The generic-type quirk also applies to `CupertinoPageRoute<T>` pages and `CnPageRoute` does not fix that case

- CHANGELOG 0.9.0 "Route types" and README mention `MaterialPageRoute<int>` only and say `CnPageRoute` "does not have this quirk". `cupertino/route.dart:166-178` has the same `nextRoute is ModalRoute<T>` test and `CnPageRoute` mixes in the Material mixin only. Probe D: `CupertinoPageRoute<int>` below `CnPageRoute<void>` keeps `secondaryAnimation` at 0.0 (no exits); `CupertinoPageRoute<void>` below it reaches 1.0. Design §5 asked for a README note on this; it is missing. Add one sentence: "the same applies to `CupertinoPageRoute<T>`; give the routes matching type arguments or use the theme builder".

### R17 (P3, reading) Example pubspec hygiene

- `example/pubspec.yaml`: `cupertino_icons` is declared but unused (`grep CupertinoIcons example/lib` finds nothing); `sdk: '>=3.0.0 <4.0.0'` (see R1); the file is still the unedited template with its comment blocks. Trim before publishing, since `example/` ships in the archive (confirmed by the dry run).

### R18 (P3, reading) `CnPageRoute.debugLabel` prints "(null)" for unnamed routes

- `cn_page_route.dart:81`: `'${super.debugLabel}(${settings.name})'`. Most pushes are unnamed, so debug output reads `CnPageRoute<void>(null)`. Append the name only when non-null.

### R19 (P3, reading) Two small lifecycle costs in the subject path

- `route_progress.dart:142-148`: every pointer-down on any `CnRouteAnimation` calls `SchedulerBinding.scheduleFrameCallback`, which schedules a frame; a tap on an idle page costs one extra frame. Harmless, but `PointerDownEvent.timeStamp` or a post-frame read when a frame is already scheduled would avoid it.
- `route_progress.dart:173-184`: `select(context)` stores the `BuildContext` in the route record until the next cover segment takes it. If no push follows (user cancels), the record holds that element (and its subtree, if later unmounted) until the next cover on that page. `takeSelection` checks `mounted`, so it is only retention, not misuse. Clearing it in the element's `dispose` would close it.

### R20 (P3, reading) The two installs do not cover under the same routes

- `CnPageRoute.canTransitionTo` (`cn_page_route.dart:62-63`): any opaque, non-fullscreen `PageRoute`, so a plain `PageRouteBuilder(opaque: true)` pulls a `CnPageRoute` page's elements out. A `MaterialPageRoute` page under the theme uses the Material rule (`material/page.dart:162-180`): Material routes or routes with a delegated transition only, so the same `PageRouteBuilder` does not. `test/integration/overlays_test.dart` pins both. Not a bug; document the difference in one README line under "Routes" so an app mixing custom `PageRouteBuilder`s knows which install to pick.

## Dimension notes without findings

- **Design vs code.** Checked the §4 table rows against `cn_route_animation.dart` and the H tests: push, pop, cover, uncover (exit slice reversed, per §3.7 rather than B's original `enter` doc, now fixed), dialogs and sheets, `pushReplacement` (train-hop verified by H), `popUntil`, zero-duration, initial vs late mounts, scroll reveal, `enabled: false`, reduced motion both modes. Subject priority `select()` > `subject: true` > pointer, with `subject: false` skipped, is a reasonable refinement of §3.5. Nested elements take the subject role (D deviation 4) is sensible and documented in the notes only; worth one dartdoc sentence on `CnRouteAnimation.subject`.
- **Back-gesture lifecycle** (`cn_back_gesture_detector.dart`). Observer added in `initState`, removed in `dispose` (which also clears the binding's gesture owner, `widgets/binding.dart:793-794`); the recognizer is disposed; a mid-gesture dispose releases the navigator's user-gesture flag post-frame, as Cupertino does. `_gestureAllowed` = `isCurrent && popGestureEnabled` covers `PopScope(canPop: false)`, `willHandlePopInternally`, first route, animating route and a gesture already in progress (`widgets/routes.dart:1841-1870`). `fullscreenDialog` disables the iOS strip only, as in Cupertino. `buildTransitions` rebuilds every frame but the detector's `State` persists (same widget type, no key), so no re-registration. Nested navigators: the first registered current-and-enabled observer wins on Android (outer page unless it is the first route), the innermost strip wins on iOS by hit-test order; both match Flutter's own builders and are documented in C2's notes but not in dartdoc.
- **Leaks.** H's allocation counts return to baseline per cycle; no `AnimationController` in the route-driven path; `CnDirectionalCurvedAnimation` attaches its parent status listener only while it has listeners and `_unbind` removes them; the `Expando` record holds no reference to its key.
- **Docs vs behaviour, other claims checked true:** 400 ms both ways; `fallbackDuration` 300 ms; stagger 0.12 / 0.25; pointer window 700 ms; "A plain `PageRouteBuilder` over a `MaterialPageRoute` never drives the lower page's exits"; "Dialogs, bottom sheets, full-screen dialogs and non-opaque routes do not cover the page"; migration steps 1–5; the README "before/after" snippet keeps the old directions.
- **Release hygiene, other:** `flutter pub publish --dry-run` in the worktree: 0 warnings, 1 expected hint; archive contains `example/`, `lib/`, `test/`, both GIFs, no `.dev/` or `build/`. Description length is within pub's range. Version 0.9.0 and the CHANGELOG entry agree.

## Next-step suggestions

1. **Fix round order for 0.9.0:** R1, R4, R3, R2 (owner picks docs or code), R5, R9's assert. All are small and none touches the choreography maths.
2. **Device check (STATUS step 7) before publishing**, with R4 applied, on Android 14+ and iOS. Watch for R6 (the blank quarter on pop / back-gesture) and the exit direction; both are judgment calls the tests cannot make.
3. **Decide R6, R8, R10 before tagging 1.0.0.** They are the three things that are cheap now and expensive after a stable API.
4. **Slice R (1.0.0) checklist additions:** delete the no-op `timing` on the routes if R8 chooses deletion; rename `CnPartingSpec.subject`; consider deprecating `delayInMilliseconds` on the basic widgets in favour of `delay` (the owner's removal list does not include it, so it stays through 1.0.0 unless decided now); update the README migration section and the two snippet tests F2 flagged.
5. **After 1.0.0:** `CnPage` for `Navigator.pages` / `go_router`; a `CnRouteTiming.uncover` slice if R6 chooses (a); `@internal` on the package-internal types once `meta` is justified; a short "How it works" section in the README that explains rest-state curve locking and geometry-bounded stagger, which is also the seed of the concept document the owner has scheduled.
6. **Keep the test strategy:** the probes in `.dev/probes/` and the H harness (`test/integration/support.dart`) are the fastest way to answer the next behaviour question; new claims in README should keep getting a line in `test/readme_snippets_test.dart`.
