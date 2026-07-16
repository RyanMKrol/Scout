# Scout

**Find the sweet spot for cell signal in any room.**

Scout is an iOS app that measures the *real* cellular data throughput reaching your
phone — live, several times a second — so you can walk around a room, watch the number
move, and settle where the signal is actually good. Poor reception in the back bedroom?
Scout tells you which corner to stand in.

---

## The problem

Everyone knows the feeling: a call drops in one chair but is fine in the next; a video
buffers by the window but not at the desk. The "bars" in the status bar are almost
useless for this — they update slowly, they're a coarse 0–4 scale, and a full-bars
connection can still be unusable. There's no good way to *hunt* for good signal.

Scout turns your phone into a live signal-finder you sweep around the room like a metal
detector.

---

## What Scout actually measures (and an honest note on iOS limits)

This is the single most important design decision in the app, so it's worth being precise.

There are two different things people mean by "signal":

| | What it is | Can a third-party iOS app read it? |
|---|---|---|
| **Radio signal strength** (RSRP / RSRQ / dBm — the "bars") | How strong the raw radio link to the tower is | **No.** iOS exposes *no public API* for this. The private APIs that used to work get apps **rejected from the App Store** and break across OS updates. |
| **Cellular throughput** (Mbps) | How much data actually moves over the cellular link right now | **Yes** — by actively transferring data over the cellular interface and measuring the rate. |

Scout is built on the second one. It **cannot** show you a raw dBm/bars number — no
App-Store-safe iOS app can. Instead it measures **effective throughput to the tower** by
pulling a data stream *specifically over the cellular radio* and timing how fast it
arrives.

For the "find the good spot" use case this is arguably the *better* metric anyway: bars
can read full while the connection is unusable, but measured Mbps is the ground truth of
whether your phone can actually do anything where you're standing.

### What we *can* surface

- **Live throughput in Mbps**, updated ~4× per second on a rolling window.
- **Radio generation** — whether you're currently on **5G NR, LTE, 3G**, etc., via
  `CoreTelephony`. So the readout reads e.g. **"5G · 84 Mbps"**.
- **Trend / history** while you move — a rolling graph so you can see the number climb as
  you find a better spot.

### What we deliberately *cannot* surface

- Raw signal strength (dBm), bars, RSRP/RSRQ — **not available to third-party apps.**
- Anything about *why* signal is weak (tower distance, band, congestion) — invisible to us.

---

## How it works

1. **Forced cellular transfer.** Scout opens a connection bound to the **cellular
   interface only** (even if Wi-Fi is connected) so the measurement reflects the mobile
   signal, not your router. Uses `Network.framework`'s `NetworkConnection` with
   `requiredInterfaceType = .cellular` (iOS 26+).
2. **Continuous download stream.** It pulls bytes from a high-bandwidth endpoint and
   counts them.
3. **Rolling-window rate.** Bytes-per-interval are converted to Mbps over a short sliding
   window and pushed to the UI ~4× per second — smooth enough to feel real-time as you
   walk.
4. **Radio label.** `CoreTelephony`'s current radio-access-technology is read alongside so
   the number is tagged with 5G / LTE / etc.
5. **Sweep the room.** You move; the number moves; you stop where it's highest.

### Data source

Measuring throughput requires downloading *from somewhere*.

- **v1:** pull from a **public high-bandwidth endpoint** (e.g. a Cloudflare speed
  endpoint) — zero backend to run, instant to prototype.
- **Later:** a **small self-hosted streaming server** for tighter control, consistent
  results, and no dependency on a third party.

---

## Trade-offs to design around

Because the measurement is an *active* data transfer, not a passive read:

- **It uses cellular data.** A continuous stream burns through your data plan. Scout needs
  a clear **start/stop**, a visible **data-used counter**, and a warning before it runs on
  a metered plan.
- **Battery.** Sustained radio + screen use. Scout is a "run it for a couple of minutes
  while I find the spot" tool, not a background monitor.
- **No background running.** Throughput can only be measured while actively transferring;
  this is a foreground, screen-on experience by design.

---

## Core UX

- A big, glanceable **live Mbps readout** you can see from arm's length while walking.
- The **radio generation** beside it (5G · / LTE ·).
- A **rolling trend graph** so you can see improvement as you move.
- Clear **Start / Stop** and a **session data-used** counter, always visible.
- A first-run explainer that's honest about *what* is being measured (throughput, not bars)
  and that it uses cellular data.

---

## Technical stack

- **SwiftUI** app.
- **Network.framework** (`NetworkConnection`) for cellular-bound transfers.
- **CoreTelephony** (`CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology`) for the
  radio-generation label.
- **Minimum deployment target: iOS 26.** This lets Scout use `NetworkConnection`
  throughout with no legacy `NWConnection` fallback path — the networking code stays
  simple and modern.

---

## Status

Early — this README captures the concept and the key technical constraints. No app code
yet.

### Roadmap (rough)

- [ ] Cellular-bound throughput sampler (forced `.cellular` interface)
- [ ] Rolling-window Mbps calculation, ~4 Hz UI updates
- [ ] Radio-generation label via CoreTelephony
- [ ] Live readout + trend graph UI
- [ ] Start/stop + data-used counter + metered-plan warning
- [ ] First-run explainer (honest about throughput-vs-bars)
- [ ] Decide data source: public endpoint → self-hosted server
- [x] Minimum deployment target: **iOS 26**

---

## Build status

This repo is built by the autonomous implementation harness (`.harness/`) — one fully-verified task at a
time, gated on green CI. The table reflects the current backlog in
[`.harness/tracking/TASKS.json`](./.harness/tracking/TASKS.json); the loop keeps task status in lockstep as
work lands. See [`.harness/docs/HARNESS.md`](./.harness/docs/HARNESS.md) for how it works.

| Task | Description | Status |
|------|-------------|--------|
| T001 | Xcode project scaffold + SwiftFormat/SwiftLint + CI green on an empty build | 🔒 needs-human — pending |

_Grow the backlog with `/implementation-harness-add-to-backlog`._

---

## Why "Scout"

You *scout* the room for signal — sweep the phone around, hunt for the good spot, plant
yourself there.
