# SALVAGE overnight build log

**State: BOOTSTRAP COMPLETE.** Sim core, judge bots and the per-commit verification
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

### Added mid-run, each after a defect got through

18. **Engine stderr is evidence and is gated.** Measured: "Invalid polygon
    data, triangulation failed" printed on every frame while the ENEMY
    SILENTLY DID NOT DRAW and every test stayed green. An `ERROR` or
    `SCRIPT ERROR` line from any headless run is now a finding.
19. **Every script parses before anything runs.** GDScript fails at load,
    so a broken script is discovered one at a time by whatever happens to
    run it. `--check-only` over every `.gd` costs a second and finds them
    in one pass.
20. **`quit()` must be followed by `return`.** It only REQUESTS a quit;
    the code after it still runs. This made a fully green fast set exit 1.
21. **A detector that has never fired is unproven.** Every new gate is
    mutation-tested against a deliberate defect before it is trusted. All
    three of 18, 19 and 20 were proven this way, plus a clean control.
22. **A deep pass cannot be DRY while the fast set is red, or stale.**
    `fast.sh` records its verdict, the commit it applied to, and the dirty
    file count; the deep set treats anything else as UNVERIFIED. Finding
    nothing new in a build already known to be broken is not evidence.
23. **Agents that write files get their own worktree.** Both subagents
    reported that a blanket `git add -A` here committed their in-progress
    work; one commit contains a known-bad version of the art. Isolate
    them instead of racing them.
24. **When a capture or a human finds something the detectors missed,
    extend the detector in the SAME commit.** Measured twice: the layout
    check only ever compared station panels to station panels, so it
    passed while a marker sat on the help bar.

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

## Content: what to build, and when to stop building it

**Not a count.** The prototype is sized by the questions in
`docs/SPEC.md` Part 2c, and the jam budget is untouched and not ours to
spend. Build until the questions are answered or the deep set goes dry.

Each item below is a beat in the teach ladder, so G-TEACH is what says
whether it is done, and each new enemy must pass the bands and the
station-occupancy check before the next one starts.

1. Fight one, the hunter crab: attacks have geography
2. The boat: Proto5 joins, a diver who costs 3 is a commitment
3. Puzzle one, flood and drain: the lock's state is readable
4. Fight two: conditions, delivered as a drum mode fitted at the boat
5. A second anatomy with a different station-to-limb map: does the
   geometry survive a different body
6. Puzzle two: escalation of the same grammar
7. A boss whose station map changes mid-fight

**Unbuilt content answers nothing.** A prototype that stops early to
respect a shipping budget has spent the run without buying information,
which is the exact failure prototype 1 was retired for.

## Feature log

- **G-TEACH built and BLOCKING.** `content/beats.gd` declares the ladder
  as data; `verify/teach.gd` checks one-new-idea-per-beat, no mechanic
  taught twice, every mechanic placed somewhere, AND cross-checks the
  declaration against what the sim actually builds so the document cannot
  quietly agree with itself. It fired immediately with 5 findings,
  including the one it was built to catch: **the ladder declared two
  divers for fight one and the sim built three.** Also caught: overdraft
  and umbilical existed as mechanics with no beat introducing them, and
  backline was smuggled into the conditions beat. All placed. Ladder is
  now 9 beats, 12 mechanics, clean.
- Beats may declare `parts`: mechanics that ARE the taught idea rather
  than separate ideas (SPEC 2.3 says "the limb IS the position", so limbs
  and stations are one idea with two names). Declaring a part costs a
  line someone can argue with, so smuggling is auditable rather than free.
- **A third bug found by the fuzz agent, in a file I own.** `checks.gd`
  called `quit(0)` without returning, so the clean path fell through and
  re-quit with 1: a fully green fast set was reporting a false red on its
  exit code. `fast.sh` survived only because it greps for FINDING instead
  of reading the exit code. Fixed.
- **G3 re-tuned for the two-diver fight** after G-TEACH forced the party
  down. Of 48 swept cells only ONE lands in band. Measured: casual 62.2
  percent, greedy 6.0 turns (exactly the floor), 10.0 squad HP lost.
  **Logged as fragile:** a band satisfied by 1 cell in 48 will fall over
  at the next content change.

