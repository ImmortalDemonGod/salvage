# Lessons from TIDESONG: the harness that built it, and what to change

**Status: v2.** v1 got the diagnosis wrong. It claimed the gates were
blind to presentation and that pixels are only checkable by a human or a
vision model. Both are false, and the run log disproves them. This
version starts where it should have started: with how the overnight
harness actually worked, because most of it is worth keeping and the
next prototype should inherit it rather than rediscover it.

Companion to the next design doc. RETRO.md is the backward-looking
account. `verify/PROOF.md` is the experiment behind Part 5.

---

# Part 1: How the overnight harness worked

Nine hours, 87 commits, 23:59 to 07:58, unattended. What made that
possible, mechanism by mechanism. This is the inventory to carry
forward.

## Keeping the run alive and on-mission

| Mechanism | What it did |
|---|---|
| `/goal` with a Stop-hook | Made stopping impossible before 11:00 AM AND before the morning report was complete with every gate stamped. SHIPPED was explicitly declared "a build state, not a stopping condition." |
| `date` printed every turn | The goal evaluator only sees the transcript, so printing the clock is what makes "no shorter than 11 AM" externally enforceable rather than self-reported. |
| `/loop` realignment every 45 min | Re-reads PROGRESS.md and DESIGN.md **in full**, because "they are the binding spec, your memory of them is not." Forces a statement of which slice priority and gate is active, verifies tests green, commits and pushes. Exists specifically to survive context compaction. |
| `caffeinate -dims` | Machine stays awake, verified alive at each checkpoint. |
| Source-doc precedence rule | DESIGN.md wins on conflicts, but before inventing anything it does not cover, consult `docs/` (Marc's proposal PDF, Glass_Goat's combat PDF, the merge proposal, the visual sketch). This is how condition stacking was nearly lost and then recovered. |

## Making claims falsifiable

- **Exit gates G1 to G9**, each with a numeric or procedural definition
  written before the work. "A gate claim without its instrument's output
  pasted below it does not count. 'It should work' and 'implemented' are
  not evidence."
- **UNVERIFIED as a first-class verdict**, but not an exit hatch: it
  requires pasted evidence of the attempt. G1, G2 and G8 may never be
  UNVERIFIED. State may not read SHIPPED unless G1 to G4 and G8 are
  green.
- **Every "X is done" line cites its evidence inline**, and every claim
  in the morning report carries a reproduce command.
- **Honest red beats dishonest green**, written into the gate text.

## Making the judges trustworthy

- **Judge bots pinned before any tuning**, with policies written into
  PROGRESS.md at 23:06 and first used at 00:06. Weakening one requires a
  logged reason plus re-running every gate that used it.
- **Judge constants pinned too**: greedy weights, heal thresholds,
  stamina penalty, boss part bonuses.
- **Metric pinned and hardened**: optimal floors measure raw
  `damageTaken`, not net `hpLost`, because net was zeroable by Heal Song
  and hid difficulty.
- **Bands encoded verbatim as tests**, thresholds copied out of
  PROGRESS.md into `test/bands.test.ts`.
- **Anti-overfit guards on disjoint fresh seed spaces.**
- **Judge pathology hunted deliberately**: an unweighted 1-ply greedy
  turtled on Bubble, so prevention was weighted 0.8x, a change that
  strengthens rather than weakens the judge.
- **Post-hoc calibration labelled as calibration.** The boss casual band
  was set around measured values in the same commit as the boss, so it
  was relabelled CALIBRATION, not prediction, and only the pre-existing
  optimal floors were treated as load-bearing.

## Adversarial review as a scheduled event

- Fresh-eyes agents every major feature and **at least every 90
  minutes**, seeing only artifacts (diffs, screenshots, the built page,
  the log), never the builder's rationale.
- **Rotating lenses**: code correctness, visual review, design fidelity
  against DESIGN.md, and a skeptic whose only job is to refute the
  latest done-claims.
- **The reviewer assigns severity. The builder may fix or escalate to a
  second independent agent, never downgrade.**
- **All HIGH findings fixed before any new feature work.**
- **Final panel of three** with the brief "prove this is NOT done."
  SHIPPED requires zero HIGH. Findings trigger a confirmation re-panel.

## Instruments

