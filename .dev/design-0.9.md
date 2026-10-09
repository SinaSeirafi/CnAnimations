# cn_animations v-next — design

Status: design for implementation agents. Baseline is the 0.1.0 fix branch (`fix/route-aware-regressions`). Flutter 3.32.7 / Dart 3.8.1 was used for every "verified by running code" claim below (probe tests live in `scratchpad/probe/test/`).

## 1. Goals / non-goals

**Goals**

- G1 Element motion is driven by the route's own progress (`ModalRoute.animation` for this page, `secondaryAnimation` for a page pushed over it). No `RouteObserver` setup. Interactive back (iOS swipe, Android predictive back) scrubs the elements; interruption and cancel are free.
- G2 "Part the list": the tapped item is the subject and stays; siblings move away from it, nearer ones first. Works with `Column`, `ListView.builder` and grids with no index bookkeeping by the developer.
- G3 A matching page route / `PageTransitionsBuilder` (fade-through) so exits are visible instead of being covered by an opaque incoming page.
- G4 Timing discipline: exits ≈ 100–150 ms, entrances ≈ 250–300 ms, stagger bounded by viewport geometry (not list length), off-screen elements do not stagger.
- G5 Scroll reveal is an explicit opt-in, off by default.
- G6 Reduced motion is configurable globally, per page and per widget, extending 0.1.0's `respectReducedMotion` name.
- G7 `CnRouteAnimation(child: x)` with no other arguments does the right thing. Every 0.1.0 public symbol keeps compiling.

**Non-goals**

- No new runtime dependencies; no RouteObserver-based features beyond what 0.1.0 ships (kept, deprecated).
- No shared-element/container-transform implementation; we only stay out of `Hero`'s way.
- No automatic parting across nested navigators or across non-`ModalRoute` containers (tabs, `PageView`); those get an explicit `progress:` hook, nothing more.
- No change to `CnFade`/`CnSlide`/`CnScale` behavior beyond additive constructor parameters.
- No attempt to detect the route that covers us (the framework does not expose the next route); we rely on the framework's `canTransitionTo`/`canTransitionFrom` rules, verified below, plus our own route's rules.

## 2. Public API sketch

All new symbols are exported from `package:cn_animations/cn_animations.dart`. Existing files (`cn_fade.dart`, `cn_slide.dart`, `cn_scale.dart`, `cn_route_aware_animation.dart`, `route_aware_widget.dart`) stay at their paths; new code lives under `lib/src/` and is re-exported.

### 2.1 Configuration value types

```dart
/// How route progress is sliced for element motion. All values are fractions of
/// the route's transition (0..1), so they scale with any route duration.
@immutable
class CnRouteTiming {
  const CnRouteTiming({
    this.exit = const Interval(0.0, 0.35),
    this.enter = const Interval(0.35, 1.0),
    this.uncover = const Interval(0.25, 0.6), // added after review R6
    this.exitStagger = 0.12,
    this.enterStagger = 0.25,
    this.exitCurve = Curves.easeIn,
    this.enterCurve = Curves.easeOutCubic,
    this.fallbackDuration = const Duration(milliseconds: 300),
  });

  /// Slice of progress during which an element leaves (push-over of this page,
  /// pop of this page, and interactive back).
  final Interval exit;
  /// Slice during which an element arrives (push of this page, return after the
  /// page above pops).
  final Interval enter;
  /// Slice of the cover progress over which a covered element returns while
  /// that progress falls from 1 (pop or back gesture of the page above), with
  /// exitStagger / exitCurve. Review R6; see §3.7.
  final Interval uncover;
  /// Maximum extra start delay added to [exit] for the element farthest from the
  /// anchor (tapped item, or the viewport's leading edge). Bounds total time.
  final double exitStagger;
  final double enterStagger;
  final Curve exitCurve;
  final Curve enterCurve;
  /// Duration of the timed entrance used when there is no progress to follow
  /// (no ModalRoute, first route of the app, zero-duration route, scroll reveal).
  final Duration fallbackDuration;

  /// Convenience: the default sliced for a 400 ms route (exit 140 ms, enter 260 ms).
  static const CnRouteTiming standard = CnRouteTiming();

  CnRouteTiming copyWith({...});
}

/// What "reduced motion" means when it applies.
enum CnReducedMotionMode {
  /// Opacity still follows progress; translation and scale are dropped. Default.
  fadeOnly,
  /// Elements render at their rest state immediately.
  none,
}

/// How siblings move away from the tapped item.
@immutable
class CnPartingSpec {
  const CnPartingSpec({
    this.distance = const Offset(0, 0.6),   // fraction of the sibling's own size, per axis
    this.distanceGrowth = 0.5,              // farther siblings move up to (1 + growth)x
    this.fadeSiblings = true,
    this.subjectBehavior = CnSubjectBehavior.stay, // was `subject` (review R10)
  });
  final Offset distance;
  final double distanceGrowth;
  final bool fadeSiblings;
  final CnSubjectBehavior subjectBehavior;
}

enum CnSubjectBehavior { stay, fade, grow }

/// Scroll reveal: timed entrance for elements first built while the page is at rest.
@immutable
class CnScrollReveal {
  const CnScrollReveal({this.duration, this.curve, this.offset = const Offset(0, 0.1), this.once = true});
  static const CnScrollReveal off = CnScrollReveal._off();
  ...
}
```

### 2.2 Widgets

