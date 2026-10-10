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

About 97% toward 0.9.0 and 95% toward 1.0.0, weighted by effort (as of the end of session 2). What remains is the owner's physical-device feel check and the step 9 push/publish go-ahead.

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
| Device check (step 7) | Done on emulators (owner offered them): Android Pixel_API_36 and iOS iPhone 17 Pro sim. Real finger feel, 120 Hz and timing remain for the owner on a physical device (not blocking a local tag) |
| R6/R8 (slice r6) | Merged (71e9b16, 1663ead, e0298ee → merge 3bea114) |
| Local tag `v0.9.0` (step 8) | Created on 869bb94 (annotated, not pushed) |
| 1.0.0 removal (slice R) | Merged (cbfd0d9, 0251d2c → merge f50f8be); version 1.0.0; root 268 pass (21 removed with the symbols) |
| Push / PR (step 9, owner chose B) | Done: branches and tag `v0.9.0` pushed; PR #1 `feat/v1-choreography` → `master` opened |
| pub publish | **Not done.** The owner is researching how best to publish for visibility and usefulness first |

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
- Step 8 done. Slice R merged (f50f8be): removed `CnRouteAwareAnimation`, `RouteAwareWidget` (+ `.routeObserver`), the top-level `routeObserver`, `CnFade.durationInMilliseconds`, `CnSlide.reverseControllerValue`, and the route `timing`. Deleted `lib/cn_route_aware_animation.dart`, `lib/route_aware_widget.dart` and their tests. CHANGELOG 1.0.0 "Breaking: removed" entry; README migration says "removed in 1.0.0". Post-merge: root/example analyze clean, root 268, example 7, apk builds, dry-run 0 warnings 0 hints. The removed names remain only in the README migration text and the 0.9.0 CHANGELOG history.
- Session 3 close-out (2026-10-11):
  - CI is pushed over SSH, which needs no `workflow` token scope. On the first run the 3.29.0 leg passed. The stable leg failed in setup because the matrix expression resolved to `flutter-version: stable`. Fixed in 037cb2e (matrix `include`, `version: any`, `checkout@v5`).
  - README "How it works" and "History" (2023 origin; 2026 rework with Claude) are merged (0da05ee), with a CHANGELOG 1.0.0 line.
  - The iOS example project migrations and `Podfile.lock` are committed (6e89a06; `flutter build ios --simulator` OK).
  - Owner: the 2023 WIP in the master checkout is not needed. It only moved `routeObserver` to a static on `RouteAwareWidget`, which 0.1.0 did and 1.0.0 then removed.
  - Cleanup (owner-authorized): every slice worktree is removed, plus `cn_animations-fixes`. All their local and remote branches are deleted after an ancestry check against `feat/v1-choreography`; `v1/slice-g` was tree-identical to its merged amend. Remaining: `master`, `feat/v1-choreography` (PR #1) and tag `v0.9.0`. The emulators are shut down.
  - Owner: merge PR #1 after a fresh-context review. An opus review is running, and pub.dev score research is still running.
- CI merged locally (72f5e28, 003344b → merge dd51a62): `.github/workflows/ci.yml`, matrix Flutter 3.29.0 + stable; triggers are PRs, pushes to master, and manual runs. `flutter_lints` ^6.0.0 → ^5.0.0 (6 needs Dart 3.8). Post-merge: root/example analyze clean, root 268, example 7, dry-run 0 warnings. **Push blocked:** the token lacks the `workflow` scope (see Next steps 1).
- Session 3 (2026-10-10), after PR #1. Owner choices: keep `delayInMilliseconds` (it duplicates `delay` but works; removing it would need a 0.9.x deprecation after the pushed `v0.9.0` tag). Three agents are running in parallel:
  - CI (sonnet, `v1/ci`): GitHub Actions on Flutter 3.29.0 plus stable, and `flutter_lints` lowered to a version that supports Dart 3.7.
  - pub.dev score research (sonnet, read-only, report in the session scratchpad).
  - README "How it works" (fable, `v1/readme-how-it-works`).
- Step 9 (owner chose B, 2026-10-09): pushed `feat/v1-choreography`, `v1/slice-f2`, `v1/slice-h`, `v1/slice-c2`, `v1/review-fixes`, `v1/slice-r6`, `v1/device-ios`, `v1/device-android`, `v1/slice-r` and tag `v0.9.0`. Opened PR https://github.com/SinaSeirafi/CnAnimations/pull/1 (base `master`). `v1/slice-g` was not pushed: it diverged from origin when its WIP commit was amended (content is merged in integration), so updating it needs a force push the owner hasn't approved. The local `master` checkout was not touched. No publish.
- Earlier: at step 9, ask the owner before pushing, merging to `master`, opening a PR, or `pub publish`. Publishing order: 0.9.0 from tag `v0.9.0` (869bb94), then 1.0.0 from `feat/v1-choreography`. No `v1.0.0` tag yet.
- Step 8: tagged `v0.9.0` locally on 869bb94; slice R started.
- Android follow-up merged (1e7039c, 8938926 → merge c7fc729): `example/android` regenerated (Kotlin DSL Gradle) and builds with `flutter build apk --debug/--profile`; `enableOnBackInvokedCallback`, label and `com.example.example` kept. On the emulator with R6: no empty screen at any hold, including the old worst case (450–650 px, no subject). The Hero flies during predictive back on both routes. Commit and cancel re-confirmed. The main thread made `example/integration_test` iOS-only (fac67c7; on Android it registers 1 skipped test, verified on the emulator). Post-merge on fac67c7: root/example analyze clean, root 289, example 7, apk builds, dry-run 0 warnings, tree clean. Artefacts (GIFs, holds) are in the session scratchpad `device-check/{android,ios}/`.
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

## Next steps, in order (revised 2026-10-11: close-out path)

The original steps 1–9 are done. The owner **skipped the physical-device check**; the emulator checks stand in for it. Accepted risk: real finger feel, 120 Hz and frame timing were never measured. The owner wants to close out soon.

1. **Unblock the CI push (owner).** `git push` of the CI commit was rejected: the `gh` token lacks the `workflow` scope. The owner runs `gh auth refresh -h github.com -s workflow` once. Then the main thread pushes `feat/v1-choreography` (dd51a62 or later) and `v1/ci`, and CI runs on PR #1 (Flutter 3.29.0 + stable). Both legs must be green, and the 3.29.0 leg is the first real run on the declared minimum SDK.
2. **Merge the two running agents' work:** README "How it works" (`v1/readme-how-it-works`) and the pub.dev score research. Apply any score fixes that are small and safe in one short slice (sonnet). Re-verify and push.
3. **Merge PR #1 into `master` and tag `v1.0.0`.** These are owner actions, or the main thread's on an explicit go-ahead. Before the owner's local `master` checkout pulls, the owner decides what to do with its uncommitted 2023 WIP (3 files).
4. **Publish** when the owner's publishing research is done: 0.9.0 from tag `v0.9.0`, then 1.0.0, or 1.0.0 only (the owner decides).
5. **Clean up** worktrees and branches only on the owner's go-ahead, after a content check against `master`.

Deferred past 1.0.0 (not blocking): `CnPage` and `MaterialPageRoute` parity on `CnPageRoute`; `@internal` on internal types; a dartdoc note on `CnFade`'s 10 ms default delay; `delayInMilliseconds` kept (owner, 2026-10-10).

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
