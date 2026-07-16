## Project-specific visual verification — audit side (Scout)

When auditing a task that made a visual `## Done when` claim, be adversarial about the evidence:

- **No capture = FAIL.** If the change touches the UI and no `screenshots/latest.png` (or a frame from
  a recorded video, for animated claims) was produced, the visual claim is unverified — fail. Do not
  accept "the build passed" as visual verification; the whole point of this check is that tests can pass
  while the screen looks wrong.
- **Letterbox bars = FAIL.** Black bars top and bottom with scaled-up UI means a missing launch screen
  (legacy compatibility mode). This distorts every screen — fail it before assessing anything else.
- **Claim must be evidenced by the actual pixels.** For each visual `## Done when` line (e.g. "shows the
  live Mbps figure", "5G/LTE badge present", "trend graph scrolls"), the screenshot/video frame must
  actually show it — a real Mbps number (not `--`/blank), the badge, the graph. A truncated, blank, or
  default-blue-tinted screen fails.
- **Animated/timing claims need a video, not a still.** Scout's readout updates ~4×/sec; a claim that a
  value ticks or a graph scrolls is only verified by frames from `simctl io … recordVideo`, never one
  screenshot. Reject any live-host-cursor "observation" as evidence.
