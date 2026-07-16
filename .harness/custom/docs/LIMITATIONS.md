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

### 2026-07-16 — Scout is a CAPPED instrument (10 Mbps down / 5 Mbps up), not a speedometer
- **What:** Readings are deliberately capped — download displays peg at "10+", upload at "5+"; quality bands are Great ≥ 6 / Usable ≥ 2 / Poor < 2 Mbps (download-only). The dial's log scale is retuned to the capped range (log10(11) / log10(6)), diverging from the handoff's illustrative 0–169 scale.
- **Why:** Owner decision (2026-07-16): the product question is "is this spot good enough to load a video / send messages?", not "how fast exactly". Capping lets the engine probe with small paced 256 KB transfers (~2 probes/sec, alternating direction), which makes the consent copy's "roughly 10–40 MB per minute" literally true. Uncapped continuous measurement would burn 600+ MB/min at high speed. The handoff explicitly permits threshold tuning ("Tune with real-world data; keep three bands").
- **Impact:** Scout cannot distinguish a 15 Mbps spot from a 150 Mbps spot — both read "10+ / Great". Fine for the stated use case; wrong for bandwidth shoppers. Thresholds/caps are constants in `ScoutMeter`, one place to retune after real-world use (device gate T025 step 7 collects the data).
- **Revisit:** After T025's real-world walk test, or if users ask "how fast actually" (see the precision-mode idea in IDEAS.jsonl).

### 2026-07-16 — Reading holds (doesn't decay) when probes stall without a path change
- **What:** If probes stop arriving but the cellular path stays "satisfied" (deep congestion, server issues), the last reading holds on screen; the window only empties toward 0/nil via the availability flip or new samples.
- **Why:** v1 simplicity; genuine loss of cellular flips the path monitor and shows the No-cellular state anyway, and a Cloudflare outage is rare enough not to design around yet.
- **Impact:** In a stalled-but-connected spot the display can look frozen-healthy for a while instead of degrading toward Poor.
- **Revisit:** If device testing (T025) shows stalls are common — add a "no samples in N s → decay to 0 / show measuring-stalled" rule to `SweepSession`.

### 2026-07-16 — Upload probe timing includes the server acknowledgement round-trip
- **What:** An upload probe's duration is measured from send-start until the server's HTTP response arrives, so it includes ~1 RTT of non-transfer time; upload Mbps is slightly underestimated, most at high speeds.
- **Why:** Without response confirmation there is no honest "bytes delivered" moment — `send()` returning only means bytes were handed to the local stack.
- **Impact:** Negligible for a 5 Mbps-capped instrument (a 256 KB probe at 5 Mbps takes ~400 ms vs ~30–60 ms RTT); the bias is conservative (understates).
- **Revisit:** Only if the upload cap is ever raised substantially.

### 2026-07-16 — Consent-declined idle state is an owner-approved design addition
- **What:** The "Not now" consent path lands on an idle measuring screen ("Sweeping is off" + Start button) that the design handoff does not spec (it said "exits", which iOS apps must not do programmatically).
- **Why:** App Review rejects self-terminating apps; a dead-end consent screen would trap the user. Copy/layout were derived from the handoff's No-cellular state (owner approved 2026-07-16).
- **Impact:** One screen exists outside the design house's blessing; T026 (design-fidelity review) explicitly checks it reads well.
- **Revisit:** If the design house issues an updated handoff covering it.

### 2026-07-16 — v1 depends on Cloudflare's public speed endpoints
- **What:** Probes hit `speed.cloudflare.com/__down` + `/__up` — a third party Scout doesn't control (verified live 2026-07-16: per-request byte cap somewhere between 50 MB and 100 MB; small probes are its intended use).
- **Why:** Zero backend to run for v1; the endpoint is designed for exactly this traffic.
- **Impact:** Cloudflare throttling/blocking/changing the endpoint breaks measurement; readings also include Cloudflare's own edge performance, not just the radio link (minor at a 10 Mbps cap). Endpoint is one constant (`HTTPProbeRequest.host`) so it's swappable.
- **Revisit:** The self-hosted endpoint idea in IDEAS.jsonl (planned "later" in the README).

### 2026-07-16 — Animated readout is verified by recorded video, not a single screenshot
- **What:** Scout's headline UI updates ~4×/sec; a still frame can't prove a value ticks or a graph scrolls. Timing/motion claims are verified from frames of `simctl io … recordVideo`.
- **Why:** A single screenshot under-verifies animation, and the alternative (driving the real host cursor to "watch" it live) is unacceptable — a sibling harness (`basket`) hit exactly that and its loop took over the operator's real mouse before the video approach was codified.
- **Impact:** Visual tasks with a motion claim must produce a short video; a claim with no capture is a FAIL. Guidance lives in `custom/visual-verify-build.md` / `visual-verify-audit.md`.
- **Revisit:** If a lighter frame-diffing / snapshot approach proves sufficient for the trend graph.
