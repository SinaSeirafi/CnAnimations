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

<!-- part 2: CnRouteAnimation usage snippets -->

### Route aware animation (deprecated)
`CnRouteAwareAnimation` and `RouteAwareWidget` react to navigation events through a `RouteObserver`. They still work in 0.9.0 and will be removed in 1.0.0. See "Migrating from 0.1.0".

![](https://raw.githubusercontent.com/SinaSeirafi/CnAnimations/master/CnAnimations%20RA%20gif%200.1.gif)


## Getting started
If you only want to use basic animations, you're good to go!

For navigation-driven choreography, use `CnPageRoute`, or add the builder to your theme:

```dart
import 'package:cn_animations/cn_animations.dart';

MaterialApp(
  theme: ThemeData(
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CnFadeThroughPageTransitionsBuilder(),
      TargetPlatform.iOS: CnFadeThroughPageTransitionsBuilder(),
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

1. Replace `CnRouteAwareAnimation` with `CnRouteAnimation`. <!-- part 2: parameter mapping table -->
2. Delete `navigatorObservers: [RouteAwareWidget.routeObserver]` unless you use `RouteAwareWidget` yourself.
3. If you used a custom `PageRouteBuilder` fade route, switch to `CnPageRoute` or the theme builder. A plain `PageRouteBuilder` over a `MaterialPageRoute` never drives the lower page's exits.
4. If you relied on items animating as they were scrolled into view, set `scrollReveal: const CnScrollReveal()` on the `CnRouteChoreography` scope.
