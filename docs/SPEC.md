# Prototype 2 design spec (living)

**Status: in progress.** Built by interview. Everything in Part 1 and
Part 2 is DECIDED and should not be reopened without a logged reversal.
Part 5 is what is still open. Part 6 is what other people have to make.

Companion docs: `INPUTS.md` (the evidence this is built from),
`LESSONS.md` (why the harness looks like this), `KIT.md` (what we carry
forward), `verify/PROOF.md` (the detector experiment).

Target: the merge proposal's **vertical slice, ~Aug 13**. One fight, one
puzzle, one gate, playable start to finish. If it slips, the content
budget shrinks to match, agreed in advance.

---

# Part 1: Fixed rulings

| Decision | Ruling |
|---|---|
| The song and singing | **Cut wholesale.** Not lore, not collectible, not puzzle lock. |
| TIDESONG's story | **Cut.** Setting is Glass_Goat's post-flood diving premise. |
| Party of three | **In.** The merge proposal's "the jam game is a solo character" is formally reversed. Something must come out of the budget to pay for it. |
| Limb targeting | **Stays.** Players liked it. "Targeting was not clear" is a legibility requirement, not an argument for removal. |
| Engine | **Godot**, 2.5D side-on, not 3D. Rust still open and decided on bot throughput. |
| Art pipeline | We build placeholder assets ourselves and hand them to Glass_Goat as the brief, same as last time. |

---

# Part 2: The combat model

## 2.1 Determinism (Q1)

**No hidden roll ever sits between a decision and its outcome.** Damage,
hit, and effects are fixed integers. Enemy intent is telegraphed a full
turn ahead with its exact target and exact number.

Carve-out: **seeded generation stays random.** Which enemy appears, its
layout, and what it drops are rolled before the fight and are fully
visible when it starts. Determinism is about resolution, not about the
game being identical every run.

Why, in one line each:

- A telegraph that says "probably" is a weather forecast. TIDESONG's had
  to read `strikes for 13 · 60% miss (blinded)`, and the loudest playtest
  finding was that nobody could tell what the enemy was doing.
- It turns our weakest gate into a proof (see 4.1).
- The evidence for randomness-as-fun was machine-generated. No human ever
  said the dice were the good part.
- Percentage effects do not compose and do not tune. We paid for that
  lesson once, on Bubble.
- With three divers and small HP, one bad roll removes a party member and
  a third of your options. Worst possible place for a coin flip.

## 2.2 The Air economy (Q2)

**One shared pool. No second economy. Stamina as a separate concept is
gone.**

| Rule | Value |
|---|---|
| Air per turn | **4**, fully refreshed |
| Banking unspent Air | **No** |
| Cost to act | The acting diver's gear cost: **1 / 2 / 3** |
| Cost to move | **1**, flat, for anyone (Q3) |
| Overdraft | **Spend HP to buy one extra Air.** The desperation valve. |
| HP | Per diver. Small, sacred, hard to heal. The attrition resource. |

**The fiction is surface-supplied diving.** The squad is on umbilicals
from one compressor on the boat. That is why the pool is shared, why a
bigger suit costs more per action, and why the number is finite each
turn. Glass_Goat's whole combat doc is built on exhaustion; underwater,
exhaustion is air.

Why one pool and not two: TIDESONG's stamina never bound (floor 16 of 20
in optimal play, because a +2 refund ran against 3 regen, and no swept
configuration ever refused a turn). A shared pool of 4 against a diver
who costs 3 is scarce on **every** turn, by arithmetic, with no regen
loophole. A second economy that does not bind is worse than none,
because it is a bar on screen teaching the player their choices do not
matter.

Why no banking: it creates a turtle line (skip a turn, double the next),
which is the exact dominant-strategy class our own gate exists to catch.

**Consequence to design around:** if Air refreshes fully, fights cannot
be won by grinding down the action economy. Difficulty must come from
enemy pressure and positioning, never from wearing the player out.

## 2.3 Stations (Q3)

**The limb is the position.** There is no separate targeting step.

Five stations ring the enemy:

| Station | Exposes | Notes |
|---|---|---|
| **FRONT** | head, jaw | The dangerous one |
| **FLANK** | side limb | |
| **UNDER** | underside | |
| **REAR** | tail or rear limb | |
| **BACK LINE** | nothing | Safe. Where the scanner and support work from. |

Rules:

- Standing in a station is what makes its limbs reachable. Moving to a
  station is how you choose what you are attacking.
- **Any number of divers may share a station**, and an attack on a
  station hits **everyone standing in it**. Clustering risk emerges with
  no extra rule.
- Each station exposes one or two limbs. BACK LINE exposes none.
- **Breaking a limb changes the map.** Break the jaw and FRONT stops
  being dangerous; break the tail and REAR stops being swept. This is
  where the "every mechanic recurs and escalates" pillar comes from
  structurally, instead of being audited at hour eighteen like last time.

**Proposed, not yet decided:** slowness expressed as *reach* rather than
price. The heavy may only move to an adjacent station; Scuba may cross
the ring in one move. Keeps everyone inside the positional game and is
readable at a glance. Cut it if week one feels crowded.

Why stations over a grid: it is the only geometry where "the limb is the
position" is literally true; a grid's state space is far past exhaustive
search and would cost us the G4 proof; stations fit the 2.5D staging
Glass_Goat explicitly endorsed over top-down; and stations need one
reposition clip per character rather than pathing, tile UI and a camera
that reads tiles.

Why movement is flat 1 and not full cost: at full cost the heavy would
need 3 to move and 3 to attack against a 4 budget, so he could never do
both in a turn, ever. He becomes a turret and one third of the party is
exempt from the mechanic the whole combat is built on. Flat 1 also
produces arithmetic that teaches itself: heavy move-and-hit is 1+3, your
entire turn; Scuba move-and-hit is 1+1, half of it.

## 2.4 One enemy per fight (Q4)

**The enemy is the board.** One creature, five stations, three divers.
Bosses included. Trash is smaller anatomies with fewer limbs.

- It keeps the board readable in one second, which is the entire reason
  we chose stations.
- It preserves the searchable state space. Two rings roughly squares the
  placement space and adds enemy-selection to every decision, and we lose
  the proof in 4.1.
- It matches the art we have, which is zero enemies. One well-built
  anatomy is a far better brief for Glass_Goat than three vague ones.
- **It makes the pillar automatic.** You cannot pad a fight with more
  bodies, so the only way to make fight three harder than fight one is a
  more interesting anatomy. That is exactly the escalation we failed to
  deliver last time.

First expansion when we need it: one primary enemy that owns the stations
plus small adds that occupy stations alongside your divers and have no
limbs of their own. It invalidates nothing above.

**Fight one is a creature, not a machine.** A mutant with four limbs
reads as an anatomy immediately, which is what teaches the station-limb
contract. A machine reads as a puzzle box, which is a second idea, and it
should be earned after the first is taught. Glass_Goat's premise lists
mutants explicitly, and Marc's proposal already enumerates head, arms,
torso and tail.

## 2.5 The squad

From `Main_Team_Rigging.fbx` and the two reference images.

| Render | Name | Gear | Air cost | Oz archetype |
|---|---|---|---|---|
| Heavy plate, gold bands | **Proto5** | big armor | 3 | Tin Man |
| Bare skin, fins, red hair | **Scuba** (`Diver_Lady`) | scuba gear | 1 | Dorothy |
| Orange suit, three-lens drum | **Prototype1** | middle armor | 2 | Scarecrow |

**The cost is readable off the silhouette.** Bare skin 1, suit 2, plate
3. No number has to be printed. After two prototypes of failing to make
numbers legible, a system where the sprite *is* the number is the best
structural answer available to us.

Fiction hook the naming gives for free: the squad are field-testing
**prototype diving armors**. Prototype 1 and Prototype 5 are suits;
Scuba is a person with no suit at all.

**Six attack animations exist, two per diver**, which is the same kit
size TIDESONG shipped, now distributed so that Air composition decides
which abilities you can reach this turn.

- Scuba: `Axe_Kick`, `Double_Knee`. Legs, unarmed, agile.
- Prototype1: `Palm_Strike`, `DualPalm`. Hands, close range.
- Proto5: two attacks, unnamed and unseen.

