# cn_animations example

A small app that shows both halves of the package:

- **Basics** (the home page): `CnFade`, `CnSlide` and `CnScale` entrances.
- **List**: 40 cards. Tap one and the others move away from it while the
  detail page arrives; swipe back (iOS) or use predictive back (Android) and
  they follow your finger.
- **Grid**: the same in three columns; cells in the tapped row move sideways.
- **No navigator**: the same elements driven by a `PageView` instead of a
  route.
- **Settings**: app-wide switches for reduced motion, scroll reveal, how the
  tapped item is detected and what it does, the fade-through route and slow
  motion.

## Run it

```sh
cd example
flutter run
```

Then open **List** under "Route-driven demos". The Android project already
sets `android:enableOnBackInvokedCallback="true"` for predictive back.

## The code that matters

The app installs the fade-through route for every platform in its theme
(`lib/main.dart`, where a Settings switch can turn it off):

```dart
MaterialApp(
  theme: ThemeData(
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final platform in TargetPlatform.values)
        platform: const CnFadeThroughPageTransitionsBuilder(),
    }),
  ),
)
```

Each card on the List page is wrapped in `CnRouteAnimation`
(`lib/pages/list_page.dart`, shortened here); `openDetail` pushes a plain
`MaterialPageRoute`, which takes the transition from the theme:

```dart
CnRouteAnimation(
  child: Card(
    child: ListTile(
      title: Text('Item $index'),
      onTap: () => openDetail(context, index),
    ),
  ),
)
```

There is no `navigatorObservers` line: the elements read the route's own
progress.