| Instrument | Purpose |
|---|---|
| `test/bots.ts` | Pinned casual / optimal / spam / nav policies |
| `test/bands.test.ts` | Difficulty bands as failing tests |
| `test/fuzz.test.ts` | 20k+ hostile world actions with per-action invariants |
| `tools/tune.ts` | The tuning loop, all encounters |
| `tools/usage.ts` | Ability usage histograms. Its own header: "a button nobody presses is a design smell G4's spam checks cannot see" |
| `tools/lab.ts` | Sim-only enemy variety lab: hook wrappers around the UNMODIFIED sim, never bundled |
| `tools/worldsim.ts`, `megasim.ts`, `deepsoak.ts`, `nightwatch.ts` | Scale: 20k mega-sim, 2000 fresh seeds per encounter, 50x soaks |
| `tools/keyfairness.ts` | Fairness of the eel's wandering key across 3000 seeds |
| `?demo=<state>` | ~20 state hooks for screenshots and reviews |
| `?filmstrip=combat` | **Real KeyboardEvents through the real handlers**, stepping the real frame function on a virtual clock, composing timestamped snapshots |
| `?filmstrip=click` | Same with real PointerEvents at measured screen coordinates |
| `?filmstrip=kill` | The win beat, held and measured |
| Headless Firefox screenshot loop | The render-and-look pass after every visual change |
| Permanent on-canvas error overlay | So an exception can never hide inside a blank screenshot |

## Rules that were adopted mid-run after being learned the hard way

These were promoted from incidents into standing rules, and they held:

1. **Times come only from `git log`.** No hand-typed timestamps anywhere,
   no wall-clock times in source comments. Adopted after three
   fabrication incidents.
2. **String replaces must assert.** Adopted after an unasserted replace
   silently broke the filmstrip instrument.
3. **Instrument labels must MEASURE, never assert.** Adopted after a
   filmstrip labelled a counterattack that a dodge had actually
   prevented.
4. **Process slips are logged, not hidden** (one commit landed without
   its pre-commit test run; it is in the log).
5. **Disclosure of softening.** When the shark was made easier, it was
   disclosed in the G5 curve entry rather than quietly absorbed.

---

# Part 2: What the harness caught on its own

Roughly 90 fixes came from the harness before any human played it. A
representative sample, chosen because each shows a different mechanism
working:

| Defect | Severity | Found by |
|---|---|---|
| Flat 60 percent respawn death-looped 20 of 100 casual runs | design-breaking | casual bot at scale |
| Slow expiry-reset cycling reached ~85 percent damage reduction, **invisible to every pinned judge** | dominant strategy | adversarial correctness review |
| Net `hpLost` was zeroable by Heal Song and hid difficulty | metric failure | adversarial correctness review |
| Death un-spent Heal Song uses | HIGH | fidelity review round 1 |
| Barrier unreachable without entering the dungeon | structural | world tests |
| Song-seal door tile was swim-through | structural | test, pre-commit |
| Anti-overfit guard only shifted bot seeds, not combat seeds | instrument bug | correctness round 2 |
| Eel Analyze said "eye" while the screen said LURE | wiring | correctness round 2 |
| Eel key derived per-attempt, so a death remapped it in 306 of 500 seeds | fairness | correctness round 2 |
| Blank screenshots were a first-paint race, not a render bug | instrument bug | render-and-look |
| Lab hook closures were per-batch, silently capping the bulwark after fight 1 | instrument bug | **its numbers came back identical to baseline** |
| Combat resolved instantly: one keypress ran the player action and the enemy answer in the same frame | HIGH | **the user**, 01:24 |
| Story was invisible: verses reached only the internal log, and the ticker renders only in combat | HIGH | realignment's sketch re-check |
| The song-seal puzzle was UNPLAYABLE, all feedback log-only | HIGH | played-experience hunt |
| **The combat log never reached the UI**: every sound, floater, ticker line and fanfare was dead in the played game, and the G7 test asserted the disconnected side of the pipe | CRITICAL | skeptic round, proved by counting oscillator starts in a headless harness: zero |
| Combat was not clickable: a mouse-first player could not act at all | HIGH | fidelity round 2 |
| The world ran under the SPENT hold; the fish could walk into a new invisible fight behind the banner | HIGH | skeptic round |
| Trench suicide was a free escalating heal | HIGH | final panel seat 1, then **refuted and re-broken** by confirmation seat A |
| Error overlay registered after page code, so a demo-path throw could blank silently | HIGH | final panel |

