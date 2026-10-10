# Fix: stock predictive-back reverse restart (Flutter 3.35+)

Branch `fix/stock-pb-jump`, from `feat/v1-choreography` 77287df.

## Bug

With Flutter's stock `PredictiveBackPageTransitionsBuilder` (the Android
default on 3.35+), a committed back gesture pops the route and then calls
`reverse(from: upperBound)` (flutter/flutter#154718). The route's
`animation` and the page below's `secondaryAnimation` jump from the
release value (0.5 in the probe) to 1.0. Flutter remaps only its own page
transforms. `CnRouteAnimation` read the raw values:

- Page below: parted siblings snapped to fully covered (24–27 px, opacity
  drop 0.6–0.77), hidden about 150 ms, at rest about 320 ms after commit.
- Top page (primary, also confirmed by probe): its elements, already
  exited at 0.5, snapped back to fully shown (opacity 0 -> 1, 6 px) and
  exited again over about 160 ms.

3.29–3.32 commit with `animateBack(0.0)` from the release value: no jump.
Cancel is a steady forward on every SDK.

## Fix

`lib/src/choreography/cn_route_animation.dart`: `_bind` wraps the route's
own `animation` and `secondaryAnimation` (never scope overrides) in a
private `_ReverseRestartGuard` before `CnDirectionalCurvedAnimation`.

- While the source reverses, the value never rises. On a rise it scales
  the source by `k = last / value`, so it continues from where it was and
  reaches 0.0 with the source.
- Turned forward while scaled (a push during the reverse hops the page
  below's train): the map is re-anchored to reach 1.0 with the source.
- A rest restores the identity. The restart notifies 1.0 with status
  completed between the two reverses, so a rest keeps the reverse anchor
  only for a reverse that starts in the same frame
  (`currentSystemFrameTimeStamp`); a rest in a later frame is real.
- Listens to its parent only while it has listeners; updates its map
  before notifying. No version checks.

## Numbers (3.47.7, probe, release at 0.5, flat timing, tapped subject)

| | before | after |
| --- | --- | --- |
| s0 largest frame step | 23.9 px / 0.605 opacity, wrong way | 2.2 px / 0.057, monotonic |
| s0 at rest | ~320 ms after commit | ~176 ms after commit |
| top element `t` | opacity 0 -> 1 at commit, re-exits | stays exited |
| no subject, any element | 3.6 px / 0.605 blink | 0.34 px / 0.057 |

3.32.7: probe rows identical with and without the fix.

## Tests

`test/route/stock_predictive_back_test.dart` (9 tests, system channel):
commit and cancel with and without a tapped subject, a second gesture
after and during a cancel, a push during the committed reverse (one
turn only), routes removed mid-reverse, a plain pop (exact uncover
values). Every sequence starts at the last drag frame. On 3.47.7 without
the fix 4 fail (both commits, second gesture after cancel, push).

| SDK | `flutter test` root | example | `flutter analyze` root / example |
| --- | --- | --- | --- |
| 3.47.7 (clone) | 279 passed | not run | no issues / not run |
| 3.32.7 (global) | 279 passed | 7 passed | no issues / no issues |
| 3.29.0 (clone) | 279 passed | not run | not run |

## Caveats

- Formatting: the repo style is `dart format --language-version=latest`
  (3.47.7 and local 3.8.1 both clean on lib and test). Plain
  `dart format` takes language 3.7 from the pubspec and already rewrites
  7 lib files at 77287df.
- CHANGELOG not updated (outside this task's file scope).
- `PredictiveBackFullscreenPageTransitionsBuilder` takes the same route
  path; not tested separately.