**Standing rule: ability names come from the animation list, not the
other way around.** TIDESONG named an ability "Tail Strike" and
retrofitted motion twice, and players still said the animations did not
match. Deriving abilities from existing motion makes that defect class
impossible by construction.

## 2.6 Fight one's anatomy (Q5)

**Three limbs, and UNDER deliberately empty.** Jaw at FRONT, claw at
FLANK, tail at REAR. UNDER exposes nothing.

- The empty station is what proves the geometry is real. UNDER is a
  place you can stand that does nothing offensively, which forces the
  question *why would I ever go there*, and the answer is that the jaw
  cannot reach it. **Safety is a reason to move**, and that lesson needs
  its own beat.
- Break the tail and REAR becomes safe too. The player watches the board
  change in fight one, so the escalation pillar is demonstrated rather
  than asserted.
- Three limbs against three divers and four Air makes the composition
  problem concrete immediately: you cannot cover everything. Four limbs
  invites "each diver has a job," which is the Final Fantasy read
  Glass_Goat criticised.

**Its one defining mechanic: the jaw only reaches FRONT, and the tail
sweeps REAR and FLANK together.** No conditions, no statuses, no special
rules. The single idea is *attacks have geography*.

**No status conditions in fight one** (ruled). TIDESONG's first fight
tried to teach conditions and targeting at once and playtesters could
articulate neither.

Creature: a **mutated hunter crab**. Reads as an anatomy at a glance,
has an obvious front-to-back asymmetry, fits the post-flood premise, and
gives Glass_Goat a brief that is not a fish.

Held back deliberately, each available as a later beat's single new
idea: status conditions, armoured limbs that gate damage, attacks that
cover multiple stations, and enemies that move.

## 2.7 The teach ladder (standing rule)

**Every beat introduces exactly one new idea, and the spec names which
one.** This is a rule, not an aspiration, because the loudest finding
from both prototypes was that players could not say what they were doing
or why.

Corollaries:

- A mechanic must appear **alone** before it appears **combined**.
- New abilities and new capabilities arrive as **rewards between
  fights**, so that progression and pacing are the same mechanism. This
  also gives the NPC a job, which fixes the "the merfolk should have
  given something" complaint structurally rather than by bolting a shop
  onto a lore stop.
- Anything held back is listed with the beat that will teach it, so the
  ladder is auditable rather than remembered.

### New gate: G-TEACH

A generated table, in the D6 family alongside the pillar matrix: for
every mechanic, the beat where it first appears, and whether any other
new mechanic appears in that same beat.

**Two new mechanics introduced in one beat is a finding.** A mechanic
that never appears alone is a finding. This is the pillar audit's
sibling, and like the pillar audit it should be generated from content
data rather than performed by hand at hour eighteen.

## 2.8 Progression and how abilities arrive (Q6)

**Unlocks are bodies, gear, and abilities. All three. Story-gated, on the
critical path, one per beat, each arriving with the obstacle that
requires it.**

An earlier draft of this spec said "never abstract abilities." **That
clause is struck.** It was wrong, and the measurements say so.

### The diagnosis that replaces it

The three abilities nobody used in TIDESONG were Bubble, Analyze and
Tail Strike: the first two at 0 percent of optimal play on every
encounter, the third dominated by Fin Slash. The two that players did
engage with were Silt Burst, because you could see mud go into an eye,
and Fin Slash, because Analyze named it as the answer on four of five
enemies.

What the dead three had in common was not invisibility, and not a
missing animation, because Tail Strike had one. **None of them arrived
with a problem that required them.** Bubble guarded nothing in
particular. Analyze answered a question the free telegraph had already
answered. Tail Strike solved nothing Fin Slash did not solve better.

So the failure was never "abilities are bad rewards." It was that six
abilities were handed over at once, unexplained and undifferentiated,
with no obstacle attached to any of them.

### The rule

> **Every ability arrives with three things: a visible source, a
> distinct motion, and the problem it solves.**

The visible source may be gear, a new diver, or the drum growing a mode.
The problem is the part TIDESONG never had.