**This is the fact that kills v1's thesis.** The harness attacked
presentation hard, with as-played instruments driving real key and
pointer events, and it found the single worst defect in the project:
the entire audio and feedback pipe was disconnected in the played game
while the tests were green.

Presentation was not an unexamined layer. So "the gates were blind to
presentation" is simply not what happened.

---

# Part 3: Why 33 defects still survived to the human

Four failure modes explain all of them. None is "we lacked an
instrument." Three of the four cost almost nothing to fix.

## 3.1 Reviewers looked, but had no named defect classes to confirm absence of

Every review round was open-ended: look at the artifact and report what
you find. Open-ended looking returns what is **salient**, not what is
**specified**.

This is measured, not asserted. In `verify/PROOF.md`, four reviewers
were given the identical screenshot of the build whose puzzle a
playtester never noticed:

- Asked to "review this screenshot and report any issues", the reviewer
  returned **12 findings, all cosmetic**: z-order, label contrast, dead
  space, a duplicated key hint. It never said the puzzle was
  unreadable.
- Asked "list every object you could interact with, say what each does,
  then say whether the image told you or you assumed it", the same class
  of reviewer named the stones' unknown activation, unknown order and
  unknown success feedback, and flagged the pickups as "no label, no
  caption, cannot tell whether they are verses, relics, pickups or
  doors."

Same model. Same pixels. Different question. **The instrument was never
the limit; the question was.**

## 3.2 Findings were adjudicated away instead of blocking

The most uncomfortable finding in this document. At 01:18, seventeen
hours before the human asked "so fin slash works best for almost every
enemy, so why would I ever use tail strike", the run produced this:

> Bubble is 0 percent of optimal play everywhere (a 1 STA trial changed
> nothing because optimal never runs dry; REVERTED as unmeasurable
> churn): it is the casual player's panic guard, a human-facing role bot
> evidence cannot value. Analyze is likewise 0 percent for bots because
> they read state for free.

The instrument fired. The tool's own header says a button nobody presses
is a design smell. The finding was then explained, labelled a
human-facing role, and shipped. Sixteen hours later a human found
Bubble was not an underrated panic guard, it was a trap: bubbling a
telegraphed heavy cost 9 to 40 MORE damage, and at 30 HP it lost runs it
was supposed to save.

The same pattern appears at panel 2, where seat C flagged "the telegraph
erodes Analyze" as a LOW and it was **DEFERRED with reason**. That LOW
is the seed of the entire "taught line loses to mashing" problem that is
still open today.

**A finding that is explained rather than fixed is a finding that
ships.** The harness had no rule that "0 percent of optimal play" is
blocking, so a plausible sentence was enough to clear it.

## 3.3 Heuristics discovered in practice were never promoted to rules

At 00:33, the enemy-variety lab had a bug, and the log records exactly
how it was caught: "its numbers came back identical to baseline, which
is what exposed it."

That is the null-result alarm, in use, at hour thirty-three minutes. It
was never written down as a rule. At 18:05, the identical signature
appeared again: making Analyze free moved **no band at all**, because
the harness was stepping fights down a path where free actions did not
exist. The same tell, unrecognised, because it lived in one log entry
instead of in the rules list.

Contrast with the two heuristics that DID get promoted (replaces must
assert; instrument labels must measure, never assert). Both held for the
rest of the run. Promotion works. It just was not systematic.

## 3.4 Some classes were never named at all

Nothing in G1 to G9 mentions any of these, so nothing looked:

- **Legibility.** Does the player understand what the screen said. Ten
  of the 33.
- **Per-option dominance.** G4 asked "does a spam bot beat a mixed bot",
  which passes while individual abilities are dead weight, because the
  mixed bot simply never picks them.
- **Bypass.** G2 proved the slice can be finished. Nothing asked whether
  it can be finished while skipping everything.
- **Escalation.** Marc's pillar ("every mechanic should appear
  throughout the game in increasingly interesting ways") was never
  audited until hour eighteen, when a hand audit found four violations
  out of nineteen mechanics.

---

# Part 4: The defect ledger

The 33 defects the human found, with the failure mode from Part 3 that
let each one through, and the detector from Part 5 that catches it.

