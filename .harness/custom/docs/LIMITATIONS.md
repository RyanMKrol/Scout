# custom/docs/LIMITATIONS.md — this project's trade-offs & limitations log

Customization overlay for `.harness/docs/LIMITATIONS.md`. **This is where your project's own
limitation/trade-off rows go** (golden rule 5): when a change introduces a trade-off, bottleneck, or known
limitation, add a row **here** — not in the pristine `docs/LIMITATIONS.md`, which is plugin-owned and
refreshed on upgrade. Harness upgrades never touch this file. (See `.harness/custom/CLAUDE.md`.)

Each row: what it is, *why* it was chosen, its **impact**, and *when to revisit*.

<!-- Add your project-specific limitation rows here. -->

### iOS CI needs a macOS runner with Xcode 26
- **What:** CI (`.github/workflows/ci.yml`) runs on `macos-latest`; Scout targets iOS 26, which requires **Xcode 26** + an iOS 26 simulator on the runner.
- **Why:** iOS apps can only be built/tested on macOS with Xcode; there is no Linux path.
- **Impact:** If GitHub's `macos-latest` image lags behind Xcode 26, CI fails at the `xcodebuild` step until the image catches up or the workflow pins an Xcode version / newer runner image. macOS runner minutes also bill ~10× vs Linux.
- **Revisit:** When the runner image ships Xcode 26 by default (then the pin can be dropped), or if CI cost becomes a concern.

### Cellular-throughput measurement can't be fully verified in CI
- **What:** Scout's core value — real cellular throughput over a forced `.cellular` interface — needs a physical device on a cellular network. The simulator has no cellular radio.
- **Why:** `NetworkConnection(requiredInterfaceType: .cellular)` and `CoreTelephony` return meaningful data only on real hardware.
- **Impact:** Automated tests + the simulator visual-verify hook confirm the app builds, lays out, and behaves against *mocked/faked* interfaces — never the real radio path. Measurement correctness on cellular must be checked by a human on a device.
- **Revisit:** Design measurement code behind a protocol so a fake feeds tests, and keep a manual on-device verification step for throughput-critical tasks.

### Autonomous SwiftUI builds are gated by tests + a screenshot, not human judgment
- **What:** The loop builds UI tasks and verifies them with `xcodebuild test` + a booted-simulator screenshot (`VISUAL_VERIFY_HOOK`).
- **Why:** SwiftUI correctness (visual polish, interaction feel) can pass every automated check while still looking or feeling wrong.
- **Impact:** A screenshot catches gross visual breakage but not subtle UX issues; expect to review UI-heavy tasks by hand.
- **Revisit:** If UI regressions slip through, add snapshot tests or tighten which tasks require human review.

### 2026-07-16 — Adopted pattern: all live-radio I/O sits behind a protocol seam
- **What:** The throughput/radio I/O (`NetworkConnection` over `.cellular`, `CoreTelephony`) is reached only through protocols (`ThroughputSampler` / `RadioInfoProviding`); a scripted fake implements them for all tests, live impls run only on-device.
- **Why:** CI/Simulator has no cellular radio, so this is the only way the loop can build and test measurement-dependent code. Mirrors how a sibling harness (`enough`) stubbed StoreKit "behind the same protocol the real impl will implement." Seam + a large pure-logic core (windowing, 5G/LTE tagging) keeps everything unit-testable from a deterministic sample stream.
- **Impact:** The end-to-end "does a real transfer actually move over cellular" behaviour is NEVER verified by the loop — only on-device by a human. Every measurement task tests the pure math, not a live transfer. Enforced via `custom/build-preamble.md` + restated in each measurement spec.
- **Revisit:** If an on-device CI runner / hardware-in-the-loop rig ever becomes available.

### 2026-07-16 — Animated readout is verified by recorded video, not a single screenshot
- **What:** Scout's headline UI updates ~4×/sec; a still frame can't prove a value ticks or a graph scrolls. Timing/motion claims are verified from frames of `simctl io … recordVideo`.
- **Why:** A single screenshot under-verifies animation, and the alternative (driving the real host cursor to "watch" it live) is unacceptable — a sibling harness (`basket`) hit exactly that and its loop took over the operator's real mouse before the video approach was codified.
- **Impact:** Visual tasks with a motion claim must produce a short video; a claim with no capture is a FAIL. Guidance lives in `custom/visual-verify-build.md` / `visual-verify-audit.md`.
- **Revisit:** If a lighter frame-diffing / snapshot approach proves sufficient for the trend graph.
