# Scout — Design Brief

**Prepared for:** the design agency engaged to design the Scout iOS app
**Prepared by:** Scout (product owner)
**Status:** v1 brief for a first-release (v1) design engagement

---

## 1. In one sentence

**Scout turns an iPhone into a live signal-finder you sweep around a room like a metal detector** —
so you can walk around, watch a number move, and settle where your cellular signal is actually good.

---

## 2. The problem we're solving

Everyone knows the feeling: a call drops in one chair but is fine in the next; a video buffers by the
window but not at the desk. The **"bars" in the status bar are almost useless for this** — they update
slowly, they're a coarse 0–4 scale, and a full-bars connection can still be unusable. **There is no good
way to *hunt* for good signal.**

Scout gives people a real-time instrument to do exactly that: hold the phone up, sweep it around the room,
and watch the reading climb as they find the good spot.

**The core interaction is a live number that responds as you move.** That responsiveness — the sense that
the phone is a real measuring instrument reacting to the world — is the heart of the product and the thing
the design must make feel great.

---

## 3. The single most important constraint (please read carefully)

There are two different things people call "signal," and **only one of them is available to a third-party
iOS app.** This shapes the entire product, so the design must be built around it honestly:

| | What it is | Available to Scout? |
|---|---|---|
| **Radio signal strength** (RSRP / dBm / "the bars") | How strong the raw radio link to the tower is | ❌ **No.** iOS exposes no public API. The private APIs get apps rejected from the App Store. |
| **Cellular throughput** (Mbps) | How much data actually moves over the cellular link right now | ✅ **Yes** — by actively transferring data over the cellular radio and timing it. |

**Scout measures throughput (Mbps), not bars.** The design must **never** depict a dBm reading, a signal-bars
icon, an antenna-strength meter, or anything that implies raw radio strength. Doing so would be dishonest and
would get the app rejected.

For the "find the good spot" use case, throughput is arguably the *better* metric — bars can read full while
the connection is unusable, but measured Mbps is the ground truth of whether the phone can actually do
anything where you're standing. **The design should lean into this as a strength**, framing Scout as
measuring *real, usable speed*, not a proxy.

### What Scout *can* show
- **Live throughput in Mbps**, updated ~4× per second on a rolling window (this is the hero number).
- **Radio generation** — whether you're on **5G, LTE, 3G**, etc. So a reading looks like **"5G · 84 Mbps"**.
- **A trend / history** while you move — a rolling graph so the climb toward a better spot is visible.

### What Scout deliberately *cannot* show
- Raw signal strength (dBm), bars, RSRP/RSRQ.
- *Why* signal is weak (tower distance, band, congestion) — invisible to us.

---

## 4. Who it's for & how it's used

- **Who:** anyone frustrated by patchy reception at home or work — non-technical mainstream users, plus a
  tech-curious tail who'll appreciate the honesty about what's measured.
- **Context of use — design for this specifically:**
  - **One-handed, on the move.** The person is *walking slowly around a room*, arm sometimes extended,
    eyes flicking between the screen and where they're going.
  - **Glanceable at arm's length.** The hero number must be readable from ~50–70 cm without squinting.
  - **Short sessions.** "Run it for a minute or two while I find the spot," not a background monitor.
  - **Foreground, screen-on.** Throughput can only be measured while actively transferring, so this is
    always an eyes-on-screen experience by design.

---

## 5. Product principles (the design should express these)

1. **Instrument, not dashboard.** Scout should feel like a precise, trustworthy measuring tool — calm,
   confident, legible — not a busy analytics dashboard.
2. **The number is the hero.** The live Mbps reading is the primary UI element. Everything else supports it.
3. **Real-time and alive.** Motion matters. The number updating and the trend line moving should feel
   immediate and physical, reinforcing the metal-detector metaphor. (Technical note: ~4 updates/second.)
4. **Honest by design.** Be upfront about what's measured (throughput, not bars) and that it uses cellular
   data. Trust is a feature.
5. **Effortless to start and stop.** A clear, obvious Start/Stop. No configuration required to get a reading.
6. **Respect the user's data & battery.** Data usage is always visible; the app never feels like it's
   secretly burning through a plan.

---

## 6. Screens & flows to design (v1 scope)

### 6.1 First-run explainer / onboarding
A short, honest intro (a few screens or one scrollable screen) that sets expectations:
- What Scout does (find the best signal spot by measuring real speed).
- The honest note: it measures **throughput (Mbps)**, not bars — and *why that's actually more useful*.
- That it **uses cellular data** while running, and is a foreground, screen-on tool.
- Ends in a clear call-to-action into the main screen.
- Should be skippable/returnable (accessible again from settings/help).

### 6.2 The main "Scout" screen (the core of the app)
The screen people spend ~all their time on. Must accommodate several **states**:
- **Idle / pre-start:** invites the user to begin; explains in a line what will happen.
- **Measuring (the hero state):** the big **live Mbps readout**, the **radio-generation label** (5G · / LTE ·)
  beside or above it, a **rolling trend graph** showing the last N seconds, a prominent **Stop**, and an
  always-visible **session data-used counter**.
