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
| Fable review, 1.0.0 removal | Not started |

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

**Open before 0.9.0:** `pubspec.yaml` declares `flutter: ">=3.10.0"`, but the route code uses much newer APIs (route back-gesture methods). Raise the lower bound to the real minimum before publishing (step 5 verification or the review fix round).

## Session 2 (2026-10-09, from ~14:05 Yerevan)

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
