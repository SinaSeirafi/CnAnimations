# Slice A notes
- Read design in full. Scope: §3.2, §3.3, §3.4, §3.6, §5; AC §7 A.
- ModalRoute.of depends on all aspects (isCurrent etc.) -> didChangeDependencies reruns on push; harmless if D compares CnRouteProgress by identity.
- currentFrameTimeStamp asserts non-null; null before first frame (runApp attach builds before any frame). Plan: initial-mount window = first bind opens, post-frame callback closes. Same rule, robust.
- package:meta not in pubspec; importing it trips depend_on_referenced_packages. foundation does not re-export @internal. => document internal types as package-internal in dartdoc (allowed by brief). F may add meta + @internal later.
- Curve rule: curves apply to parent value as-is (matches C's §3.7 usage). Primary exit on pop (A 1->0) needs FlippedCurve(exitInterval) so the slice is time-ordered -> D's job; documented.
- Robustness add: a covered page goes Offstage in the same frame S hits 1, so nobody may read value at exactly 1 -> lock would miss the rest. Fix: parent status listener attached only while this animation has listeners (no disposal needs still holds).
- Wrote both lib files (curve + route_progress). Next: analyze, tests.
- directional_curve_test written (7 tests).
- FINDING (design gap): on the FIRST frame of a push, HeroController sets route.offstage=true and ModalRoute.animation's proxy parent = kAlwaysCompleteAnimation -> elements bind seeing A=1.0 completed. Naive §3.6 rule classifies them `initial` (timed entrance) instead of following. Fix in A: classifyMount returns `following` when route.offstage && primary is route.animation. Also the proxy swap back (completed->forward, value 0) must record rest 0 in the curve: status listener now records rest from value on ANY status change.
- FINDING: tester.pump(d) only advances currentSystemFrameTimeStamp if a frame is scheduled; pointerSubject must be called during a frame (cover tick). Documented; test forces frames.
- Tests: directional 8, route_progress 18 (26 new). analyze clean.

## Internal API for D (lib/src/progress/route_progress.dart, not exported)
CnRouteProgress.of/resolve (route, primary, cover, recordKey, record, classifyMount, ==), CnMountKind {untracked, following, initial, late},
CnRouteRecord.of/maybeOf (recordPointerDown, pointerSubject, lastPointerDown, select/takeSelection, beginCoverSegment/endCoverSegment, inCoverSegment, coverSegment, subject, subjectRect, segmentCache),
CnPointerDown, CnTimedFallbackMixin (ensureTimedFallback, playTimedFallback, timedFallback), staggeredExitInterval / staggeredEnterInterval.

## Design gaps (notes, design not edited)
1. §3.6/§4 "Page pushed": on the first frame of a push under a HeroController (Material/CupertinoApp), route.offstage is true and ModalRoute.animation reads kAlwaysCompleteAnimation (1.0, completed). The naive rule classifies those mounts `initial`. A handles it: classifyMount -> following when route.offstage && primary is route.animation; the curve records rest 0 when the proxy swaps back.
2. §3.2 step 2 / §3.4: curves apply to the source value as-is. A primary exit (A: 1->0) slice measured from the start of leaving needs FlippedCurve(staggeredExitInterval(...)) in the `exit` slot. For the cover source, covering is S leaving 0, so the exit slice goes in the `enter` slot (and in `exit` for uncover). D must wire these explicitly.
3. §3.3 "no listeners of its own": refined. While it has listeners, the curve listens to its parent's status so a rest is recorded even when no one reads value at that frame (covered page goes offstage on the frame S hits 1; proxy swap above). Still no disposal needs.
4. §3.6 "currentFrameTimeStamp equal": implemented as an initial-mount window (opened by the first bind, closed by a post-frame callback). Same rule, but it also works when the tree is built before the first frame (runApp attach), where currentFrameTimeStamp asserts.
5. §3.5 700 ms window clock: pointer-downs are stamped with currentSystemFrameTimeStamp at the next frame; pointerSubject must be called during a frame. In tests, tester.pump(d) advances that clock only when a frame is scheduled.
6. @internal needs package:meta in pubspec (F). Until then, internal types are documented as package-internal.
7. B's select(): should call CnRouteRecord.of(ModalRoute.of(context)!).select(context); D resolves takeSelection() to its State with findAncestorStateOfType.
