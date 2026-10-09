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


### Route aware animation (deprecated)
`CnRouteAwareAnimation` and `RouteAwareWidget` react to navigation events through a `RouteObserver`. They still work in 0.9.0 and will be removed in 1.0.0. See "Migrating from 0.1.0".

![](https://raw.githubusercontent.com/SinaSeirafi/CnAnimations/master/CnAnimations%20RA%20gif%200.1.gif)


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

The deprecated `CnRouteAwareAnimation` and `RouteAwareWidget` still need the observer:

```dart
MaterialApp(
  navigatorObservers: [RouteAwareWidget.routeObserver],
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

The two installs cover a page under slightly different routes. A `CnPageRoute` page is covered by any opaque, non-full-screen-dialog `PageRoute`, including a plain `PageRouteBuilder(opaque: true)`. A `MaterialPageRoute` page under the theme builder follows Flutter's Material rule: it is covered only by Material routes (`MaterialPageRoute`, `CnPageRoute`) or routes with a delegated transition, so a plain `PageRouteBuilder` above it does not pull its elements out. If your app pushes its own `PageRouteBuilder`s, push the pages below them as `CnPageRoute`.

A `CupertinoPageRoute<T>` page below a `CnPageRoute` receives exits only when both routes have the same type argument (`CupertinoPageRoute.canTransitionTo` compares them); `CnPageRoute` does not fix this. Give the routes matching type arguments, or use the theme builder.

### Route Aware Animation

If you simply add it on top of your widget, it will do a basic fade and slide upon all navigation events. 

```dart
CnRouteAwareAnimation(
  child: child,
) 
```

You can differentiate between Same page and Next page animations by changing input values. 

With the values below, the child widget comes in to the page from left and goes out towards right. 

```dart
CnRouteAwareAnimation(
  // Where slide begins for Same Page animation 
  beginSamePage: const Offset(-0.5, 0),
  // Where slide ends for Next Page animation 
  endNextPage: const Offset(0.5, 0),
  // Cancel fade animations for all navigation events
  showFadeAnimation: false,
  child: child,
) 
```


## Migrating from 0.1.0
0.9.0 keeps every 0.1.0 widget working. The route-aware widgets are deprecated and will be removed in 1.0.0, so migrate now:

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
   // 0.1.0 (deprecated, removed in 1.0.0)
   CnRouteAwareAnimation(
     beginSamePage: const Offset(0, -0.1),
     endNextPage: const Offset(0, 0.1),
     child: child,
   )

   // 0.9.0
   CnRouteAnimation(
     enterOffset: const Offset(0, -0.1),
     exitOffset: const Offset(0, 0.1),
     child: child,
   )
   ```

2. Delete `navigatorObservers: [RouteAwareWidget.routeObserver]` unless you use `RouteAwareWidget` yourself.
3. If you used a custom `PageRouteBuilder` fade route, switch to `CnPageRoute` or the theme builder. A plain `PageRouteBuilder` over a `MaterialPageRoute` never drives the lower page's exits.
4. If you relied on items animating as they were scrolled into view, set `scrollReveal: const CnScrollReveal()` on the `CnRouteChoreography` scope.
5. Also deprecated, and removed in 1.0.0: `RouteAwareWidget`, `RouteAwareWidget.routeObserver`, the top-level `routeObserver`, `CnFade.durationInMilliseconds` (use `duration`) and `CnSlide.reverseControllerValue` (no effect).

