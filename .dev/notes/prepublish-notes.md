# Pre-publish notes (v1/prepublish)

Branch start B = 01d52cd. Running notes, newest last.

## Step 1: orientation
- Read brief.
- Read STATUS (publishing decisions, next steps, close-out 3), publishing-suggestions §1-§5, review N1-N6 (original path present).
- SDKs: ~/flutter = 3.32.7 (Dart 3.8.1); session-3 scratchpad flutter-3.47.7 (Dart 3.13.5) present. 3.47.7 is the newest local SDK.
- `.dev/` is tracked in git (only excluded from pub/analyze). So this notes file is committed; to keep `git diff F R100` CHANGELOG-only, the notes are committed in a trailing notes-only commit after R100 (outside the release shape; the release tags still go on R100/R090).

## Step 2: findings while reading
- README has no "run the example" line today; item 11 adds one (example home is Basics; "List" is in its "Route-driven demos" row: example/lib/pages/basics_page.dart:74).
- Basic defaults from code (same in 0.9.0 and 1.0.0): CnFade 500 ms, delayInMilliseconds 10, fade 0 -> 1, curve easeInOut; CnSlide 300 ms, delay 0, begin Offset(0, 0.5), easeInOut; CnScale 300 ms, delay 0, begin 0.7, easeInOut. `delay:` (Duration) wins over delayInMilliseconds.
- Quick-start snippets: theme install = existing "route install / theme builder" test; one-line wrap = existing "CnRouteAnimation / minimal" test. New coverage: a test pinning the basic defaults table.
- N2: also fixed the same wrong claim at cn_route_animation.dart:568 ('plain with no stagger' while passing f = 1.0 to _setRole); same finding, true to code.

## Step 3: N1 (test/route/stock_predictive_back_test.dart)
- Split the `settle` loop into two tests. "a second gesture after a cancel commits one way" is unchanged in behaviour. The `settle == false` variant is now "a back gesture during a cancel is refused and pops plainly".
- Deviation from the brief (true to code): the brief/review asked to assert `userGestureInProgress` is false after the drag. Probe on both SDKs: right after the second drag, top=0.997 (3.32.7) / 0.891 (3.47.7), status forward, `userGestureInProgress` **true** on both, because the first gesture's cancel holds the flag until its forward run completes. So the test asserts value not ~0.5 and status still `forward` after the drag (the drag never took over), then after the commit + settle: route dismissed, 't' gone, `userGestureInProgress` false, s0 at rest.
- Verified `popGestureEnabled` returns false while animating on 3.32.7 (routes.dart ~1857), as the review said for 3.47.7.
- Result: stock_predictive_back_test.dart 9/9 pass on 3.32.7 and on 3.47.7 (3.47.7 run in a scratch copy of the tracked files, so the worktree's .dart_tool/locks stay on 3.32.7).

## Step 4: items 2-11 in their 1.0.0 form (commit F)
- N2: cn_route_animation.dart:656 reworded; plus :568 (see above).
- N3: one sentence after "...wherever the route goes." in How it works.
- N4: the three 0.9.0 CHANGELOG bullets rephrased as behaviour.
- pubspec: description = §1.1 Proposed (160 chars), **double-quoted** because it contains ": " (a plain YAML scalar with ": " does not parse); same for the second screenshot description. topics §1.2; screenshots §1.3 (all four paths exist; descriptions 70/69/62/48 chars). `homepage` dropped; repository/issue_tracker kept.
- README first screen per §2. Vocabulary (§5.7): the draft's tagline said "covers it" / "parts away" and "Parting ... on by default"; rewritten as "leaves when a new page opens over it", "moves away from the item you tapped", "The item you tap stays put while the others move away from it". Quick start step 2 adds why the install matters (Flutter's default transitions move or hide the page below).
- Claims checked: "Needs Flutter 3.29+" = pubspec `flutter: ">=3.29.0"`; go_router via the theme = existing README Routes text (MaterialPage builds a Material route that takes the theme transition); PageView via scope `progress:` = README Configuring section + snippet test 'scope progress drives elements'.
- The old "Features" and "Getting started" sections are replaced by the first screen (their snippets live on in the quick start and Usage). Sections then follow §2's order under "## Usage" (kept so the existing #usage anchor in How it works still resolves).
- Images: swipe-back GIF on the first screen, basics GIF in Basic animations, predictive-back GIF in Routes after the manifest-flag sentence. All `raw.githubusercontent.com/SinaSeirafi/CnAnimations/v1.0.0/screenshots/...` in F/R100.
- §5.5 defaults table read from code; new snippet test 'defaults table in the README' pins every value. Quick-start theme snippet and one-line wrap are the existing 'theme builder' and 'minimal' tests (comments added).
- §5.6 "Migrating from 0.0.x" with the 0.1.0-never-published note; anchor updated in History; CHANGELOG 1.0.0 bullet's "Migrating from 0.1.0" reference updated too. The migration "before" comment says `// 0.0.x` (the 0.0.3 constructor already had beginSamePage/endNextPage).
- §5.11: no run-the-example line existed; added one to the quick start ("run the example app in `example/` (`flutter run`) and open List").
- History: "280 tests, plus 7 in the example app; CI on Flutter 3.29.0 and stable" (1.0.0 counts; 0.9.0 gets its own).
- CHANGELOG: one docs line in the 0.9.0 entry only. Not in 1.0.0's entry, because 1.0.0 says "Nothing else changed" relative to 0.9.0 and the README rework is in both.
- Stale-reference grep (outside .dev): no `gif%20`, `RA gif`, `/master/`, `Migrating from 0.1.0`, `homepage`.
- F checks (3.32.7): root analyze clean, root 280 pass; example analyze clean, 7 pass; dart format (3.13.5 and 3.8.1) clean on lib and test.