- **Stopped / paused:** shows the last reading and/or session summary; easy to start again.
- **Error / edge states:** e.g. no cellular available, or the device is Wi-Fi-only / airplane mode — Scout
  measures the *cellular* radio specifically, so it needs a graceful "can't measure right now" state.

Design questions to resolve here: how the number, unit, radio badge, and trend graph compose; how big the
hero number can be; how the trend graph reads while moving; how "good vs bad" is conveyed *without* implying
bars (e.g. via the number, trend direction, or restrained color — see §9 open question on color).

### 6.3 Data-usage awareness
- An always-visible **session data-used** counter on the measuring screen.
- A **warning before/while running on a metered or low-data plan** (e.g. a first-run or pre-start notice).
  Because the measurement is a continuous download, this must be handled respectfully and clearly.

### 6.4 Light settings / about (keep minimal)
- Re-open the explainer / "how it works."
- Honest "what we can and can't measure" info.
- (Possibly) a choice of data source later — **not required for v1 visual design**, but leave room.

> **Out of v1 scope:** accounts/login, history across sessions/persistence, maps or floor-plans, social
> sharing, a companion web/marketing site, any settings beyond the minimal set above. If the agency sees a
> compelling case for one of these, raise it — but v1 is deliberately a focused single-purpose instrument.

---

## 7. Platform & technical constraints (design within these)

- **iOS only, iPhone-first, portrait orientation.** Minimum deployment target **iOS 26**, built in
  **SwiftUI**. Design should feel native and current to iOS 26 (modern system materials, type, and
  controls — e.g. Liquid Glass where appropriate), not a cross-platform or web aesthetic.
- **One-handed, thumb-reachable controls.** Primary actions (Start/Stop) should sit in comfortable reach.
- **Live data at ~4 Hz.** The number and trend update several times a second — motion/transition design
  should feel smooth at that cadence, never jittery or seizure-inducing.
- **Foreground, screen-on tool.** No background mode, no lock-screen/widget experience needed for v1.
- **No custom backend assumed for v1** — this doesn't affect visual design, but means no server-driven
  content or account state to design around.

---

## 8. Deliverables we'd like from the agency

1. **User flows** for the journeys in §6 (onboarding → first measurement → stop; error/edge paths).
2. **Wireframes** establishing layout and the state model of the main screen.
3. **High-fidelity mockups** for every screen and state, in **both light and dark mode**.
4. **A lightweight design system / component set** aligned to SwiftUI + iOS 26 (type scale, color, the hero
   readout treatment, the trend-graph component, buttons, badges, the data-used counter).
5. **Motion / interaction specs** for the two moving elements — the live number updating and the trend graph
   scrolling — since "feeling alive" is core. Prototype or annotated spec is fine.
6. **App icon** and basic brand expression (see §9).
7. **Accessibility-ready designs:** support Dynamic Type (the hero number especially), sufficient color
   contrast, VoiceOver-friendly structure, and a design that does **not** rely on color alone to convey
   meaning.
8. **Developer handoff** in Figma (or equivalent) with specs/tokens a SwiftUI developer can implement from.

---

## 9. Brand & tone

- **Name meaning:** you *scout* the room for signal — sweep the phone around, hunt for the good spot, plant
  yourself there. The **metal-detector metaphor** is the guiding image for the core interaction.
- **Personality:** precise, honest, calm, confident. A quality instrument. Not gamified, not noisy, not
  "hacker/technical" for its own sake — but it can have a satisfying, tactile, responsive feel.
- **Tone in copy:** plain-spoken and trustworthy; comfortable being honest about limitations.

---

## 10. Open decisions to confirm with us

These are genuinely open — we'd welcome the agency's recommendation:

1. **Visual direction / mood.** We've described a "precise instrument" personality but haven't locked a
   specific aesthetic (e.g. minimalist-clinical vs. warm-approachable vs. bold-utilitarian). Propose 2–3
   directions.
2. **Conveying "good vs bad" without bars.** How should the design signal that a reading is strong or weak —
   purely by the number and trend, by restrained color coding, by a qualitative label ("Great / Usable /
   Poor")? It must never look like signal bars, and must stay honest and non-alarming.
3. **iPad support:** v1 is iPhone-first; is a basic iPad layout in scope for this engagement or a later phase?
4. **Trend graph design:** timescale shown, whether it's a simple line, how it handles the ~4 Hz cadence, and
   whether it needs axis/scale labels or should stay glanceable-only.
5. **Any existing brand assets** (logo, colors, type) we should work within, or is this a clean slate?
6. **Timeline, budget, and milestone structure** for the engagement.

---

## 11. Reference material

- The product concept and technical rationale live in this repo's **`README.md`** — it's the fuller
  narrative behind this brief (including the honest measurement note in §3). Please read it alongside this
  document; where they differ in emphasis, this brief governs the design engagement.
