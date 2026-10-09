# cn_animations: superior version, run notes

## Owner decisions (2026-10-09)
- Approved all improvement suggestions from the review and the concept answer:
  progress-driven route choreography, tapped-item ("part the list") awareness, matching route,
  fast and capped timing, scroll-reveal as an explicit option.
- Reduced motion: configurable. Respected by default; the developer can opt out.
- Use agents in parallel where it makes sense (Opus / Sonnet / Haiku); a Fable advisor may review state and suggest next steps.
- Later, probably: a platform-agnostic concept document distilled from this work (the owner's original goal).
- No push or publish without asking.

## Locations
- Owner main checkout (has uncommitted 2023 WIP, DO NOT TOUCH): ~/Development/CnPackages/cn_animations
- Fix worktree: ~/Development/CnPackages/cn_animations-fixes, branch fix/route-aware-regressions (base 0f3b9bd)
- Pristine 0.0.3 clone: scratchpad/repo/CnAnimations
- Fix agent notes: scratchpad/fix-notes.md

## Steps
1. [done 65182fb; verified analyze clean, 31+2 tests pass] Opus fix agent: bugs 1–8, exports, deprecations, reduced motion, tests, housekeeping → 0.1.0
2. [done] Fable design: scratchpad/design-v-next.md (8 slices A–H; 4 owner questions, recommended defaults in use until answered)
   - Fix agent told: per-widget `respectReducedMotion` (default true) in 0.1.0; the global config is left to the design.
3. [review done: 1 high, 3 med, 3 low → fix agent applying F1–F7 (external controller wins over reduced motion; one tree shape)] Review the fix branch (Opus, read-only) → merge any fixes → then implement design slices in parallel worktrees/branches off the fix branch
4. [planned] Fable review of the merged state + next-step suggestions

## v1 build (design §7)
- Worktrees: ~/Development/CnPackages/cn_animations-wt/slice-<x>, branches v1/slice-<x>, base 65182fb
- Wave 1 running: A (opus), B (opus), C (sonnet). Notes: scratchpad/slice-<x>-notes.md
- Review fixes landed: 2b3ee71 (verified: analyze clean, 39+2 tests pass). Integration branch feat/v1-choreography created at 2b3ee71. Slice E (sonnet) running in slice-e worktree from 2b3ee71.
- Then: integration branch feat/v1-choreography off the fix head; merge A/B/C/E; wave 2 D; wave 3 F, then G + H; full verification on the merged tree; Fable review
- Owner answers (2026-10-09): Q1 1.0.0 ✓, Q2 reduced motion fadeOnly ✓, Q3 pointer subject detection on ✓, Q4 enterOffset = Offset(0, 0.1) FROM BELOW (Material convention; "there are no existing users"). The deprecated CnRouteAwareAnimation keeps its own -0.1 default.

## Scheduled, NOT started (owner, 2026-10-09)
1. After the package: a concept document on the corrected version. Covers the concept, the value it brings, and a general (not detailed) guide to building similar packages on other platforms.
2. Then possibly: similar packages for web and Android (Kotlin). Goals: simplify animations, and navigation-driven animations.
- Slice C done: 4cdd77f on v1/slice-c (10 route tests). Timing choice (a): no `timing` param yet.
  F todo: add `timing` to CnFadeThroughPageTransitionsBuilder + CnPageRoute; swap _directional_curve_copy.dart for A's class and delete the copy; export both route classes.
  Extra `maintainState` param on CnPageRoute (needed by ModalRoute).
- Slice E done: 2df0c6d (44 tests in its worktree). It also touched test/barrel_export_test.dart (a file-level ignore, outside its list; harmless).
  F todo (CHANGELOG): `animation:` param; deprecations.
- Integration worktree: ~/Development/CnPackages/cn_animations-wt/integration (feat/v1-choreography)
  - merged E (4fb5a70) + C (0784f44): 54 tests pass; analyze shows only the 5 expected example deprecation infos (G fixes)
- Waiting on A and B → merge → slice D off the integration head
- Slice B done: 3a3c477 (37 new tests), merged into integration.
  Surface for D: CnRouteChoreography.of / Data.reducedMotionFor, kCnPointerSubjectWindow, the CnRouteSubjectTarget interface (select()), cnPlacement / cnStaggeredExit / cnStaggeredEnter / cnPartingOffset / cnGlobalRect / cnViewportRect.
  Gaps (accepted): parting falls back to the other axis component; slice curves come from exitCurve/enterCurve (curves set on the timing.exit/enter Intervals are ignored → document); select() with no target asserts in debug and is a no-op in release.
  F todo: export cn_route_choreography.dart with `show` (hide the kCn* constants and CnRouteSubjectTarget); don't export geometry.dart.
- Slice A done: 1bf1ba4 (26 new tests), merged. Gaps: see the end of slice-a-notes.md (Hero offstage first frame handled in A; curve slots: FlippedCurve for this page's exit, exit slice in the enter slot for cover; F adds meta for @internal; B's select() should route to CnRouteRecord.select)
- Wave 1 complete. Slice D (opus) worktree slice-d off the integration head.
- Owner decision (2026-10-09): TWO releases.
  - 0.9.0 = the bridge: all new APIs, old route-aware widgets kept deprecated.
  - 1.0.0 = old widgets removed.
  This replaces "1.0.0 with deprecations" (Q1). F part 1 has been told to use 0.9.0.
  After 0.9.0 is verified: slice R (removal) on top → 1.0.0. Also: the deprecation messages in E's files should say "removed in 1.0.0".
- pub.dev (checked 2026-10-09): latest published 0.0.3 (2023-01-30); 28 downloads in the last 30 days, 0 likes, 140/160 points.
- F part 1 done: f623adb (0.9.0; timing on the route; curve copy removed; exports; meta added, no @internal yet), merged as e0185c8. I then committed the deprecation wording "removed in 1.0.0" on integration (120 tests pass).
  Part 2 todo: CnRouteAnimation export + CHANGELOG bullet + README snippets + migration param mapping; optional @internal on A/B internals.
  The R (1.0.0) step must also remove CnFade.durationInMilliseconds and CnSlide.reverseControllerValue.
- Slice D done: 745fd97 (43 new tests; 160 total).
  Follow-up running: exitOffset default = -enterOffset (Material shared axis: forward → outgoing moves up); B doc fixes; CnScrollReveal.once removed.
  For F2: export cn_route_animation.dart in full. For H: skipOffstage: false for the covered page; use zero stagger + fade-through everywhere for exact values.
  Subject priority: select() > subject:true > pointer.
- Next after the D follow-up: merge D → launch F2 (sonnet), G (sonnet), H (opus) in parallel on disjoint files
- D follow-up aacc94e merged as 8dcc1e1. I exported CnRouteAnimation (8b55c8a); 164 tests pass.
- Wave 3 running from 8b55c8a: F2 (sonnet, README/CHANGELOG/snippet tests), G (sonnet, example/**), H (opus, test/integration/**)
- Remaining: merge wave 3 → full verification → Fable review → fixes → tag 0.9.0 → R step (1.0.0 removal) → ask the owner about push/publish