| # | What the player hit | Mode | Detector |
|---|---|---|---|
| 1 | Fish faced east while swimming west | 3.1 | D1 |
| 2 | All six abilities played one shared nudge | 3.1 | D1 |
| 3 | HUD did not name the next step; cleared ruin had no current | 3.4 | D2 |
| 4 | Hub was pointless: verses granted nothing | 3.4 | D2, D4 |
| 5 | Song-seal did not read as the alcove vault it is | 3.1 | D2 |
| 6 | Optional treasure was silently missable | 3.4 | D4 |
| 7 | Same ending printed at 0/5 and 5/5 verses | 3.4 | D6 |
| 8 | Verses had no readable lesson, only a stat | 3.4 | D6 |
| 9 | Analyze said "slow is effective"; nothing said what slow means | 3.4 | D1, D2 |
| 10 | Every enemy bypassable via adjacency triggers | 3.4 | D4 |
| 11 | Ability cards never showed their damage numbers | 3.4 | D1 |
| 12 | Slow won on all 5 enemies; blind-only measured identical to no conditions on 3 | 3.4 | D3 |
| 13 | Bubble at 0 percent of optimal play, actively harmful | **3.2** | D3 |
| 14 | Analyze at 0 percent of optimal play | **3.2** | D3 |
| 15 | Tail Strike was a body ram; Silt Burst conjured silt in open water | 3.1 | D1, D2 |
| 16 | Ending choice unreachable by keyboard | 3.1 | D1, D7 |
| 17 | Low dark in one beat; heavy cycle flat; seal appeared once | 3.4 | D6 |
| 18 | Heal Song (per ruin) and Bubble (per fight) both printed "2 left" | 3.4 | D2 |
| 19 | Gullet seal silent: card gate matched "song-seal", emitter said "the gullet's seal" | 3.1 | D5 |
| 20 | Ruin 2 opened with a third squid reskin | 3.4 | D6 |
| 21 | Boss Analyze dropped its condition hint | 3.1 | D3, D5 |
| 22 | Verse card swallowed by an adjacent fight | 3.1 | D1 |
| 23 | Intro banners blanked the enemy they introduced | 3.1 | D1 |
| 24 | Analyze cost a full turn, so the taught line lost to mashing | **3.2** | D3 |
| 25 | Band harness drove a path where free actions did not exist | **3.3** | D7 |
| 26 | Boss bar counted durability never on the victory path | 3.4 | D3 |
| 27 | Wall rebuff card mistitled THE SONG-SEAL | 3.1 | D5 |
| 28 | Teach line repeated the cards instead of teaching SPACE and aiming | 3.4 | D2 |
| 29 | Ticker, analyze hint and teach line drawn into one overlapping band | 3.1 | D1 |
| 30 | Damage floaters overlapped each other | 3.1 | D1 |
| 31 | Story card reward line landed on the card's bottom border | 3.1 | D1 |
| 32 | The puzzle read as scenery | 3.1 | D2 |
| 33 | Fragment buffs never read as rewards | 3.1 | D2 |

Two distributions, because they answer different questions. What kind of
defect it was:

| Class | Count |
|---|---|
| LEGIBILITY (system worked, screen never said so) | 10 |
| LAYOUT (text colliding or clipped) | 5 |
| DESIGN-HOLE (content with no reason to engage it) | 5 |
| BALANCE (option dominated, dead, or actively bad) | 4 |
| WIRING (two halves of one feature never met) | 4 |
| ANIMATION (motion did not match the name) | 3 |
| VARIETY, STRUCTURE, HARNESS | 3 |

**Fifteen of 33 are LEGIBILITY plus LAYOUT.** The screen, not the
simulation, is where this prototype's surviving defects lived.

And why each escaped:

| Failure mode | Count |
|---|---|
| 3.1 looked, but not for this class | 14 |
| 3.4 class never named at all | 13 |
| 3.2 found, then explained away | 3 |
| 3.3 heuristic never promoted to a rule | 1 |

Twenty-seven of 33 were reachable with the instruments that already
existed. What was missing was a checklist and an adjudication rule.

---

# Part 5: The detectors

Seven, all implemented in `verify/`, all proven in `verify/PROOF.md`
against worktrees at the commit before each fix. Seven of eight aimed
detectors fire on the buggy build and go quiet on the fixed one.

