<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

Flutter basic animations simplified.
Flutter is made of widgets, right?
So adding a simple fade in or slide animation shouldn't be that hard. 
In fact, it should be as simple as adding a widget on top of your current widget.

This is exactly what this package is trying to do. 

## Features

### Basic Animations: 
- Fade
- Slide
- Scale

### Route Aware Animation
Combining Fade and Slide animations with navigation 
- same page push / pop animation
- next page push / pop animation 
Note: Requires adding RouteObserver in Material App to work
Otherwise only push will work

### Route Aware Widget 
Can be used separately.
It is used within CnRouteAwareAnimation.

Setup: Add routeObserver in material app (main)
```dart
MaterialApp(
    navigatorObservers: [routeObserver],
) 
```

## Getting started
If you want to use RouteAwareWidget or CnRouteAwareAnimation you need to setup routeObserver as above. 
Otherwise, you're good to go!

## Usage

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
