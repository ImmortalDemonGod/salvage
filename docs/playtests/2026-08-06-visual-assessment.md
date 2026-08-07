# Visual System Assessment — Untitled Dive/Limb-Combat Game

**Instrument:** Game Visual Systems Evaluation Framework v0.1
**Frames supplied:** 2 (F1 "dive 2 of 9 · the descent", F2 "dive 3 of 9 · the hunter crab")
**Resolution:** 1119 × 635 both
**Weighted score:** **243 / 400 (60.8%)**

> **Sample-size caveat.** The protocol specifies ≥6 frames, ≥12 preferred. With 2 frames, Layer 9
> (cohesion) and all drift findings are provisional — they are consistent across the pair but the
> pair is small. Layer 9's score in particular should be treated as **E2, not E1**, until more
> frames are seen. A mouse cursor is visible in F1; treated as capture artifact, not a defect.

---

## 1. Genre Contract (declared before scoring)

Turn-based tactical combat with limb/part targeting, run-structured ("dive N of 9"), shared-resource
economy (AIR), keyboard-driven, text-forward. No per-frame time pressure. **Information density is
the product** — the player's job is reading state and planning, not reacting.

This is not a listed column in §5 of the framework, so weights are derived and documented here:

| Layer | Weight | Rationale |
|---|---|---|
| 1. Value structure | 14 | Entity separation still matters |
| 2. Color allocation | 15 | Heavy semantic encoding load |
| 3. Shape & silhouette | 11 | Limb targeting depends on part legibility |
| 4. Detail density | 8 | Low action density lowers the stakes |
| 5. Lighting & depth | 4 | Flat 2D presentation by design |
| 6. Spatial hierarchy | 8 | Single-screen diorama, no navigation |
| 7. **UI system** | **24** | The UI *is* the game surface here |
| 8. VFX & feedback | 3 | Minimal; mostly E0 from stills |
| 9. Cohesion | 11 | Solo/small-team indie; process proxy |
| 10. Technical finish | 2 | Vector-flat, low surface area for defects |

---

## 2. Measurements

**T1/T2 — Value structure**

| | F1 | F2 |
|---|---|---|
| Mean lightness | 0.157 | 0.160 |
| Below 0.15 | 76.0% | 79.1% |
| Below 0.25 | 90.7% | 87.3% |
| Above 0.60 | 2.1% | 2.7% |
| Bins 1–2 of 10 | **89.6%** | **85.7%** |

**T6 — Palette (k=8, area-weighted).** F1: four near-identical navies at 39.8 / 18.5 / 17.5 / 13.0%
= **88.8% of frame**, then olive-grey 5.7%, tan 3.3%, dark 1.3%, black 0.9%. F2 substantially
identical (86.3% navy family).

**T7 — Saturation.** Mean S 0.52 / 0.50; 76.1% / 64.8% of pixels above S 0.5. High saturation
figure is an artifact of dark navy being a saturated hue — not a saturation-ceiling problem.

**T9 — Edge density.** Overall 9.82% (F1) / 14.28% (F2). Heatmap peak in **both** frames is
row 4 / col 1 — the action-button stack — at **50.6% / 49.5%**. Battlefield tiles (rows 3–4,
cols 5–7) run 3.8–8.2% in F1.

**Content coverage (L > 45): 12.3% (F1) / 15.6% (F2). The frame is 84–88% empty field.**

**T10 — Contrast audit, 16 regions**

| Region | Ratio | 4.5:1 | 3:1 |
|---|---|---|---|
| Header "AIR one shared tank" | 7.82 | PASS | PASS |
| "dive 2 of 9 · the descent" | 7.68 | PASS | PASS |
| Narrative log text (amber on dark) | 4.93 | PASS | PASS |
| Action title "Axe Kick" | **3.84** | FAIL | PASS |
| Action subtitle "2 dmg, re-aims…" | **4.17** | FAIL | PASS |
| "End turn [ENTER]" | **4.34** | FAIL | PASS |
| "Scuba 24/24" label | 4.85 | PASS | PASS |
| "MAW 6/6 [Q][A]?" | 8.35 | PASS | PASS |
| Bottom status text | 9.11 | PASS | PASS |
| "CLAW 12/12 [W][A]?" | 8.30 | PASS | PASS |
| "UNDER [E]" | 9.81 | PASS | PASS |
| **Disabled "Read limb 1 air [A]"** | **2.83** | **FAIL** | **FAIL** |
| **Disabled subtitle "what is it weak to?"** | **2.09** | **FAIL** | **FAIL** |
| "Prototype1 34/34" label | 5.11 | PASS | PASS |
| Brittle tooltip | 7.27 | PASS | PASS |
| Bottom action log | 5.81 | PASS | PASS |

