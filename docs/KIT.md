# The portable kit: what travels to the next prototype

Everything below either copies verbatim, copies with a rename, or is a
rule to paste into the new run's PROGRESS.md. Nothing here is TIDESONG
content. Companion to LESSONS.md (why) and this file (what).

Four tiers: **copy verbatim**, **copy the shape**, **know this already**,
**leave behind**.

---

# Tier 1: Copies verbatim

## 1.1 The run-control harness

Paste into the new PROGRESS.md unchanged. This is what made nine
unattended hours produce 87 commits instead of drifting.

| Mechanism | Why it is non-negotiable |
|---|---|
| `/goal` with a Stop-hook naming a wall-clock time AND a completion artifact | Stopping early is the default failure of a long autonomous run. The hook makes it impossible. Word it so SHIPPED is explicitly "a build state, not a stopping condition." |
| `date` printed every turn | The evaluator only sees the transcript. Printing the clock is what makes the time condition externally enforceable rather than self-reported. |
| `/loop` realignment every 45 minutes | Re-read the spec files **in full**, because "they are the binding spec, your memory of them is not." Must force: state the current priority and gate, verify tests green, commit and push. This is the anti-compaction device. |
| `caffeinate -dims`, verified alive at each checkpoint | The machine sleeping ends the run silently. |
| Source-doc precedence | The distilled design doc wins on conflicts, but before inventing anything it does not cover, consult the original source docs. Condition stacking was nearly lost to a distillation gap and recovered this way. |

## 1.2 The evidence rules

- A gate claim without its instrument's output pasted below it does not
  count. "It should work" and "implemented" are not evidence.
- UNVERIFIED is first class but is not an exit hatch: it requires pasted
  evidence of the attempt. Name which gates may never be UNVERIFIED.
- Every "X is done" line cites its evidence inline.
- Every claim in the final report carries a reproduce command.
- An honest red gate beats a dishonest green one.

## 1.3 The judge discipline

- Pin judge bots **before** any tuning. Weakening one requires a logged
  reason plus re-running every gate that used it.
- Pin the judge constants too (weights, thresholds, penalties).
- Pin the metric, and pick one that cannot be zeroed by a player-side
  resource. Raw damage taken, not net HP lost.
- Encode bands verbatim as failing tests.
- Anti-overfit guards on disjoint fresh seed spaces. **Shift every seed
  the harness uses, not just the bot seed.**
- Hunt judge pathology deliberately. Fix it in the direction that
  strengthens the judge.
- Label post-hoc numbers CALIBRATION, not prediction.

## 1.4 The adversarial protocol

- Fresh-eyes agents every major feature and at least every 90 minutes,
  seeing only artifacts, never the builder's rationale.
- Rotating lenses: correctness, visual, design fidelity, and a skeptic
  whose only job is to refute the latest done-claims.
- **The reviewer assigns severity. The builder may fix or escalate to a
  second independent agent, never downgrade.**
- All HIGH fixed before any new feature work.
- Final panel of three briefed "prove this is NOT done." Zero HIGH to
  ship. Any HIGH triggers a confirmation re-panel.

## 1.5 The standing rules (five earned in TIDESONG, six new)

Earned the hard way last time, and they held:

1. **Times come only from `git log`.** No hand-typed timestamps, no
   wall-clock times in source comments.
2. **String replaces must assert.**
3. **Instrument labels must MEASURE, never assert.**
4. **Process slips are logged, not hidden.**
5. **Disclosure of softening.** If a fight gets easier, say so with
   numbers where the difficulty claims live.

New, from this retro:

6. **A null result is an instrument failure until proven otherwise.** A
   rule change that moves no metric is a claim about the metric.
7. **A finding may be fixed, escalated, or ruled on by the human. It may
   not be closed by the builder's explanation.**
8. **Any heuristic used to catch a bug is promoted to this list in the
   same commit.**
9. **Every "deferred with reason" gets a BACKLOG line at the moment it
   is deferred.**
10. **A detector's seed count is load bearing and is measured, not
    guessed.** Found by wiring the detectors into the suite: the hint
    detector reports the eel's best disable as *blind* at 60 seeds and
    *slow* from 150 through 2400, and the taught-line finding set omits
    the elder below 400 seeds. A cheap detector run produces confident
    false findings, which is worse than no detector.
11. **Every detector is invoked by the suite or by a scheduled job.** An
    instrument nothing runs cannot block and will rot. `verify/` sat
    orphaned from `bun test` for its entire first life.

## 1.5b Keeping an autonomous run honest about being done

Measured from the last run: gates went green at 06:21, the run continued
to 07:58, and those 97 minutes produced re-verification and a README and
**zero new content**. The builder concluded it was finished and filled
time.

The mechanism is **information yield, not duration**. A suite that always
passes tells you nothing however long it takes.

