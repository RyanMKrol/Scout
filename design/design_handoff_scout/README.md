# Handoff: Scout — live cellular-speed finder (iOS)

## Overview
Scout turns an iPhone into a live signal-finder you sweep around a room like a metal
detector. It measures **real cellular throughput (Mbps)** — not "bars" — updates it ~4×
per second, and labels the reading Great / Usable / Poor so a person can walk around and
settle where usable speed actually is. The app is a focused, single-purpose instrument:
no accounts, no history, no map. It opens and it is already measuring.

**Chosen direction: "Sweep"** — a radar-style dial. This is what to build. The other
directions in the prototype (Readout, Verdict, Field) were exploration and can be ignored.

## About the design files
The files in this bundle are **design references created in HTML** — a prototype showing
the intended look, motion, and states. They are **not production code to copy**. The task
is to **recreate these designs natively in SwiftUI** (deployment target iOS 26), using
system materials, SF Pro, and standard iOS patterns. Where the HTML uses web hacks
(conic-gradient sweep, SVG rings), implement the native equivalent (e.g. `Canvas` /
`TimelineView`, `Circle().trim`, `AngularGradient`).

The one thing the implementation must get honest and right — separate from visuals — is the
measurement itself: **Scout can only measure throughput by actively transferring data over
the cellular radio and timing it.** iOS exposes no public API for raw signal strength (dBm /
RSRP / bars); using private APIs gets the app rejected. The UI must therefore **never** show
bars, an antenna meter, or a dBm value. Radio generation (5G / LTE / 3G) via
`CTTelephonyNetworkInfo` is allowed and shown.

## Fidelity
**High-fidelity.** Colors, typography, spacing, motion timing, and copy below are final —
recreate pixel-accurately with SwiftUI equivalents. Dark mode only (by decision); no light
mode required.

## Screens / Views

The app is essentially two screens plus supporting states:
1. **Splash** (brief, on cold launch)
2. **First-run consent** (once, before the first measurement)
3. **Measuring** (the home screen — where ~all time is spent)
4. **No cellular** (fallback state of the measuring screen)

All screens: near-black background `#050506`, portrait, safe-area aware. The iOS status bar
and home indicator are the system's own (shown by the device frame in the prototype only).

---

### 1. Splash
- **Purpose:** momentary brand beat while the first measurement spins up. Shown ≤ ~1s, or
  until the first reading is ready. Not shown often (only on cold launch).
- **Layout:** vertically + horizontally centered stack. Radar mark, then wordmark, then
  tagline. A thin loader bar and one honest line pinned near the bottom (~64pt up).
- **Components:**
  - **Radar mark** — 196×196pt. Three concentric stroked rings (r = 92 / 62 / 32 pt,
    stroke 1.5pt, white at 9% / 11% / 13% opacity) + a filled center dot (r 6pt, accent
    green). A soft rotating "sweep" wedge behind it (angular gradient, ~98° of accent at
    ~18% opacity), rotating 360° every **3.2s linear, infinite**.
  - **Wordmark** — "Scout", SF Pro Display, 48pt, weight ~650 (semibold→bold),
    letter-spacing −1.5, white.
  - **Tagline** — "Find your signal.", 17pt medium, white 50%.
  - **Loader** — 132×3pt track (white 12%), fill 40% width, accent green, radius pill.
  - **Honest line** — "Measures real usable speed — not signal bars", 12pt, white 30%.

### 2. First-run consent
- **Purpose:** the single intentional pause before measuring, because measuring spends
  cellular data. Shown once (persist a flag). Honest, non-alarming; "Not now" is a real
  choice that exits without measuring.
- **Layout:** top-aligned content, buttons pinned to the bottom (thumb reach). Padding
  ~32pt sides, top begins below status bar (~132pt from top in the mock).
