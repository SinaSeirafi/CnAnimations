# Screenshots session notes (2026-10-11)

Running notes for the pub.dev screenshots slice on `v1/screenshots` (from 7ce1495).
Raw captures and helper scripts live in the session scratchpad:
`/private/tmp/claude-501/-Users-cn-Development-life-overview/a71d1f67-e562-4299-94b1-45a6ae2bd759/scratchpad/screenshots/`.

## Status

| File | State |
| --- | --- |
| `screenshots/basics.gif` | Done: `git mv` of `CnAnimations gif 0.2.gif`, content unchanged (380x766, 66 frames, 1.09 s, 233 KB). `CnAnimations RA gif 0.1.gif` removed. |
| `screenshots/parting-swipe-back.gif` | Checkpoint from iOS take 1 committed (360x783, 105 frames, 20 fps, 5.25 s, 995 KB). A retake with the pause at 47 % width (parting more visible while paused) is in progress; it replaces this file if better. |
| `screenshots/parting-lineup.png` | Not done. Frames come from the iOS recording. |
| `screenshots/predictive-back.gif` | Not done. Android emulator Pixel_API_36, profile APK already built in `example/build`. |

## How the iOS recording is driven

- Simulator: iPhone 17 Pro (iOS 26.5, DE1EDC20-42EE-478A-9997-2CACC3CC7DB1), debug build (the simulator has no profile mode). Status bar set with `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi`.
- Driver: a throwaway integration test, `example/integration_test/record_swipe_test.dart`. It is **never committed** and is deleted at the end; a copy stays in the scratchpad. It runs the unchanged `ExampleApp` and:
  - sets `WidgetsApp.debugAllowBannerOverride = false` inside the test (no DEBUG banner; the example source is untouched);
  - dispatches pointer events as *device* events (`binding.shouldPropagateDevicePointerEvents = true`, `binding.handlePointerEvent`), so the live test binding does not paint its crosshair;
  - draws a simulator-style touch dot (44 px grey circle, white rim) in a `Stack` above the app, so the swipe reads as a finger;
  - moves the pointer on a time-based cosine ease (exact durations even when timers run late);
  - waits for a `go<N>` file in the scratchpad before each take, so the host script can start `xcrun simctl io <udid> recordVideo --codec=h264` only once the host is quiet. Several takes run in one app session.
- Flow per take: List at rest, tap Item 6, detail page arrives, edge-swipe from x = 4 at y = 60 % height, pause, continue to 72 %, release with zero velocity (commits).
- GIF: `ffmpeg -ss <tap-0.4> -t 5.2 -i take.mov -vf "fps=20,scale=360:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=96:stats_mode=diff[p];[s1][p]paletteuse=dither=none:diff_mode=rectangle"`. 96 colours, no dither keeps it under 1 MB; 256 colours with bayer dither was 1.4 MB with no visible gain.
- Smoothness check: `ffprobe` frame timestamps of the .mov (gaps > 30 ms listed), then every GIF frame tiled and inspected.

## Host load

- The brief expected an idle host, but other agents' processes (eslint, vitest in life-overview worktrees) and macOS daemons (mds, ecosystemd, mediaanalysisd) kept the 1-min load between 4.5 and 130 from 08:05 onwards. The gate waits up to 4 min per take for load < 4, then records anyway and logs the load.
- iOS take 1 (08:47): load 6.2-6.9; largest frame gap 50 ms (one, during the push), all others <= 33 ms. Smooth in the frame-by-frame check.
