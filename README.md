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

TODO: Put a short description of the package here that helps potential users
know whether this package might be useful for them.

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

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder.


## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