- **Components:**
  - **Radar mark** — 76×76pt, same construction as splash (rings r 35/22, center dot r 4.5),
    static sweep wedge at 20% opacity.
  - **Title** — "Scout uses cellular data to measure", 30pt bold, letter-spacing −0.6,
    line-height ~1.12, white, balanced wrap.
  - **Body** — "To read real, usable speed, Scout transfers a little data over your cellular
    connection while it's running.", 16pt, white 60%, line-height ~1.55.
  - **Three bullets** (accent-green 6pt dot + text, 15pt, white 72%, 18pt gap):
    1. "Roughly **10–40 MB per minute**, always shown on screen." (the MB figure white 100%, semibold, tabular)
    2. "Only while the screen is on and you're looking — never in the background."
    3. "On a metered or low-data plan? Keep sessions short."
  - **Primary button** — "Start sweeping", full-width, height 56pt, radius 16pt,
    background accent green `oklch(0.80 0.14 158)`, label 18pt weight 650, text `#04140C`
    (near-black for contrast on green).
  - **Secondary** — "Not now", height 44pt, centered, 16pt medium, white 50%, no fill.

### 3. Measuring (home)
- **Purpose:** the core. Big live number + dial; the person sweeps the phone and watches it
  climb. No Start/Stop buttons — it measures whenever this screen is foreground.
- **Layout:** full-height vertical stack, space-between: status row (top), dial (center),
  footer (bottom). Padding: top ~120pt (below status bar), sides 30pt, bottom 48pt.
- **Components:**
  - **Status row** (top, centered horizontally): a **pulsing dot** (7pt, accent = current
    quality color, opacity/scale pulse `scoutPulse` 1.6s ease-in-out infinite: 0.3/0.8 →
    1/1 → 0.3/0.8) + label "SWEEPING", 14pt semibold, letter-spacing 2.5, uppercase,
    white 50%.
  - **Dial** — 288×288pt, centered. Layers:
    - *Sweep wedge*: 258×258 circle, angular gradient (~92° of quality color) at 14%
      opacity, rotating 360° / **3.4s linear infinite**.
    - *Track ring*: full circle, r 132pt, stroke 7pt, white 7%.
    - *Progress arc*: r 132pt, stroke 7pt, round cap, quality color. Fills from the top
      (start angle −90°) proportional to speed on a **log scale**:
      `fraction = clamp(log10(mbps + 1) / log10(169), 0.04, 1)`. Animate arc length
      changes over 0.28s linear, color over 0.45s ease.
    - *Center stack*: generation label (e.g. "5G", 15pt weight 590, letter-spacing 2,
      white 50%) → **hero number** (88pt, weight 600, letter-spacing −3, **tabular
      figures**, quality color, color transitions 0.45s) → "Mbps" (18pt medium, white 55%).
  - **Footer** (bottom, centered):
    - **Quality label** — "Great" / "Usable" / "Poor", 20pt semibold, quality color.
    - **Session data counter** — down-arrow glyph + value + "this session". 15pt, tabular.
      Value white 72%, suffix white 50%. Always visible; accumulates bytes transferred.

### 4. No cellular (fallback)
- **Purpose:** graceful, honest state when there's no cellular radio to read (Airplane
  mode, Wi-Fi-only, no SIM/service). Calm, not an error alarm.
- **Layout:** identical structure to Measuring.
- **Components:**
  - Status row: static dot at white 28% (no pulse) + "PAUSED", white 40%.
  - Dial: track ring only (white 6%), no arc, no sweep. Center shows an em-dash "—"
    (96pt, weight 600, white 22%) over "Mbps" (white 35%).
  - Footer: "No cellular to measure" (20pt semibold, white 82%) + body "Scout measures your
    **cellular** speed. Turn off Airplane Mode or Wi-Fi to start sweeping." (15pt, white 50%,
    centered, max width ~280pt; the word "cellular" white 70% semibold).

## Interactions & behavior
- **Cold launch:** Splash → (if first run) Consent → Measuring. After first run, Splash →
  Measuring directly.
- **Consent:** "Start sweeping" persists consent + enters Measuring. "Not now" exits (or
  returns to a minimal idle without transferring data).
- **Measuring cadence:** update the reading **~4×/sec (every 250ms)** on a rolling window of
  measured throughput. Number and arc update each tick; keep transitions smooth (arc 0.28s
  linear, color 0.45s ease) so it never looks jittery or strobing at 4Hz. **Use tabular
  figures** so the number doesn't shift width as digits change.
- **Quality thresholds** (drive color + label): `mbps ≥ 72` → Great; `≥ 18` → Usable;
  else Poor. (Tune with real-world data; keep three bands.)
- **Generation:** read from `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology`;
  map to "5G" / "LTE" / "3G". Display only; never a strength.
