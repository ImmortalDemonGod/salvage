# SALVAGE overnight build log

**State: SCAFFOLD.** Sim core, judge bots and the per-commit verification
set exist and run headless. No presentation, no content, no art.

Binding documents, in precedence order: this file, then `docs/SPEC.md`.
For anything neither covers, consult `docs/` (Marc's proposal, Glass_Goat's
combat PDF, the merge proposal, the visual sketch) **before inventing**,
and cite which one informed the decision. `docs/KIT.md` and
`docs/LESSONS.md` are why this file looks the way it does; read them once
at run start and do not re-litigate them.

---

## The stopping condition

**The run does not stop because the tests pass.** It stops when the deep
pass has gone dry.

- DONE requires **three consecutive nightly deep passes that find nothing
  new**, plus every gate GREEN or explicitly UNVERIFIED with pasted
  evidence of the attempt.
- SHIPPED is a build state, not a stopping condition.
- **Re-running a green suite is not work.** If the fast set is green and
  the deep set is still finding things, the answer is to build, not to
  re-run.

Measured justification, from the last project: all nine gates went green
at 06:21 and the run continued to 07:58 producing re-verification, a
100,000-fight depth block and a README, and **zero new content**. A
wall-clock stop plus a completed report is satisfiable by waiting. This
one is not.

---

## Exit gates

No gate is GREEN without its instrument's output pasted beneath it. "It
should work" and "implemented" are not evidence. UNVERIFIED is a
first-class verdict but not an exit hatch: it requires pasted evidence of
the attempt. **G1, G2, G14 and G-TEACH may never be UNVERIFIED.**

| Gate | Requirement |
|---|---|
| **G1 BUG-FREE** | Fast set green; fuzz bot survives 10k hostile actions with invariants held (HP in range, Air in range, no diver in two stations, broken limbs stay broken); web build loads with zero console errors |
| **G2 WINNABLE** | The scripted bot clears the slice start to finish; the casual bot also finishes. A win must exist from every reachable state, so positioning can never strand a diver |
| **G3 BANDS** | See pinned numbers below |
| **G4 PER-OPTION DOMINANCE** | For **every** ability there exists a reachable state where it is the unique optimal action, by a measurable margin. Not "a mixed bot beats a spam bot" |
| **G5-MACHINE** | Pacing, decision density, curve, evidenced |
| **G5-HUMAN** | **UNVERIFIED by definition** until a person who did not build it plays it. No bot playthrough written in a human profile is evidence about fun, ever |
| **G6 VISUAL** | Fresh-eyes gallery review, reviewer assigns severity |
| **G7 AUDIO** | Named events wired and machine-verified. Musical quality permanently UNVERIFIED |
| **G8 FIDELITY** | Built game matches SPEC.md in both directions; parking lot provably clean |
| **G9 HONEST REPORT** | Every claim PROVEN with a reproduce command, EVIDENCED, or UNVERIFIED |
| **G10 LEGIBILITY** | **BLOCKING.** Cold-read questionnaire: questions generated from SPEC, reviewer blind to SPEC, no leading, forced CANNOT TELL, mandatory told-versus-assumed column. Scored on the diff between runs, not the absolute count |
| **G11 TAUGHT LINE** | **BLOCKING.** A bot playing exactly what the tutorial teaches must beat a naive masher |
| **G12 BYPASS** | The maximum-skip route is a ruling, not a discovery |
| **G13 PILLAR** | Generated mechanic-by-beat matrix. Anything appearing once, or identically everywhere, is a finding |
| **G14 HARNESS FIDELITY** | The sim is plain `RefCounted` with no `Node` and no scene access. Bots call the same functions the input handler calls. Differential check on every commit |
| **G-TEACH** | **BLOCKING.** Generated table: for every mechanic, the beat where it first appears, and whether another new mechanic appears in the same beat. Two new mechanics in one beat is a finding. A mechanic that never appears alone is a finding |

### PINNED JUDGE POLICIES AND BANDS (pinned before any tuning)

Changing any of these requires a logged reason **and** re-running every
gate that used them.

- **casual bot**: uniform random over affordable legal actions, 15 percent
  pass rate.
- **greedy bot**: scores attacks by damage per Air with a finishing bonus,
  steps out of a telegraphed station when below half HP.
