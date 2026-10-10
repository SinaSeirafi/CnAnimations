# cn_animations: publishing and visibility suggestions

Prepared 2026-10-11 for the package owner, before 0.9.0 and 1.0.0 are published. Read-only research; nothing in the package was changed. Each item is marked **before** (do before `pub publish`) or **after**, and ranked by value against effort. The 160/160 formatting fix is handled elsewhere and is not repeated here. Sources are listed at the end.

## Ranked summary

How pub.dev ranks search results, in order of weight: query relevance against the package name, description, README and doc comments; then popularity (downloads and likes); then pub points ([pub.dev search help](https://pub.dev/help/search)). The package has no downloads or likes to speak of, so the only levers before publishing are the words on the page and how the page looks. Everything else is slow and follows from people seeing it.

| # | Recommendation | When | Value | Effort |
| --- | --- | --- | --- | --- |
| 1 | Rewrite the README's first screen: tagline, one GIF of the parting plus swipe-back, a quick start that includes the route install (§2) | before | high | 1–2 h |
| 2 | Add `screenshots:` to the pubspec (static lineup first, then GIFs), rename the GIFs, link README images to a tag, not `master` (§1.3) | before | high | 2–3 h incl. recording |
| 3 | Rewrite `description` around the words people search for; add `topics`, `repository`, `issue_tracker` (§1.1, §1.2, §1.4) | before | high | 15 min |
| 4 | Publish 0.9.0 and 1.0.0 the same day, after PR #1 merges to `master`; do the pre-publish checks in §3.2 | before | high | 1 h |
| 5 | Keep the name `cn_animations`; the one cheap moment to rename is now, so decide deliberately (§3.5) | before | decision | 10 min |
| 6 | File the Flutter Gems issue and post once on r/FlutterDev with the GIF and the "progress, not events" angle (§4) | after, first week | medium | 1 h |
| 7 | Put the example on GitHub Pages and link it from the README and the pub.dev page (§4.4) | after | medium | 2 h |
| 8 | Write the technique article (already planned as the concept document) for dev.to or Flutter Community (§4.3) | after | medium | half a day |
| 9 | Verified publisher, only if the owner already has a domain (§3.4) | after | low–medium | 30 min |
| 10 | Enable GitHub Actions publishing for releases after 1.0.0 (§3.3) | after | low | 30 min |
| 11 | Fix the first-time-user traps that are docs-only (§5); API ones go to 1.1.0 | before (docs) / after (API) | medium | 1 h |

## 1. The pubspec

### 1.1 `description` (before)

The current description (138 chars) is accurate but leads with the least distinctive part ("Fade, slide and scale widgets") and uses "choreography", a word nobody types into pub.dev search. The description is the second-highest-weighted search field after the name, and it is also the one line shown in search results and on Flutter Gems. Lead with what the package does that others do not, and use the terms developers search for: "page transition", "animate", "swipe back", "predictive back". Keep it plain text, no Markdown ([pubspec reference](https://dart.dev/tools/pub/pubspec#description)).

Proposed (160 chars):

```yaml
description: Animate page elements with the route transition: enter on push, part around the tapped item, scrub with swipe-back and predictive back. Also fade, slide, scale.
```

Alternative if the owner prefers "widgets" to appear (161 chars): `Page elements that animate with the route: enter on push, part around the tapped item, follow swipe-back and predictive back. Plus fade, slide and scale widgets.`

Both stay inside 60–180. The search result for `route animation` today lists `local_hero`, `hero_animation`, `page_route_transition` and similar; none of them describes parting or back-gesture scrubbing, so these words are where the package can win a query.

### 1.2 `topics` (before)

Topics are a filter (`topic:<name>` in the search box) and a browse page, not a ranked field ([pub.dev search help](https://pub.dev/help/search)). The useful choice is therefore: one broad topic so the package appears when people filter, plus small topics where the package is visible on the first page. Counts from [pub.dev/topics](https://pub.dev/topics) on 2026-10-11:

| Topic | Packages | Note |
| --- | --- | --- |
| `animation` | 544 | The broad one. `animations` (46) is a separate, uncanonicalized topic; use the singular, which `animations` (flutter.dev) and `flutter_animate` use. |
| `transitions` | 20 | Small; the company is good (`go_transitions`, `hyper_effects`, `universal_back_gesture`). `transition` (22) is a separate topic; pick one. |
| `page-transition` | 5 | Smallest and the most exact; the package would be on the first screen. |
| `navigation` | 315 | Broad, matches the route-driven angle. |
| `widget` | 1179 | Low value, but `widgets` is aliased to it and it describes the fade/slide/scale half. |

Not worth a slot: `flutter` (2222 packages; pub.dev already tags `sdk:flutter`), `ui` (1144), `motion` (13, mostly unrelated). `predictive-back` and `swipe-back` do not exist as topics; a new topic is accepted but nobody filters by it, so leave those words to the description and README.

```yaml
topics:
  - animation
  - page-transition
  - transitions
  - navigation
  - widget
```

Rules: max 5, lowercase letters, digits and single hyphens, 2–32 chars. The only canonical aliases pub.dev applies today are in [topics.yaml](https://github.com/dart-lang/pub-dev/blob/master/doc/topics.yaml) (eight entries; `widgets` → `widget` is the one that matters here).

### 1.3 `screenshots` (before)

Rules ([pubspec reference](https://dart.dev/tools/pub/pubspec#screenshots)): up to 10 entries, each a `description` (≤160 chars) and a `path` inside the package; png, jpg, gif or webp; ≤4 MB each; static or animated. **The thumbnail in search results and on the package page is the first screenshot, and for an animated file it is its first frame.** Screenshots are shipped in the package archive, so every `pub get` downloads them; keep the total small. Packages with screenshots can be filtered for in search, and the package page shows a carousel ([Dart blog](https://dart.dev/blog/screenshots-and-automated-publishing-for-pub-dev)).

What exists today:

| Asset | Where | Size | Usable? |
| --- | --- | --- | --- |
| `CnAnimations gif 0.2.gif` | repo root, 380×766, 233 KB | basics (fade/slide/scale) | Yes, after a rename; the content is the 2023 basics, still accurate. |
| `CnAnimations RA gif 0.1.gif` | repo root, 380×766, 395 KB | 2023 route-aware | No: it shows the removed API's motion; retire it. |
| `predictive-back-scrub.gif` | scratchpad `device-check/android/artefacts`, 320×693, 533 KB | Android predictive back | Content is right, but it was captured at 5–8 fps under host load (the device report says so). Re-record. |
| `swipe-back-tapped.gif` | scratchpad `device-check/ios`, 240×522, 311 KB | iOS swipe-back | Too small; re-record. |

Recommended set (four files, first one static so the thumbnail is sharp):

1. `screenshots/parting-lineup.png`: a static lineup of three or four frames from the list demo (at rest, mid-push with neighbours parted, detail page, mid-swipe-back). This is what the `animations` package does and it reads at thumbnail size, which a GIF's first frame (a list at rest) does not. About 1200×700, under 300 KB.
2. `screenshots/parting-swipe-back.gif`: the list demo on the iOS simulator: tap Item 6, let the detail page arrive, then edge-swipe slowly, pause, and release. 4–6 s, 360 px wide, 20 fps, under 1 MB.
3. `screenshots/predictive-back.gif`: the same on the Android emulator with system predictive back (the device check's adb motion-event script in the scratchpad already drives it).
4. `screenshots/basics.gif`: the renamed 2023 basics GIF.

Record at idle, not with other agents running; the earlier captures were taken while the host was saturated. Pipeline that keeps files small: `xcrun simctl io booted recordVideo out.mov` (iOS) or `adb shell screenrecord` (Android), then `ffmpeg -i out.mov -vf "fps=20,scale=360:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" out.gif`. Animated webp is about half the size of a GIF and renders on both pub.dev and GitHub, but GIF is the safe choice if the owner does not want to verify webp playback in the README. Do not put captions, logos or device frames in the images; pub.dev asks for none.

```yaml
screenshots:
  - description: List items part around the tapped item, then follow an iOS swipe-back.
    path: screenshots/parting-lineup.png
  - description: Tap an item, swipe back slowly: the neighbours scrub with the finger.
    path: screenshots/parting-swipe-back.gif
  - description: Android predictive back scrubs the page below in the same way.
    path: screenshots/predictive-back.gif
  - description: CnFade, CnSlide and CnScale entrance animations.
    path: screenshots/basics.gif
```

Two link mechanics to get right:

- The README today loads the GIF from `raw.githubusercontent.com/.../master/CnAnimations%20gif%200.2.gif`. That URL works only while that exact file exists on `master`. After the rename it 404s on pub.dev until PR #1 is merged. Link README images to the **release tag** instead (`.../v1.0.0/screenshots/parting-swipe-back.gif`): a tag URL never moves, and the README that pub.dev renders is frozen with the version anyway.
- Delete the two spaced filenames rather than keeping them beside the new ones; otherwise both ship in the archive.

### 1.4 `repository`, `issue_tracker`, `homepage`, `documentation` (before)

pub.dev already infers repository and issues from the GitHub `homepage` (the 0.0.3 page shows both links), so this is tidiness, not score. Set them explicitly and drop `homepage`, which would duplicate `repository`:

```yaml
repository: https://github.com/SinaSeirafi/CnAnimations
issue_tracker: https://github.com/SinaSeirafi/CnAnimations/issues
```

`documentation:` is for docs hosted somewhere other than the repository and the generated API reference; there is none, so omit it. If the example goes to GitHub Pages (§4.4), `homepage: https://sinaseirafi.github.io/CnAnimations/` becomes worth adding then, because pub.dev shows it as a separate link.

## 2. The README's first screen (before)

What the first screen does today: a CI badge, the heading "Flutter basic animations simplified", three sentences about fade-in being easy, then a Features list that starts with the basics. A reader on pub.dev gets no hint of the route-driven part until the second screen, and the GIF they see is the 2023 basics. The [package page guidance](https://dart.dev/tools/pub/writing-package-pages) says readers spend seconds on the opening: short description first (do not repeat the package name, pub.dev shows it), badges near the top, a GIF or video early for UI behaviour, one copy-pasteable sample, then usage.

What to show above the fold, in order:

1. **Tagline**, one line, with the words from the description.
2. **One GIF**: the list demo, push with parting, then a slow swipe-back. One file, not two; the second (predictive back) can sit in the "Routes" section where the manifest flag is explained.
3. **Badges**: pub version (`https://img.shields.io/pub/v/cn_animations`), CI, license. Three is enough; pub points and likes badges show small numbers for a while and add nothing.
4. **Quick start** in three steps that a reader can paste in under a minute: add the dependency, install the route, wrap an element. The route install must be in the quick start, because without it a `CnRouteAnimation` under Flutter's default zoom transition shows only entrances and the reader concludes the package does nothing on push (§5, item 1).
5. **A one-paragraph "when to use it"**, so people with a `go_router` app or a PageView know early whether it fits (theme builder works with `go_router`; `PageView` via `progress:`).

Then the existing sections in this order: Basic animations (short, with the basics GIF) → Navigation-driven animation → Parting → Configuring → Reduced motion → Routes → How it works → Migrating from 0.0.x → History. "How it works" should stay after Usage; it is the section that earns trust, not the one that sells.

Draft of the first ~30 lines (the image URL assumes §1.3; replace `v1.0.0` with the tag actually published):

````markdown
[![pub](https://img.shields.io/pub/v/cn_animations.svg)](https://pub.dev/packages/cn_animations)
[![CI](https://github.com/SinaSeirafi/CnAnimations/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/SinaSeirafi/CnAnimations/actions/workflows/ci.yml)
[![license](https://img.shields.io/github/license/SinaSeirafi/CnAnimations)](LICENSE)

# Page elements that move with the route

Wrap an element in `CnRouteAnimation` and it enters with its page, leaves when
another page covers it, parts away from the item you tapped, and follows an
iOS swipe-back or Android predictive back with your finger. No `RouteObserver`,
no controllers: the motion is read from the route's own progress. Fade, slide
and scale widgets for one-off entrances are included.

![Tap an item: its neighbours part away; swipe back slowly and they follow the finger](https://raw.githubusercontent.com/SinaSeirafi/CnAnimations/v1.0.0/screenshots/parting-swipe-back.gif)

## Quick start

1. Add the package: `flutter pub add cn_animations`.
2. Install the route transition (it keeps the page below still while its
   elements leave), or push single routes with `CnPageRoute`:

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

3. Wrap the elements of a page:

   ```dart
   CnRouteAnimation(child: Card(child: ListTile(title: Text('Item'))))
   ```

That is all. Parting around the tapped item and back-gesture scrubbing are on
by default. For Android predictive back, set
`android:enableOnBackInvokedCallback="true"` on `<application>`, as for
Flutter's own predictive-back transition.

Works with `Navigator.push`, `Navigator.pages` and `go_router` (their
`MaterialPage`s take the transition from the theme). Needs Flutter 3.29+.
````

Two notes on the draft. The GitHub rendering of the title is the only place the name does not appear above it, so the H1 can stay a tagline rather than "cn_animations". And the current README's "Flutter is made of widgets, right?" paragraph can go; it describes the 2023 package and delays the point.

## 3. Release mechanics

### 3.1 Publishing 0.9.0 then 1.0.0, and the gap between them (before)

Publish both on the same day, 0.9.0 first, 1.0.0 an hour or so later, once PR #1 has merged to `master` and `v1.0.0` is tagged. Reasons:

- The bridge release exists for 0.0.x users, and there are almost none (28 downloads in 30 days, most of them likely crawlers and mirrors; the owner already noted there are no users to keep continuity for). A gap of weeks buys nothing for them and costs the package weeks of showing a `0.9.0` that the README calls a bridge.
- pub.dev shows the latest stable version's README, score and pubspec. Only 1.0.0's page matters for visibility; 0.9.0 is a version row with its own CHANGELOG entry and that is enough for a migrating user to pin it.
- A same-day pair also means one announcement, not two.

What a 0.0.x user sees: with the usual `cn_animations: ^0.0.3` constraint (`>=0.0.3 <0.0.4`), `flutter pub upgrade` changes nothing; `flutter pub outdated` lists 1.0.0 as the latest and 0.9.0 is only visible on the Versions tab. So the bridge is found by someone who reads the CHANGELOG, not by the tool. For that reader, the 0.9.0 CHANGELOG entry already says what is deprecated and the deprecation messages say "removed in 1.0.0"; the README's migration section should be titled "Migrating from 0.0.x" because 0.1.0 was never published (§5, item 6).

The tag `v0.9.0` (869bb94) predates the formatting fix, the README rework and anything in §1. Do not backport them to 0.9.0: the score and the page that readers see belong to 1.0.0. The one exception is if the owner wants 0.9.0 to pass the same `dart format` check, which is cosmetic (pub.dev scores old versions but nobody looks). Publish 0.9.0 from a temporary worktree at the tag (`git worktree add /tmp/cn-0.9.0 v0.9.0`), run the dry run there, publish, remove the worktree.

Version jump: `pub publish` prints a hint about jumping from 0.0.3; it is a hint, not a warning. Retraction is available for seven days after each publish if something is wrong, and a retracted version stays visible with a badge ([publishing docs](https://dart.dev/tools/pub/publishing)); the usual advice is to publish a fixed version instead.

### 3.2 `pub publish` checks (before)

The dry run already reports 0 warnings. Before the real publish, in this order:

1. `dart format lib test example` with the newer SDK and the `// dart format off` guard from the score report, so pana on pub.dev (Dart 3.13) and the local 3.8 agree.
2. `flutter analyze` on the root and `example/`; `flutter test`.
3. `flutter pub publish --dry-run` and read the **file list**, not just the summary. Things that must not be in it: `.dev/` (hidden, so excluded), `build/`, `example/build/`, `example/ios/Pods/`, `example/macos/Pods/`, `.dart_tool/`, the two old GIFs. Things that must be: `screenshots/*`, `LICENSE`, `CHANGELOG.md`. There is no `.pubignore` today; the `.gitignore` covers `build/` and `.dart_tool/`, and `pub` honours it, but check `example/ios/Podfile.lock` and `example/macos/Podfile.lock`, which were committed on purpose and will ship (harmless, small).
4. Check the archive size the dry run prints. The example's six platform folders are the bulk; under a few MB is fine.
5. Clean `git status` in the directory being published; `pub publish` warns about uncommitted tracked files.
6. Open the rendered README on GitHub at the tag and click every image and anchor. pub.dev renders the same Markdown; relative links break, absolute ones do not.
7. After publishing, open the package page, wait for the analysis (minutes to an hour), and check the score page for the formatting line and the screenshots carousel.

### 3.3 Automated publishing from GitHub Actions (after)

pub.dev can publish from a GitHub Actions workflow with a tag pattern such as `v{{version}}` and OIDC, no stored credentials; it is enabled on the package's Admin tab by an uploader, and it works for individually owned packages. The tag's version must match `pubspec.yaml`, and pub.dev rejects publishes not triggered by a tag ([automated publishing](https://dart.dev/tools/pub/automated-publishing)). For these two releases the setup costs more than it saves; publish manually. Set it up for 1.1.0 onward, with the reusable `dart-lang/setup-dart/.github/workflows/publish.yml@v1` workflow. Note that `v0.9.0` is already pushed, so enabling it with the `v{{version}}` pattern today would not retroactively publish anything.

### 3.4 Verified publisher (after, unless a domain already exists)

A verified publisher is a pub.dev identity backed by a domain: the creating account must be verified for that domain in Google Search Console, after which the package page shows the domain with a badge instead of "unverified uploader", the publisher gets a page listing its packages, and any member of the publisher can upload ([verified publishers](https://dart.dev/tools/pub/verified-publishers)).

For: it removes the "unverified uploader" line, which is the one trust signal on the sidebar a reader sees before the README; it also gives a stable place for the planned sister packages. Against: it needs a domain the owner controls (a yearly cost if there is none), the transfer of a package into a publisher is irreversible, and it does not affect score or ranking. Verdict: if the owner already owns a domain, do it now, before 0.9.0, so both versions appear under it from the start; otherwise publish first and transfer later, which pub.dev allows at any time for an existing package. Do not buy a domain for this alone.

### 3.5 The package name (decision, before)

`cn_animations` says nothing about what the package does, and the name is the highest-weighted search field. A rename on pub.dev is not a rename: it is a new package plus marking the old one discontinued with a "suggested replacement" (the old one stays installable, disappears from search, and shows a DISCONTINUED badge) ([publishing docs](https://dart.dev/tools/pub/publishing)). Candidate names are free as of today: `route_choreography`, `route_animations`, `navigation_choreography`, `page_choreography` all return 404 on the pub API.

Weighing it:

- The cost of renaming is lowest right now and only goes up. Today it is 28 monthly downloads, 0 likes and no inbound links; after the announcement it is every link and every `pubspec.yaml` that mentions the name.
- The gain is smaller than it looks. Relevance is computed on name, description, README and doc comments together; a description and README that use "page transition", "swipe back" and "predictive back" cover most of the query space, and the parting feature has no established search term that a name could claim.
- The owner plans sister packages (web, Kotlin) and the API already carries the `Cn` prefix on every class. A family name has value there, and a descriptive name for this one (`route_animations`) would not fit a Kotlin library anyway.
- A rename invalidates PR #1's history on pub.dev, the pushed `v0.9.0` tag's meaning, and the 0.9.0 bridge itself (a new package has no 0.0.x users to bridge).

Recommendation: keep `cn_animations`. Make the description and the README H1 carry the descriptive words instead. The one case to rename is if the owner, looking at the sister-package plan, decides the family should not be called "cn" at all; then do it before 0.9.0 and skip the bridge release.

## 4. Discoverability beyond pub.dev (after)

Where Flutter developers actually find packages, in rough order of traffic for a package like this: pub.dev search and topic pages; Flutter Gems (category browsing, and it ranks well on Google for "flutter <thing> package"); r/FlutterDev and its Discord; articles on Medium's Flutter Community and dev.to that rank on Google months later; X and Bluesky for a one-day spike that feeds the first likes. The owner's time is the scarce resource, so only the first four are worth it, and each once.

### 4.1 Flutter Gems (first week, 15 min)

Community-curated directory of 7,000+ packages by category; its "Animation" and "Page Transition / Route" pages are where people go when they do not know a name. Listing is by opening an issue with the "add a package" template in [animator/fluttergems](https://github.com/animator/fluttergems); the README gives no eligibility criteria, and the description shown is the pubspec `description`, another reason for §1.1. Do this after 1.0.0 is live so the entry links to a page with screenshots.

### 4.2 r/FlutterDev, once (first week, 30 min)

The subreddit's moderators remove plain promotion but allow open-source work when the post contains "an insightful dive into the development" (a January 2025 removal notice quoted the rule; the current rules page could not be fetched, so read the sidebar before posting). A package post that leads with the GIF and the one idea that is actually novel (elements read route progress instead of navigation events, so back gestures scrub for free) fits that. One post, replies answered, no repost. The announcement draft below is written for this.

### 4.3 One article (first month, half a day)

The concept document already scheduled in STATUS is the article: "progress, not events", curves locked by the rest state, geometry-bounded stagger, the dead-frame measurement. Publish it on dev.to (no editorial queue, `#flutter` tag, indexed well) and submit the same piece to Medium's Flutter Community publication, whose About page links its submission guidelines (the guidelines post itself returns 403 to fetch; open it in a browser). An article that explains a technique keeps sending readers for years, where an announcement is gone in a day. Link the pub.dev page and the live demo from the first paragraph.

### 4.4 Example app on GitHub Pages (first month, 2 h)

The example builds for web, so a `flutter build web --base-href /CnAnimations/` deployed with `actions/upload-pages-artifact` and `actions/deploy-pages` gives a URL anyone can open from the README and the pub.dev sidebar (`homepage:`), with no install. Several current guides show the workflow shape; the base-href must start and end with a slash and match the repository name, or the page is blank ([codewithandrea](https://codewithandrea.com/articles/flutter-web-github-pages/), [DEV example](https://dev.to/janux_de/automatically-publish-a-flutter-web-app-on-github-pages-3m1f)). Caveat to state on the demo page: on the web there is no swipe-back or predictive back, so the demo shows push, pop and the parting; the scrubbing is only in the GIFs and on a device. Put the demo link next to the GIF in the README.

### 4.5 Not worth the time now

- **X / Bluesky**: one post with the GIF and `#FlutterDev` the day the article goes out. Without an existing following it is a few dozen views; it costs five minutes, so do it, but expect nothing.
- **Newsletters** (Flutter Digest, FlutterTap, Flutter Weekly): no submission paths found; most are curated from Reddit and X anyway, so the post in 4.2 is how to reach them.
- **awesome-flutter list PR**: real but slow to merge and gated on maturity; revisit after some likes.
- **Flutter Favorite**: not applicable at this stage.

### 4.6 Draft announcement (under 150 words; adapt the tone to the venue)

```text
cn_animations 1.0: page elements that move with the route

I rewrote my 2023 animation package around one idea: an element should read
its route's progress instead of listening for navigation events.

Wrap a list item in CnRouteAnimation and it enters with the page, leaves when
another page covers it, and parts away from the item you tapped (nearer ones
first). Because it reads progress, an iOS swipe-back or Android predictive back
scrubs everything with your finger, with nothing extra wired up: no
RouteObserver, no controllers.

Works with Navigator, Navigator.pages and go_router through a theme
PageTransitionsBuilder, or per route with CnPageRoute. Reduced motion falls back
to fade-only by default. Fade/slide/scale widgets are still there.

Flutter 3.29+, no dependencies, 268 tests, MIT.

pub.dev: https://pub.dev/packages/cn_animations
Source and demo: https://github.com/SinaSeirafi/CnAnimations

Happy to hear where it breaks.
```

(The rework was done with Claude; the README's History section says so. Leave that in the README, where the context is, rather than in the announcement, where it becomes the topic.)

## 5. What would put a first-time user off

Listed in order of how likely a new user hits it. "Docs" items fit before publishing; "API" items are additive and belong in 1.1.0 (or a 0.9.x/1.0.x deprecation, not a 1.0.0 change).

1. **Nothing visible on push with the default transitions** (docs, before). A reader who adds `CnRouteAnimation` to a stock `MaterialApp` sees entrances only, because Flutter's zoom and Cupertino transitions hide the page below. The README says this, but on the fourth screen under "Routes". The quick start must install the route first (§2).
2. **The theme install is a seven-line for-loop** (API, after). `for (final platform in TargetPlatform.values) platform: const CnFadeThroughPageTransitionsBuilder()` is what every user will paste. A one-liner such as `CnFadeThroughPageTransitionsBuilder.theme()` returning a `PageTransitionsTheme` (or a documented `const` map) removes the most copied snippet. Additive; 1.1.0.
3. **Android predictive back needs a manifest flag** (docs, before). `enableOnBackInvokedCallback="true"` is a one-line setup step that currently sits in the "Routes" section after two paragraphs on route types. Put it in the quick start, as the draft does.
4. **`delayInMilliseconds` beside `delay`, with different defaults** (API, after). `CnFade` defaults `delayInMilliseconds` to 10, `CnSlide` and `CnScale` to 0, and `delay` (a `Duration`) wins when set. A new user sees two ways to say one thing and a 10 ms delay they did not ask for. The owner chose to keep it for 1.0.0; deprecate it in 1.1.0 and add the dartdoc note on the 10 ms default that STATUS already lists.
5. **Inconsistent basic defaults**: `CnFade` 500 ms, `CnSlide` and `CnScale` 300 ms; `CnSlide.begin` is `Offset(0, 0.5)` (half the widget's height), `CnRouteAnimation.enterOffset` is `0.1`. Not wrong, but a user combining them has to look each one up. Docs: a short defaults table in the Basic animations section. API: leave for 2.0.
6. **"Migrating from 0.1.0"** (docs, before). 0.1.0 was never published; pub.dev users are on 0.0.3. Title it "Migrating from 0.0.x" and say that 0.1.0's fixes are included in 0.9.0.
7. **The vocabulary**: "choreography", "subject", "parting", "cover", "uncover" are precise but new. The README defines each on first use; the quick start and tagline should avoid them and use "the tapped item", "the page below", "swipe back". Keep the terms in the configuration sections where precision matters.
8. **The History paragraph** (keep, but place it). Saying the rework was done with Claude is honest and some readers will weigh it against the package. It already sits last, after "How it works"; that is right. Make sure the test count and the CI matrix (3.29.0 and stable) are stated near it, since those are what answers the concern.
9. **`CnRouteChoreographyData` and `CnDirectionalCurvedAnimation` in the barrel**: fine for advanced users, but they appear in the API reference beside the five widgets a beginner needs. A `@category` or a short "Advanced" heading in the library doc comment would separate them (the pana report lists the library itself as undocumented).
10. **No `CnPage`** for `Navigator.pages`: documented; the theme builder covers it. Leave as is, keep the sentence in the quick start.
11. **Example app's first page is the basics**. Someone who runs the example to see the headline feature lands on fade/slide/scale boxes and a "Route-driven demos" row below. Consider making the list demo the home page in 1.1.0; for now the README's "run the example" line should say "open List".

## Sources

Official:

- pub.dev search ranking: https://pub.dev/help/search
- pubspec fields (description, topics, screenshots, repository, issue_tracker, homepage, documentation): https://dart.dev/tools/pub/pubspec
- Writing package pages (README guidance): https://dart.dev/tools/pub/writing-package-pages
- Publishing (dry run, retraction, discontinue and replacement, uploaders): https://dart.dev/tools/pub/publishing
- Verified publishers: https://dart.dev/tools/pub/verified-publishers
- Automated publishing from GitHub Actions: https://dart.dev/tools/pub/automated-publishing
- Screenshots and automated publishing announcement: https://dart.dev/blog/screenshots-and-automated-publishing-for-pub-dev
- Canonical topics and aliases: https://github.com/dart-lang/pub-dev/blob/master/doc/topics.yaml
- Topic counts (read 2026-10-11): https://pub.dev/topics

Comparable packages (read 2026-10-11): `animations` (flutter.dev, 6.88k likes, topics `animation`, `ui`, screenshots lineup), `flutter_animate` (gskinner.com, 4.25k likes, topics `animation`, `ui`, `effects`, `widget`, three GIFs at the top of the README), `page_transition` (1.58k likes, no topics, no GIF above the fold). Search results for `route animation`, `topic:page-transition` and `topic:transitions` on pub.dev. The current `cn_animations` 0.0.3 page: https://pub.dev/packages/cn_animations

Community:

- Flutter Gems contribution repo: https://github.com/animator/fluttergems
- r/FlutterDev rule 9 as quoted in a 2025 moderator notice: https://redlib.hbubli.cc/r/FlutterDev/comments/1hrra7c/my_first_app_with_flutter (the rules page itself could not be fetched; check the sidebar)
- Flutter Community publication (about page links the submission guidelines): https://medium.com/flutter-community/about
- Flutter web on GitHub Pages: https://codewithandrea.com/articles/flutter-web-github-pages/ and https://dev.to/janux_de/automatically-publish-a-flutter-web-app-on-github-pages-3m1f

In-repo: `README.md`, `CHANGELOG.md`, `pubspec.yaml`, `example/`, `.dev/STATUS.md`, and the pub.dev score report in the session scratchpad (`pub-score/pub-score-report.md`). Emulator capture sizes measured with `sips` on the scratchpad `device-check/` files.