```dart
/// Optional configuration scope. Put it in `MaterialApp.builder` for app-wide
/// defaults, or around one page/list to override. Nearest wins; unset fields
/// inherit from the next scope up, then from built-in defaults.
class CnRouteChoreography extends InheritedWidget {
  const CnRouteChoreography({
    super.key,
    required super.child,
    this.timing,
    this.parting,
    this.scrollReveal,
    this.respectReducedMotion,        // bool?; default true (0.1.0 name)
    this.reducedMotionMode,           // CnReducedMotionMode?; default fadeOnly
    this.axis,                        // Axis?; default vertical. Main axis for parting/stagger
    this.subjectDetection,            // CnSubjectDetection?; default pointer
    this.progress,                    // Animation<double>?; replaces ModalRoute.animation
    this.coverProgress,               // Animation<double>?; replaces ModalRoute.secondaryAnimation
  });

  /// Marks the nearest CnRouteAnimation above [context] as the subject of the
  /// next cover transition (for programmatic navigation / keyboard activation).
  static void select(BuildContext context);
  static CnRouteChoreographyData of(BuildContext context);   // resolved, never null
}

enum CnSubjectDetection { pointer, manual, off }

/// The element wrapper. Replaces CnRouteAwareAnimation.
class CnRouteAnimation extends StatefulWidget {
  const CnRouteAnimation({
    super.key,
    required this.child,
    this.enterOffset = const Offset(0, -0.1), // 0.1.0 default (beginSamePage)
    this.exitOffset,                           // default: enterOffset; used when there is no subject
    this.fade = true,
    this.scale,                                // double? begin scale for enter (e.g. 0.95); null = no scale
    this.enabled = true,
    this.enter = true,                         // take part in this page's enter/exit (animation)
    this.cover = true,                         // take part in cover/uncover (secondaryAnimation)
    this.subject,                              // bool?: force/forbid being the subject
    this.timing,                               // CnRouteTiming? override
    this.respectReducedMotion,                 // bool? override
    this.reducedMotionMode,                    // override
    this.scrollReveal,                         // CnScrollReveal? override
    this.builder,                              // CnRouteAnimationBuilder? custom rendering
  });
  ...
}

/// For `builder:` users: the resolved state for one frame.
typedef CnRouteAnimationBuilder = Widget Function(
    BuildContext context, CnElementProgress progress, Widget? child);

@immutable
class CnElementProgress {
  final double shown;      // 0 hidden .. 1 shown, after curves and stagger (enter/exit of this page)
  final double covered;    // 0 uncovered .. 1 covered (page above)
  final CnElementRole role;   // subject | sibling | plain
  final Offset partingDirection; // unit-ish vector away from subject (zero for plain/subject)
}
enum CnElementRole { subject, sibling, plain }

/// Animation<double> whose curve is locked when the parent leaves a rest state:
/// leaving 0 uses [enter], leaving 1 uses [exit]. Exposed because builder users
/// and the route need the same rule.
class CnDirectionalCurvedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> { ... }
```

### 2.3 Route

```dart
/// Fade-through transition designed for the choreography: the page below keeps
/// its own element exits visible for the first part, the incoming page fades
/// and lifts in over the rest. 400 ms both ways.
class CnFadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const CnFadeThroughPageTransitionsBuilder({this.backgroundColor, this.timing = CnRouteTiming.standard});
  @override Duration get transitionDuration => const Duration(milliseconds: 400);
  @override DelegatedTransitionBuilder? get delegatedTransition;   // non-null (see §3.5)
  @override Widget buildTransitions<T>(...);
}

/// Standalone route for apps that do not want to touch the theme.
class CnPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  CnPageRoute({required this.builder, super.settings, super.fullscreenDialog, this.timing = CnRouteTiming.standard, this.backgroundColor});
  // delegatedTransition, buildTransitions, transitionDuration forward to the builder above;
  // canTransitionTo(next) => next is PageRoute && next.opaque && !next.fullscreenDialog
}
```

### 2.4 Usage snippets

**Simplest case** — wrap and it works. Enters when the page is pushed, leaves when it is popped or covered, scrubs with swipe-back. No observer, no setup.

```dart
CnRouteAnimation(
  child: ListTile(title: const Text('Hello')),
)
```

