## Project-specific visual verification (Scout)

- **Capture via `./build_run.sh`** — it generates, builds, installs, launches on the dedicated
  `Scout-Sim` simulator, and writes `screenshots/latest.png`. Open and LOOK at that PNG; don't just
  check that the build succeeded.
- **The app MUST fill the whole screen.** If the screenshot shows BLACK LETTERBOX BARS at the top and
  bottom with the UI scaled up in the middle, the app is running in iOS legacy compatibility mode
  because it is missing a launch screen — that is a HARD FAIL, not a style nit. Confirm `UILaunchScreen`
  is present in the generated Info.plist (`plutil -extract UILaunchScreen xml1 -o - Sources/Info.plist`)
  and in `project.yml`. This globally distorts every screen's proportions, so judge it BEFORE assessing
  any individual component.
- **Screenshot at DEFAULT text size unless the task is specifically about Dynamic Type.** The simulator's
  Dynamic Type is a PERSISTENT setting — a prior accessibility task can leave it cranked up so every later
  screenshot looks wrongly oversized. `build_run.sh` resets it to `large` for you, but if you screenshot
  manually, reset first: `xcrun simctl ui booted content_size large` (note the UNDERSCORE — `content-size`
  with a hyphen silently no-ops on Xcode 26). Only an explicit accessibility task sets an `accessibility-*`
  size, and it MUST reset to `large` when done.
- **Verify what Scout is supposed to show:** the big glanceable **Mbps figure is a real number, not
  `--`/blank**; the **radio-generation badge** (5G / LTE) is present beside it; the **Start/Stop** control
  and **session data-used** counter are visible; the trend graph area renders. Truncated text, a
  default-blue SwiftUI tint where a custom accent is specified, or a blank screen = NOT verified.

### Timing / animated claims — a single screenshot is not enough

Scout's headline UI is a **live Mbps readout updating ~4× per second** and a rolling trend graph. A still
frame CANNOT prove a value animates, a graph scrolls, or a number ticks smoothly. For any `## Done when`
claim about motion/timing over time, capture a short **video of the simulator framebuffer** and inspect
frames, rather than one screenshot (and NEVER drive the real host mouse/keyboard to "watch" it live):

```bash
UDID=<the booted Scout-Sim UDID>
xcrun simctl io "$UDID" recordVideo --codec h264 screenshots/run.mov &   # Ctrl-C or kill to stop
# …drive the app / let the readout run for a few seconds…
kill %1 2>/dev/null || true
# extract a frame at 2s to eyeball, e.g. with ffmpeg if available:
# ffmpeg -y -i screenshots/run.mov -ss 2 -vframes 1 screenshots/frame-2s.png
```

A visual claim you cannot produce a capture for is itself a FAIL — do not pass on "probably fine."
