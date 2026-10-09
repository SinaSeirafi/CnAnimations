# Slice R6 (review R6 + R8), branch v1/slice-r6

From integration head b3c5f0b. Decisions: STATUS "Delegated" block, R6 (a) and R8 (a).

## Approach

- `CnRouteTiming.uncover` (default `Interval(0.25, 0.6)`), in `copyWith`, `==` and `hashCode`. It is read on the cover progress S as-is, in the same coordinates as `exit` on the way in, so `uncover: exit` gives back the pre-0.9.0 behaviour exactly.
- `cnStaggeredUncover` (geometry.dart): the same `f·exitStagger` shift, clamp and `exitCurve` as `cnStaggeredExit`. The R9 assert now also checks `uncover.curve`.
- The element's cover animation is `CnDirectionalCurvedAnimation(cover, enter: cover slice, exit: uncover slice)`. The existing rest lock picks the slice: exit after S leaves 0, uncover after S leaves 1. No status check and no new state.
- R8: `@Deprecated('Has no effect; removed in 1.0.0')` on the field and on the constructor parameter of both classes, in the same style as `CnSlide.reverseControllerValue`. `CnPageRoute` no longer forwards `timing`. The only remaining use is the test that pins the deprecated surface (`test/route/cn_page_route_test.dart`). `example/` never passed it.

## Gap numbers (flat timing, both installs identical)

Source: `test/route/uncover_gap_test.dart`. Fake-clock widget tests (60 Hz, 400 ms pop), so the host load during the run does not affect them. "Dead" means the top element (own opacity × page fade) and the element below (own opacity × what the top page leaves uncovered) are both under 0.01.

| | Before | After |
| --- | --- | --- |
| Button pop, per frame | 7 of 24 frames, S ∈ [0.375, 0.625] | 1 of 24 (S = 0.625) |
| Predictive back over the real channel, p = 0.05…0.95 | 7 of 19 samples, S ∈ [0.35, 0.65] | 2 of 19 (S = 0.65, 0.60) |

The gap before was S ∈ [0.35, 0.65], wider than the reviewer's [0.35, 0.6]: the top element's own exit (0–0.35 of leaving) is already over at A = 0.65, before the page fade ends at 0.6. The window left is S ∈ (0.6, 0.65), between the end of the uncover slice and the end of the top element's exit. Only `uncover.end ≥ 0.65` would close it completely, for example `Interval(0.3, 0.65)`. That is the owner's call because it changes the decided default. With the default stagger the farthest elements start returning at S = 0.72, which already overlaps the gap.

## Edge cases (each pinned in uncover_gap_test.dart, both installs)

- **Cancelled back gesture:** S falls to 0.05 and then climbs back to 1, staying on the uncover slice the whole time. Every 4 ms frame matches `1 - uncover(S)` and changes by no more than slope × ΔS. No jump to the exit slice's value.
- **Reversal mid-push:** a push popped at S ≈ 0.3 never reaches 1, so the exit slice stays in use both ways. This is checked per frame, and `stack_ops_test` "reversed push" still passes unchanged.
- **Push during a pop:** the top page pops, and at S ≈ 0.5 a new page is pushed over the page below. S follows the popping route down to about 0.24, train-hops to the new route and rises to 1. There is no rest in between, so the uncover slice applies throughout and the re-cover also runs on uncover rather than exit. It is continuous and ends fully covered.
- **Reversal mid-pop:** Flutter cannot reverse a button pop. The cancelled gesture covers this case.

## Tests changed by the new default

- `test/integration/support.dart`: adds `uncoverSlice` / `uncoveredAt`. `coveredAt` is now documented as cover-only.
- Integration (required by the new behaviour): `stack_ops_test` pushReplacement and popUntil uncover checks, the `interactive_back_test` Sampler (all its scenarios start at S = 1) and the `choreography_claims_test` reduced-motion journey (uncover while the top route is reversing). These now use `uncoveredAt`. One test name ("track the uncover curve") and two stale slice comments were also corrected. No assertion was loosened.
- `cn_route_animation_test`: the pop and predictive-back checks use `uncoveredAt`. The parting test samples at 200 ms instead of 300 ms, because at S = 0.25 the uncover is already done. The iOS swipe test drags 20 × 25 px instead of 100/150/150/100, because its 0.25-per-frame jump bound measured the finger's step size once the siblings move during the drag.

## Verification

Root `flutter analyze`: No issues found. Root `flutter test`: 289 pass (280 + 8 gap/edge tests + 1 geometry test). Example `flutter analyze`: No issues found. Example `flutter test`: 7 pass.

## Gotcha

Plain `dart format` now uses the tall style (language 3.7 since R1) and rewrites every file. The repo's style is `dart format --language-version=3.6`.
