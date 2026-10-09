# Slice B notes

- Started: reading design.
- Read design in full. SDK >=3.0 so records + interface classes are fine. No package:meta dep -> no @internal; internal symbols are public-in-lib/src, F must export with show/hide.
- Plan: `of` walks the scope chain (getElementForInheritedWidgetOfExactType from each scope's parent element), depends on every scope, merges outermost->innermost.
- select() hook choice: an interface `CnRouteSubjectTarget` (method `selectAsSubject()`) that D's State implements; select walks self+ancestors for the nearest StatefulElement whose state implements it. No global static callback (no mutable global state, nothing to reset in tests). Fakeable in tests by a fake State.
- geometry.dart: `cnPlacement(...)` returning record (onScreen, f, direction) + interval/parting-vector helpers + side-effect-free render lookups (global rect, viewport rect).
- Wrote cn_route_choreography.dart. Design gap: `distance ⊙ direction` with default (0,0.6) gives zero for cross-axis/horizontal parting; resolved in geometry by falling back to the other component's magnitude.
- Wrote geometry.dart: cnPlacement (record), cnStaggeredExit/Enter, cnPartingOffset, cnGlobalRect, cnViewportRect. exit.curve/enter.curve of the timing Intervals are ignored (design formula uses exitCurve/enterCurve).
- scope_test.dart: 16 tests pass; analyze clean.
- geometry_test.dart: 21 tests. Full suite 68 pass (37 mine + 31 existing); analyze clean; dart format clean.
- Surface for D: CnRouteChoreography.of / CnRouteChoreographyData (+ reducedMotionFor), CnRouteSubjectTarget (State implements selectAsSubject), kCnPointerSubjectWindow, cnPlacement, cnStaggeredExit/Enter, cnPartingOffset, cnGlobalRect, cnViewportRect.
- For F: export cn_route_choreography.dart with `show` (hide k* constants and CnRouteSubjectTarget); do not export geometry.dart.
- Design gaps: (1) distance ⊙ direction zero for cross/horizontal with default (0,0.6) -> fallback rule; (2) CnRouteTiming.exit/enter Interval curves are ignored (exitCurve/enterCurve used); (3) select() with no element above: debug FlutterError, release no-op; (4) no @internal available without adding package:meta.