- **Metric**: HP lost across the whole squad. Not net, and no
  player-side resource can zero it.

| Band | Value |
|---|---|
| Casual win rate per encounter | **55 to 90 percent** |
| Greedy turns to clear, floor | **6.0** |
| Greedy squad HP lost, floor | **8.0** |
| Station occupancy under optimal play | **no station at 0 percent, none above 60 percent** |

### Day-zero measurements, banked before any tuning

```
godot --headless --path ~/salvage --script tools/bench.gd -- 10000
casual   2000 fights   808 ms   404 us/fight   win  0.9%  turns 19.3  hp lost 31.9  downed 2.97
greedy   2000 fights   471 ms   236 us/fight   win 100.0%  turns  4.0  hp lost 15.0  downed 1.00

godot --headless --path ~/salvage --script verify/checks.gd
G3 bands   casual win 1.4% (band 55-90)   greedy turns 4.0 (min 6.0)   greedy hp lost 15.0 (min 8.0)
stations   FRONT 9.1%  FLANK 45.5%  UNDER 0.0%  REAR 18.2%  BACKLINE 27.3%
telegraph  4843 hostile slots, announced == delivered
FINDING  G3 casual win rate 1.4% outside band 55-90
FINDING  G3 greedy clears in 4.0 turns, floor is 6.0: the fight ends before it can teach
FINDING  DEAD STATION: UNDER is never occupied in optimal play
VERIFY: 3 finding(s)
```

**G3 is RED and stays red until fight one is tuned into band. This is the
run's first task and it cannot be faked.**

**The UNDER finding is the most interesting of the three and must not be
tuned away silently.** UNDER is the deliberately empty station whose whole
job is to teach that safety is a reason to move (SPEC 2.6). The greedy bot
never stands there, which means either the bot does not value survival
correctly, or the design is wrong and avoidance does not pay. A likely
cause: the umbilical rule costs 1 Air next turn when a strike hits empty
water, so dodging costs 1 Air to move plus 1 Air later, against 4 damage
on a diver with 16 HP. **The vacate fix may have over-corrected and killed
the reason to move at all.** Rule on it, with numbers, and log the ruling.

---

## Standing rules

1. Times come only from `git log`. No hand-typed timestamps, ever, and no
   wall-clock times in source comments.
2. String replaces must assert.
3. Instrument labels must MEASURE, never assert.
4. Process slips are logged, not hidden.
5. Disclosure of softening: if a fight gets easier, say so with numbers
   where the difficulty claims live.
6. **A null result is an instrument failure until proven otherwise.** A
   rule change that moves no metric is a claim about the metric.
7. **A finding may be fixed, escalated, or ruled on by the user. It may
   not be closed by the builder's explanation.** Measured precedent: the
   last project printed "Bubble is 0 percent of optimal play everywhere",
   explained it as a human-facing role, and shipped a trap.
8. Any heuristic used to catch a bug is promoted to this list in the same
   commit.
9. Every "deferred with reason" gets a BACKLOG line at the moment it is
   deferred.
10. **A detector's seed count is load bearing and is measured, not
    guessed.** Measured precedent: a hint detector reported the opposite
    winner at 60 seeds and the correct one from 150 up.
11. **Every detector is invoked by the fast set or the nightly job.** An
    instrument nothing runs cannot block and will rot.
12. No em dashes in user-shareable text.
13. No session-link trailers or AI co-author lines in commits.
14. Placeholder art only. We build placeholders ourselves as the brief for
    Glass_Goat; all final art is his.
15. All dialogue and story text is placeholder-marked for Marc.
16. `sim/` stays pure: `RefCounted`, no `Node`, no scene, no timers. If a
    bot cannot run the whole game headless with no scene instantiated,
    the split has already leaked.
17. Commit cadence: never more than 45 minutes of uncommitted work. Each
    mechanic and its check land in the SAME commit.

---

## The defect-class checklist

Every review round confirms **absence** against this list. A round that
returns "nothing found" must say which classes it checked.