11 pass / 3 marginal / 2 fail.

**T8 — Colorblind simulation (ΔRGB, base → deuter / protan)**

| Pair | Base | Deuter | Protan | Verdict |
|---|---|---|---|---|
| Ally teal vs enemy red (labels) | 160.9 | 112.0 | 115.5 | Survives |
| Ally bar vs enemy bar (fills) | 175.4 | 136.1 | 142.4 | Survives |
| Damage ring amber vs enemy red | 83.3 | 92.0 | 83.4 | Weak in all conditions |
| **UI chrome amber vs damage-ring amber** | **2.4** | 3.0 | 1.7 | **Identical color** |

**Local subject-vs-surround contrast**

| Pair | CR |
|---|---|
| F1 creature limbs vs local bg | **2.82** |
| F1 background silhouette shapes vs field | 2.00 |
| F1 player sprite vs local bg | 10.10 |
| F2 crab body vs local bg | 11.35 |
| F2 Prototype1 vs deck | 3.14 |
| **F2 crab body vs Scuba body** | **1.08** |

**T3/T4 — Blur σ=12.7px leaves 8.3% / 11.7% of pixels above L60. 200px thumbnail: all UI text
illegible; only sprite/creature masses survive.**

---

## 3. Layer Scores & Findings

### Layer 1 — Value structure: **2 / 4** (Functional)

The histogram shows **two bands, not the three-to-four the framework targets**: 85–90% of pixels sit
in the bottom two deciles, 2% above 0.6. Value has one gap to spend and everything competes for it.

Where it's spent well, it's spent very well — the player sprite reads at CR 10.10 and the F2 crab at
CR 11.35. Both are excellent.

Where it fails: **F1's MAW sits at CR 2.82 against local background, while decorative background
silhouettes sit at CR 2.00.** The enemy body and the set dressing occupy adjacent value bands. This
is exactly the "decoration hogging the same band as gameplay content" failure. F2 does not have this
problem, which makes it a **per-encounter inconsistency**, not a global one — the MAW encounter is
measurably harder to read than the hunter crab encounter.

> **F-001** · L1 · **S2 Major** · **E1** · Frame F1
> MAW body reads at CR 2.82 vs local background; background décor reads at 2.00. Enemy and
> decoration are in adjacent value bands. F2's crab achieves 11.35 in the same engine, so the
> ceiling is proven reachable.
> *Confound:* the MAW may be intentionally murky (a deep, half-seen thing) — a defensible fiction
> choice. If so it needs a compensating channel (rim, outline, motion), not assessable here (E0).
> *Fix:* asset-level. Lift MAW albedo to F2-crab range, or add an edge treatment.

### Layer 2 — Color allocation: **3 / 4** (Systematic)

**This is a real reservation system**, which is uncommon and worth stating plainly. Distinct
semantic assignments hold across both frames:

- **teal/mint** — ally HP, used nowhere else in frame
- **salmon/red** — enemy limb HP
- **tan/khaki** — creature bodies
- **warm off-white** — player-side sprites
- **navy family** — void/ground, 86–89% coverage
- **olive-green** — interactive panel fill

Colorblind performance is acceptable: ally-vs-enemy separation degrades ~30% under deuteranopia
(161 → 112) but survives, helped by a value difference and by positional redundancy (ally bars sit
above the sprite; enemy limb bars run horizontally from the limb).

The failure is **overload, not absence**:

> **F-002** · L2 · **S2 Major** · **E1** · Frames F1, F2
> The incoming-damage indicator (the amber ring showing "5") and every UI box border are the
> **same color** — ΔRGB 2.4, CR 1.03. The single most time-critical piece of information on screen
> is painted in the frame-decoration hue. This violates the reserved-action-layer rule: the vivid
> action color must appear nowhere in the base layers.
> Amber-vs-enemy-red separation is additionally weak (ΔRGB 83, CR 1.62; 92 under deuteranopia), so
> the threat indicator is also poorly separated from the thing threatening you.
> *Confound:* none material. Both instances measured directly.
> *Fix:* **system-level, highest ROI in this report.** Demote chrome amber (desaturate or shift it
> toward the navy family) and promote the damage indicator to a hue used nowhere else. Cheap,
> non-artistic, changes the read of every combat frame.

### Layer 3 — Shape & silhouette: **2 / 4** (Functional)

Creature silhouettes are the strong part. The MAW's segmented tentacle-arms and the crab's splayed
legs are distinctive, and — importantly — they **read as limb-targeting affordances**. The shape
language is doing mechanical work: you can see where the parts are, which is the whole game.

The problem is on the friendly side:

> **F-003** · L3 · **S2 Major** · **E1** · Frame F2
> The crab body and the Scuba sprite measure **CR 1.08** against each other — (200,211,176) vs
> (240,209,183). Player and enemy occupy effectively identical value *and* hue. Friend/foe is
> encoded **only** by size, screen position, and the attached HP label — no body-level visual
> channel distinguishes them. Prototype1 (orange) does differ, but sits on a deck at CR 3.14.
> *Confound:* in play, position is stable and animation differs — real disambiguators not visible
> in stills (E0). The finding is that the *body* carries no signal, not that players are confused.
> *Fix:* system-level. Cool-shift the player-side palette, or apply a consistent ally rim/fresnel —
> the approach Riot uses in Valorant, where allies and enemies get differently-colored grazing-angle
> light for exactly this reason.

Secondary: **Scuba's silhouette is ~25×45px and generic.** It does not survive T4 thumbnail. In a
game where the player character is the emotional anchor of a 9-dive run, that's a missed identity
opportunity — though at this camera scale it's a hard constraint, not negligence.

### Layer 4 — Detail density: **3 / 4** (Systematic)

Density is low and there are genuine rest areas (rows 5–6 mostly 0–4%). Clustering is fine; nothing
is scattered.

The notable structural fact: **the busiest region of the frame is the UI, not the battlefield.**
Edge-density peaks at ~50% in the action-button stack while battlefield tiles run 4–8%. For most
games that inversion would be a finding. For a text-forward tactics game where reading state *is*
the activity, it's arguably the correct allocation — flagged as an **observation, not a defect**,
pending the genre contract you want to commit to.

### Layer 5 — Lighting & depth: **1 / 4** (Attempted but broken)

Effectively unmanaged. Flat fills, no directional key, no cast shadows, no atmospheric perspective.
Depth is **binary**: the F2 crab at CR 11.35 and the background silhouettes at CR 2.00, with nothing
occupying the space between.

Scored 1 rather than 0 because the parallax background shapes are a real attempt at a background
plane.

> **F-004** · L5 · **S3 Moderate** · **E1** · Both frames
> No midground value band exists. Foreground and background are separated by ~9 CR with no
> intermediate staging.
> *Opportunity, not just defect:* this is an **underwater** game. Atmospheric perspective is
> physically motivated here, visually cheap in a flat-fill renderer (a per-depth-layer value/hue
> lerp toward the navy), and would simultaneously improve Layer 5, Layer 6, and F-001's readability
> problem. Highest quality-per-effort item in the report.

### Layer 6 — Spatial hierarchy: **2 / 4** (Functional)

The battlefield has a legible focal anchor. But **content coverage is 12.3% / 15.6% — the frame is
84–88% empty navy.** In F1 the entire region left of x≈400 between y≈120 and y≈500 is dead space
holding nothing and framing nothing. The composition is UI pinned to the edges with a small diorama
floating right-of-center and a hole in the middle.

Some of this is intentional (void = depth = dread), and it's a defensible mood choice. But the void
is currently *uniform*, so it reads as unfilled canvas rather than as space. Gradient, particulate,
or depth-graded void would convert the same pixels from "empty" to "deep."

### Layer 7 — UI system: **2 / 4** (Functional) — 24% weight

