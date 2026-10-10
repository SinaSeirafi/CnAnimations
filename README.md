[![CI](https://github.com/SinaSeirafi/CnAnimations/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/SinaSeirafi/CnAnimations/actions/workflows/ci.yml)

# Flutter basic animations simplified

Flutter is made of widgets, right?
So adding a simple fade in or slide animation shouldn't be that hard. 
In fact, it should be as simple as adding a widget on top of your current widget.

This is exactly what this package is trying to help you with.

## Features

### Basic animations
- Fade
- Slide
- Scale

![](https://raw.githubusercontent.com/SinaSeirafi/CnAnimations/master/CnAnimations%20gif%200.2.gif)

### Navigation-driven element choreography
Elements of a page animate with the page transition itself: they leave when another page covers theirs, arrive when the page appears, and follow a swipe-back gesture. The motion is driven by route progress, not by navigation events, so it stays in sync however the route moves.

Pair it with `CnPageRoute` or `CnFadeThroughPageTransitionsBuilder`, and tune it app-wide with `CnRouteChoreography`.

```dart
CnRouteAnimation(
  child: Card(child: ListTile(title: Text('Item'))),
)
```

No `RouteObserver` is needed. The element reads the route it sits on: it arrives with the page, leaves when another page covers it, returns when that page is popped, and follows a swipe-back or predictive-back gesture.


## Getting started
If you only want to use basic animations, you're good to go!

For navigation-driven choreography, use `CnPageRoute`, or add the builder to your theme for every platform:

```dart
import 'package:cn_animations/cn_animations.dart';

MaterialApp(
  theme: ThemeData(
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final platform in TargetPlatform.values)
        platform: const CnFadeThroughPageTransitionsBuilder(),
    }),
  ),
)
```


## Usage
### Basic Animations

Simply add these widgets above target widget.

```dart
CnFade(
  child: child,
) 
```

```dart
CnSlide(
  begin: const Offset(-0.2, 0),
  duration: const Duration(milliseconds: 500),
  // Delay before starting the animation
  delay: const Duration(milliseconds: 100), 
  curve: Curves.easeIn,
  child: child,
) 
```

If you want you can pass the animation controller to the widget. 
But the duration is not overriden.

```dart
CnScale(
  begin: 0.5,
  controller: _controller,
  child: child,
) 
```

Pass an `Animation<double>` instead of a controller to follow any progress value. The widget never starts or disposes it, and reduced motion never overrides it. Give at most one of `controller` and `animation`.

```dart
CnFade(
  animation: animation,
  child: child,
)
```

### Navigation-driven animation (CnRouteAnimation)

Wrap the elements of a page. Each one enters with the page and exits when another page covers it.

```dart
CnRouteAnimation(
  // Where the element enters from, as a fraction of its own size.
  // Default Offset(0, 0.1): from below (the Material convention).
  enterOffset: const Offset(0, 0.1),
  // Where it goes when covered. Default is -enterOffset (covered content
  // moves up and comes back from above).
  exitOffset: const Offset(0, -0.1),
  scale: 0.95,
  child: child,
)
```

Switch parts off per element: `fade: false`, `enter: false` (ignore this page's own enter and exit), `cover: false` (ignore being covered), `enabled: false` (always shown). For full control use `builder`, which receives `shown` and `covered` progress values between 0 and 1:

```dart
CnRouteAnimation(
  builder: (context, progress, child) => Opacity(
    opacity: progress.shown * (1 - progress.covered),
    child: child,
  ),
  child: child,
)
```

#### Parting around the tapped item
In a list or grid, the item you tap stays put while its neighbours part away from it, nearer ones first. The tapped item is detected from the pointer-down: this is on by default and applies to a push within 700 ms of the tap. Nothing else is needed:

```dart
ListView.builder(
  itemBuilder: (context, i) => CnRouteAnimation(
    child: ListTile(
      title: Text('Item $i'),
      onTap: () => Navigator.of(context).push(
        CnPageRoute<void>(builder: (_) => const DetailPage()),
      ),
    ),
  ),
)
```

Use `subject: false` on an element that must never be the subject, `subject: true` to always make it the subject, or `CnRouteChoreography.select(context)` to choose it in code (for example before a programmatic push). Switch detection to `CnSubjectDetection.manual` or `.off` in the scope below.

#### Configuring app-wide or per page
`CnRouteChoreography` is an optional scope. Every field is optional; inner scopes override outer ones field by field, and a widget parameter overrides the scope.

```dart
CnRouteChoreography(
  timing: const CnRouteTiming(
    exitCurve: Curves.easeIn,
    enterCurve: Curves.easeOutCubic,
    exitStagger: 0.12,
    enterStagger: 0.25,
  ),
  parting: const CnPartingSpec(
    distance: Offset(0, 0.6),
    subjectBehavior: CnSubjectBehavior.stay,
  ),
  // Axis along which neighbours part (vertical for lists).
  axis: Axis.vertical,
  subjectDetection: CnSubjectDetection.pointer,
  // Elements built later on a page at rest (scrolled into view) reveal once.
  scrollReveal: const CnScrollReveal(),
  child: child,
)
```

Covered elements leave over `CnRouteTiming.exit` (default `Interval(0.0, 0.35)` of the cover progress) and come back over `CnRouteTiming.uncover` (default `Interval(0.3, 0.65)`, the same length) when the page above pops or is dragged back with predictive back or the iOS edge swipe. So they start returning as the top page's elements finish leaving, rather than after the top page is gone. Set `uncover:` to the `exit` slice to replay the exit backwards instead.

Curves come from `CnRouteTiming.exitCurve` (also used for `uncover`) and `enterCurve`; curves set on the `exit` / `enter` / `uncover` `Interval`s are ignored. To follow your own progress instead of a route (a `PageView`, for example), pass `progress:` (and optionally `coverProgress:`) to the scope. Without any progress source, an element plays one timed entrance of `CnRouteTiming.fallbackDuration` (300 ms).

#### Reduced motion
When the platform asks to disable animations, reduced motion is respected by default, in `fadeOnly` mode: opacity still follows the route, translation and scale are dropped. `CnReducedMotionMode.none` shows elements at rest instead. To opt out entirely, set `respectReducedMotion: false`. Precedence is widget, then scope, then the default (`true`, `fadeOnly`).

```dart
// App-wide: show elements at rest when animations are disabled.
CnRouteChoreography(
  reducedMotionMode: CnReducedMotionMode.none,
  child: child,
)

// App-wide opt-out, and a single widget that opts back in.
CnRouteChoreography(
  respectReducedMotion: false,
  child: CnRouteAnimation(
    respectReducedMotion: true,
    child: child,
  ),
)
```

An external `controller:` or `animation:` on the basic widgets belongs to your app and is never overridden by reduced motion.

#### Routes
Install the fade-through transition for every route, or use `CnPageRoute` for individual routes. Both keep the page below still while its elements exit, then fade the new page in over 400 ms.

```dart
MaterialApp(
  theme: ThemeData(
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final platform in TargetPlatform.values)
        platform: const CnFadeThroughPageTransitionsBuilder(),
    }),
  ),
  home: const HomePage(),
)
```

The theme builder is also the way to use the transition with `Navigator.pages` or go_router: their `MaterialPage`s build Material routes, which take the transition from the theme. There is no `CnPage` form of `CnPageRoute`.

```dart
Navigator.of(context).push(
  CnPageRoute<void>(builder: (_) => const DetailPage()),
);
```

Under Flutter's zoom or Cupertino transitions the page below is hidden by the transition itself, so element exits are mostly invisible; use one of the routes above to see them. Dialogs, bottom sheets, full-screen dialogs and non-opaque routes do not cover the page, so elements stay.

Android predictive back needs `android:enableOnBackInvokedCallback="true"` on the `<application>` in your `AndroidManifest.xml`, as for Flutter's own predictive-back transition.

A `Hero` follows the iOS swipe-back and Android predictive back only when it sets `transitionOnUserGestures: true`, as with Flutter's own transitions; without it the hero stays on its page during the gesture and flies only on push and button pops.

The two installs cover a page under slightly different routes. A `CnPageRoute` page is covered by any opaque, non-full-screen-dialog `PageRoute`, including a plain `PageRouteBuilder(opaque: true)`. A `MaterialPageRoute` page under the theme builder follows Flutter's Material rule: it is covered only by Material routes (`MaterialPageRoute`, `CnPageRoute`) or routes with a delegated transition, so a plain `PageRouteBuilder` above it does not pull its elements out. If your app pushes its own `PageRouteBuilder`s, push the pages below them as `CnPageRoute`.

A `CupertinoPageRoute<T>` page below a `CnPageRoute` receives exits only when both routes have the same type argument (`CupertinoPageRoute.canTransitionTo` compares them); `CnPageRoute` does not fix this. Give the routes matching type arguments, or use the theme builder.


## How it works
A short mental model of the choreography, for deciding whether it fits your app. The [Usage](#usage) sections above say how to configure each part; this section says why it behaves the way it does.

### Progress, not events
A `CnRouteAnimation` does not listen for navigation events. It reads the two animations its `ModalRoute` already exposes: `animation` (this page coming and going) and `secondaryAnimation` (another page coming over this one). Each frame, the element's opacity, offset and scale are computed from those two values and nothing else. There is no `RouteObserver`, no timer, and no `AnimationController` of its own while a route is driving it.

Because the values are the route's own, the elements go wherever the route goes. A swipe-back on iOS or a predictive back on Android moves the route's animation with the finger, so the elements scrub with it; letting go settles the same value back or on to completion, and the elements follow. The package's routes keep the platform's back-gesture wiring for this reason: `CnPageRoute` and `CnFadeThroughPageTransitionsBuilder` wrap the page in a reproduction of the predictive-back and edge-swipe handling that Flutter's stock transitions carry, and those gestures only move the route's progress.

### Four roles, sliced from one transition
An element plays one of four parts, depending on which animation is moving and which way:

| Part | Source | Default slice of progress |
| --- | --- | --- |
| Enter: this page is pushed | `animation` rising 0 → 1 | `CnRouteTiming.enter`, `Interval(0.35, 1.0)` |
| Exit by cover: another page is pushed over this one | `secondaryAnimation` rising 0 → 1 | `CnRouteTiming.exit`, `Interval(0.0, 0.35)` |
| Return by uncover: the page above pops or is dragged back | `secondaryAnimation` falling 1 → 0 | `CnRouteTiming.uncover`, `Interval(0.3, 0.65)`, read on the falling value |
| Exit by pop: this page pops or is swiped back | `animation` falling 1 → 0 | the `exit` slice, measured from the start of leaving |

Slices are fractions of the route transition, so the same timing works on a 300 ms Material route, a 500 ms Cupertino route or the package's 400 ms fade-through. On the fade-through, exits take 140 ms and entrances 260 ms. The exit and uncover slices use `exitCurve` (`Curves.easeIn`); the enter slice uses `enterCurve` (`Curves.easeOutCubic`).

The slices are aligned with the fade-through page transition. On a push, the page below is left untouched by the transition and its elements leave during the first 35 % (47 % with stagger) while the new page fades and lifts in over the last 70 % (from 30 %) and its elements enter from 35 %. On a pop, the top page fades out within the first 40 %, its elements leave within the first 35 % (47 % with stagger), and the page below's elements start returning at that point (cover progress 0.65; staggered elements earlier, by the same shift they left with), so there is no stretch where neither page shows its content. The figures below are for an element with no stagger:

```text
push, 400 ms       0%        35%         100%
  page below       | exit    |
  new page         |      fade in  ------>|
  new page items   |         | enter ---->|

pop, 400 ms        0%        35%  40%  70%   100%
  top page items   | exit    |
  top page         | fade out     |
  page below items |         | return   |
```

The first page of an app, a restored page and a zero-duration route have no push to follow, so their elements play one timed entrance of `fallbackDuration` (300 ms) instead; see [Configuring app-wide or per page](#configuring-app-wide-or-per-page).

### Curves are locked by the rest state that was left
Exits are faster than entrances, so the same progress value needs a different curve depending on which way the route is going. Flutter's `CurvedAnimation` picks its `reverseCurve` by the animation's status, and that is the wrong key here: during a back gesture the route's value drops from 1 while its status stays `forward`, so a status-keyed curve would play the entrance window backwards.

The package instead remembers which rest value, 0 or 1, the animation last sat at (`CnDirectionalCurvedAnimation`, which is exported). While the value is strictly between the two, the curve is the one for leaving that rest, and it holds until the next rest is reached. On the cover source this is also what chooses between the `exit` and `uncover` slices: after leaving 0 the `exit` slice applies, after leaving 1 the `uncover` slice applies.

The effect is that nothing jumps. A cancelled swipe-back (leave 1, come back to 1) reverses on the slice it started on: the top page's elements go back along their exit, and the page below's elements re-cover along their uncover. A push that is popped halfway (leave 0, come back to 0) replays the entrance and the cover exit backwards. The fade-through page transition uses the same rule for its own fade.

### The tapped item is found by pointer-down
Every `CnRouteAnimation` wraps its child in a `Listener` that records a pointer-down on the page's shared record. The listener defers hit-testing to the child and takes no part in the gesture arena, so taps, long-presses and swipes inside the child are untouched. When a cover transition starts (the cover progress leaves 0), the first element to see it resolves the subject once for that transition: an explicit `CnRouteChoreography.select(context)` wins, then an element with `subject: true`, then the last pointer-down if that element is still mounted and no older than 700 ms. Elements with `subject: false` are skipped.

The subject stays where it is (or fades, or grows slightly, per `CnPartingSpec.subjectBehavior`). Every other element on the page becomes a sibling and is given a direction away from the subject along the scope's axis: above moves up, below moves down. A grid cell in the subject's own row parts sideways instead. An element nested inside the subject, or wrapping it, is treated as part of it and stays. Without a subject every element is plain and slides to its own `exitOffset`. See [Parting around the tapped item](#parting-around-the-tapped-item) for the options.

### Stagger is bounded by geometry, not by list index
Each element delays its slice by a factor `f` between 0 and 1 times the stagger (`exitStagger` 0.12, `enterStagger` 0.25 of the transition). `f` is the element's distance along the axis from an anchor, divided by the viewport's extent on that axis: the anchor is the subject's center when there is one, else the viewport's leading edge. Geometry is read from the render tree when the transition starts, so `ListView.builder` and grids need no index bookkeeping, and the ripple starts next to the subject.

Because `f` cannot exceed 1, the whole choreography always ends with the route transition however long the list is. The farthest on-screen element starts its exit at most 48 ms late and its entrance at most 100 ms late on the 400 ms fade-through. Elements laid out outside the viewport (a lazy list's cache extent) get `f = 1` and skip the stagger; they still follow progress, so they are correct if scrolled into view mid-transition. Siblings also move farther the farther they are from the subject (`distanceGrowth`, up to 1.5 times by default).

### Reduced motion defaults to fade-only
When `MediaQuery.disableAnimations` is set, the default is `CnReducedMotionMode.fadeOnly`: opacity keeps following the route, translation and scale are dropped, and the timed entrance fades only. The elements still read progress, so a back gesture still scrubs their opacity. `CnReducedMotionMode.none` renders elements at rest instead. The decision is per element: the widget's `respectReducedMotion` and `reducedMotionMode` win over the scope's, which win over the defaults (`true`, `fadeOnly`), so an app can opt out everywhere and opt one widget back in. A `controller:` or `animation:` passed to the basic widgets is owned by your app and is never overridden. Options are in [Reduced motion](#reduced-motion).

### What covers a page
An element exits by cover only when the route pushed over its page animates the page's `secondaryAnimation`. Flutter decides that per route pair, and the package relies on those rules. Dialogs, bottom sheets, `fullscreenDialog` routes and non-opaque routes do not cover a page, so its elements stay where they are. A `CnPageRoute` page is covered by any opaque, non-full-screen-dialog `PageRoute`; a `MaterialPageRoute` page under the theme builder is covered by Material routes and routes with a delegated transition, which is why the fade-through builder declares a no-op one. The exact rules per install, and the Cupertino type-argument caveat, are in [Routes](#routes).

## Migrating from 0.1.0
1.0.0 removes the route-aware widgets that 0.9.0 deprecated. If you are on 0.1.0 or earlier, move to the new API as follows:

1. Replace `CnRouteAwareAnimation` with `CnRouteAnimation`:

   | `CnRouteAwareAnimation` | `CnRouteAnimation` |
   | --- | --- |
   | `beginSamePage` | `enterOffset` (default is now `Offset(0, 0.1)`, from below) |
   | `endNextPage` | `exitOffset` (default `-enterOffset`) |
   | `showFadeAnimation` | `fade` |
   | `showPush`, `showPop` | `enter` |
   | `showPushNext`, `showPopNext` | `cover` |
   | `animate` | `enabled` |
   | `fadeDuration`, `slideDuration`, delays | `timing` (scope or widget); route transitions run 400 ms |
   | `respectReducedMotion` | `respectReducedMotion` (plus `reducedMotionMode`) |

   Before and after:

   ```dart
   // 0.1.0 (removed in 1.0.0)
   CnRouteAwareAnimation(
     beginSamePage: const Offset(0, -0.1),
     endNextPage: const Offset(0, 0.1),
     child: child,
   )

   // 1.0.0
   CnRouteAnimation(
     enterOffset: const Offset(0, -0.1),
     exitOffset: const Offset(0, 0.1),
     child: child,
   )
   ```

2. Delete `navigatorObservers: [RouteAwareWidget.routeObserver]`; `RouteAwareWidget` and the observer are gone and nothing in the package needs one.
3. If you used a custom `PageRouteBuilder` fade route, switch to `CnPageRoute` or the theme builder. A plain `PageRouteBuilder` over a `MaterialPageRoute` never drives the lower page's exits.
4. If you relied on items animating as they were scrolled into view, set `scrollReveal: const CnScrollReveal()` on the `CnRouteChoreography` scope.
5. Also removed in 1.0.0: `RouteAwareWidget`, `RouteAwareWidget.routeObserver` and the top-level `routeObserver` (no replacement needed), `CnFade.durationInMilliseconds` (use `duration`), `CnSlide.reverseControllerValue` (it had no effect; delete it) and the `timing` parameter of `CnFadeThroughPageTransitionsBuilder` and `CnPageRoute` (it had no effect; set element timing with `CnRouteChoreography` or `CnRouteAnimation.timing`).


## History
cn_animations was first published in January 2023 (0.0.1 to 0.0.3) with `CnFade`, `CnSlide`, `CnScale` and the route-aware widgets. In 2026 it was reworked with Claude, Anthropic's AI model, into the progress-driven route choreography of 0.9.0 and 1.0.0. Claude worked on the design, implementation, tests, reviews and documentation; the package author made the product decisions. If you are coming from 0.0.x, see [Migrating from 0.1.0](#migrating-from-010).