### The convergence worth keeping

"Every ability arrives with the problem it solves" and **G4 per-option
dominance** ("every ability must be the single best choice somewhere by
a measurable margin") are the same requirement seen from two ends. An
ability introduced by an obstacle that demands it cannot be dominated,
because at least one state exists where it is the answer. An ability
that fails G4 was introduced without a problem.

**The teach ladder and the hardest balance gate are one check.**

### Story-gated, with one binding condition

Story gates capability. That inverts TIDESONG's failure exactly: story
was a collectible, so it was optional, so it was invisible. Making story
the gate makes it load-bearing without a line of exposition, and it
gives the player a reason to care about it.

**Condition: story-gated only works if the story is on the critical
path.** Last time the load-bearing verse, the one carrying the inciting
incident, sat behind an optional puzzle nobody found. If capability is
behind story, the story cannot be skippable, or we have rebuilt the same
bug under a new name.

### The boat is the hub

Surface-supplied diving means a compressor on a boat. **The boat is
where divers join and where prototype suits are upgraded.** That gives
the hub a job that is not lore delivery, which is the direct fix for
"the merfolk should have given something." The umbilical, the shared Air
pool, the hub, the NPC and the progression are one idea rather than
five.

### The ladder

| Beat | New idea, taught alone | Delivered as |
|---|---|---|
| Opening | Who you are and what you want | Scene |
| Fight 1 | Attacks have geography | Two divers, three limbs, empty UNDER |
| Boat | A diver who costs 3 is a commitment | Proto5 joins |
| Puzzle 1 | The lock's state is readable | Environment |
| Fight 2 | Conditions | Drum mode fitted at the boat |

The **Aug 13 slice** is the first three rows plus the puzzle.

**Open risk, flagged now rather than in week six:** six abilities plus
three divers plus drum modes needs roughly six or seven teaching beats,
against an agreed budget of one hub and two dungeons. Tight but
workable. The ladder gets written before the content, so we find out
early.

Upgrades are **story-gated, not bought.** Salvage as a currency is
deferred: the slice's job is to prove the combat reads, and an economy
is a second thing to explain before the first has evidence.

## 2.9 The six abilities (Q7)

**One verb per diver**, expressed twice at different scales or scopes.

| Diver | Cost | Verb | Ability | Does |
|---|---|---|---|---|
| Scuba | 1 | **displace** | `Axe_Kick` | knocks the target limb's guard open, or shoves an enemy part |
| | | | `Double_Knee` | attacks and moves Scuba to an adjacent station in one action |
| Prototype1 | 2 | **disable** | `Palm_Strike` | applies the condition currently fitted to the drum |
| | | | `DualPalm` | applies it to two limbs at once, or refreshes it |
| Proto5 | 3 | **break** | `Attck1` | heavy damage to one limb, the reliable breaker |
| | | | `Attck2` | hits two adjacent stations, the crowd answer |

Why one verb per diver:

- It makes composition legible. "Who do I spend Air on" becomes the same
  question as "what do I need to happen right now." Three verbs, three
  costs, four Air, and a player can hold that in their head.
- It gives us three problems to build obstacles around, which is exactly
  what the teach ladder needs. An enemy that must be moved teaches
  Scuba; a limb that must be shut off teaches Prototype1; an armoured
  limb teaches Proto5. Obstacle and ability are designed as one thing.
- It matches the clips we have. Scuba's are both kicks, which read as
  impact and displacement. Prototype1's are both open-handed palm
  strikes, which read as *applying* rather than smashing. Proto5's are
  undefined and can be the heavy breaks.
- The rejected alternative, "cost tier defines role," produces six
  abilities that differ only in magnitude, which is exactly how Tail
  Strike ended up dominated.

**Confidence note:** this is the first section of the spec that is
invented rather than derived from evidence. It should be the first thing
the bands and the dominance proof are pointed at.

## 2.10 Numbers (Q8)

**HP is tiered by gear.** The gear tier already sets Air cost and is
already readable off the silhouette; letting it set HP too means one
visual carries two mechanics that agree with each other. Plate costs 3
and survives. Bare skin costs 1 and dies. Nothing new to explain.

Opening values, to be moved by the bands, not defended:

| Diver | Air cost | HP | Damage |
|---|---|---|---|
| Scuba | 1 | 6 | 2 |
| Prototype1 | 2 | 10 | 2 + condition |
| Proto5 | 3 | 16 | 5 |

Limb durability 6 to 8. Enemy damage 3 to 4.

**The property worth noticing:** at 2 damage for 1 Air, Scuba is the
*efficient* diver, while Proto5 at 5 damage for 3 Air is *concentrated*.
So the heavy is not "more damage," he is "damage that lands this turn."
That is a reason to exist rather than a bigger number, and it is the
thing that stops him being Tail Strike.

Rejected: flat HP for everyone leaves armour decorative, which wastes
our one legibility win. A shared party HP pool removes the reason to
care who gets hit, which is the entire tension stations create.

## 2.11 Turn structure (Q9)

**Full player turn spending up to 4 Air, then the enemy's full turn.
The telegraph is shown at the START of the player's turn.**

The contract: you see exactly what is coming and where, then you get a
whole turn to answer it.

It also protects the search. One decision node per turn containing an
allocation of 4 Air. Initiative interleaving would multiply the tree by
permutations and make the dominance proof much more expensive, and
strict alternation would delete allocation, which is the reason Air
exists.

Rejected: an enemy that acts inside the player's turn. A plan you cannot
finish is indistinguishable from a random outcome, which contradicts 2.1.

## 2.12 The slice's puzzle (Q10)

**Flood and drain.** Valves raise and lower the water level, and the
level changes what is reachable.

**Water level is the most readable state in any game world.** You can
see it from across the room, you can see it change, and you can read it
from a screenshot with no HUD, which is exactly what the blocking
cold-read gate tests. It is the song puzzle's failure inverted: that
puzzle's state lived in the player's memory of a sequence; this one's
state is a line you can point at.

Later escalation, free: a room whose water level changes is a room whose
stations change.

Rejected: power routing and pressure doors are good Zelda idioms whose
state lives in small indicators, which is nearer the failure we are
correcting than the fix.

---

# Part 3: Premise and opening

**All text here is a committed draft, placeholder-marked for Marc.** It
exists because a blank where the premise goes is a decision to have no
game. Rewrite freely; the structure below is the part that is load
bearing.

Working title: **SALVAGE** (team can rename).

## 3.1 The premise

The water never went down. What is left of people lives on rigs and
boats, and everything worth having is underneath them.

The squad are salvage divers working off one rig, field-testing
prototype diving armours. **The rig's compressor is failing.** It is the
thing that lets anyone dive, and diving is how the rig eats. The parts
that would fix it are in the drowned city below, deeper each time, and
the mutants got there first.

**The goal sentence, said out loud on the boat in the first minute:**
*"The pump is dying. What fixes it is down in the city. We go down."*

## 3.2 Why this premise and not another

It follows the one story lesson TIDESONG got right, which is to derive
theme from the verbs rather than paste it on:

- **The Air pool and the stake are the same object.** The compressor is
  what gives you four Air a turn, and it is also the thing that is
  dying. The core mechanic and the plot are one item.
- **It renews.** Every dive has a reason and the reason gets worse.
- **It explains the hub.** You surface to the rig because the rig is
  where the compressor, the gear and the other divers are.
- **It explains the fiction of shared Air**: surface-supplied diving,
  umbilicals from one pump.
- **It fixes the Dorothy problem.** "Get home" cannot mean the surface
  in a flooded world, and the divers start on a boat, so they are
  already there. Home is *down there*, drowned. Scuba came from the city
  before the water took it. That is a sharper version of the Oz want,
  not a weaker one.

Each archetype keeps one want, in the Oz shape, all placeholder:
Scuba wants the place she came from, Prototype1 wants to understand what
is down there, Proto5 wants a reason to be in a suit at all.

## 3.3 The opening (Q11)

**A short scene on the boat, then the descent.** Under a minute, and it
must deliver four things and nothing else:

1. Who you are.
2. What you want (the goal sentence above).
3. What is in the way.
4. What the buttons do.

It opens on the rig because the rig is already the hub, so the opening
teaches the hub for free and introduces the two starting divers as
people rather than menu entries.

**The opening is a mechanic and is budgeted as one.** It is the direct
fix for the loudest finding of the last playtest, which was that nobody
could say what they were supposed to be doing or why.

## 3.4 Standing story rules

- **Story gates capability and therefore sits on the critical path.**
  TIDESONG made story a collectible, so it was optional, so it was
  invisible. Not repeatable.
- **Puzzle grammar is machinery and flow**, chosen because its whole
  state is readable off the objects.
- **Analyze is a character, not an ability.** Prototype1 carries the
  three-lens drum. Under Air, spending 2 on the scanner instead of 3 on
  the heavy is a composition choice, not a wasted turn.

---

# Part 4: Verification plan

## 4.1 The upgrade: G4 stops being a statistic

Determinism plus five stations plus a 4-Air budget makes the turn-plan
tree small and enumerable to a depth of three to five turns.

- **G4 becomes a proof.** For each ability: does there exist a reachable
  state where it is the unique optimal action? If not, it is dominated,
  proven rather than estimated. This lands on the gate that failed twice
  last time, on Bubble and on Tail Strike.
- **G11 becomes exact.** The taught line's distance from optimal is a
  number. "Following the tutorial costs you 2 HP against perfect play"
  is a sentence we could not previously write.
- **G2 becomes stronger.** Not "a casual bot finished" but "a win exists
  from every reachable state." Positioning adds a real softlock risk,
  which is a diver stranded where it can neither act usefully nor
  retreat, and only reachability analysis catches that.

**Accepted design constraint: the state space is a budget.** A mechanic
that makes the tree unsearchable costs us the proof and drops us back to
sampling. This is deliberate, and it is the opposite of last time, where
instruments chased a design that had already outrun them.

## 4.2 Three new defect classes stations create

1. **Dead station.** A place nobody profitably stands is the positional
   version of a dead ability. Detector is a direct port of the usage
   histogram: occupancy frequency per station under optimal play.
   **0 percent is blocking.**
2. **Dominant station.** The inverse and more likely. If one station is
   optimal on most turns, positioning is theatre.
3. **Broken station-limb contract.** "The limb is the position" is a
   promise the UI makes. The station-to-limb map is **one typed data
   table** that sim and presentation both read, never two agreeing
   lists. This is the bug that made the gullet seal silent.

## 4.3 What existing gates inherit, changed

- **Telegraph honesty** gains a spatial term and gets stricter.
  Determinism turns "announced matches happened" from a distribution
  check into an equality: station, limb and exact number.
- **Motion readability** moves to build time. Assert every enemy action
  has a telegraph naming a station, a bound animation clip, and a travel
  path from the enemy to that station. A missing binding is a build
  failure, not a discovery in someone's living room.
- **G10 cold read (blocking)** takes its question set from the geometry:
  which diver is about to be hit and for how much; what can the diver at
  FRONT attack; why would you move; what did the enemy just do and to
  whom. A cold reader who cannot answer from one screenshot is a finding
  that blocks.
- **Layout invariants** gain station geometry, and Godot makes them
  nearly free since `Control.get_global_rect()` hands us boxes: station
  markers never overlap, two divers sharing a station never fully
  occlude each other, the telegraph line always points at a station that
  exists on screen.
- **G14 harness fidelity**: the sim is plain `RefCounted` with no `Node`
  inheritance and no scene access. The bot calls the same entry point
  the input handler calls. Differential test on every commit. If a bot
  cannot run the whole game with `--headless` and no scene instantiated,
  the split has already leaked.

---

# Part 4b: Tech stack and bootstrap order (Q12)

**Pure GDScript, executed with the split-cost discipline.**

## Two corrections to the earlier draft

1. **The dominance proof was overstated.** Brute force to depth six is
   roughly 300^6 and is not happening. Memoised on game state it is
   tractable, because the state is small (three diver stations, three HP
   values, three limb durabilities, enemy state), but that is tens of
   millions of states. The honest claim is **depth-limited, memoised
   search over representative states, dramatically stronger than
   sampling, not a complete solve.**
2. **Web export may be the decisive constraint and was ignored.** Every
   piece of real feedback this project has ever received came from a
   link. GDScript web export is first class; C# web export is partial and
   historically the weak spot; Rust via gdext needs matching emscripten
   toolchains and is finicky. The question is not throughput versus
   ergonomics, it is **throughput versus distribution**, and distribution
   is where all our evidence comes from.

## The split

| Runs | Contains | Constraint |
|---|---|---|
| **Every commit** | bands, differential harness check, layout invariants, telegraph honesty | must stay fast |
| **Nightly or on demand** | dominance search, deep soaks, taught-line comparison, cold reads | allowed to take a long time |

Still measure on day one: build the sim and one encounter, run 10,000
fights, and time both that and a depth-3 memoised search. That decides
which bucket things land in, with a number instead of an argument. If
even the bands are slow, a Rust sim core becomes real and we accept the
export cost.

## Bootstrap order (binding)

1. Sim core as plain `RefCounted`. No `Node`, no scene access. One
   encounter, no art.
2. Bot, plus the throughput measurement.
3. **Layout invariants over the scene tree, before any content exists.**
   `Control.get_global_rect()` gives us boxes for free, and retrofitting
   this was the most expensive thing we did last time.
4. Differential harness test, so the bot and the input handler provably
   enter the same door.
5. **A clickable web export on day one**, with a placeholder in it.
6. Only then, content.

## Long tests are a feature of an autonomous run

Evidence from the last run: all nine gates went green at 06:21 and the
run continued to 07:58. Those 97 minutes produced re-verification, a
100,000-fight depth block, a stability soak and a README. **Zero new
content.** The model concluded it was done and then filled time.

The mechanism is **information yield, not duration**. A suite that always
passes tells you nothing however long it takes; 267,930 green assertions
means the instruments are exhausted, not that the game is finished. Slow
tests help only because they make re-running a green suite for
reassurance impractical.

Three devices, to be written into the next run's PROGRESS.md:

1. **Expensive generative verification runs continuously in the
   background**, so there is always a pending question and "what do I do
   while that runs" has one honest answer.
2. **Loop-until-dry as the stopping condition, not a timestamp.** Done is
   when K consecutive deep passes find nothing new. That makes "done" an
   empirical property of the search rather than a judgement the builder
   makes about itself. The last run's hook required a wall-clock time and
   a completed report, both of which are satisfiable by waiting.
3. **A content checklist that cannot be faked.** G-TEACH supplies one:
   every mechanic needs a beat where it appears alone. Unbuilt beats mean
   a red gate that no amount of re-running turns green.

Standing rule: **re-running a green suite is not work.**

---

# Part 2b: Rules that were missing, now ruled

Ruled with the user's standing permission to change any of them during
the build if they become a problem. Change them **with a logged reason**,
not silently.

| # | Rule | Ruling |
|---|---|---|
| A1 | **A strike into empty water** | **Cuts the umbilicals: minus 1 Air from next turn's pool.** Without this, three divers vacate every telegraphed station for 3 of 4 Air every turn and the enemy never connects. That is a dominant strategy of exactly the class G4 exists to catch, and it was sitting in the spec. The fix is diegetic (air lines lie on the seabed where the fight is), it gives the compressor plot mechanical presence, and it makes the choice real: eat the damage, or run next turn on three Air |
| A2 | **A diver at 0 HP** | Out for the rest of the fight, back at the boat afterwards. Losing a body mid-fight is punishment enough against a 4-Air budget |
| A3 | **HP recovery** | Fully at the boat, never mid-dive. The dive is the unit of attrition, which is what makes HP sacred without a healing economy |
| A4 | **Fail state** | All three down ends the dive. You surface, keep progress, lose the salvage |
| A5 | **Enemy action selection** | A fixed rotation over its unbroken attacks, visible in the telegraph. Deterministic, and the *rule* is readable rather than only the outcome |
| A6 | **One diver acting twice in a turn** | Allowed, Air permitting. It is what makes Scuba at cost 1 interesting |
| L1 | **Heavy adjacent-only movement** | **Cut.** Flat 1 for everyone. Revisit only if the first bands run says the heavy is too mobile |

**A1 carries a live risk, already measured.** The day-zero station
histogram reports UNDER at 0.0 percent occupancy under optimal play, and
UNDER is the deliberately empty station whose entire job is to teach that
safety is a reason to move (2.6). Dodging now costs 1 Air to move plus 1
Air of umbilical damage, against 4 damage on a diver with 16 HP.
**The vacate fix may have over-corrected and removed the reason to move
at all.** Rule on it with numbers early; do not tune it away silently.

# Part 2c: Two budgets, and they are not the same budget

An earlier draft of this section cut the jam budget to "pay for" the
party. **That was wrong and is withdrawn.** It imported the merge
proposal's shipping budget, which is sized around two months of human
labour for the Oct 5 build, and applied it to a prototype that is built
overnight by a machine. A shipping budget constrains how much a team can
finish. A prototype budget constrains how much can be learned. Optimising
the second with the first inverts the purpose: the entire finding from
prototype 1 was that we did not learn enough, and the proposed remedy was
to learn less.

## The jam budget: unchanged, and not ours to spend

1 hub plus 2 dungeons, 2 bosses, 3 enemy types, 1 to 2 relics, 2 to 3
puzzle types, ~6 abilities. Marc and Glass_Goat own it, for October.
Nothing in this prototype spends it.

## The prototype budget: set by questions, not by counts

An overnight autonomous build is not labour-bound. What it IS bound by:

- **Teaching burden.** Every new mechanic needs a beat where it appears
  alone (G-TEACH). More *mechanics* costs. More *instances* of a mechanic
  does not.
- **Human art and human words.** Glass_Goat and Marc are the real
  bottleneck, which is why everything ships placeholder.
- **Per-encounter complexity, not encounter count.** The dominance search
  is per fight, so ten fights is ten linear passes while one fight with
  twice the limbs is exponential. Where this spec says "the state space is
  a budget", it means per encounter.

So the content list is derived from what has to be answered:

| Question the prototype must answer | Content it requires |
|---|---|
| Does "the limb is the position" read to a cold player? | fight one, full station ring |
| Does the station system survive a different anatomy? | a second enemy with a different station-to-limb map |
| Does party composition actually bind? | a fight no single diver solves |
| Does the Air economy bind? | measured, no extra content |
| Do conditions land as a taught beat? | the drum unlock, then a fight that needs it |
| Does the puzzle grammar read? | two puzzles, one to teach and one to escalate |
| Does the format escalate at a boss? | one boss whose station map changes mid-fight |
| Does the teach ladder hold? | every beat present, G-TEACH green |

**The prototype should overshoot the shipping budget, because unbuilt
content answers nothing.** Build until the questions are answered or the
deep set goes dry, not until a count is reached.

---

# Part 5: Still open

The question tree is complete. What remains are loose ends rather than
branches.

| # | Loose end |
|---|---|
| L2 | The six ability effects in 2.9 are invented rather than derived, and should be the first thing the bands and the dominance search are pointed at |
| L4 | The full teach ladder written out beat by beat, before content starts |

---

# Part 6: External dependencies

## Art asks for Glass_Goat, in priority order

1. **Enemy animations.** There are zero enemy models or clips, and the
   most severe playtest finding was that enemy attacks read as nothing.
   Needed: idle, wind-up, strike, hit reaction, death. We will build
   placeholders first and hand them over as the brief.
2. **A reposition clip per diver.** Positioning is in and no movement
   animation exists for anyone.
3. **Death animations.** None exist.
4. **Non-attack ability animations**: guard, scan, use-the-drum.
5. **A deform-only export.** The rig is Auto-Rig Pro at 136 bones per
   character, mostly FK and IK controls. Worth agreeing a bone budget
   before animation work scales.

## Budget renegotiation

Party members were on the post-jam list alongside Resonance, inventory,
and the full exhaustion vision. Reopening party means the agreed content
budget (30 to 45 minutes, 1 hub plus 2 dungeons, 2 bosses, 3 enemy
types, 1 to 2 relics, 2 to 3 puzzle types) needs re-agreement rather
than an addition.
