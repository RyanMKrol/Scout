# Scout — standing rules for every build (injected into every builder prompt)

- **The `.xcodeproj` is generated — never hand-edit it or `Sources/Info.plist`.** Change project-level
  settings by editing `project.yml` and running `xcodegen generate`. New source files just go under
  `Sources/` (or `Tests/`) and are picked up automatically on the next generate.
- **Test destination — ALWAYS the dedicated `Scout-Sim`, never a generic model name.** Ensure it
  exists with `./tools/loop_sim.sh` (idempotent; prints the UDID). **This overrides any command text
  quoted in a task's spec or `verify`:** if a spec says `name=iPhone 16` (or any generic model),
  substitute `name=Scout-Sim` when you run it. Any NEW script or tool a task has you create that
  boots or targets a simulator must default to `Scout-Sim` via `tools/loop_sim.sh`, never a generic
  model. Simulators are exclusive resources — a generic by-name device is shared with other loops on
  this Mac, and two loops installing/launching onto one device stamp on each other. (Exception: CI
  workflows resolve their own runner-local sim — never "fix" CI to `Scout-Sim`.)
- **Live-radio code is NEVER exercised in tests or CI.** The real throughput path
  (`NetworkConnection` bound to `.cellular`) and the radio-generation read (`CoreTelephony`) do not
  work on the Simulator or CI — there is no cellular radio. Put every such surface behind a protocol
  (e.g. `ThroughputSampler`, `RadioInfoProviding`) with a live impl (device-only) and a scripted
  fake, and drive ALL unit tests from the fake. Never claim a live-transfer / real-radio behaviour
  verified from a Simulator run — that portion is human-verify-only on a real device.
- **Determinism:** any "current time" read for the rolling-window Mbps math must come from an injected
  clock/time source (a `DateProvider` / `now` closure), never a bare `Date()` / `.now`, so the
  windowing logic is unit-testable against a scripted clock and scripted sample stream.
- **iOS 26, modern APIs only.** `@Observable` (not `ObservableObject`), `NavigationStack` (not
  `NavigationView`), `.cellular`-bound `NetworkConnection` (no legacy `NWConnection` fallback). Code
  must be Swift 6 strict-concurrency clean.
- **No force-unwraps (`!`) or `try!`** in non-test `Sources`.
- **UI tests follow the house rules:** query by `accessibilityIdentifier` (never display copy); use
  bounded waits; never assert live UI state directly. Give the live-Mbps readout, the 5G/LTE badge,
  and the start/stop control stable accessibility identifiers so tests can assert state a screenshot
  can't show.
- **Copy style:** no em dashes in any user-facing string.
- **Docs lockstep:** a change that alters user-visible behaviour updates `README.md` in the same commit.
