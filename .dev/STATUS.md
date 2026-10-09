# cn_animations 0.9.0 / 1.0.0: status and next steps

Last updated: 2026-10-09, when the first working session stopped. This file is the single source of truth for where the work stands. Update it at every checkpoint.

## Where everything is

All work is **local only**. Nothing has been pushed to GitHub or published to pub.dev. Pushing and publishing need the owner's explicit go-ahead.

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
| C: fade-through builder and `CnPageRoute` (`lib/src/route/`) | Merged; **has the back-gesture bug below** |
| D: `CnRouteAnimation` (`lib/src/choreography/cn_route_animation.dart`) | Merged |
| E: `animation:` param on the basic widgets; deprecations | Merged |
| F1: exports, route timing param, 0.9.0 pubspec, CHANGELOG/README skeleton | Merged |
| F2: README snippets, CHANGELOG bullet, snippet tests | Not started (branch created, no changes) |
| G: example app (`example/**`) | WIP 7ffb772 |
| H: integration tests (`test/integration/**`) | WIP f8b0af5; interactive back done, rest of design §8 not started |
| Full verification, Fable review, 1.0.0 removal | Not started |

## Known bugs (found by slice H; fix before 0.9.0)

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

Full repros are in `.dev/notes/slice-h-notes.md` → "Bugs found".

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
9. **Ask the owner** before any `git push` or `pub publish`. Publishing order: 0.9.0, then 1.0.0.

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