| Code | Detector | Defects it covers |
|---|---|---|
| D1 | Layout invariants over a display list | 11 |
| D2 | Cold-read questionnaire | 11 |
| D3 | Policy bots and usage histograms | 6 |
| D4 | Route search over the world graph | 4 |
| D5 | Typed events instead of string matching | 4 |
| D6 | Generated content tables | 5 |
| D7 | Differential harness fidelity | 3 |

Rows overlap: several defects have two detectors.

## D1. Layout invariants over a display list

**Not because a model cannot see pixels.** A vision-capable reviewer
looked at this game repeatedly and reported cosmetic issues while a 2px
clipping defect stood in front of it. The argument for a loop is
different and better:

- It is **deterministic**. It cannot be salient-biased, it cannot get
  bored on state 17 of 20, and it returns the same answer every run.
- It can **fail a build**. A prose review cannot.
- It is **free**. Milliseconds, no tokens.

Division of labour: **use a loop for "is this geometrically correct",
use a model for "does a person understand this."**

The shape to build, once a project outlives one weekend:

```ts
// pure, testable, no canvas
type Draw =
  | { kind: "text"; id: string; text: string; box: Rect; clip: string | null }
  | { kind: "sprite"; id: string; pose: Pose; facing: -1 | 1; box: Rect }
  | { kind: "panel"; id: string; box: Rect; style: "normal" | "selected" }
  | { kind: "bar"; id: string; value: number; max: number; box: Rect };

export function buildScene(state: World, ui: Ui): Draw[]   // pure
export function blit(ctx: CanvasRenderingContext2D, scene: Draw[]): void
```

The invariants, each mapped to what it catches:

1. **No two text boxes in the same layer intersect.** Catches 29, 30,
   22, 23.
2. **Every draw is inside its clip box, with minimum padding.** Catches
   31. Proven: fires at -2.3px on the buggy build, silent after.
3. **Sprite facing agrees with the sign of movement.** Catches 1.
4. **Hash each ability's pose sequence across its cast; two identical
   hashes is a defect.** Catches 2, and would have flagged 15 as "these
   three casts are the same motion."
5. **Exactly one panel carries `style: "selected"` and its id equals the
   cursor's id.** Catches 16.
6. **Every active mechanic has a `Draw` whose text contains its
   explanation string**, driven from a mechanics registry rather than
   hand-written tests. Catches 9, 11.

Two things the proof run taught that were not obvious:

1. **The invariants must run over PLAYED frames.** The story-card defect
   exists only during a pickup, so no `?demo=` state contains it and the
   17-state gallery was structurally incapable of catching it. The
   `?filmstrip=` family already had the right idea; it just was not
   wired to invariants.
2. **The naive containment rule was 67 percent false positives** until
   the owning panel was required to be drawn within 4 ops of the text.

Implementation note: `verify/d1-recorder.js` recovers a display list at
runtime by proxying the 2D context, so this works on any build including
old commits with no engine change. A real refactor to `buildScene()`
would be cleaner, and is worth it for a project outliving one weekend.

## D2. The cold-read questionnaire

The class D1 cannot reach. Protocol, and the protocol is the whole
trick:

1. **Questions are generated from the design doc.** Every mechanic
   yields a fixed question.
2. **The reviewer never sees the design doc.**
3. **Questions must not leak their own answer.** "There is a puzzle
   here, what does it want" is a worse question than "list every object
   you could interact with and say what each does."
4. **A forced told-versus-assumed column.** This is the decisive
   feature. It separates what the screen said from what the reviewer
   filled in from genre convention, which is exactly the failure mode
   that made the overnight roleplay playthroughs worthless.
5. **A forced CANNOT TELL option**, with a statement of what is missing.
6. **Scored on the diff between runs, not the absolute count.** On the
   fixed build the verdict word stayed CANNOT TELL but the reason
   narrowed from "nothing says whether these uses ever come back" to
   "the word ruin is never defined."

Run against the shipped build it found three unreported defects: the
Analyze card prints both "1 STA" and "free"; Bubble's "the next hit
lands 20%" is unresolvable from the screen; Heal Song is dimmed at full
HP with no stated reason.

## D3. Policy bots that encode intent, and histograms as standard output

