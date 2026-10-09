# cn_animations 0.9.0 / 1.0.0: status and next steps

Last updated: 2026-10-09, when the first working session stopped. This file is the single source of truth for where the work stands. Update it at every checkpoint.

## Where everything is

All work branches below (everything except `master`) were **pushed to origin on 2026-10-09 as a backup**, at the owner's request. `master` on origin is unchanged at 0.0.3. Nothing is published to pub.dev. Future pushes of new commits to these branches are fine as backups, but `master` must not be touched, and publishing needs the owner's go-ahead.

| Branch | Worktree | Head | State |
| --- | --- | --- | --- |
| `master` | `~/Development/CnPackages/cn_animations` | 0f3b9bd (0.0.3) | The owner's checkout. It has **uncommitted 2023 WIP in 3 files; do not touch it.** |
| `fix/route-aware-regressions` | `~/Development/CnPackages/cn_animations-fixes` | 2b3ee71 | 0.1.0: 8 bugs fixed plus the 7 review findings. Done and verified (39 + 2 tests). |
| `feat/v1-choreography` | `~/Development/CnPackages/cn_animations-wt/integration` | see `git log` | **Integration branch for 0.9.0.** Slices A–F1 merged; 164 tests pass; analyze shows only 5 example deprecation infos (slice G clears them). This `.dev/` folder lives here. |
| `v1/slice-f2` | `…/cn_animations-wt/slice-f2` | 8b55c8a (no commits) | Slice F part 2: README and CHANGELOG for `CnRouteAnimation`. Not started; there were no changes when the session stopped. |
| `v1/slice-g` | `…/cn_animations-wt/slice-g` | 7ffb772 (WIP) | Example app rewritten; tests not fully verified. |
| `v1/slice-h` | `…/cn_animations-wt/slice-h` | f8b0af5 (WIP) | Integration tests: interactive back only, 7 pass and 4 are skipped as bugs. |
| `v1/slice-a`…`e`, `v1/slice-d` | `…/cn_animations-wt/slice-*` | merged | Already merged into integration. Their worktrees can be removed once 0.9.0 ships. |

`.dev/` is excluded from `flutter analyze` and from `pub publish` (verified with `--dry-run`).

## Owner decisions (binding)

- **Two releases.**
  - 0.9.0 is the bridge: all new APIs, with the old route-aware widgets kept but deprecated, and every deprecation message saying "removed in 1.0.0".
  - 1.0.0 removes them: `CnRouteAwareAnimation`, `RouteAwareWidget`, `RouteAwareWidget.routeObserver`, the top-level `routeObserver`, `CnFade.durationInMilliseconds` and `CnSlide.reverseControllerValue`.