**A list with part-the-list** — nothing to wire; the pointer-down that leads to the push marks the subject. Index/position comes from geometry, so `ListView.builder` and `GridView.builder` work unchanged.

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, i) => CnRouteAnimation(
    child: ListTile(
      title: Text(items[i].title),
      onTap: () => Navigator.push(context, CnPageRoute(builder: (_) => DetailPage(items[i]))),
    ),
  ),
)
// Programmatic/keyboard navigation: mark the subject explicitly.
CnRouteChoreography.select(itemContext);
Navigator.push(...);
```

**A custom route / theme** — pick one of the two. The theme form makes every `MaterialPageRoute` (named routes, `go_router`'s Material pages) use the fade-through and keeps route types uniform (see §5 for why that matters).

```dart
MaterialApp(
  theme: ThemeData(
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CnFadeThroughPageTransitionsBuilder(),
      TargetPlatform.iOS: CnFadeThroughPageTransitionsBuilder(),
    }),
  ),
  builder: (context, child) => CnRouteChoreography(
    timing: const CnRouteTiming(exitStagger: 0.08),   // app-wide defaults
    child: child!,
  ),
)
// or per push:
Navigator.push(context, CnPageRoute(builder: (_) => const DetailPage()));
```

**Reduced-motion opt-out** — three levels, same name as 0.1.0.

```dart
// Global: ignore MediaQuery.disableAnimations everywhere.
CnRouteChoreography(respectReducedMotion: false, child: child)
// Page: respect it, but fall to rest instead of fading.
CnRouteChoreography(reducedMotionMode: CnReducedMotionMode.none, child: page)
// Widget: this one element always animates.
CnRouteAnimation(respectReducedMotion: false, child: logo)
```

## 3. Architecture

### 3.1 Files and classes

| File (under `lib/src/`) | Owns |
| --- | --- |
| `progress/cn_directional_curved_animation.dart` | `CnDirectionalCurvedAnimation` — rest-locked curve selection (§3.3). |
| `progress/route_progress.dart` | `_RouteRecord` (per-`ModalRoute` shared state via `Expando`), `CnRouteProgress` (resolves `animation`/`secondaryAnimation` or scope overrides; first-frame detection; the shared timed fallback controller factory). |
| `choreography/cn_route_choreography.dart` | `CnRouteChoreography`, `CnRouteChoreographyData` (resolved config with inheritance), `CnRouteTiming`, `CnPartingSpec`, `CnScrollReveal`, enums, `select()`. |
| `choreography/geometry.dart` | Pure functions: viewport rect lookup, on-screen test, anchor distance factor, parting direction for lists and grids. |
| `choreography/cn_route_animation.dart` | `CnRouteAnimation`, `CnElementProgress`, the element state machine, pointer-down subject recording, `builder` support. |
| `route/cn_fade_through_page_transitions_builder.dart` | `CnFadeThroughPageTransitionsBuilder`. |
| `route/cn_page_route.dart` | `CnPageRoute`. |

Existing top-level files keep their public symbols (§6). `lib/cn_animations.dart` exports everything.

### 3.2 How progress reaches an element

1. In `didChangeDependencies`, `CnRouteAnimation` resolves `CnRouteChoreography.of(context)` and `ModalRoute.of(context)`. The primary source is `scope.progress ?? route?.animation`, the cover source is `scope.coverProgress ?? route?.secondaryAnimation`. Both `ModalRoute.animation` and `secondaryAnimation` are stable `ProxyAnimation` objects for the route's lifetime (verified in `routes.dart`: `_animationProxy` / `_secondaryAnimationProxy`; the secondary's *parent* is swapped by `_updateSecondaryAnimation`, the proxy is not), so listeners are attached once and re-attached only if the route object changes.
2. Each source is wrapped in a `CnDirectionalCurvedAnimation` with the element's enter/exit `Interval`s (stagger applied per element, §3.4). Primary gives `shown` (enter 0→1, exit 1→0 through the locked curve). Cover gives `covered`.
3. The element renders `FadeTransition(opacity) → SlideTransition(position) → [ScaleTransition]` fed by `Animation`s derived with `Animatable`s from a `CompoundAnimation` of the two sources (`Listenable.merge` semantics, no `AnimationController` of our own in the route-driven path). Opacity = `lerp(hiddenOpacity, 1, shown) * lerp(1, coverOpacity, covered)`; offset = `enterOffset * (1 - shown) + exitVector * covered`. Nothing here needs `setState`; the only rebuilds are from `didChangeDependencies` when the route or scope changes.
4. When neither source exists (no `ModalRoute`, no scope override), the element owns one `AnimationController` (`fallbackDuration`) and plays the entrance once on mount; cover never happens. This is the `CnFade`+`CnSlide` behavior and keeps "wrap and it works" on pages without a navigator.

### 3.3 `CnDirectionalCurvedAnimation`: why not `CurvedAnimation.reverseCurve`

Exits must be faster than entrances, so the same progress value needs a different curve depending on the direction of travel. `CurvedAnimation(curve:, reverseCurve:)` picks by *status*. Verified by running code (probe H): during an interactive back gesture (`TransitionRoute.handleStartBackGesture` / Cupertino drag) the route controller's value drops from 1 while its status stays `forward`, so `reverseCurve` is never used for a gesture-driven exit; on commit the status flips to `reverse` but `CurvedAnimation` keeps its locked forward direction. The exit would therefore play the *entrance* window backwards. Status is the wrong key; the rest state that was left is the right one.

Rule: the animation tracks which rest value (0 or 1) the parent was last at, in its own `value` getter (every read goes through it, so the lock is consistent within a frame regardless of listener order — `AnimationController` notifies value listeners before status listeners). When the parent's value is exactly 0 or 1 the lock is cleared and the rest is recorded. When the value is strictly between, the curve is `enter` if the last rest was 0, `exit` if it was 1, held until the next rest. A cancelled gesture (leave 1, go back to 1) therefore plays the exit backwards, which is exactly what the page transition does. `status` and `isCompleted`/`isDismissed` delegate to the parent. No listeners of its own, no disposal needs.

### 3.4 Timing: slices of progress and the millisecond mapping

Every element gets its own two `Interval`s from `CnRouteTiming` plus a stagger factor `f ∈ [0, 1]`:

- exit: `Interval(exit.begin + f·exitStagger, min(1, exit.end + f·exitStagger), curve: exitCurve)`
- enter: `Interval(enter.begin + f·enterStagger, 1.0, curve: enterCurve)` — the end is pinned so every element is at rest when the route is.

With the defaults on a 400 ms route (`CnPageRoute`): exits run 140 ms starting within the first 48 ms; entrances run 260 ms (≥160 ms for the farthest element) starting between 140 and 240 ms. On `MaterialPageRoute`'s 300 ms Zoom: 105 / 195 ms. On Cupertino's 500 ms: 175 / 325 ms. Pops use `reverseTransitionDuration`, which equals the forward duration for every stock route, so the exit slice of a popping page is also ~140 ms. Because `f` is bounded, total choreography time never exceeds the route transition no matter how long the list is.

`f` is geometric, not index-based: `f = clamp(|d| / viewportMainExtent, 0, 1)` where `d` is the signed distance along the scope's axis from the anchor to the element's center. Anchor = subject's center when there is a subject, else the viewport's leading edge (top for vertical). Geometry is read at the moment the segment starts (first non-rest value), from `RenderBox.localToGlobal` against the nearest `RenderAbstractViewport.maybeOf(renderObject)` paint rect, or the screen when there is none; cached for the segment. Elements laid out outside the viewport rect get `f = 1` and skip stagger entirely (they still follow progress, so they are correct if scrolled into view mid-transition). Verified by running code: a 600 px `ListView.builder` with 100 px items builds 9 items (cache extent), so 3 are off-screen yet alive — this test is what the on-screen rule is for.

### 3.5 Tapped-item mechanism

State shared by all elements of one page lives in a `_RouteRecord`, held in a package-private `Expando<_RouteRecord>` keyed by the `ModalRoute` (weak; nothing to dispose; works for any route class and needs no scope widget). The record holds: `lastPointerDown` (element state + `Duration` timestamp), the resolved `subject` for the current cover segment, the segment's geometry cache, and `firstFrameStamp` (§3.6).

Detection (`CnSubjectDetection.pointer`, default): every `CnRouteAnimation` wraps its child in `Listener(behavior: HitTestBehavior.deferToChild, onPointerDown: ...)`, which records itself as `lastPointerDown`. `Listener` is not a gesture-arena participant, so taps, long-presses and `Dismissible` swipes inside the child are untouched. When the cover source leaves rest 0 (a page is being pushed over), the first element to observe it resolves the subject once for the segment: `lastPointerDown` if it is still mounted and younger than 700 ms, else none. `subject: true` on an element wins over the pointer; `subject: false` excludes an element from ever being the subject (a "like" button row, a header). `manual` disables the pointer path and only honors `select()`/`subject: true`; `off` disables parting.

Roles for the segment: the subject renders per `CnPartingSpec.subjectBehavior` (renamed from `subject` after review R10; `stay`: no transform, no fade; `fade`; `grow`: scale to 1.04). Siblings get `partingDirection` = sign of their main-axis distance from the subject (above → −1, below → +1); same-row siblings in a grid (|main-axis distance| < half the subject's extent) part along the cross axis instead. Exit vector = `distance ⊙ direction × (1 + distanceGrowth·f)`; delay factor `f` as in §3.4, so the ripple starts next to the subject. Elements built *during* the segment (lazy list rebuilt mid-transition) compute their role from the cached subject rect on first layout (post-frame) and render hidden-for-cover until then; before geometry is known they use `f = 1`, which is the no-stagger value, so the one-frame correction is monotonic.

### 3.6 Rest-state mounts: initial entrance vs scroll reveal

Verified by running code (probe E): the first route of a `Navigator` and every restored route go through `didAdd`, which sets the controller to its upper bound before the first frame, so `animation` is `completed/1.0` when their elements mount; the same is true for a zero-duration route one frame in. Progress-driven alone would give those pages no entrance, while 0.1.0 plays one (its `subscribe` calls `didPush`). The record's `firstFrameStamp` is set by the first element that binds to a route at rest; an element that mounts in the same frame (`SchedulerBinding.instance.currentFrameTimeStamp` equal) is an *initial* mount and plays the timed fallback entrance (§3.2 step 4, with stagger from geometry). An element that mounts on a later frame while the route is at rest is a *late* mount: it renders at rest unless `scrollReveal` is enabled, in which case it plays the timed entrance once (`once: true` keyed on the element state). That is the whole of G5: the old side effect becomes a named, default-off path.

### 3.7 The matching route and how it plays with `pageTransitionsTheme`

`CnFadeThroughPageTransitionsBuilder.buildTransitions` renders the incoming page as `FadeTransition(opacity: CnDirectionalCurvedAnimation(animation, enter: Interval(0.3, 1.0), exit: Interval(0.6, 1.0)))` with a small lift (`SlideTransition` from `Offset(0, 0.02)`), over `backgroundColor ?? ColorScheme.surface`. So during a push the page below is fully visible for the first ~30 % while its elements exit (0–35 % + stagger), and during a pop the top page is gone within the first 40 % while the page below's elements return over `exit` reversed (they move while `secondaryAnimation ∈ [0, 0.47]`, i.e. the last ~55 % of the pop, after the top page has faded).

**Corrected after review R6 (0.9.0, slice R6).** Replaying `exit` backwards left a gap: the top element's own exit ends at A = 0.65 and the page below only started returning at S = 0.35 (0.47 for the farthest elements), so with flat timing about a quarter of a pop (S ∈ [0.35, 0.65]; 7 of 24 frames at 60 Hz) and of a back gesture showed neither page's elements. `CnRouteTiming.uncover` (default `Interval(0.25, 0.6)`, read on S as-is, stagger and curve as `exit`) now applies while S falls from 1 (pop, predictive back, iOS swipe), rest-locked like the other slices (`CnDirectionalCurvedAnimation`, `exit` after S leaves 0, `uncover` after it leaves 1), so a cancelled gesture or a reversal never switches slice mid-flight. Measured (flat timing, `test/route/uncover_gap_test.dart`): the gap shrinks to S ∈ (0.6, 0.65), 1 frame of a pop. Closing it fully would need `uncover.end ≥ 0.65`.

`delegatedTransition` is non-null and returns `child` unchanged (a no-op `DelegatedTransitionBuilder`). This is load-bearing, verified by running code (probes E2/G): `MaterialRouteTransitionMixin.canTransitionTo` returns true only if the next route is also a Material route *or* has a non-null `delegatedTransition`. A plain `PageRouteBuilder` (0.0.3's example route) pushed over a `MaterialPageRoute` leaves that page's `secondaryAnimation` dismissed — its elements would never exit. With the no-op delegate the page below animates its secondary and keeps its own (Zoom/Cupertino) secondary transition suppressed, which is what we want: our elements do the exit, the page itself holds still.

Two ways to install, same transition: `theme.pageTransitionsTheme` (every `MaterialPageRoute`, named routes and router packages included), or `CnPageRoute` per push. `CnPageRoute` mixes in `MaterialRouteTransitionMixin` and overrides `buildTransitions` to call the builder directly (ignoring the theme), so Material routes below recognize it by type and not only through the delegate — this matters because of a Flutter generic-type quirk (§5). `CnPageRoute.canTransitionTo(next)` is `next is PageRoute && next.opaque && !next.fullscreenDialog`: dialogs, sheets, and transparent overlay routes do not pull the page's elements out (verified: probe G `cn-under-transparentPRB` stays dismissed, `cn-under-cn` animates).

## 4. Behavior table

`A` = this route's `animation`, `S` = its `secondaryAnimation`. "rest-locked" means the curve chosen by §3.3. Verified rows cite the probe that produced the values.

| Route event | A | S | Subject | Sibling | Plain element (no subject) | No ModalRoute / scope `progress:` |
| --- | --- | --- | --- | --- | --- | --- |
| Page pushed (`push`) | 0→1 forward | 0 | n/a (no cover) | n/a | enters over `enter` slice, staggered from viewport top | enters once via timed fallback (no route); follows `progress:` if given |
| First route / restored / zero-duration push | 1 before first frame (probe E) | 0 | n/a | n/a | initial mount → timed fallback entrance, staggered; late mounts → rest (or scroll reveal if on) | same |
| Another page pushed over (opaque `PageRoute`, Material/Cupertino/Cn) | 1 | 0→1 forward (probe E2 `prb-under-material`, G) | stays (or fade/grow) | moves away from subject along axis, nearer first, fades if `fadeSiblings` | slides to `exitOffset` and fades, staggered from top | no cover source → nothing |
| That page pops (button) | 1 | 1→0 reverse (probe E `a-popUntil`) | returns to rest (no-op) | returns along the same vector, over `uncover` (R6) | returns | nothing |
| That page is swipe-backed / predictive-backed | 1 | 1→x, status `forward` while dragging (probes C, D) | returns proportionally; gesture cancel re-exits smoothly | same, rest-locked on the `uncover` slice both ways (R6) | same | nothing |
| This page pops (button) | 1→0 reverse | 0 | n/a | n/a | exits over the `exit` slice (fast), fades | nothing (widget is being disposed) |
| This page swipe-backed / predictive-backed | 1→x forward while dragging, then `reverse` on commit (probes C, D) | 0 | n/a | n/a | exit curve locked while leaving 1; scrubs with the finger; cancel reverses the exit | nothing |
| `showDialog`, `showGeneralDialog`, `showModalBottomSheet`, `showCupertinoDialog`, `showCupertinoModalPopup` over this page | 1 | stays 0 (probes A, A2, B1, B2) | nothing | nothing | nothing | nothing |
| `MaterialPageRoute(fullscreenDialog: true)` over this page | 1 | stays 0 (B1, B2) | nothing | nothing | nothing | nothing |
| `PageRouteBuilder(opaque: false)` over this page | 1 | 0→1 only when this page is itself a plain `PageRouteBuilder`; stays 0 under `MaterialPageRoute` (theme or not) and `CnPageRoute` (probe G; review R7, `test/integration/overlays_test.dart`) | parts | parts | exits | — |
| `pushReplacement` of this page | 1 | 0→1 (probe E `b-replaced`) | parts | parts | exits, then the route is disposed | — |
| `popUntil` past several pages | 1 | 1→0 once, driven by the top popped route (probe E) | returns | returns | returns once | — |
| Reduced motion on (`respectReducedMotion` resolves true, `fadeOnly`) | as above | as above | opacity only | opacity only, no translation | opacity only | timed fallback fades only |
| Reduced motion on, `none` | — | — | rest | rest | rest | rest |
| `enabled: false` | — | — | child as-is | child as-is | child as-is | child as-is |

## 5. Edge cases

- **Dialogs and sheets.** Verified by running code: every stock popup (`DialogRoute`, `RawDialogRoute`, `ModalBottomSheetRoute`, `CupertinoDialogRoute`, `CupertinoModalPopupRoute`) is a `PopupRoute`, not a `PageRoute`, and `PageRoute.canTransitionTo` (and the Material/Cupertino mixin overrides) reject it, so the page below's `secondaryAnimation` stays dismissed under Material, Cupertino *and* `PageRouteBuilder` pages. The owner's "does animate in some cases" is the non-opaque `PageRoute` case (`PageRouteBuilder(opaque: false)`, custom `PageRoute` subclasses), and only when the page below is itself a plain `PageRouteBuilder` (or another route without the Material/Cupertino mixin): the base `PageRoute.canTransitionTo` only checks `is PageRoute`, so that page animates. A `MaterialPageRoute` page (theme or not) uses the Material mixin's override, which requires a Material next route or a non-null `delegatedTransition`, so a plain `PageRouteBuilder` over it leaves its `secondaryAnimation` at 0 (corrected after review R7). Design: `CnPageRoute` suppresses it by `opaque` check; for other page routes we document "use `showGeneralDialog`/`PopupRoute` for overlays, or subclass and override `canTransitionFrom => false`". We deliberately do not add an element-level "am I under a dialog" heuristic — the route stack is not inspectable from a widget and `ModalRoute.isCurrent` cannot distinguish dialog from page.
- **Flutter generic-type quirk (verified, probe G).** `MaterialRouteTransitionMixin.canTransitionTo` tests `nextRoute is ModalRoute<T>` with the *lower* route's `T`. A `MaterialPageRoute<int>` beneath a `CnRoute<dynamic>` that relies only on `delegatedTransition` never animates its secondary. Mitigations, in order: (1) `CnPageRoute` mixes in `MaterialRouteTransitionMixin`, so the `is MaterialRouteTransitionMixin` branch passes regardless of `T`; (2) recommend the theme form, which keeps every route a `MaterialPageRoute`; (3) README note for `CupertinoPageRoute<T>` users (Cupertino mixin has the same check and no Cn mixin can satisfy both).
- **Nested navigators.** `ModalRoute.of` finds the nearest route. Elements inside a nested navigator's page react to that navigator's pushes only; an outer push does not touch them (the inner route is nobody's `nextRoute`). Documented; `CnRouteChoreography(coverProgress:)` lets an app forward the outer route's `secondaryAnimation` if it wants both.
- **Zero-duration routes.** `AnimationController.forward()` with `Duration.zero` completes synchronously, so `A` is already 1 at the elements' first frame (probe E). They are initial mounts and play the timed fallback entrance; set `CnRouteTiming(fallbackDuration: Duration.zero)` or `enter: false` to make them instant. The page below sees `S` jump 0→1 in one frame: elements snap to exited (no visible motion, no stagger needed) and snap back on pop.
- **`pushReplacement`.** The replaced page's `S` runs 0→1 (probe E); its elements exit normally and the route is then disposed. The page beneath both keeps `S` at 1 through the train-hop (believed from `_updateSecondaryAnimation` source; not run).
- **`popUntil`.** Each popped route reverses its controller, but only the top one is visible; the surviving page's `S` runs 1→0 once (probe E), so its elements return once. Nothing special to do.
- **State restoration.** Restored routes are `didAdd`ed: top page elements are initial mounts → timed entrance (we accept this: a cold start deserves an entrance); pages beneath are offstage, play the timed entrance unseen, and are at rest when uncovered. No restoration IDs are introduced; the package stores nothing.
- **`Hero` on the tapped item.** With `stay` the subject gets no transform or opacity change, so the Hero's source placeholder and flight are undisturbed and the shuttle starts from the element's true rect. `grow` scales the *placeholder* (Hero replaces the child with a sized box during flight), which is harmless but pointless — docs recommend `stay` with Hero. Sibling parting continues under the flight. On swipe-back the Hero flies in reverse under the framework's own gesture handling; our siblings scrub in parallel.
- **Lists rebuilt mid-transition.** New element states compute role/geometry post-frame from the record's cached subject rect and viewport (§3.5); disposed elements simply drop their listeners. A `setState` that rebuilds all items mid-segment does not reset locks because the lock lives in the element state, keyed by the same route objects. If the subject itself is disposed mid-segment (filtered out), siblings keep their computed vectors for the segment.
- **RTL.** Vertical parting is direction-free. Cross-axis parting in grids and horizontal `enterOffset`/`exitOffset` use `SlideTransition.textDirection`-aware semantics: offsets are specified in logical `Offset` and flipped for RTL via `Directionality.of(context)` in the element (matches `SlideTransition(textDirection:)`). Horizontal lists (`axis: horizontal`) part "before/after" in reading order.
- **Interactive back on the covering page while the page below is scrolled.** Geometry is read at segment start from the actual viewport, so stagger follows the scroll position at that moment; a scroll during the gesture does not recompute (cached), which is acceptable because the page below cannot be scrolled during a back gesture.

## 6. Backward compatibility, migration from 0.1.0, version

**Kept and unchanged in behavior:** `CnFade`, `CnSlide`, `CnScale` (0.1.0 bodies, including `respectReducedMotion`). Additive only: each gains an optional `animation: Animation<double>?` parameter (progress source that, like `controller`, disables the internal controller — lets `CnSlide` ride a route's animation directly for builder users). No new required arguments, all constructors stay `const`.

**Kept, deprecated (removed in the next major):**

- `CnRouteAwareAnimation` — `@Deprecated('Use CnRouteAnimation; it needs no RouteObserver')`. Body untouched (0.1.0 ValueNotifier design). Mapping documented in its dartdoc: `beginSamePage → enterOffset`, `endNextPage → exitOffset`, `showFadeAnimation → fade`, `animate → enabled`, `showPush/showPop → enter`, `showPushNext/showPopNext → cover`, `respectReducedMotion → respectReducedMotion`, `fadeDuration/slideDuration/*Delay* → CnRouteTiming` (slices, not durations).
- `RouteAwareWidget` and `RouteAwareWidget.routeObserver` — deprecated with the message "no longer needed by cn_animations; keep it only for your own `onPush*` callbacks". The already-deprecated top-level `routeObserver` stays as is. Nothing in the new code touches the observer, so an app that still registers it loses nothing.
- Top-level import paths `package:cn_animations/route_aware_widget.dart` etc. keep working (the example imported one directly in 0.0.3).

**Migration guide (README section "Migrating from 0.1.0"):** (1) replace `CnRouteAwareAnimation` with `CnRouteAnimation` using the mapping; (2) delete `navigatorObservers: [RouteAwareWidget.routeObserver]` unless you use `RouteAwareWidget` yourself; (3) if you used a custom `PageRouteBuilder` fade route as in the old example, switch to `CnPageRoute` or the theme builder — a plain `PageRouteBuilder` over a `MaterialPageRoute` never drives the lower page's exits (§3.7); (4) if you relied on items animating as they were scrolled into view, set `scrollReveal: const CnScrollReveal()` on the scope. A one-line `dart fix` is not provided (no data-driven fix file); the mapping is mechanical enough for find-and-replace.

**Version: 1.0.0** (recommended) rather than 0.2.0. Reasons: the central concept changes (event-triggered → progress-driven), the public surface is designed as a whole and tested, and under pub's semver a 1.0.0 lets deprecated 0.x widgets be removed in 2.0.0 with a conventional signal, whereas 0.2.0 → 0.3.0 would make every later removal look like a routine minor. The 0.1.0 widgets remaining compilable and deprecated is exactly the compatibility story a 1.0.0 should ship with. The case for 0.2.0 is only that the parting heuristics may need a second round after device feedback; the `CnPartingSpec`/`CnRouteTiming` value types are where that tuning would land, without breaking signatures, so it does not outweigh the above. Owner decision (§10 Q1).

## 7. Implementation slices

Base branch: `fix/route-aware-regressions` at 65182fb (0.1.0). Each slice owns the listed files exclusively; shared files (`lib/cn_animations.dart`, `CHANGELOG.md`, `README.md`, `pubspec.yaml`) are owned by slice F only. Interfaces are fixed by §2; a slice may add private members freely but may not change a public signature without a design update.

| # | Slice | Model | Owns (create/modify) | Tests (owned) | Depends on |
| --- | --- | --- | --- | --- | --- |
| A | Progress foundation | opus | `lib/src/progress/cn_directional_curved_animation.dart`, `lib/src/progress/route_progress.dart` | `test/progress/directional_curve_test.dart`, `test/progress/route_progress_test.dart` | — |
| B | Scope, config, geometry | opus | `lib/src/choreography/cn_route_choreography.dart`, `lib/src/choreography/geometry.dart` | `test/choreography/scope_test.dart`, `test/choreography/geometry_test.dart` | — |
| C | Matching route | sonnet | `lib/src/route/cn_fade_through_page_transitions_builder.dart`, `lib/src/route/cn_page_route.dart` | `test/route/cn_page_route_test.dart` | — (uses `CnDirectionalCurvedAnimation`; until A lands, ship with a private copy of the ≤40-line class and swap the import in F) |
| D | Element widget | opus | `lib/src/choreography/cn_route_animation.dart` | `test/choreography/cn_route_animation_test.dart` | A, B |
| E | Basic widgets `animation:` param + deprecations | sonnet | `lib/cn_fade.dart`, `lib/cn_slide.dart`, `lib/cn_scale.dart`, `lib/cn_route_aware_animation.dart`, `lib/route_aware_widget.dart` | extend `test/basic_animations_test.dart`, `test/route_aware_test.dart` (both exist; E owns them) | — |
| F | Exports, docs, version | sonnet | `lib/cn_animations.dart`, `README.md`, `CHANGELOG.md`, `pubspec.yaml` (+ example `pubspec.yaml`) | `test/exports_test.dart` (every public symbol resolves) | A–E |
| G | Example app | sonnet | `example/lib/**` | `example/test/smoke_test.dart` | D, C |
| H | Integration and claim tests | opus | `test/integration/**` (gesture, dialog, parting, popUntil, replacement, reduced motion, leak check) | all in this folder | D, C, F |

**Order and parallelism.** Wave 1: A, B, C, E in parallel (disjoint files, no dependencies). Wave 2: D (needs A and B; also the slice most likely to find interface gaps — it may file a design note but not edit A/B files; the A/B agent is re-invoked for fixes). Wave 3: F, G, H in parallel (G and H depend on D and C; F merges exports last within the wave so G/H import through `package:cn_animations/cn_animations.dart` only after F's export commit — practically: F runs first for a few minutes, then G and H start). Heavy verification (`flutter analyze`, full `flutter test`, example `flutter test`) runs once on the merged tree after wave 3.

**Per-slice acceptance criteria**

- A: `CnDirectionalCurvedAnimation` picks `enter` when the parent leaves 0 and `exit` when it leaves 1, holds the choice until the next rest, and is unaffected by status flips (unit test drives an `AnimationController` through `value = 0.95` from completed, then `reverse()`, asserting the curve in use each step — the probe-H scenario). `route_progress.dart` resolves sources from `ModalRoute` and from scope overrides, keeps one `_RouteRecord` per route (`identical` across two elements on the same page), flags initial vs late mounts by frame timestamp, and exposes a timed fallback controller factory that disposes with its owner. No allocations retained after the route is gone (`Expando` only).
- B: `CnRouteChoreography.of` merges nested scopes field-by-field (inner non-null wins) and returns defaults with no scope. `geometry.dart` is pure: given element rect, viewport rect, axis and optional subject rect, returns `(onScreen, f, direction)`; tests cover above/below/same-row-grid, off-screen cache-extent items (`f == 1`, `onScreen == false`), horizontal axis, and RTL flip of cross-axis direction.
- C: the builder's transition fades the incoming page in over `[0.3, 1]` and out over `[0.6, 1]` on pop (asserted via `FadeTransition.opacity.value` at fixed pumps); `delegatedTransition` is non-null and returns its child; `MaterialPageRoute<int>` beneath `CnPageRoute<void>` drives its `secondaryAnimation` (the probe-G quirk, inverted to pass); `CnPageRoute.canTransitionTo` rejects `PageRouteBuilder(opaque: false)`, `fullscreenDialog` and dialogs; `transitionDuration == reverseTransitionDuration == 400 ms`; installing via `pageTransitionsTheme` makes a plain `MaterialPageRoute` use it.
- D: the §4 table rows for push, pop, cover, uncover, no-ModalRoute, initial mount, late mount with/without `scrollReveal`, `enabled: false`, reduced-motion `fadeOnly` and `none`, and `respectReducedMotion` precedence (widget > scope > default). No `AnimationController` is created in the route-driven path (assert via `FlutterMemoryAllocations` or a debug counter). Pointer-down records the subject; `subject: false` excludes; `select()` works without a pointer. `builder:` receives correct `CnElementProgress`. No `setState` during build (the 0.1.0 pitfall: a test toggles `enabled` across a push).
- E: `CnFade/CnSlide/CnScale(animation:)` follows the given animation and never starts the internal controller; all 0.1.0 tests still pass unchanged; deprecations carry messages and `analyze` is clean with `deprecated_member_use_from_same_package` ignored only where the old widgets reference each other.
- F: `flutter pub publish --dry-run` passes; README has the four §2.4 snippets and the migration section; CHANGELOG lists additions, deprecations and the §5 route-type note; `pubspec` version per owner decision (§10 Q1), SDK constraints unchanged from 0.1.0.
- G and H: §9 and §8 respectively.

## 8. Test strategy

All tests are `flutter_test` widget tests; no device. The helpers below were exercised in the scratch probes and are known to work on Flutter 3.32.7.

**Driving interactive back without a platform.**

- Android predictive back: `TransitionRoute.handleStartBackGesture(progress:)`, `handleUpdateBackGestureProgress(progress:)`, `handleCancelBackGesture()`, `handleCommitBackGesture()` are public on `TransitionRoute` (the `PredictiveBackRoute` interface). Verified: start at 0.95 then update to 0.6 sets `animation.value` accordingly with status `forward`, the page below's `secondaryAnimation` follows, cancel animates back to 1 (status stays `forward`), commit flips to `reverse` and runs to 0. Tests assert element `shown`/`covered` values at each step and that the curve in use is the exit curve throughout.
- iOS swipe-back: `ThemeData(platform: TargetPlatform.iOS)` + `MaterialPageRoute`, then `tester.startGesture(Offset(5, y))`, `moveBy(Offset(100, 0))`, `pump()`. Verified: the top route's `animation` drops (0.88, 0.63, …), the lower route's `secondaryAnimation` mirrors it, `navigator.userGestureInProgress` is true, and release below the threshold animates back. Tests scrub to three points, release, and assert monotonic return of sibling offsets with no discontinuity (sample every pump, assert |Δ| ≤ a bound).
- Reverse direction mid-flight (push then immediately pop) to check locks: leaving 0 locks `enter`; a `pop()` at 0.4 makes `A` reverse from 0.4 — the lock stays `enter` (we left rest 0), so the entrance plays backwards. Assert no jump.

**Dialog and `secondaryAnimation` claims (the §4 rows).** One test per overlay kind — `showDialog`, `showGeneralDialog`, `showModalBottomSheet`, `showCupertinoDialog`, `showCupertinoModalPopup`, `MaterialPageRoute(fullscreenDialog: true)` — over a `MaterialPageRoute`, a `PageRouteBuilder` and a `CnPageRoute` page: pump 3 frames, assert `secondaryAnimation.isDismissed` and element `covered == 0`. Counter-tests: `PageRouteBuilder(opaque: false)` over a plain `PageRouteBuilder` page *does* cover (base `PageRoute` rule); over a `MaterialPageRoute` page (theme or not) and over a `CnPageRoute` it does not (corrected after review R7; pinned in `test/integration/overlays_test.dart`). The generic quirk: `MaterialPageRoute<int>` under `CnPageRoute<void>` covers; under a bare `PageRouteBuilder` does not (regression guard for §3.7's reasoning).

**Choreography claims.**
- Stagger bound: a 200-item `ListView.builder` with 100 px items in a 600 px viewport; assert the last on-screen element's exit start ≤ `exit.begin + exitStagger`, off-screen built items have `f == 1`, and every element is at rest at `A == 1` / `S == 0`.
- Parting: tap item 4 of 9, push; assert items 0–3 move up (negative dy), 5–8 move down, item 4 unchanged, and |dy| grows with distance; with a 3-column grid tap the center cell and assert same-row cells move horizontally.
- Scroll reveal: build a list at rest, scroll 800 px; with default config newly built items have opacity 1 on first frame; with `CnScrollReveal()` they start below 1 and reach 1 after `fallbackDuration`.
- Initial mount: `MaterialApp(home: …)` first frame — elements start hidden and reach rest after `fallbackDuration` (the `didAdd` case); the same for a `transitionDuration: Duration.zero` push.
- No ModalRoute: elements inside a bare `MaterialApp.builder` child (no Navigator) play the timed entrance once.
- Reduced motion: `MediaQuery(disableAnimations: true)` → `fadeOnly`: `SlideTransition.position.value == Offset.zero` at every pump while opacity still tracks `A`; `none`: opacity 1 at first frame; `respectReducedMotion: false` at widget level overrides a scope that sets it true.
- Leaks: reuse the 0.1.0 `CurvedAnimationTracker` (`FlutterMemoryAllocations`) across push/pop/dispose cycles; also assert the `Expando` record is not reachable after the route is disposed (hold it via `WeakReference`, force a GC-free check by asserting the route-keyed lookup returns null for a new route object — a strict GC test is not possible in `flutter_test`, so this is best effort and documented as such).
- Mid-transition rebuild: push, pump to 0.3, `setState` the list to a new filtered set, pump to rest; assert no exception and all elements at rest.

**Not covered by automated tests (needs a device):** real predictive-back feel, Hero flight visuals, 120 Hz smoothness. The example app (§9) has toggles for these.

## 9. Example app plan

`example/lib/main.dart` becomes a small multi-page app; keep `restart_widget.dart`. The `MaterialApp` installs `CnFadeThroughPageTransitionsBuilder` for all platforms and wraps `builder:` in a `CnRouteChoreography` whose fields are bound to an in-memory `SettingsModel` (`ChangeNotifier`) so toggles apply app-wide without restart. No `navigatorObservers` line — its absence is part of the demo.

1. **Home: "Basics"** — the 0.1.0 column (`CnFade`, `CnScale`, `CnSlide`, chained, combined) kept as-is, plus a bottom nav to the pages below. Shows that the simple widgets are unchanged.
2. **List** — `ListView.builder` of 40 cards, each `CnRouteAnimation(child: Card(... onTap: push Detail))`. Demonstrates parting on tap, stagger bound (scroll down, tap near the bottom), scroll reveal toggle (off by default: scroll, nothing animates; on: items reveal), and swipe-back/predictive-back scrubbing of siblings. Header row uses `subject: false`.
3. **Grid** — 3-column `GridView.builder`, same wrapper; demonstrates cross-axis parting of same-row cells.
4. **Detail** — a `Hero` image whose tag matches the tapped card (shows `stay`), a few `CnRouteAnimation` paragraphs entering staggered, an "Open dialog" button (`showDialog`, proves the page's items do not exit), an "Overlay (elements stay)" button (`PageRouteBuilder(opaque: false)`, a counter-demo: it does not cover a Material or `CnPageRoute` detail page, so nothing exits; corrected after review R3/R7), a "Replace" button (`pushReplacement` to a second detail), and "Pop to root" (`popUntil`).
5. **Settings** — switches: respect reduced motion / mode (`fadeOnly`/`none`), scroll reveal, subject detection (pointer/manual/off), subject behavior (stay/fade/grow), route (Cn fade-through theme vs platform default — rebuilds `MaterialApp` with a different `pageTransitionsTheme`; demonstrates that exits are hidden under Zoom/Cupertino and visible under fade-through), and a timing preset (standard / slow-motion ×4 via `timeDilation` for inspection).
6. **No-navigator pane** — a page containing a `PageView` whose pages hold `CnRouteAnimation`s with `CnRouteChoreography(progress: pageController-derived animation)`, showing the explicit progress hook and the timed fallback when no hook is given.

`example/test/smoke_test.dart`: app builds, each page can be reached, a tap on list item 3 parts neighbors, dialog does not cover.

## 10. Open questions for the owner

1. **Version: 1.0.0 or 0.2.0?** Recommended default: 1.0.0 (§6). Implementation is identical either way; only `pubspec.yaml` and the CHANGELOG heading differ.
2. **Reduced motion default meaning: `fadeOnly` or `none`?** Recommended default: `fadeOnly`. Flutter does not shorten route transitions when `disableAnimations` is set, so a page still cross-fades over 400 ms; elements that fade in step read as "no motion" while popping in at frame 1 reads as broken. 0.1.0's basic widgets jump to rest — they keep that, because they have no page to sync with.
3. **Pointer-based subject detection on by default (700 ms window)?** Recommended default: on. Risk is a wrong subject when a non-navigating tap is followed within 700 ms by a programmatic push; `subject: false` on such rows and `CnSubjectDetection.manual` cover it. The alternative (manual only) costs every list one `select()` call and most adopters would not discover parting at all.
4. **Default entrance direction: keep 0.1.0's from-above `Offset(0, -0.1)` or switch to Material's from-below `Offset(0, 0.1)`?** Recommended default: keep `-0.1` for visual continuity with 0.1.0 migrations; the fade-through builder lifts the page from below by 0.02 regardless, so both read as "arriving".

## Verification ledger

Verified by running code (Flutter 3.32.7, `scratchpad/probe/test/probe*_test.dart`): dialogs/sheets/Cupertino popups/`fullscreenDialog` never drive `secondaryAnimation` under Material, Cupertino or `PageRouteBuilder` pages; `PageRouteBuilder(opaque: false)` does only over a plain `PageRouteBuilder` page, not over a `MaterialPageRoute` or `CnPageRoute` page (corrected after review R7); a bare `PageRouteBuilder` over a `MaterialPageRoute` does not drive the Material page's secondary, a `MaterialPageRoute` over a `PageRouteBuilder` does; a route with non-null `delegatedTransition` makes `MaterialPageRoute<dynamic>` beneath it animate but `MaterialPageRoute<int>` beneath a `<dynamic>`/`<void>` route does not (generic quirk); Cupertino swipe-back and the public `handleStartBackGesture` family scrub `animation` with status `forward` while dragging, cancel returns with status `forward`, commit flips to `reverse`; the previous route's `secondaryAnimation` mirrors the gesture; `CurvedAnimation.reverseCurve` is not used during a gesture exit; home route and zero-duration route are at `completed/1.0` on their first frame; `pushReplacement` runs the replaced route's secondary 0→1; `popUntil` runs the surviving route's secondary 1→0 once; `ListView.builder` builds cache-extent items beyond the viewport (9 built for 6 visible); `RenderAbstractViewport.maybeOf` and `IndexedSemantics` ancestors are available from an item's context.

Believed from reading Flutter source, not run: `_updateSecondaryAnimation` train-hopping keeps the page two levels down covered during `pushReplacement`; `AnimationController` notifies value listeners before status listeners (`_tick` order); `Expando` keyed on `Route` objects is weak; `didAdd` is used for restored routes; the Material/Cupertino mixins' `canTransitionTo` branch on `is MaterialRouteTransitionMixin` passes irrespective of `T`.

## Owner decisions (2026-10-09, supersede §10)

- Q1: superseded. Two releases: 0.9.0 (new APIs + deprecated old widgets), then 1.0.0 (old widgets removed).
- Q2: reduced motion default `fadeOnly`.
- Q3: pointer subject detection on by default (700 ms window).
- Q4: **`CnRouteAnimation.enterOffset` defaults to `Offset(0, 0.1)` (from below, the Material convention), not -0.1.** The owner notes there are no existing users to keep continuity for. The deprecated `CnRouteAwareAnimation` keeps its own default unchanged.