`tools/usage.ts` already existed. What it lacked was teeth.

- **Usage histograms print on every band run**, and **0 percent of
  optimal play is a BLOCKING finding**, not an observation to explain.
  Catches 13, 14.
- **Taught-line bot**: a bot playing exactly what the tutorial teaches
  must beat a naive masher. Measured at HEAD: it loses on squid, elder
  and eel, and on the eel it wins 3.5 percent against a masher's 100.
  Catches 24, and is the correct framing of 12.
- **Hint-versus-winner cross-check**: for every claim the game makes to
  the player, a bot that checks the claim is true. Catches 21 and 12.
  Proven: fires on ink and eel at the pre-fix commit, silent after.
- **Displayed-progress monotonicity**: any bar shown as progress must
  correlate with distance to the outcome. The eel's bar read 54/66 two
  hits from death. Catches 26.

**Honest limit, found by running it.** A greedy bot cannot value an
INFORMATION ability, so Analyze reads 0 percent forever whether it is
good or broken. Information abilities are printed and excluded from
findings and referred to D2. That distinction is what the 01:18 entry
was groping at; the fix is to make it a rule instead of a judgement
call.

## D4. Route search over the world graph

- **Maximum-skip route**: reach the end touching the fewest encounters
  and pickups. Its output is the design-hole list. Catches 10, and would
  have caught swimming under the sealed door.
- **Content necessity matrix**: for each piece of content, can the game
  be finished without it. Often "yes, and that is fine", but as a ruling
  rather than a discovery. Catches 6.
- **Reward reachability**: for every reward, does a state exist where
  the HUD names it. Optional must not mean invisible. Catches 4.

## D5. Typed events, not string matching, across module boundaries

Defect 19 is the purest bug in the project: the world emitted "the
gullet's seal" and the card gate matched `"song-seal"`, so the puzzle
gating the ending verse was silent. Sim correct, tests green, feature
absent.

The fix is a type, not a test. Cross-module signals carry enum tags and
prose stays a presentation leaf:

```ts
type Signal = { tag: "seal.progress"; sealId: "hub" | "gullet"; step: number }
```

Then the compiler catches 19 and 27. **No feature may depend on two
modules agreeing about a string.** This also retires `src/events.ts`'s
substring matching on copy like `"rings true"` and `"spills out of it"`,
which silently returns null the moment a writer edits a line. Catches
19, 21, 27, and the whole family they belong to.

## D6. Generated content tables

- **Mechanic-by-beat matrix**, generated: which beats each mechanic
  appears in, and whether any parameter differs between appearances.
  PILLAR-AUDIT.md is this table made by hand at hour eighteen; it found
  four violations. Catches 17.
- **Encounter variety table**: enemy families per beat, flagging repeats
  in adjacent beats. Catches 20.
- **Outcome variety table**: all reachable endings and the states that
  produce them. Would have shown at a glance that 0/5 and 5/5 verses
  printed identical text. Catches 7, and 8 by the same shape.

All three are cheap, generated, and reviewed once per session rather
than once per project.

## D7. Differential harness fidelity

- **Structural**: bots enter through the player's door. Make the inner
  stepping functions module-private so `combatAction` is the only way
  in.
- **Differential**: play one seeded script down the world path and the
  harness path and assert identical outcomes. Proven: on the half-done
  free-Analyze change it reports turns 7 vs 8, hp 81 vs 94.
- **The null-result alarm, now a rule**: any rule change that moves no
  metric beyond noise is flagged as an instrument failure until proven
  otherwise. Proven: the bands came back byte-identical after halving an
  ability's cost.

D7 is a guard at the moment of change, not a way to discover existing
drift, so it belongs on every commit.

---

# Part 6: The harness for the next prototype

## Keep, unchanged

Everything in Part 1. The goal hook, the realignment loop, gates with
pasted evidence, UNVERIFIED as first-class, pinned judges and constants,
bands as tests, anti-overfit guards, the adversarial panel with
reviewer-assigned severity, the final zero-HIGH panel, mechanic-plus-test
in one commit, the demo and filmstrip instrument families, the
git-clock-only rule, asserted replaces, measured instrument labels,
logged process slips.

## Add: a standing defect-class checklist

The single highest-value change, and it is a document, not a machine.
Every review round must confirm **absence** against a named list, not
report what it noticed. Minimum list, derived from this project's 33:

legibility, layout collision and clipping, animation-matches-name,
per-option dominance, dead options, taught-line-beats-naive, bypass
routes, escalation across beats, cross-module string coupling, charge
and scope wording, displayed-progress honesty, harness fidelity.

A round that returns "nothing found" must say which classes it checked.

## Add: adjudication rules that remove the escape hatch

1. **A finding may be fixed, escalated, or ruled on by the human. It may
   not be closed by the builder's explanation.**
2. **These findings are automatically blocking**: any ability at 0
   percent of optimal play; the taught line losing to naive play; any
   mechanic appearing in exactly one beat; any content reachable but
   never named on screen.
3. **Every "deferred with reason" gets a line in BACKLOG.md at the time
   it is deferred**, so a LOW cannot quietly become the thing the
   playtest finds.
4. **Any heuristic used to catch a bug gets promoted to the rules list
   in the same commit.** This is what 00:33's null-result catch needed.

## Add: gates that name the missing classes

- **G4 becomes per-option**: every ability must have an encounter where
  it is the single best choice by a measurable margin.
- **G5 splits**: G5-MACHINE stays evidenced. G5-HUMAN is UNVERIFIED by
  definition until a person who did not build it plays it. Bots measure
  balance; only humans measure fun. No bot playthrough written in a
  human profile counts as evidence about fun, ever.
- **G10 LEGIBILITY (blocking)**: the cold-read questionnaire, scored on
  the diff, with unanswerable questions as findings that must be fixed.
- **G11 TAUGHT LINE (blocking)**: the taught policy beats the naive one.
- **G12 BYPASS**: the maximum-skip route is a ruling, not a discovery.
- **G13 PILLAR**: the mechanic-by-beat matrix is generated, not audited
  by hand at hour eighteen.
- **G14 HARNESS FIDELITY**: differential on every commit, plus the
  null-result alarm.

## Honest coverage estimate

Of the 33 defects: roughly **20 were mechanically detectable** with no
model in the loop (D1, D3, D4, D5, D6, D7), around **11 needed a model
reading a screen** and answering spec-derived questions (D2), and the
remainder were rulings rather than bugs.

The claim is not that a machine would have made the game good. It is
that the machine could have handed the human a list of 20 things before
they ever sat down, so the afternoon of play went to the questions only
a person can answer. And note what that estimate really measures: **27
of the 33 were reachable with instruments this project already had**, so
most of that coverage costs a checklist and an adjudication rule, not an
engineering budget.

## Keep the commit history segmented

Autonomous findings and human findings must stay separable in the log.
That segmentation is the only reason this analysis was possible at all:
87 commits before the human touched it, 19 after, cleanly divided.

---

# Part 7: What no system catches

Named on day zero so it can never be vacuously greened later, the way
G7 correctly did for musical quality:

- Whether the game is fun. The cold verdict was 6/10, "the first ruin is
  a 7, the second ruin is a 4."
- Whether the pacing of a beat is right.
- Whether the music is good, the art reads, the story lands.
- Whether the combination of individually legible systems is enjoyable
  to hold.

These are scheduled as human time, at the end of the run, not as machine
time during it.

---

# Part 8: The four questions, settled

1. **Is the display list worth the refactor cost in a jam?** The
   question was built on a wrong premise. A vision model already looked
   at this game and missed these defects, so "models cannot see pixels"
   was never the issue. Build the loop for determinism and because it
   can fail a build, and if the loop is expensive, get the same value by
   naming the classes the reviewer must confirm absence of. Either way
   this is a notice-and-fix, not a question to raise.
2. **Should the cold read block a gate?** Yes. That is the entire point
   of a harness: to force the work to actually happen. Findings-only is
   how 3.2 happens.
3. **What is the right cadence for human play?** After the overnight
   run, not during it. A two-hour cadence would stall the autonomous run
   to nothing and buy findings that are cheaper to get in one sitting at
   the end. The run's job is to arrive at the morning with every
   machine-checkable class already closed.
4. **What defect class are we still not seeing?** The one this version
   fixes: the harness itself was never studied, so v1 reinvented
   instruments that already existed (usage histograms, as-played
   filmstrips, the null-result alarm) and misdiagnosed why the
   survivors survived.