### OPEN, escalated rather than explained away (standing rule 7)

**G4: `attack:Prototype1` is never the unique optimal action in 400
sampled states.** It costs 2 Air for 2 damage against Scuba's 1 Air for 2,
so it is strictly worse at attacking, which is Tail Strike again.

The cause is structural, not numeric: **SPEC 2.9 gives Prototype1 the
verb *disable*, and conditions are not built until beat `fight3`.** Until
then it has no reason to exist beyond being a second body, and no damage
number fixes that, because with a shared Air pool and no per-diver action
limit, 4 Air buys the same total damage whoever spends it.

The fork, for the user:
  (a) fight one runs ONE diver, and Prototype1 arrives at `boat1` with
      the drum that gives it its verb. Cleanest ladder: one diver, then
      two, then three, each arriving with a reason. Costs another re-tune.
  (b) fight one keeps two divers and Prototype1 stays dominated until
      `fight3`, accepted as a known-open finding with a date.
  (c) give Prototype1 a non-damage reason that IS the station lesson,
      such as being the only diver who can hold FRONT against the jaw.

I have not picked. This is a design fork that moves the ladder and the
bands, and rule 7 says a finding may be fixed, escalated, or ruled on by
the user, but not closed by my explanation.

- RUN START. Bootstrap 1-5 complete. Godot 4.7.1, pure GDScript (Q12
  closed on measurement: 10k fights in ~6.5s).
- **Bootstrap 3, layout invariants over the scene tree.** Built BEFORE
  content, per the binding order. `verify/layout.gd` walks every Control,
  checks label-on-label collision, containment in the owning panel with
  padding, and whether the text actually fits the box it was given. It
  caught a defect in the first scene ever written, before any human
  looked at it: help_panel's label sat 5px from its edge against a 6px
  minimum. That is the class that took a human playtest to find last
  time.
- **Bootstrap 4, differential.** `verify/differential.gd` drives one
  scripted sequence down the bot path and the scene's keyboard path and
  compares full state after every step. 10 steps, identical.
- **Bootstrap 5, web export and deploy.** Templates installed,
  `tools/deploy.sh` builds and publishes to gh-pages in one command.
  NOTE: the repo is private, so Pages will not serve until it is made
  public.
- **JUDGE CHANGE, logged with reason (standing rule).** The casual bot
  was uniform random over ALL legal actions. In a positional game that is
  roughly 3 attacks against 12 moves, so it attacked 20 percent of the
  time and wandered the rest. It won 1.4 percent, and a full 36-cell
  parameter sweep (`tools/sweep.gd`) found NO configuration that could
  lift it into band, because every number that lengthens the fight for
  the skilled bot feeds the wanderer more enemy turns. That is judge
  pathology, not a broken game: a human who does not know what they are
  doing still mostly attacks. Casual now attacks when it can and wanders
  30 percent of the time. Every gate that used it was re-run.
- **G3 GREEN.** Tuned by sweep, not by argument. Eight configurations
  land in band; chose the smallest numbers per Glass_Goat's chess
  directive. limbs 14/10/10, divers 6/10/16, jaw 3 tail 2. Measured:
  casual 75.8 percent, greedy 7.0 turns, 22.0 squad HP lost.
- **Three sim bugs found by the fuzz bot**, all fixed: overdraft stacked
  without limit so Air reached 8 against a bound of 5 (unlimited actions
  for HP, a dominant strategy rather than a valve; now once per turn);
  `act_move` did not validate its station and put a diver on station 5 of
  a five-station board; and a caller could not distinguish refusal from
  corruption. All three now validate before spending anything.
- **DEAD STATION resolved, and the diagnosis mattered.** UNDER sat at 0.0
  percent occupancy. The cause was not that safety is worthless, it was
  that BACKLINE is ALSO safe with no downside, so UNDER was dominated by
  a duplicate. Fight one now runs on FOUR stations; BACKLINE arrives in
  fight two with the scanner that makes standing there worth it. UNDER
  went to 17.6 percent and G3 held. The teach ladder produced the fix:
  a station arrives with the thing that makes it worth occupying.
