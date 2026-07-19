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
App-Store-safe iOS app can. Instead it measures **effective throughput over the cellular radio** by
actively transferring data (both download and upload) and timing how fast it moves.

For the "find the good spot" use case this is arguably the *better* metric anyway: bars
can read full while the connection is unusable, but measured Mbps is the ground truth of
whether your phone can actually do anything where you're standing.

### What we *can* surface

- **Live throughput in Mbps** — both download (hero metric) and upload (secondary) — updated
  ~4× per second on a rolling window.
- **Deliberately capped at realistic limits:** downloads capped at 10 Mbps (displayed "10+"),
  uploads capped at 5 Mbps (displayed "5+"). The product question is "is this spot good enough
  to load a video / send messages?" — not "how fast exactly" — so we measure with small paced
  transfers (~256 KB) to keep total data use roughly **30–60 MB per minute**, matching the
  consent copy.
- **Quality bands** (download-driven): **Great** ≥ 6 Mbps, **Usable** ≥ 2 Mbps, **Poor** < 2 Mbps.
  Color + label always shown together.
- **Radio generation** — whether you're currently on **5G NR, LTE, 3G**, etc., via
  `CoreTelephony`. So the readout reads e.g. **"5G · 10+ Mbps"** with a quality label.

### What we deliberately *cannot* surface

- Raw signal strength (dBm), bars, RSRP/RSRQ — **not available to third-party apps.**
- Anything about *why* signal is weak (tower distance, band, congestion) — invisible to us.
- Trend history or stored measurements — Scout measures in-session only, no persistence.

---

## How it works

1. **Forced cellular transfer, both directions.** Scout opens connections bound to the **cellular
   interface only** (even if Wi-Fi is connected) so the measurement reflects the mobile
   signal, not your router. Uses `Network.framework`'s `NetworkConnection` with
   `requiredInterfaceType = .cellular` (iOS 26+). It transfers in both directions: measuring
   download from a remote server and upload back to it.
2. **Paced, small transfers.** Rather than a continuous stream, Scout makes repeated small
   transfers (~256 KB) at a measured pace, so total session data stays in the 30–60 MB/min range
   and feels respectful of a metered plan.
3. **Rolling-window rate.** Bytes-per-interval are converted to Mbps over a short sliding
   window and pushed to the UI ~4× per second — smooth enough to feel real-time as you
   walk.
4. **Radio label.** `CoreTelephony`'s current radio-access-technology is read alongside so
   the number is tagged with 5G / LTE / etc.
5. **Foreground-only.** The moment the app backgrounds, all transfers stop immediately.
   No background measurement of any kind — this is a foreground, screen-on experience by design.
6. **Sweep the room.** You move; the number moves; you stop where it's highest.

### Data source

Measuring throughput requires endpoints to transfer to/from.

- **v1:** pull from **Cloudflare's public speed endpoints** (`https://speed.cloudflare.com/__down?bytes=N`
  for download, `/__up` for upload) — zero backend to run, instant to prototype.
- **Later:** a **small self-hosted streaming server** for tighter control, consistent
  results, and no dependency on a third party.

---

## Trade-offs and P0 rules

Because the measurement is an *active* data transfer, not a passive read:

- **It uses cellular data.** Paced transfers stay roughly 30–60 MB per minute. Scout shows
  a **visible session data counter** and the first-run consent is explicit about data use and
  metered plans.
- **Battery.** Sustained radio + screen use. Scout is a "run it for a couple of minutes
  while I find the spot" tool, not a background monitor.
- **P0 rule — no background running.** The moment the app leaves the foreground (backgrounded,
  app switcher, screen lock), **ALL data transfers stop immediately**. No background mode,
  no widget, no lock-screen — this is a foreground, screen-on experience by design. This rule
  is non-negotiable for user trust.

---

## Core UX

Scout is a focused, single-purpose instrument: **no accounts, no history, no map.** It opens and
is already measuring (once first-run consent is given).

- A big, glanceable **live dual-arc dial** with download (outer, hero) and upload (inner, secondary)
  throughput — visible from arm's length while walking.
- The **radio generation** labeled (5G · / LTE ·).
- A **quality label** (Great / Usable / Poor, download-driven) pinned to the bottom, color + label
  always together.
- A **session data counter** (split download/upload, in MB) showing total bytes transferred this
  session, always visible.
- **Automatic measurement** — no Start/Stop buttons. The app measures whenever this screen is
  foreground; transfers stop immediately on background/lock.
- A **first-run consent flow** that's honest: throughput (not bars), dual measurement, 30–60 MB/min
  data budget, and the promise "only while the screen is on."
- **Three screen states:** Splash (cold launch), First-run consent (once), Measuring (home), plus a
  fallback "No cellular" state for Airplane mode / Wi-Fi-only.

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

## Design source of truth

The authoritative design is in **`design/design_handoff_scout/`** — both the HTML prototype
(`Scout.dc.html`) and this README. The v1 app recreates those designs natively in SwiftUI
(iOS 26+), using system materials, SF Pro, and standard iOS patterns. Where the HTML uses
web techniques, the implementation uses SwiftUI equivalents (e.g. `Canvas` / `TimelineView` for
the rotating sweep, `Circle().trim()` for the arc).

---

## Building this project

This repo is built by the autonomous implementation harness (`.harness/`) — one fully-verified task at a
time, gated on green CI. The live backlog and per-task status live in
[`.harness/tracking/TASKS.json`](./.harness/tracking/TASKS.json) and the harness dashboard (always current);
see [`.harness/docs/HARNESS.md`](./.harness/docs/HARNESS.md) for how the loop works and
[`.harness/README.md`](./.harness/README.md) to get started.

---

## Why "Scout"

You *scout* the room for signal — sweep the phone around, hunt for the good spot, plant
yourself there.