- **Reduced motion** is configurable: respected by default (`fadeOnly`), with opt-out at widget > scope > default via `respectReducedMotion: false`, or `reducedMotionMode: none`. An external `controller:` or `animation:` is app-owned and is never overridden by reduced motion.
- **Pointer subject detection** is on by default (700 ms window).
- **Direction follows the Material convention.** `enterOffset` defaults to `Offset(0, 0.1)` (from below), and `exitOffset` defaults to `-enterOffset`, so covered content moves up and returns from above. The owner noted there are no existing users to keep continuity for.
- **No push or publish** without the owner's explicit go-ahead.
- **Delegated to the main thread (owner, 2026-10-09: "decide best and move forward"):**
  - R2: (a) docs only. Reduced motion does apply to a scope `progress:`. A scope progress stands in for navigation, which is exactly what reduced motion targets, and `respectReducedMotion: false` on the scope is the opt-out. `controller:` / `animation:` on the basic widgets stay app-owned.
  - R6: (a) add a separate `uncover` slice to `CnRouteTiming` (default `Interval(0.3, 0.65)`; first set to `Interval(0.25, 0.6)`, which measurement showed left one dead frame per pop; 0.65 is where the top element's exit ends, and the length matches the exit slice), used when S is falling (pop and interactive back), so the page below's elements start returning while the top page is still fading. Additive; decided before 1.0.0 because changing the default later is a visual change.
  - R8: (a) the no-op `timing` on `CnFadeThroughPageTransitionsBuilder` and `CnPageRoute` is deprecated in 0.9.0 ("has no effect; removed in 1.0.0") and removed by slice R.
  - R11: (a) keep the protected `route.controller` access (it matches Cupertino's own code and its settle feel). Revisit only if Flutter changes it.
- **pub.dev on 2026-10-09:** the latest published version is 0.0.3 (2023-01-30), with 28 downloads in the last 30 days, 0 likes and 140/160 points.

## Progress

About 70% toward 0.9.0 and 65% toward 1.0.0, weighted by effort.

| Stage | State |
| --- | --- |
| 0.1.0 fixes, Opus review, review fixes | Done (`fix/route-aware-regressions`) |
| Design (Fable): `.dev/design-0.9.md`, with the owner decisions at its end | Done |
| A: directional curve and route progress (`lib/src/progress/`) | Merged |
| B: scope, config, geometry (`lib/src/choreography/cn_route_choreography.dart`, `geometry.dart`) | Merged |
| C: fade-through builder and `CnPageRoute` (`lib/src/route/`) | Merged |
| C2: back-gesture wiring (`lib/src/route/cn_back_gesture_detector.dart`) | Merged (310644c → merge ee3de20); 32 new tests; root 215 pass, analyze clean. Not device-checked. |
| D: `CnRouteAnimation` (`lib/src/choreography/cn_route_animation.dart`) | Merged |
| E: `animation:` param on the basic widgets; deprecations | Merged |
| F1: exports, route timing param, 0.9.0 pubspec, CHANGELOG/README skeleton | Merged |
| F2: README snippets, CHANGELOG bullet, snippet tests | Merged (40d3726 → merge f9a2280); 19 snippet tests; root 183 pass, analyze clean |
| G: example app (`example/**`) | Merged (85346d2 → merge 76dae93); example 7 tests, root 164 tests, both analyzes clean |
| H: integration tests (`test/integration/**`) | Merged (afaff3d…e80fe25 → merge 3f644e8); 62 integration tests, 0 skipped |
| Full verification (step 5) | Done on 3f644e8 |
| Fable review (step 6) | Done: `.dev/review-0.9.0.md`, 0 P0 / 4 P1 / 6 P2 / 10 P3 |
| Review fix round | Merged (2f9d0ca, e3da2ad, 98b70e2 → merge eadd57b); see `notes/review-fixes-notes.md` |
| Owner device check (step 7) | **Waiting for the owner** |
| R6/R8 (slice r6) | Merged (71e9b16, 1663ead, e0298ee → merge 3bea114) |
| 1.0.0 removal (slice R) | Not started; must also remove the deprecated route `timing` (R8) |

## Known bugs (found by slice H; fixed by C2 in ee3de20, pending H un-skip and device check)

1. **P0: Android predictive back never reaches the Cn routes.**
   - Only Flutter's `PredictiveBackPageTransitionsBuilder` registers the observer that forwards `flutter/backgesture` to `TransitionRoute.handleStartBackGesture` (flutter `material/predictive_back_page_transitions_builder.dart:117-123`).
   - `CnFadeThroughPageTransitionsBuilder.buildTransitions` and `CnPageRoute.buildTransitions` wrap only the fade-through. So nothing scrubs on a real device, and committing the gesture falls through to a plain 400 ms pop.
   - Repro: `test/integration/interactive_back_test.dart` on `v1/slice-h`, skipped unless `--dart-define=RUN_BUGS=true`.
2. **P0: iOS edge swipe-back is gone under the Cn routes.**
   - The edge-drag detector lives in `CupertinoRouteTransitionMixin.buildPageTransitions` (`_CupertinoBackGestureDetector`). Neither Cn install adds it.
   - Repro: in the same file, run the iOS edge drag case with `platform: iOS`.
   - The D unit test's swipe passes only because it uses the stock Cupertino builder.
- **Why this matters:** the headline promise, that elements follow your finger on swipe-back and predictive back, currently holds only with Flutter's stock page transitions, not with the package's own recommended route.
- **Fix direction:** on Android, wrap the fade-through child in the predictive-back observer, by delegating to or reproducing `PredictiveBackPageTransitionsBuilder`'s gesture wiring. On iOS, wrap it in the Cupertino back-gesture detector. Keep the fade-through visuals. Un-skip the 4 tests. Model: **opus** (gesture and route lifecycle subtlety).

Full repros are in `.dev/notes/slice-h-notes.md` → "Bugs found". The fix is described in `.dev/notes/slice-c2-notes.md`.

**Fixed (R1, eadd57b):** `pubspec.yaml` now declares `sdk: ^3.7.0`, `flutter: ">=3.29.0"` (was `>=3.10.0`). Not run on an actual 3.29 SDK (only 3.32.7 installed). `flutter_lints ^6.0.0` (dev only) needs Dart 3.8, so contributors on exactly 3.29 can't `pub get` the dev deps; consumers are unaffected.

## Session 2 (2026-10-09, from ~14:05 Yerevan)

- Step 6 fix round merged (eadd57b). Post-merge: root and example analyze "No issues found"; root 280 pass (3 new: R9, R18, R19); example 7 pass; dry-run 0 warnings, 1 expected hint. R9 deviation: the assert lives in `cnStaggeredExit`/`cnStaggeredEnter` (a const constructor can't read `Interval.curve`). R10: `CnPartingSpec.subject` → `subjectBehavior`. R12: `CnRouteRecord.pointerWindow` removed; record uses `kCnPointerSubjectWindow`.
- iOS simulator check (iPhone 17 Pro, iOS 26.5, on d1bd682, before R6): the example builds and runs on Flutter 3.32.7 + Xcode 26.6. 22 device tests in `example/integration_test` (commit 5f8d440 on `v1/device-ios`) pass, with no exceptions and no package bugs. Swipe-back scrubs on both installs, commit/cancel/fling work, `fullscreenDialog` doesn't swipe, and elements part around the tapped item and return from above. The pre-R6 dead zone was confirmed (progress 0.662→0.463). The example's Hero doesn't fly on swipe-back because it lacks `transitionOnUserGestures: true`; the package handles it when the flag is set. Follow-up running on the same branch: merge R6, re-measure, Hero flag plus a README sentence, commit a minimal Podfile (the generated one names a missing `RunnerTests` target). Timing was not measured (host load; profile mode can't run on the simulator).
- Android emulator check (Pixel_API_36, Android 16, on d1bd682, before R6; real system predictive back via adb motion events; logcat shows `mAnimationCallback=true`): predictive back scrubs, commits and cancels on both installs. Elements part around the tapped item and return from above. Push/pop direction is correct, and there are no exceptions. The pre-R6 pop gap was confirmed (1–2 slow-mo frames). The Hero flies on push and pop but not on predictive back (example flag; fixed since). **Finding: `example/android` does not build on Flutter 3.32.7** (Gradle 7.4 can't run on Java 21; on JDK 17 the imperative `app_plugin_loader` apply is rejected). The agent ran `example/lib` in a throwaway host app. Follow-up running on `v1/device-android`: merge bcb5f60, regenerate `example/android` keeping `enableOnBackInvokedCallback`, and re-check R6 and the Hero on the emulator. Timing was not measured (host load).
- iOS follow-up merged (075d2a3, 61ab333, a25edf4 → merge 3737fcb). With R6 on the simulator, a swipe sampled at about every 1 % of progress has no point where neither page's elements are visible, even at a 5 % threshold (dimmest: A 0.721, top 0.163 / below 0.153). Back-button pop: 0 dead frames. The example Hero now has `transitionOnUserGestures: true` and flies during swipe-back (asserted), and there is a README sentence about it. `example/ios/Podfile` is committed without the template's `RunnerTests` block. The main thread then committed the CocoaPods wiring that `pub get`/`pod install` generate (xcconfig includes, macOS Podfile/lock/project; `flutter build macos --debug` OK) and the Flutter `.gitignore` migration (83d0b59 and the next commit), so the tree stays clean. Post-merge: root/example analyze clean, root 289, example 7, device 22/22 (on the branch), dry-run 0 warnings.
- R6/R8 merged (3bea114). Dead pop frames (neither page's elements visible), button pop per frame: 7/24 → 0/24. Predictive back, 19 samples: 7 → 1, and that one is the zero-width point S = 0.65. Post-merge: root and example analyze clean; root 289 pass, example 7 pass. The emulator checks ran on d1bd682, before R6, so re-run the iOS integration test on the merged tree.
- **Step 7:** the owner allowed emulator runs. Two opus agents are running in parallel: Android on the `Pixel_API_36` emulator (worktree `device-android`, adb-driven real predictive back, no code changes) and iOS on the iPhone 17 Pro simulator, iOS 26.5 (worktree `device-ios`, adds `example/integration_test/**`). Reports go to the session scratchpad and will be summarized here. Owner decisions on R2 (b), R6, R8 and R11 are still pending.
- Step 6 review done: `.dev/review-0.9.0.md` (Fable, read-only on fd993cf). Fix round (opus, branch `v1/review-fixes`) takes R1–R5, R7, R9, R10, R12–R20. Held for the owner: R2 code option (b) (fix round applies docs option (a)), R6 pop dead zone (feel, device check), R8 no-op `timing` (tied to R6), R11 iOS swipe via protected `controller` vs public back-gesture API (decide after device check).
- Step 5 done on 3f644e8: root analyze and example analyze "No issues found"; root `flutter test` 277 pass, 0 skipped; example 7 pass; `flutter pub publish --dry-run` 0 warnings, 1 hint (version jump from 0.0.3; expected per owner decision), `.dev/` not in the archive.
- Step 4 done: H merged (3f644e8). 4 bug tests un-skipped (progress 0.7, 3×200 px), all 11 interactive-back pass; overlays, stack ops, choreography claims, leaks/rebuild written; no new library bugs. `pushReplacement` train-hop belief **holds** (page two down keeps secondaryAnimation at 1.0; uncovered once on pop). **Design correction for the review round:** §8 and the §4 non-opaque row say `PageRouteBuilder(opaque: false)` over a `MaterialPageRoute` page covers it; it does not (Material only animates the page below for a Material next route or one with `delegatedTransition`). Tests pin the real behaviour, which matches the README.
- Step 3 done: C2 merged (ee3de20). Post-merge: root analyze clean, root 215 pass. C2 ran H's repro with RUN_BUGS=true: route checks pass in all 4; the 4 still fail only on H's own "sibling has moved" check, which uses progress 0.5 / 3×100 px drags that stay inside the exit slice (S in 0–0.35). H must change them to 0.7 and 3×200 px when un-skipping (then 11/11 pass).
- Step 2 done: F2 merged (f9a2280). Post-merge: root analyze "No issues found", root 183 pass. Slice R must also update README migration and delete 2 tests in `test/readme_snippets_test.dart` (deprecated "before" snippet, `RouteAwareWidget.routeObserver` install) — see `notes/slice-f-notes.md` → F2.
- Step 1 done: G merged (76dae93). Post-merge: root analyze "No issues found", root 164 pass; example analyze clean, 7 pass.
- Steps 1–3 started in parallel (disjoint files): G (sonnet, `example/**`), F2 (sonnet, README/CHANGELOG/`test/exports_test.dart`/`test/readme_snippets_test.dart`), C2 (opus, new worktree `…/cn_animations-wt/slice-c2`, branch `v1/slice-c2` from 0a0d763, owns `lib/src/route/**` and `test/route/**`).

## Next steps, in order

Run each step as a delegated agent, working in its slice worktree and committing on its branch. The main thread merges into `feat/v1-choreography` and re-runs `flutter analyze` plus the full `flutter test` after each merge. Checkpoint this file after every step.

1. **Finish slice G** (sonnet), in the `slice-g` worktree. Follow "Status at stop" in `.dev/notes/slice-g-notes.md`:
   - run `flutter test` in `example/`;
   - fix the dialog-test finders so they target the Card/Text inside the keyed `CnRouteAnimation`, because the keyed render object sits outside the translation;
   - run the root analyze (it must show **No issues found**) and the root tests;
   - amend the WIP commit into a real one.
2. **Finish slice F2** (sonnet), in the `slice-f2` worktree. Its brief: README snippets that compile against the real API, the `CnRouteAnimation` CHANGELOG bullet, `test/exports_test.dart` positives, and a new `test/readme_snippets_test.dart`. The facts it must state are in `.dev/notes/run-notes.md` and the design's "Owner decisions" section. Check its branch for partial work first.
3. **Fix the two P0 back-gesture bugs** (opus), on a new `v1/slice-c2` branch from the integration head. It owns `lib/src/route/**` and `test/route/**`. Then un-skip H's 4 bug tests.
4. **Finish slice H** (opus), in the `slice-h` worktree after rebasing or merging the bug fix. Follow "Status at stop" in `.dev/notes/slice-h-notes.md`. Write `overlays_test.dart`, `stack_ops_test.dart` (including verifying or refuting the `pushReplacement` train-hop belief), `choreography_claims_test.dart` and `leaks_rebuild_test.dart`, using `support.dart`. New bugs get a `skip: 'BUG: …'` and a repro; they are not fixed in H.
5. **Merge F2, G and H**, then run full verification on the merged tree: `flutter analyze` at the root and in `example/` (both clean), full `flutter test` at the root and in `example/`, and `flutter pub publish --dry-run`.
6. **Fable review** of the merged 0.9.0 (read-only), weighing the design against the code, the docs against the behavior, and API ergonomics, plus next-step suggestions. Then an **Opus** fix round for confirmed findings. One review round.
7. **Owner check on a device:** run `example/` on Android and iOS. This is the only way to judge feel: predictive back, Hero, 120 Hz, and the exit direction. Ask the owner.
8. **Tag 0.9.0 locally**, then **slice R** (sonnet): remove the deprecated symbols listed under owner decisions, their tests and the old example usage; set version 1.0.0; write the CHANGELOG entry; update README migration to "removed in 1.0.0". Run full verification again.
9. **Ask the owner** before merging to `master`, opening a PR, or running `pub publish`. Publishing order: 0.9.0, then 1.0.0.

## Scheduled after the package (owner request, not started)

1. **A concept document** on the corrected version: what the idea is, the value it brings, and a general (not detailed) guide to building similar packages on other platforms. The source material is `.dev/design-0.9.md`, the concept answer in the original session (summarized in the design's §1–§3), and the lessons in the notes:
   - progress-driven beats event-driven;
   - curves must be locked by the rest state that was left, not by status;
   - the route must keep the platform's back-gesture wiring;
   - the tapped subject should be identified by pointer-down;
   - stagger should be bounded by geometry;
   - reduced motion should default to fade-only.
2. **Then possibly sister packages for web and Android (Kotlin)**, with the same two goals: simpler animations, and navigation-driven animations.

## Files in `.dev/`

- `STATUS.md`: this file.
- `design-0.9.md`: the authoritative design. Its §7 slices, §8 test strategy and §9 example plan apply, and the "Owner decisions" at its end supersede §10.
- `review-0.1.0.md`: the Opus review of 0.1.0. All findings are fixed in 2b3ee71.
- `notes/`: run notes, plus one notes file per slice. These record interface details and design gaps that each agent found, and each has a "Status at stop" for the WIP slices.
- `probes/`: the designer's and reviewer's probe tests, kept as reference for test techniques on Flutter 3.32.7. They are not run by `flutter test`.