## Step 5: release rebuild
- F = eae7b8e "Pre-publish fixes (1.0.0 form)" on B = 01d52cd.
- R090 = 0aad6ca "Release 0.9.0": `git revert --no-commit 3a64c0f`; conflicts resolved deliberately: pubspec = F's with version 0.9.0; CHANGELOG = F's minus the 1.0.0 entry; README rebuilt from F's README (links v1.0.0 -> v0.9.0; a "### Route-aware animation (deprecated)" section at the end of Usage holding 0.9.0's deprecation blurb, the observer snippet and the two 2023 usage snippets, without the retired RA GIF; migration text in its 0.9.0 wording, retitled 0.0.x; count 301). Every other file auto-reverted to its 646e4fd content.
- R100 = 1b8eae1 "Release 1.0.0": `git cherry-pick --no-commit 3a64c0f`; pubspec/README conflicts resolved to F's 1.0.0 form; the cherry-picked CHANGELOG 1.0.0 entry said "Migrating from 0.1.0", set to F's "0.0.x" wording. Result tree == F's tree.
- Trailing commit after R100: this notes file only (`.dev/`, not shipped). The tags belong on R090 and R100, not on the notes commit.

## Step 6: diff checks
- `git diff F R100`: empty (not even CHANGELOG; F already carried the 1.0.0 entry).
- `git diff 646e4fd R090 -- lib test example`: 3 files: cn_route_animation.dart (N2, two comments), readme_snippets_test.dart (+1 defaults-table test, 2 comments), stock_predictive_back_test.dart (N1). Nothing else.
- `git diff 3a64c0f R100 -- lib test example`: the same 3 files, same hunks.
- R090 -> R100 (all): 19 files, +34/-1209: the removals plus CHANGELOG (1.0.0 entry), README (deprecated section, migration wording, tag links, test count), pubspec version.
- Commit trailers: all three end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Image targets: `git cat-file -e` OK for screenshots/{parting-swipe-back,basics,predictive-back}.gif in both R090 and R100. The lineup PNG is only in pubspec `screenshots:` (path exists in both).

## Step 7: verification (worktree, one release at a time; 3.32.7 unless noted)
| | R090 (0aad6ca) | R100 (1b8eae1) |
| --- | --- | --- |
| dart format lib (Dart 3.13.5, from flutter 3.47.7, the newest local SDK) | 0 changed | 0 changed |
| flutter analyze root / example | No issues / No issues | No issues / No issues |
| flutter test root / example | 301 / 7 pass | 280 / 7 pass |
| pub publish --dry-run (3.32.7) | 0 warnings, 1 hint (non-incremental after 0.0.3, expected), 2 MB | 0 warnings, 2 MB |
| 3.47.7, clean scratch export of the commit: root test, dry-run | 301 pass; 0 warnings, 1 hint, 2 MB | 280 pass; 0 warnings, 2 MB |
- Dry-run file lists: no `.dev/`, `.github/`, `build/`, `.dart_tool/`, Pods dirs, or root GIFs; `screenshots/` (4 files), LICENSE, CHANGELOG.md present. `example/ios/Podfile.lock` / macos Podfile.lock ship (intentional, small).
- CI's stable may be newer than 3.47.7; not checked from here.
- Counts: 1.0.0 root was 279, now 280 (+1 defaults-table snippet test; the N1 split keeps 2 tests). 0.9.0 was 300, now 301.

## Status at stop
Done. Not pushed, not tagged. Main thread: move `v0.9.0` -> 0aad6ca and `v1.0.0` -> 1b8eae1, push, run CI on both.
