# Slice D notes (CnRouteAnimation)

- Step 1: started; reading design + wave-1 notes.
- Read design (all), A/B/C/E notes, run notes, A's and B's lib files, C's route, probes.
- Plan: State listens to A's CnDirectionalCurvedAnimation wrappers (so A's status tracking is active) + fallback controller; each tick does segment bookkeeping then fires a private ChangeNotifier hub; transitions read values via tiny Animation adapters on the hub, created fresh per build (so FadeTransition re-reads after a config change, no notify during build). Constant tree: Listener > Fade > Slide > Scale > child (builder path: Listener > ListenableBuilder).
- Curve slots: primary enter = cnStaggeredEnter as-is; primary exit = FlippedCurve(cnStaggeredExit); cover enter AND exit = cnStaggeredExit as-is (uncover = cover reversed, per §3.7 "return over exit reversed, S in [0,0.47]"). Design inconsistency: B's CnRouteTiming.enter doc says enter covers "return after the page above pops"; §3.7/§4 say exit reversed. Going with §3.7/§4.
- Subject priority: select() > subject:true (registry per record) > pointer (if detection==pointer). subject:false rejects at resolve time (still records pointer, so a tap on it clears an older pointer subject). detection off -> no subject.
- Wrote lib/src/choreography/cn_route_animation.dart (~750 lines); analyze lib clean. Next: tests.
- Tests group 1 (push, stagger, pop, cover/uncover, dialog, reversal): 7 pass first run.
- Group 2 (initial, stagger, zero-duration, no route x2, late with/without reveal): 14 total pass.
- Group 3 (enabled, fadeOnly, none x2, precedence x5, no controller): 24 total pass.
- Group 4 (isCurrent toggle, parent toggle mid-push, child state survives, builder x2): 29 pass.
- Group 5 parting (list 4 of 9 exact vectors, uncover, grid sideways, subject:false, select(), subject:true + select beats it, window expiry/within, detection off, builder roles): 39 pass.
- Group 6 gestures (predictive back cancel/commit, iOS drag) + mid-segment mount + RTL grid: 43 pass in my file.
- Verified: dart format clean; flutter analyze = only the 5 known example infos; flutter test full = 160 pass (117 + 43 new).

## Deviations / decisions (D)
1. Uncover runs the exit slice in reverse (cover curve in both slots, as-is on S), per §3.7/§4. B's CnRouteTiming.enter dartdoc says enter also covers "return after the page above pops" -> contradicts; see Requests.
2. CnElementProgress got a public const constructor and a `rest` constant (sketch listed fields only).
3. Subject priority: select() > subject:true > pointer (pointer only with detection=pointer). subject:false candidates are skipped (fall through). detection off -> no subject.
4. Nested elements: an element inside or wrapping the subject gets role subject and renders as `stay` (else the subject would move/fade with its wrapper). With nested elements the outermost records the pointer last, so the outermost becomes the subject.
5. `fade: false` is a master switch: no opacity change at all (subject `fade` and sibling fade included).
6. builder: live progress under fadeOnly (builder decides); CnElementProgress.rest under none / enabled:false. With a builder the built-in fade/slide/scale are not applied.
7. CnScrollReveal.once: each element state reveals at most once by construction; once:false adds nothing (no re-reveal of a kept-alive element). Documented gap.
8. Default exitOffset = enterOffset (design). With the owner's Q4 (0, 0.1), plain (no-subject) elements move DOWN when covered; under the old -0.1 they moved up. Flag for owner/G.
9. Geometry is never read during build/layout/paint (schedulerPhase == persistentCallbacks): deferred to a post-frame measure (one retry per scheduling).

## Requests for A/B (none blocking)
- B (cn_route_choreography.dart, CnRouteTiming.enter doc): change "Slice during which an element arrives (push of this page, return after the page above pops)." to "Slice during which an element arrives (push of this page)." and add to `exit`: "Run in reverse when the page above pops." Reason: D implements §3.7/§4 (uncover = exit slice reversed).
- B/F (CnScrollReveal.once): document that reveal is per element state (an item scrolled out and disposed reveals again when rebuilt), or drop `once`. D cannot give once:false a distinct meaning without tracking element identity across disposal.

## For F/G/H
- F: export cn_route_animation.dart whole (CnRouteAnimation, CnElementProgress, CnElementRole, CnRouteAnimationBuilder); nothing internal in it.
- H: read a covered page's elements with skipOffstage: false (the page goes offstage at S == 1). Exact-value checks are easiest with CnRouteTiming(exitStagger: 0, enterStagger: 0) and a fade-through theme on every platform (page below holds still).
- Committed 745fd97 on v1/slice-d (not pushed). Done.
- Follow-up commit 3068c67: exitOffset default -enterOffset, B docs fixed, CnScrollReveal.once removed; 161 tests pass, analyze 5 known infos.