```
legibility                 does the player understand what the screen said
motion readability         can a cold viewer name what a character just did
layout                     collision, clipping, overflow, on PLAYED frames
animation-matches-name     does the motion look like the word on the button
per-option dominance       does every option win somewhere
dead options               0 percent of optimal play is BLOCKING
dead / dominant station    the positional version of the same check
taught-line beats naive    the tutorial's line must beat mashing
bypass                     can content be skipped, and is that a ruling
escalation                 does every mechanic recur and change
teach ladder               one new idea per beat, alone before combined
string coupling            no feature depends on two modules agreeing on prose
station-limb contract      one typed table, read by sim and presentation both
progress honesty           any bar shown as progress tracks the real outcome
harness fidelity           instruments enter through the player's door
```

---

## Verification

**Fast set, every commit (currently 0.8s):**

```
godot --headless --path ~/salvage --script verify/checks.gd
```

**Deep set** (owns dominance, the taught line, and bypass):

```
godot --headless --path ~/salvage --script verify/deep.gd -- 600
```

It writes `verify/deep-ledger.json`, which is what makes DRY computable:
the ledger holds the union of every finding signature ever seen, and a
pass is dry when it introduces none. **A pass with any UNVERIFIED check
can never be dry**, so a thin deep set cannot fake coverage. Without that
clause the very first pass at SCAFFOLD counted as dry, which is the
vacuous-done failure this whole mechanism exists to prevent.

Day-zero deep pass:

```
dominance  300 states sampled | attack:Proto5 1  attack:Prototype1 3  attack:Scuba 12
                                move->BACKLINE 1  move->FLANK 21  move->FRONT 15
                                move->REAR 102  move->UNDER 3
taught     taught win 100.0% hp 15.0   naive win 0.0% hp 16.0
UNVERIFIED bypass: the slice has one fight, so there is no route to skip yet
DEEP pass 1: 0 signature(s), 0 NEW, 1 UNVERIFIED  ->  dry streak 0 of 3
```

G4 and G11 both pass at scaffold: every action is uniquely optimal in
some sampled state, and the taught line beats naive play 100 percent to 0.
Neither result means much until content exists, which is exactly why the
UNVERIFIED clause blocks the streak.

## The stop gate

`tools/stop-gate.sh` is the Stop hook. It reads the ledger and blocks
stopping until the streak reaches 3, with a safety valve at 400 blocks in
case the ledger breaks. **This makes the stopping rule executable rather
than written**, which matters because the rules that survived the last
project survived by being checkable, not by being written down.

Install:

```json
"hooks": { "Stop": [ { "hooks": [
  { "type": "command", "command": "$HOME/salvage/tools/stop-gate.sh" }
] } ] }
```

Verified both directions: blocks at streak 0, allows at streak 3.

**Q12 is ANSWERED and closed: pure GDScript.** 10,000 fights run in about
6.5 seconds across both policies, which fits inside a commit loop
comfortably, so the Rust option is not needed and the frictionless web
export is kept. Re-open only if the deep set stops fitting in a night.

---

## Launch sequence

1. Start `caffeinate -dims` and verify it is alive.
2. Arm the realignment loop (prompt below) at 45 minutes.
3. Print `date`. Append the run-start line to the feature log.
4. **Bootstrap order is binding.** Steps 1 and 2 are already done; do not
   skip ahead past 5.
   1. ~~Sim core, pure, one encounter~~ DONE
   2. ~~Judge bots plus the throughput measurement~~ DONE, Q12 closed
   3. **Layout invariants over the scene tree, BEFORE any content
      exists.** `Control.get_global_rect()` gives boxes for free.
      Retrofitting this was the most expensive thing we did last time.
   4. **Differential harness check**: one seeded script down the bot path
      and the input-handler path, asserting identical state.
   5. **A clickable web export**, with a placeholder in it, on day one.
   6. Only then, content, starting by tuning G3 into band.

## Realignment prompt (verbatim, every 45 minutes)

"Realign: run `date` and print it. Re-read ~/salvage/PROGRESS.md and
~/salvage/docs/SPEC.md in full; they are the binding spec and your memory
of them is not. For anything they do not cover, consult docs/ before
inventing. State which bootstrap step and which gate you are on. Run the
fast verification set and paste its output. Verify caffeinate is alive.
Commit and push. The run does not stop until three consecutive nightly
deep passes find nothing new; SHIPPED is not a stopping condition;
re-running a green suite is not work, so if the fast set is green, build."

---

## Feature log
