# Review fix round (0.9.0), branch v1/review-fixes

From integration head 1112c62. Findings from `.dev/review-0.9.0.md`.

## Applied as suggested

- R1: `sdk: ^3.7.0`, `flutter: ">=3.29.0"` in both pubspecs; CHANGELOG line.
- R2: docs option (a) only. README drops "or `progress:` on the scope"; the CHANGELOG sentence moved to the `animation:` bullet. Reduced-motion code unchanged.
- R3: kept the overlay button as a counter-demo; label "Overlay (elements stay)", comment corrected.
- R4: `android:enableOnBackInvokedCallback="true"` on `<application>`; README sentence in "Routes".
- R5: `meta` removed with its CHANGELOG line; no `@internal`.
- R7: design §4 row, §5 bullet, §8 counter-test and ledger corrected; also §9's example line (R3) and the §2.1 / §3.5 mentions of `CnPartingSpec.subject` (R10).
- R10: `CnPartingSpec.subject` renamed `subjectBehavior` (lib, tests, README, example). CHANGELOG never named the field.
- R12: `CnRouteRecord.pointerWindow` removed; `pointerSubject` defaults to `kCnPointerSubjectWindow` (not exported, so it stays package-internal). `route_progress.dart` now imports it from `cn_route_choreography.dart`.
- R13: dartdoc on each `CnSubjectBehavior` value; `grow` states the fixed 1.04.
- R14, R15, R16, R20: README sentences in "Routes"; both theme snippets use the `TargetPlatform.values` form; `readme_snippets_test` checks every platform gets the builder. R16 also in the CHANGELOG "Route types" bullet and the `CnPageRoute` dartdoc.
- R17: `cupertino_icons` and the template comments removed from `example/pubspec.yaml`.
- R18: `debugLabel` appends `(name)` only when the name is non-null; test.
- R19: `CnRouteRecord.clearSelection(context)` called from the element's `dispose`; clears only when the stored context is that element's. Test (fails without the fix). `scheduleFrameCallback` left as is.

## Deviations

- R9: the assert is not in the `CnRouteTiming` constructor. That constructor is `const`, and a const constructor's assert cannot read `Interval.curve` (compile error at every `const CnRouteTiming(...)` / `const CnFadeThroughPageTransitionsBuilder()` use). It lives in `cnStaggeredExit` / `cnStaggeredEnter` (`geometry.dart`), the only place the slices are built, so it fires in debug as soon as an element uses the timing, not at construction. Same message ("Set exitCurve / enterCurve instead"). No existing code, test or README snippet passes a curved Interval to `CnRouteTiming` (the curved `exitSlice` / `enterSlice` constants in two tests are only expected values).
- R1 side effect: with language version 3.7, wildcard variables apply and `unnecessary_underscores` (flutter_lints 6) flagged 23 `__` / `___` parameters in tests and 2 in the example; renamed to `_`.
- R1: `flutter_lints: ^6.0.0` kept (dev dependency only; it needs Dart 3.8 for contributors' `pub get`, not for package users). `example/pubspec.lock` therefore still says `dart: ">=3.8.0"`.

## R1 evidence (re-checked in ~/flutter, git tags)

- `git show 3.27.0:packages/flutter/lib/src/material/page_transitions_theme.dart`: `PageTransitionsBuilder` has `delegatedTransition` but no `transitionDuration` / `reverseTransitionDuration`; `material/page.dart` at 3.27.0 hard-codes `transitionDuration => 300 ms`.
- At 3.29.0 (next stable after 3.27.x; there is no 3.28): `PageTransitionsBuilder.transitionDuration` (300 ms default) and `reverseTransitionDuration` exist, and `MaterialRouteTransitionMixin.transitionDuration` reads the theme builder's value.
- `packages/flutter/pubspec.yaml` at 3.29.0: `sdk: ^3.7.0-0`.
- Other APIs the lib uses exist at 3.29.0: `PredictiveBackEvent`, `TransitionRoute implements PredictiveBackRoute`, `popGestureEnabled`, `RenderAbstractViewport.maybeOf`, `MediaQuery.disableAnimationsOf`, `Curves.fastEaseInToSlowEaseOut`.
- Not done: running the package on an actual 3.29 SDK. Only 3.32.7 is installed.

## Verification (final tree)

Root and example `flutter analyze`: No issues found. Root `flutter test`: 280 pass (277 before + 3 new). Example `flutter test`: 7 pass. `flutter pub publish --dry-run`: see the final report.
