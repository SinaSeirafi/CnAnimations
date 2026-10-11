# Brief: pre-publish fix slice and release rebuild (cn_animations 0.9.0 / 1.0.0)

Model: opus. Role: builder for one slice. Do not publish, do not push, do not move tags; the main thread does those.

## Where
- Worktree: `~/Development/CnPackages/cn_animations-wt/prepublish`, branch `v1/prepublish`, created by the main thread from `feat/v1-choreography` AFTER the owner-approved `v1/screenshots` branch is merged into it (so `screenshots/` with four files exists and both root GIFs are already gone).
- NEVER touch `~/Development/CnPackages/cn_animations` (the owner's checkout) or any other worktree.
- Read first: `.dev/STATUS.md` (the "Publishing decisions" bullet under Owner decisions, "Next steps", and close-out step 3 for how the releases were built last time), `.dev/publishing-suggestions.md` §1.1–§1.3, §2, §5.
- History shape today: `f2d0355` → `646e4fd` "Release 0.9.0" (tag `v0.9.0`) → `3a64c0f` "Release 1.0.0" (tag `v1.0.0`) → merge `06c20b9` on master → STATUS-only commits → screenshots merge. HEAD content = 1.0.0. `git diff 646e4fd 3a64c0f` = the 1.0.0 removals (19 files) plus CHANGELOG/pubspec version.
- Keep running notes in `.dev/notes/prepublish-notes.md` from your first step (it ships nowhere; `.dev/` is excluded from pub).

## Changes (content; each must end up in BOTH releases)
Source for N1–N4: `/private/tmp/claude-501/-Users-cn-Development-life-overview/f58a96b7-9082-48ef-abd1-1d0ed213ab70/scratchpad/final-review-opus/review.md` (read N1–N6).
1. **N1** `test/route/stock_predictive_back_test.dart` (~249-278, the `settle == false` "during a cancel" variant): rename to what it really tests ("a back gesture during a cancel is refused and pops plainly") and assert that (top route value is not 0.5 after the drag; `userGestureInProgress` is false). Verify it still passes on 3.32.7 and, if you can, on 3.47.7 (SDK at the session-3 scratchpad `flutter-3.47.7/`, if present).
2. **N2** `lib/src/choreography/cn_route_animation.dart` (~656): "keeps f = 1 (no stagger)" → "keeps f = 1 (the largest delay)".
3. **N3** README "How it works": one sentence after "Because the values are the route's own, the elements go wherever the route goes." saying that under Flutter's stock predictive-back builder on 3.35+, a committed back is the one exception: the elements continue from the release value instead of following the route's restart from 1.0.
4. **N4** 0.9.0 CHANGELOG: rephrase the three bullets that read as fixes to never-released versions ("no longer jump on commit", "which made the page snap back before popping", "Set `uncover:` to the `exit` slice for the old behaviour") as behaviour ("settle from the release point", "elements continue from the release value", "the `exit` slice gives a symmetric return").
5. **pubspec** (both versions): `description` exactly as `.dev/publishing-suggestions.md` §1.1 "Proposed"; `topics` as §1.2; `screenshots` as §1.3 (the four paths that exist in `screenshots/`; check each `description` ≤ 160 chars). Drop `homepage` (§1.4; `repository` and `issue_tracker` stay).
6. **README first screen** per §2's draft: pub/CI/license badges, tagline H1, one paragraph, the swipe-back GIF, three-step quick start (dependency, route install, wrap an element), the manifest-flag sentence, the "works with" line. Remove the 2023 intro ("Flutter is made of widgets, right?" …). Then the existing sections in the order §2 gives. Check the draft's claims against the code (e.g. "Needs Flutter 3.29+", `go_router` via theme) before keeping them.
7. **Image links**: every README image is an absolute `https://raw.githubusercontent.com/SinaSeirafi/CnAnimations/<TAG>/screenshots/...` URL, where `<TAG>` is `v0.9.0` in the 0.9.0 commit and `v1.0.0` in the 1.0.0 commit. The basics GIF goes in the Basic animations section; the predictive-back GIF in the Routes section next to the manifest flag. No references to the deleted root GIFs anywhere (grep `gif%20`, `RA gif`, `master/`).
8. **§5 docs-only items**: 1 and 3 (covered by the quick start), 5 (a short defaults table in Basic animations: durations, delays incl. `CnFade`'s 10 ms `delayInMilliseconds`, offsets — read the values from code), 6 (rename "Migrating from 0.1.0" → "Migrating from 0.0.x" and say 0.1.0's fixes are included in 0.9.0; 0.1.0 was never published), 7 (quick start and tagline avoid "choreography", "subject", "parting", "cover"; keep those terms in the configuration sections), 11 (the run-the-example line says to open List).
9. **History section**: make sure the test count and the CI matrix (Flutter 3.29.0 and stable) are stated near it (§5 item 8), with the counts true for each release (0.9.0 and 1.0.0 differ).
10. **README snippet tests** (`test/readme_snippets_test.dart`): any new Dart snippet in the README (the quick-start theme install, the one-line wrap) must be covered the way existing snippets are.
11. **CHANGELOG**: a short line in each release's entry for the README/pubspec rework is fine; don't invent fixes.

## Release rebuild (history on `v1/prepublish`)
Produce exactly this linear shape on top of the branch start `B`:
1. `F` — "Pre-publish fixes" commit(s) on the 1.0.0 content: items 1–11 in their 1.0.0 form (links to `v1.0.0`).
2. `R090` — "Release 0.9.0": the 1.0.0 removals undone (equivalent to reverting `3a64c0f`'s non-CHANGELOG changes: deprecated API back with "removed in 1.0.0", version 0.9.0), with every item 1–11 in its 0.9.0 form (links to `v0.9.0`; 0.9.0's README sections for the deprecated API kept, minus the deleted RA GIF image; test counts for 0.9.0).
3. `R100` — "Release 1.0.0": the removals re-applied plus the 1.0.0 CHANGELOG entry, links to `v1.0.0`.
Checks, all recorded in your notes:
- `git diff F R100` is empty except CHANGELOG.md (and nothing else). If not, explain each extra hunk.
- `git diff 646e4fd R090 -- lib test example` contains only N1/N2 and snippet-test changes; `git diff 3a64c0f R100 -- lib test example` likewise.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Verification (run on R090 and on R100, in the worktree, one at a time)
- `dart format --output=none --set-exit-if-changed lib` with the latest stable Dart available at the package language version (plain `dart format`, no `--language-version`); CI checks lib/. If the newest local SDK is older than CI's stable, say so.
- `flutter analyze` (root and `example/`), `flutter test` (root and `example/`), with counts.
- `flutter pub publish --dry-run`: 0 warnings; read the file list (no `.dev/`, `build/`, Pods, old GIFs; `screenshots/*`, LICENSE, CHANGELOG present); note the archive size.
- Every README image URL: confirm the target path exists in the same commit (`git cat-file -e <commit>:screenshots/<file>`). The URLs will only resolve once the main thread moves the tags.

## Done means
Report compactly: commit hashes of F, R090, R100; the diff checks; test/analyze/dry-run results per release with counts; anything in items 1–11 you changed from the brief and why; caveats. Worktree clean. Do not push, tag, publish, or touch any other branch.