**Type classification (Fagerholt–Lorentzon):** overwhelmingly **non-diegetic** (air tank, dive
counter, action list, narrative box, status boxes, action log) with a working **spatial** layer
(HP labels above sprites, limb bars anchored to limbs, damage rings, reticle). No diegetic, no meta.

Anchoring the limb HP bars to the limbs themselves is a **correct and non-obvious choice** — it puts
the targeting information in the same place as the target. That's the spatial layer earning its
production cost.

**What's working:** single typeface with a consistent size ramp; the corner-tick box motif applied
uniformly across every panel (a genuine identity marker); 11 of 16 measured text regions clear
4.5:1.

**What's not:**

> **F-005** · L7 · **S1 Critical** · **E1** · Frame F2
> Disabled action "Read limb 1 air [A]" measures **2.83:1**; its subtitle "what is it weak to?"
> measures **2.09:1**. Both fail the 3:1 floor. Web practice exempts disabled controls, but that
> exemption assumes the disabled control carries no information the user needs. Here it does —
> the subtitle is the explanation of *what the action would have done*, and in a resource-economy
> game "why can't I do that right now" is a core question. The player loses the answer.
> *Fix:* asset-level. Lift disabled state to ≥3:1 and keep the subtitle at ≥4.5:1; encode
> "disabled" via desaturation plus an explicit affordance change, not via lightness alone.

> **F-006** · L7 · **S2 Major** · **E1** · Frames F1, F2
> **Anchor drift.** F1 shows one status box at x≈420–700, y≈510–595. F2 shows two boxes at
> x≈275–555 and x≈565–845 plus a full-width action-log bar at y≈600. Between frames the status
> readout changes count, position, and horizontal extent. There is no stable screen location for
> "where is my party state," so the eye must re-acquire it every turn.
> *Confound:* the layout is presumably reflowing to accommodate a variable party size — a real
> constraint, not carelessness. But reflow is a solvable layout problem, not a required outcome.
> *Fix:* system-level. Reserve fixed slots sized for max party count; render empty slots as
> placeholders or collapse them without moving their neighbors.

> **F-007** · L7 · **S3 Moderate** · **E1** · Frame F1
> Three action-button text regions measure 3.84, 4.17, 4.34 — all clear 3:1 but miss 4.5:1. These
> are the most-read interactive elements on screen.
> *Fix:* trivial. Darken the olive panel fill ~8–10% or lighten the label text.

> **F-008** · L7 · **S3 Moderate** · **E2** · Both frames
> **Zero iconography.** Every piece of information is text. In an information-dense tactics UI with
> a repeating vocabulary (air cost, damage, limb state, brittle/weak tags), this pushes all parsing
> through reading. Shape-and-color encoding for the recurring atoms would cut glance cost
> substantially. Not a defect — a deliberate-looking text-forward aesthetic — but an unexploited
> channel.

**Latent risk (E3):** spatial-layer elements (limb bars, HP labels) have **no scrim, outline, or
shadow**. Currently harmless because the background is uniformly dark. If any brighter environment
ships — a surface level, a lit interior, a bright hazard — these elements have no background
treatment and will fail immediately. Cheap to fix now, expensive to retrofit across a content set.

### Layer 8 — VFX & feedback: **2 / 4** — mostly **E0**

Assessable: the trajectory line (Scuba → reticle) is low-contrast against navy; the reticle is a
distinct yellow and reads well; damage rings are proportionally sized to the number they carry.
Effect silhouettes are simple and don't occlude their targets.

**Not assessable and not opined on:** timing, anticipation, decay, hit-stop, telegraph legibility,
whether feedback is proportional to action weight in motion, screen-space clutter during resolution.
Requires video.

### Layer 9 — Cohesion: **4 / 4** (Systematic and expressive) — provisional, E2

**The strongest layer by a wide margin, and the most important signal in the report.**

Every asset is unmistakably one hand: flat fills throughout, no gradients, no mixed shading models,
no outline-treatment inconsistency, one typeface, one border motif, one palette source. Texel
density is not applicable (vector-flat). No proportion drift. No asset-pack tells.