- **Cellular availability:** watch reachability / interface type; if the active path is not
  cellular (or transfer fails), show the No-cellular state and stop transferring. Resume
  automatically when cellular returns.
- **Foreground only:** measurement runs only while this screen is foreground and visible.
  Stop transfers on background/inactive. No background mode, widget, or lock-screen.
- **Accessibility:** hero number must support Dynamic Type (scale the dial/layout, don't clip).
  Quality is conveyed by **label + color together**, never color alone — keep the word.
  VoiceOver: announce e.g. "84 megabits per second, 5G, Usable signal, 14 megabytes used
  this session." Motion: respect Reduce Motion (drop the rotating sweep; keep the number).

## State management
- `firstRunConsentGiven: Bool` (persisted, e.g. `@AppStorage`).
- `appPhase: .splash | .consent | .measuring` (routing).
- Measuring session:
  - `currentMbps: Double` (rolling-window throughput, updated 4Hz)
  - `generation: enum { fiveG, lte, threeG, unknown }`
  - `sessionBytes: Int64` → format as MB for the counter
  - `quality: enum { great, usable, poor }` derived from `currentMbps`
  - `cellularAvailable: Bool` → toggles No-cellular state
- Measurement engine: repeatedly download from a throughput endpoint over the cellular
  interface, time it, compute a rolling Mbps; accumulate bytes into `sessionBytes`. (Backend
  choice is the dev's; none assumed for v1.)

## Design tokens
**Color**
- Background: `#050506` (near-black). Splash/consent may also use `#050506`; icon uses a
  radial `#101015 → #050506`.
- Text: white at 100% / 82% / 72% / 60% / 55% / 50% / 40% / 35% / 30% / 22% (see per-use above).
- Accent / quality colors (OKLCH — convert to sRGB for SwiftUI `Color`):
  - **Great (green):** `oklch(0.80 0.14 158)` ≈ `#3FD08A`-ish
  - **Usable (amber):** `oklch(0.82 0.13 82)` ≈ warm gold
  - **Poor (clay, not alarm-red):** `oklch(0.70 0.10 30)` ≈ muted terracotta
  - Brand/primary accent (splash, icon, buttons) = the Great green `oklch(0.80 0.14 158)`.
  - Convert with any OKLCH→sRGB tool and lock the hex in an asset catalog; keep the three
    quality colors equal in chroma/lightness so only hue signals meaning.

**Typography** — SF Pro (system). Display sizes: 160/152/96/88/62/48/44/30 pt as noted.
UI: 20/18/17/16/15/14/13/12 pt. Hero + all numeric readouts use **tabular figures**
(`.monospacedDigit()` or `.fontFeature` tnum). Letter-spacing (tracking) negative on large
display (−1.5 to −6 scaled), positive on small uppercase labels (2–2.5).

**Radius:** buttons 16pt; consent icon container n/a (circular); app-icon superellipse
(~22.5% of side — use the iOS icon mask, don't hand-roll).

**Shadow:** icon `0 12px 30px rgba(0,0,0,0.28)` (scales down with size). Screens are flat.

**Motion:** sweep rotation 3.2–3.4s linear infinite; pulse 1.6s ease-in-out infinite; arc
0.28s linear; color 0.45s ease; background/field 0.6s ease. Number cadence 250ms.

## Assets
- **App icon** — the radar mark: near-black superellipse, concentric rings, accent-green
  center dot, one static sweep wedge (angular gradient). Provided as a spec, not a file;
  produce the full icon set from it. Verify legibility at 60pt and 40pt.
- No photography or third-party icons. The only glyphs are the small down-arrow (data
  counter) and the concentric-ring mark — reproduce with SF Symbols / `Path` as convenient.

## Files
- `Scout.dc.html` — the full interactive prototype (all directions + the chosen "Sweep"
  flow: splash, consent, measuring, no-cellular). Open in a browser. The **Scenario** control
  forces Great/Usable/Poor to inspect each state. The signal shown is simulated.
- `ios-frame.jsx` — the device-bezel component used only to frame the prototype. Not part of
  the app; ignore for implementation.
- Build to spec from **Turn 2** (splash, measuring, no-cellular) and **Turn 3** (consent,
  icon). Turn 1 is discarded exploration.
