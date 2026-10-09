# Flutter basic animations simplified

Flutter is made of widgets, right?
So adding a simple fade in or slide animation shouldn't be that hard. 
In fact, it should be as simple as adding a widget on top of your current widget.

This is exactly what this package is trying to help you with.

## Features

### Basic Animations: 
- Fade
- Slide
- Scale

![](https://raw.githubusercontent.com/SinaSeirafi/CnAnimations/master/CnAnimations%20gif%200.2.gif)

### Route Aware Animation
Combining Fade and Slide animations with navigation events
- same page push / pop animation
- next page push / pop animation

![](https://raw.githubusercontent.com/SinaSeirafi/CnAnimations/master/CnAnimations%20RA%20gif%200.1.gif)

Requires setup. (below)

### Route Aware Widget 
Run functions based on navigation events. (push, pop, pushNext, popNext)

It is used within CnRouteAwareAnimation.
Requires setup. (below)


## Getting started
If you only want to use basic animations, you're good to go!

If you want to use RouteAwareWidget or CnRouteAwareAnimation you need to setup routeObserver. 

Setup: Add RouteAwareWidget.routeObserver in material app (main)
```dart
import 'package:cn_animations/cn_animations.dart';

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