- **Expensive generative verification runs continuously in the
  background**, so there is always a pending question.
- **Loop-until-dry is the stopping condition, not a timestamp.** Done is
  K consecutive deep passes finding nothing new. A wall-clock hook plus a
  completed report is satisfiable by waiting; this is not.
- **A content checklist that cannot be faked**, such as G-TEACH: every
  mechanic needs a beat where it appears alone.
- **Long-running tests are an asset in an unattended run**, because they
  make re-running a green suite for reassurance impractical.

Standing rule: **re-running a green suite is not work.**

## 1.6 The defect-class checklist

The cheapest high-value item in the whole kit. Every review round must
confirm **absence** against this list, and a round that returns "nothing
found" must say which classes it checked.

```
legibility                 does the player understand what the screen said
layout                     collision, clipping, overflow, on played frames
animation-matches-name     does the motion look like the word on the button
per-option dominance       does every option win somewhere
dead options               0 percent of optimal play is BLOCKING
taught-line beats naive    the tutorial's line must beat mashing
bypass                     can the content be skipped, and is that a ruling
escalation                 does every mechanic recur and change
string coupling            no feature depends on two modules agreeing on prose
charge and scope wording   per-fight vs per-run must be on the card
progress honesty           any bar shown as progress tracks the real outcome
harness fidelity           instruments enter through the player's door
```

## 1.7 Code that copies with zero edits

| File | Lines | Note |
|---|---|---|
| `verify/d1-recorder.js` | 98 | Proxies the 2D canvas context to recover a display list at runtime. Contains no reference to this game. Works on any canvas project. |
| `verify/d1-layout.mjs` | ~175 | Text-collision and card-containment invariants, plus the `play:` and `demo:\|keys` drivers that send real KeyboardEvents at 40ms taps on a **fake clock**, so runs are reproducible. Resolves `playwright-core` by bare specifier and discovers the newest installed chromium shell, so there are no absolute paths and no pinned browser build. **Set `PLAYWRIGHT_CORE` if you run it from outside a tree with `node_modules` above it**, and change the canvas dimensions if they differ. |
| `build.ts` | 32 | Bundle to a single self-contained `dist/index.html`. |
| The `gh-pages` deploy recipe | - | blob, mktree, commit-tree, update-ref, push. One link for the team, zero setup. |

---

# Tier 2: Copies the shape

Rewrite against the new game's verbs. The structure is the value.

| From | Shape to keep |
|---|---|
| `src/game.ts`, `src/world.ts` | **Pure sim: no DOM, no canvas, no timers.** The single highest-leverage architectural decision. It is what makes every bot, band, and soak possible, and it ports to Unity or Godot unchanged. |
| `src/render.ts` | Presentation reads state and never owns it. **New for this build: emit a display list, then blit it.** See LESSONS.md D1 for the `buildScene`/`blit` sketch. |
| `test/bots.ts` (222 lines) | Casual (uniform random over affordable), optimal (greedy 1-ply), spam-X, nav (axis-greedy). Plus: the harness steps through the player's entry point. |
| `test/bands.test.ts` (356 lines) | Bands as tests with the thresholds copied verbatim from the spec, plus anti-overfit fresh-seed guards. |
| `test/fuzz.test.ts` | Random inputs with per-action invariant checks. |
| `test/fullrun.test.ts` | The scripted clear, and the softlock definition (from every checkpoint, the casual bot reaches the end within N actions). |
| `tools/tune.ts` | The tuning loop over all encounters, one command. |
| `tools/usage.ts` | Usage histograms. **Now standard output on every band run, and 0 percent is blocking.** |
| `tools/lab.ts` | Sim-only variant lab: hook wrappers around the UNMODIFIED sim, never bundled, verified absent by bundle grep. |
| `tools/megasim.ts`, `deepsoak.ts`, `nightwatch.ts` | Scale batteries: 20k runs, 2000 fresh seeds per encounter, 50x soaks. |
| `verify/d3-usage.ts`, `d3-hint.ts`, `d3-taught.ts` | The three policy detectors. Swap the ability set. |
| `verify/d7-differential.ts` | Drive one seeded script down both paths, assert identical outcome. |
| `?demo=<state>` hooks | ~20 states for screenshots and reviews. |
| `?filmstrip=<mode>` hooks | **Real KeyboardEvents and PointerEvents through the real handlers, on a virtual clock, with measured labels.** This family found the worst defects of the run. New for this build: wire the D1 invariants to it, because static states cannot see a transient card. |
| Error overlay registered **before all page code** | An exception must never hide in a blank screenshot. |
| Synchronous module-scope first paint | Otherwise headless screenshots race the first rAF and come back blank. |

---

# Tier 3: Know this already, do not rediscover

## 3.1 Combat and economy findings

