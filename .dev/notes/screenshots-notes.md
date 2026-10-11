# Screenshots session notes (2026-10-11)

Running notes for the pub.dev screenshots slice on `v1/screenshots` (from 7ce1495).
Raw captures and helper scripts live in the session scratchpad:
`/private/tmp/claude-501/-Users-cn-Development-life-overview/a71d1f67-e562-4299-94b1-45a6ae2bd759/scratchpad/screenshots/`.

## Status

| File | State |
| --- | --- |
| `screenshots/basics.gif` | Done: `git mv` of `CnAnimations gif 0.2.gif`, content unchanged (380x766, 66 frames, 1.09 s, 233 KB). `CnAnimations RA gif 0.1.gif` removed. |
| `screenshots/parting-swipe-back.gif` | Checkpoint from iOS take 1 committed (360x783, 105 frames, 20 fps, 5.25 s, 995 KB). A retake with the pause at 47 % width (parting more visible while paused) is in progress; it replaces this file if better. |
| `screenshots/parting-lineup.png` | Checkpoint committed from iOS take 1 (1224x700, 79 KB, 256-colour PNG): frames at 2.5 s (list at rest), 2.978 s (mid-push, neighbours parted, Item 6 stays), 3.8 s (Detail 6), 5.2 s (mid-swipe, touch dot). Panels 276x600 with a 1 px #C9D3D0 border on #E4EAE8, built by `make-lineup.sh` in the scratchpad. Regenerated from the retake if that one is used. |
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
11:16 Session 2 picks up: evaluating retake take4/take5, then predictive-back on Android. Load at start 3.15.
- 11:18 Retake evaluated. take4 (load 3.75-4.01): gaps 37 ms at 0.03 s (before the tap), 32 ms, 35 ms at 4.28 s (swipe start). take5 (load 3.93-4.80): one gap 33 ms at 2.94 s (push), all else <= 30 ms. Both frame sheets show the full flow; the pause at 47 % holds the parted list. take5 chosen: smoothest, lower load than take 1 (6.2-6.9, 50 ms gap), better pause.
- take5 tap at ~2.85 s (touch dot first frame). GIF: -ss 2.45 -t 5.2, same recipe but max_colors=88 (96 gave 1.03 MB; 88 gives 982 KB, no visible loss). Lineup frames: 2.5 (rest), 3.02 (mid-push, parted), 3.8 (Detail 6), 5.9 (paused mid-swipe, touch dot). 3.04 rejected: ghost "Detail 6" title over the List title.
- 11:20 Android: emulator booted headless (`-no-window -gpu host`). Manifest already has `android:enableOnBackInvokedCallback="true"` on `<application>`; gesture navigation (mode 2). Profile APK from 08:21 is newer than the last example/lib change (01:18), reused. Image is a user build: no `adb root`, `sendevent` to /dev/input is denied, and console `event send` does not reach the virtio touchscreen. Console `event mouse x y 0 1` (device 0 = touch screen, pixel coordinates) does, through the hardware input path, so the system back gesture sees it. Driver `emucon.py` + `rec-android.py` in the scratchpad: one persistent console socket, cosine-eased moves at 120 Hz, same flow and timings as iOS (pause at 47 % width, continue to 72 %, release). Dry run: system back arrow shows, the list below scrubs, release commits. Touch dot: `show_touches 1`. Status bar: sysui demo mode, clock 09:41, wifi full, mobile hidden, battery 100.
- 11:25-11:34 Android takes pb1-pb3 (`rec-android-multi.sh`, guest `screenrecord --size 720x1560 --bit-rate 16M`; screenrecord emits frames only on change, so static stretches (detail at rest, the pause, the hold before release) show as long gaps and are not hitches). pb1 load 3.73-4.53: motion deltas 69 ms (first frame after tap), 74 ms (late push), else <= 32 ms. pb2 load 5.83-6.32: 45 ms (tap), 48 ms (swipe start), else <= 26 ms. pb3 load 7.96-8.57: max 33 ms during motion. Host load is again macOS daemons (ecosystemd, ecosystemanalyticsd, trustd) plus a node process; qemu itself ~26 % CPU. 11:35 one more take gated on load < 4 for up to 8 min (keeps the total wait under 20 min).
- 11:39 pb4 recorded at load 3.84-4.00 (gate passed at 3.91). Motion deltas: 56 ms (first frame after the tap, touch dot appearing), 48 ms (swipe start, before the system gesture engages), 33 and 38 ms (end of the eased continue move), else <= 25 ms; the push has no delta over 25 ms. Chosen over pb3 (smoother still but load 8) because it meets the load bar and the push is clean.
- predictive-back.gif from pb4: tap at 2.63 s (first changed frame). screenrecord leaves no frames in static stretches, so input `-ss` skips the rest frames; trim in the filter instead: `tpad=stop_mode=clone:stop_duration=1,fps=20,trim=start=2.23:duration=5.2,setpts=PTS-STARTPTS,scale=360:-1:flags=lanczos,...palettegen=max_colors=96...` (tpad covers the 0.25 s past the last frame). 360x780, 104 frames, 5.2 s, 953 KB. Frame sheet: list at rest, push with parting, Detail 6, edge swipe with the system back arrow, pause with the list below scrubbed and parted, continue, release, commit, list at rest.