**Amateur-signature cluster: 0 of 8 hits.** No engine-default UI, no icon-family mixing (there are
no icons), no contradictory light directions, no texel mismatch, no uniform-detail failure, a
reserved palette does exist, proportions are consistent, no post-processing masking.

Per the framework's own logic, cohesion is the best available proxy for **production process
maturity** — it's the one thing individual asset skill cannot fake, because it requires a style
discipline enforced over time. This project has one.

### Layer 10 — Technical finish: **3 / 4**

Clean edges, consistent AA, no z-fighting, no seams, no clipping, no overflow. No post-processing
stack at all, which removes an entire class of failure. Mouse cursor in F1 is a capture artifact.

---

## 4. Weighted Score

| Layer | Score | Weight | Points |
|---|---|---|---|
| 1. Value structure | 2 | 14 | 28 |
| 2. Color allocation | 3 | 15 | 45 |
| 3. Shape & silhouette | 2 | 11 | 22 |
| 4. Detail density | 3 | 8 | 24 |
| 5. Lighting & depth | 1 | 4 | 4 |
| 6. Spatial hierarchy | 2 | 8 | 16 |
| 7. UI system | 2 | 24 | 48 |
| 8. VFX & feedback | 2 | 3 | 6 |
| 9. Cohesion | 4 | 11 | 44 |
| 10. Technical finish | 3 | 2 | 6 |
| **Total** | | **100** | **243 / 400 = 60.8%** |

**Rapid triage (§7) cross-check:** 4 of 6 applicable questions pass. Grayscale entity-finding is
frame-dependent (F2 pass, F1 marginal); 200px thumbnail fails on all text; palette jobs are all
nameable; shadow test is N/A; smallest text contrast fails at 2.09:1; no imported-looking asset;
zero icon families. Triage and full instrument agree: **a managed visual system with allocation
problems**, which is the favorable side of the diagnosis.

---

## 5. Remediation, ordered by severity × effort

| # | Finding | Sev | Effort | Action |
|---|---|---|---|---|
| 1 | F-002 | S2 | **Low** | **Split amber.** Demote chrome borders toward the navy family; give incoming-damage/threat a hue reserved exclusively for it. Changes the read of every combat frame. |
| 2 | F-005 | S1 | **Low** | Lift disabled-state contrast to ≥3:1, subtitle to ≥4.5:1. Encode disabled via desaturation + affordance, not lightness alone. |
| 3 | F-007 | S3 | **Trivial** | Darken olive panel fill ~8–10% to clear 4.5:1 on the three action buttons. |
| 4 | F-003 | S2 | Medium | Encode friend/foe in the body. Cool-shift player-side palette or add an ally rim treatment. |
| 5 | F-006 | S2 | Medium | Lock status-readout anchors to fixed slots sized for max party. |
| 6 | F-001 | S2 | Low | Lift MAW body contrast toward the F2-crab range (2.82 → ≥6), or give it a compensating edge treatment. |
| 7 | F-004 | S3 | Medium | **Add depth staging.** Per-layer value/hue lerp toward navy. Fixes L5 and L6 together and helps F-001. Best quality-per-effort item here. |
| 8 | Latent | — | Low | Add scrim/outline to spatial-layer UI *before* any bright environment ships. |
| 9 | F-008 | S3 | High | Consider iconography for the recurring information atoms (air cost, damage, limb state). |

**Items 1–3 are all low-effort and account for the two highest-severity findings.** They are
non-artistic changes — color-value edits, not redraws.

---

## 6. Assessment Summary

This is **not** a game with an art problem. The cohesion score of 4/4 and a clean sweep on the
amateur-signature cluster say there is a working visual system and someone enforcing it — the rarer
and harder half of the job is already done.

The score of 60.8% is depressed almost entirely by **allocation**: a reserved palette exists but
amber is doing two incompatible jobs; value contrast is achievable (proven at CR 11.35) but
inconsistently spent; the UI has real structure but drifts its anchors and drops two text elements
below the accessibility floor; and an underwater setting is leaving free depth staging on the table.

Allocation problems inside a coherent system are the cheap kind. The reverse — beautiful assets with
no system — is what usually can't be fixed without restaffing.

**Re-assess after items 1–3.** They're low-effort, and if the estimate is right they should move the
weighted score into the low 70s without a single asset being redrawn.