1. **Disable-first combat is validated.** Conditions pay 1.5 to 2.6x
   over ignoring them, and they pay more under a heavy cycle, not less.
2. **A visible intent telegraph is the strongest single mechanic**, and
   it eats a paid Analyze ability's job. **Decide the information budget
   up front**: what is free, what is paid, what each uniquely buys.
3. **Costs on information are the most sensitive knob in the design.**
   One change (making a look free on first use) moved casual win rate to
   93.4 percent.
4. **A resource that never binds is not a resource.** Stamina's floor in
   optimal play was 16 of 20 because a +2 refund ran against 3 regen. If
   it is meant to constrain, cut regen and refund together.
5. **Percentage mitigation does not tune; charged guards do.** A
   percentage guard was bimodal (0 percent bot usage at 72, 42 percent
   at 75) with nothing usable between. Discrete charges with large
   effects became a real decision immediately.
6. **Flat respawn death-loops.** A flat 60 percent respawn looped 20 of
   100 casual runs. A pity escalator (60/75/90, capped) fixed it. Decide
   the philosophy on purpose, and note that any mercy rule can become
   the efficient heal if a hazard is cheaper than a fight.
7. **A greedy judge turtles on defensive options** unless prevention is
   down-weighted.
8. **A greedy judge cannot value information at all**, so an information
   ability reads 0 percent forever. That is a cold-read question, not a
   bot question.

## 3.2 Content and structure findings

9. **Optional content must announce that it exists.** Optional does not
   mean hidden.
10. **Escalation is a requirement, not a nice-to-have**, and it needs a
    generated table, not an audit at hour eighteen.
11. **Derive theme from the verbs.** TIDESONG's spine fell out of
    Analyze being "learn a name" and the seal being "restore a
    sequence." Theme pasted on reads as decoration; theme derived does
    not.
12. **Adjacency triggers make every encounter skippable by accident.**
    Decide which enemies hold their ground.

## 3.3 Review findings

13. **Open-ended visual review returns what is salient, not what is
    specified.** Measured: the same reviewer given the same screenshot
    returned 12 cosmetic findings under "report any issues" and found
    the actual defect under a structured question.
14. **A model roleplaying a playtester is worthless as evidence about
    fun.** It reports what it expects a playtester to say. Four such
    playthroughs said "I wanted to keep playing" about a build a human
    scored 6/10.
15. **A cold-read questionnaire needs**: questions generated from the
    design doc, a reviewer blind to that doc, no leading, a forced
    CANNOT TELL, and a **told-versus-assumed column**. Score it on the
    diff between runs, not the absolute count.

---

# Tier 4: Leave behind

- **All TIDESONG content**: story, verses, enemy stats, world layout,
  numbers. Placeholder art and text stay with their owners.
- **The 1528-line build log.** Most of it is review-round bookkeeping
  nobody will read. Cap it: one design doc, one story doc, one backlog,
  one README, and a short build log where review rounds get a line each.
- **The roleplay-playtester review lens.** Proven to produce confident
  reassurance.
- **Open-ended "review this screenshot" as the primary visual gate.**
  Keep it as a secondary lens for things the checklist cannot anticipate.
- **`events.ts`-style substring matching across module boundaries.**
  Replace with typed signals.
- **Human playtesting during the run.** It belongs after, so the
  autonomous hours are not spent waiting. Keep the commit history
  segmented so autonomous and human findings stay separable, which is
  the only reason this retro was possible.

---

# Day-zero setup order

1. Write the design doc and the gate list. **Derive the gates from the
   design doc's own claims** ("the player can see X", "X escalates",
   "X is a choice"), plus the checklist in 1.6, plus the fixed set: bug
   free, winnable, bands, per-option dominance, fidelity, honest report.
2. **Name the unmeasurables now** (fun, music, art, story resonance,
   pacing) as permanently UNVERIFIED, so they can never be vacuously
   greened later.
3. Scaffold: pure sim core, presentation as a display list, single-file
   build, error overlay, first paint.
4. Copy Tier 1.7 verbatim. Wire D1's invariants to the filmstrip driver
   before any content exists, so layout can never regress unseen.
5. Pin the judges and the metric **before** the first tuning pass.
6. Arm the goal hook, the realignment loop, and caffeinate. Print
   `date`. Start.

## The five gates that are new this time

- **G-DOMINANCE**: every option must be the single best choice
  somewhere, by a measurable margin.
- **G-LEGIBILITY (blocking)**: the cold-read questionnaire. Unanswerable
  questions are findings that must be fixed, not logged.
- **G-TAUGHT (blocking)**: the taught line beats the naive line.
- **G-BYPASS**: the maximum-skip route is a ruling, not a discovery.
- **G-FIDELITY**: differential harness check plus the null-result alarm,
  on every commit.
