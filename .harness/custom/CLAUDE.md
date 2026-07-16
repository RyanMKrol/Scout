# .harness/custom/CLAUDE.md — your project-specific harness instructions

This is the **customization overlay** for `.harness/CLAUDE.md`. Anything you add here loads automatically
(the pristine `.harness/CLAUDE.md` imports it with `@custom/CLAUDE.md`), and **harness upgrades never touch
this file** — so this is where your edits belong.

## Why this file exists — the overlay rule

The harness's own prose files (`.harness/CLAUDE.md`, `README.md`, and everything under `docs/`) are
**plugin-owned**: `implementation-harness:implementation-harness-upgrade` refreshes them from the latest plugin version. If you
edit them in place, your changes collide with every future upgrade and force a manual reconcile. Instead,
put project-specific additions in the matching file under `.harness/custom/` — this tree **mirrors** the
harness layout (`custom/CLAUDE.md`, `custom/README.md`, `custom/docs/HARNESS.md`, …). The pristine files
then stay byte-identical to the plugin and upgrade cleanly, while your customizations ride along untouched.

(Scripts and config are NOT covered by this prose overlay — customize the loop via `config/harness.env`,
and if you need a script change, flag it to upstream into the plugin rather than hand-editing in place.)

Add your project's harness-authoring conventions, house rules, and reminders below.

## Scout-specific authoring conventions (apply to every task spec)

The cold builder only sees the spec — so any repo rule that must hold has to be **restated in the task's
`## Do` / `## Done when`**, not just left here. When authoring/reviewing Scout tasks:

- **Live-radio code is untestable in CI — bake the protocol seam into the spec.** Any task touching the
  throughput/measurement path (`NetworkConnection` over `.cellular`, `CoreTelephony`) MUST require it to
  sit behind a protocol (`ThroughputSampler` / `RadioInfoProviding`) with a scripted fake, and MUST test
  the **pure math** (rolling-window Mbps, 5G/LTE tagging, unit formatting) against that fake — never a
  live transfer. The end-to-end real-cellular behaviour is human-verify-only on a device; say so in the spec.
- **Determinism:** specs for tasks touching the rolling window / any time-dependent logic must require an
  **injected clock** (never bare `Date()` / `.now`), so the ~4Hz windowing is unit-testable with a scripted clock.
- **Freeze interfaces in the spec.** When a task creates a type/view a later task consumes, write the exact
  protocol + initializer signatures verbatim in `## Do` (later cold tasks bind to them → no integration drift).
- **Done-when must be checkable, not vibes.** Assert exact numbers / clamped edges / a named test file with
  lettered assertions driven by a fake sample stream (e.g. "given a fake sampler emitting [10,20,30] Mbps at
  250 ms, the rolling label reads '20.0 Mbps' within 1 s"), never "it displays the speed".
- **UI tests:** require `accessibilityIdentifier` queries (never display copy) and bounded waits; never
  assert live UI state directly.
- **Simulator:** the pinned LOCAL destination is the dedicated `Scout-Sim` by UDID (see root CLAUDE.md);
  CI resolves a sim by name. `xcodegen generate` runs first in every build/test command.
- **Layer picking (facets):** `Sources/**/Views` / SwiftUI screens = `ui`; the pure Mbps/windowing math =
  `measurement`; `NetworkConnection`/`.cellular` transport wrappers = `networking`; `CoreTelephony` radio
  reads = `telephony`; app entry / lifecycle / session state = `app`; `project.yml` / CI / lint config =
  `build`; docs = `docs`.

<!-- Add your project-specific instructions here. -->
