# Prototype 2 inputs (accumulating)

Source 1: human playtester notes, collected by the user.
Source 2: team Discord, Jul 15 to Aug 4 2026 (137 messages, three
members: mhanna112 / Marc, glass_goat, etn3_i / the user).

---

# Part 0: Rulings (settled, not open)

| Decision | Ruling |
|---|---|
| The song and singing | **Cut wholesale.** Not as lore, not as a collectible, not as a puzzle lock. |
| The TIDESONG story | **Cut.** Setting moves toward Glass_Goat's post-flood diving premise. |
| Party of three in combat | **In.** The merge proposal's "the jam game is a solo character" is formally reversed. |
| Limb targeting | **Stays in. Players liked it.** The complaint was that targeting was not clear, and the answer is legibility, not removal. This overrides Glass_Goat's combat-PDF preference for skill-plus-condition. |
| Engine | **Godot.** 2.5D, not 3D, per Glass_Goat. Rust still open, decided on bot throughput. |
| Which build was played | **The latest.** Confirmed by the user. |

Also confirmed and new: **several players who tried it found it fun.**
The 6/10 cold read was one reviewer, not a consensus. We are iterating on
a base people enjoyed, not rebuilding a failure.

Assets received: Glass_Goat has supplied the character files (Drive link
with team rigging FBX). Not retrievable by me; needs to be placed in the
repo or exported.

Still wanted: the two reference images posted immediately before the
action-sphere messages (Aug 3 17:46). The user recalls them as pictures
of "the legends", discussed as a source for both character archetypes
and puzzles. They line up with the Wizard of Oz framing of the sphere
system, and they are the only visual record of what the squad is meant
to be.

---

# Part 1: The playtester dataset

Twelve findings, grouped by what they are actually about.

## A. Framing: the player did not know why they were there

The largest cluster, and it appeared as several different symptoms.

| Finding | Note |
|---|---|
| No one understood what they were supposed to be doing, or why they were there | Reported as the recurring problem across players |
| No one understood there was a puzzle; one person solved it, and not on the first playthrough | Second prototype in a row |
| Needs clear directions on what to do | |
| Wants an opening that sets up the story and the goal, doubling as lore | The user's own read: initially sounded like polish, in hindsight it is the fix for the above |

**This is one problem, not four.** The prototype had a story bible, five
verses, a keeper who answered by progress state, and a two-ending
choice, and players still could not state their objective. Story
delivered through optional discovery cannot establish a goal, because
establishing a goal is the one thing that cannot be optional.

Worth noting what already worked: the HUD's NEXT and ALSO objective
lines were called "the single most useful thing on screen" by a blind
cold-read reviewer. So the moment-to-moment direction landed. What was
missing was the frame around it: who am I, what do I want, what is
stopping me.

## B. Combat legibility

| Finding | Class |
|---|---|
| Targeting was not clear | LEGIBILITY, recurrence |
| **Enemy attacks had no animation at all**, so it was not clear what they were doing | ANIMATION, new and severe |
| Player animations did not match the attack | ANIMATION, recurrence |

The enemy-attack finding is the most actionable single item in the set.
TIDESONG's best-rated mechanic was the intent telegraph, and the
telegraph was **a line of text**. The enemy body never performed the
thing the text announced. Players were reading combat, not watching it.

## C. Systems that were missing rather than broken

| Finding | Note |
|---|---|
| The merfolk should grant abilities, buffs, or trade something. NPCs must do more than lore | Recurrence of "the hub was pointless" |
| No movement in combat; you could not position or set up | New |
| **Three characters should participate in combat**; the prototype had one | Glass_Goat, and see the scope flag below |
| Positioning might replace arrow-key targeting: move to where you want to hit | New, and see the synthesis below |

## D. What the dataset does not say

Nobody complained about the disable-first core, the difficulty, the
condition system, the boss phase structure, or the pace of a fight. That
is meaningful negative evidence: **the part the bot batteries validated
stayed validated.** Every reported problem is framing, presentation, or
a missing system. This matches the retro exactly.

---

# Part 2: Which build they played, and why it is bad news

Settled from the `gh-pages` deploy log and the Discord timestamps.

| Who | When | Build they saw |
|---|---|---|
| glass_goat | Jul 29 20:33 | `7240fa6`, 18:15. Has the ability animations (16:32) and the combat layout fixes (18:14). **Does not** have the puzzle mechanism visuals (23:15). |
| The human playtesters | Aug 2 onward | `5dfc57a`, 23:19. **Everything.** |

The last deploy was 23:19 Jul 29 and no build shipped after it, so the
playtesters had every fix.

**So two legibility fixes were made, deployed, and did not work:**

1. **The puzzle mechanism.** Light threads from each stone to a
   breathing door, resonance halos, carved note faces, a sung stone that
   stays lit, and a thread tying the door to the verse it guards. Players
   still did not know there was a puzzle. One solved it, not on the first
   try.
2. **The ability animations.** Tail Strike given a tail-first pivot and a
   swept arc, Silt Burst given a seabed sweep with a rising plume, Heal
   Song given rings and notes. Players still said the animations did not
   match the attack.

There is a third, subtler case. The run log says the fun pass shipped
"enemy windup, strike snap, recoil." Players reported **enemy attacks had
no animation at all**. Both are probably true: a small snap on a mostly
static sprite reads as nothing.

**The lesson is a new defect class, and it is not "we did not fix it."**
It is that a presentation fix has a perception threshold, and shipping
"an animation" is not the same as shipping a readable one. Every one of
these fixes was verified by the builder looking at a render and judging
it improved. None was verified by a cold reader who did not know what
had changed.

This is the strongest possible argument for G-LEGIBILITY blocking, and
it is now evidence rather than theory: **the un-cold-read fix failed
twice in a row on the same build.**

New checklist entry: **motion readability**. Does a cold viewer, shown a
capture of the action, name what the character just did.

---

# Part 2b: What Glass_Goat validated

He played on Jul 29 and his verdict was mostly positive, which the
playtester notes do not capture:

> "Honestly this is all the base mechanics"
> "the movement is very good"
> "making a 2.5 rpg is actually a great idea, so instead of top down
> pokemon we can do the 2D map"
> "the abilities here make sense"
> "the slow going to level 2 works very well"
> "that's one hell of a base"

Carried forward as validated: **the 2.5D format** (he explicitly adopts
it over top-down), the ability kit, and **condition levels I and II**,
which the retro had flagged as rarely surfacing in natural play.

His one criticism is a direction, not a bug:

> "it's still pulling too much for the basic final fantasy, the overall
> idea is all there the polishing are just details"

Static sprites trading blows in a menu. The positional and action-sphere
ideas below are the answer to it.

---

# Part 2c: Glass_Goat's design work since the playtest

Three separate contributions, all after he played. None of them are in
the playtester notes.

## The premise has already moved off merfolk

Jul 29 23:35, unprompted, hours after playing:

> "earth was flooded, many treasures of humanity ended up at the bottom
> of the sea, those treasures are opened with sound based codes, so
> Frequencies, songs and poems are how you rearrange those frequencies"

Aug 3, sharpened:

> "Diving expedition" / "mutants, scarce resources" / "underwater
> treasures" / "the underwater Distopian expedition"

So the setting he is working toward is a **post-flood dystopian diving
expedition**: human treasures on the seabed, mutants, scarce resources,
divers rather than fish. That is compatible with cutting the TIDESONG
story, and it is his own pitch, so it already has buy-in.

**But note what it keeps.** His premise makes sound the *puzzle grammar*
(frequency codes open the treasures), not the story theme. That is a
different thing from what the playtesters rejected. The song failed as
lore and as a collectible; it has never been tried as a lock. Worth
separating before cutting it wholesale, because his premise loses its
puzzle language without it.

Divers also fix a smaller thing for free: "why is a fish fighting" goes
away, and scarce resources become diegetic (air, gear, salvage).

## The numbers directive: chess, not dice

Jul 29 23:18:

> "Having low number about 10 HP and 20 Stamina So that the interactions
> are very predictable, like chess where all results are predictable so
> the strategy does not feel random but calculated"

Consistent with his combat PDF: "Players want consistent and predictable
results, the limb system brings too much ifs and buts."

**This conflicts head-on with what TIDESONG shipped.** 100 HP, 15 percent
dodge, 60 and 80 percent blind miss rolls, drift targeting, and G5
counted "uncertainty" as a fun axis with the evidence "outcomes are not
predetermined." His model wants the opposite. This is a real, unresolved
disagreement and it has to be settled before any tuning happens, because
the bands are built on top of the answer.

One thing in its favour that is easy to miss: small integers and no
rolls make the sim **more** testable, not less. Exhaustive search over a
whole fight becomes possible, so "is there a dominant line" stops being
a statistical question and becomes a solved one.

## Action spheres: the combat breakthrough

Aug 1 to Aug 3, and he flagged it as the thing he had been working on:

> "I cracked the code. I know how to make the combat more engaging"
> "it actually has to do with the wizard of OZ"
> "Resource action spheres"
> "characters each have an action sphere cost to act"
> "Dorothy and Scarecrow cost 1 action, Lion costs 2, Tin Man 3"
> "for example you get 4 action spheres in your turn"
> "so you can spend them in any combination of character costs"
> "Sphere cost big armor 3, Middle armor 2, Scuba gear 1"

**This is the strongest single idea any source has produced**, and it
answers documented failures rather than adding a mechanic:

1. **It is an action economy that binds by construction.** The retro's
   sharpest unfixed finding was "a resource that never binds is not a
   resource": stamina's floor in optimal play was 16 of 20 because a +2
   refund ran against 3 regen. Spheres are scarce every single turn with
   no regen loophole. Four spheres, and a heavy character eats three of
   them.
2. **It makes the party a decision, not three bodies.** Each turn you
   choose composition: four cheap actions, or one heavy plus one cheap,
   or two mediums. That is a real choice on turn one of every fight,
   which is exactly what "every attack should feel meaningful" asked for.
3. **It is deterministic**, so it satisfies the chess directive without
   removing tension. The tension comes from allocation, not from rolls.
4. **The cost is diegetic and therefore legible.** Big armor costs 3.
   You can read the number off the silhouette. After two prototypes of
   failing to make numbers legible, a system where the sprite *is* the
   number is worth a great deal.
5. **It gives turn order meaning** without a hidden Speed stat.

Open mechanical questions it raises: do spheres carry over between
turns, do enemies use the same economy, can one character act twice in a
turn, and does a downed character's cost come back to the pool.

Unretrieved inputs: two reference images posted immediately before the
sphere messages, and a Google Drive link on Aug 4 captioned "the squad",
which is presumably the three characters. Both are worth pulling before
the design session.

## Marc's contribution in the same window

Aug 3: "ask AI to generate Zelda-like puzzles to add to the game."
Consistent with his proposal ("Exploration is inspired by classic Zelda
games"). Note it sits directly against the playtest evidence that nobody
found the one puzzle that shipped, so the question is not whether to
have Zelda puzzles but how a player is told one is in front of them.

---

# Part 2d: Where the three sources agree, and where they collide

## Converged, treat as decided unless someone objects

| Point | Sources |
|---|---|
| A party of three in combat | Playtesters, Glass_Goat's spheres, his combat PDF ("incentivised to swap party members"), Marc's proposal ("protect allies", "strengthen allies", "manipulate turn order") |
| 2.5D side-on presentation, not top-down | Glass_Goat explicitly, after playing |
| Disable-first combat, ability kit, condition levels | Glass_Goat after playing; nobody complained |
| The economy must actually bind | Glass_Goat's PDF (HP sacred, hard to heal), his "scarce resources", the spheres, and the retro's own finding |
| An opening that states the goal | Playtesters, and the user's reversal |

## Collisions, three of four now settled

1. **Limb targeting: SETTLED, stays in.** Marc's proposal specified five
   parts; Glass_Goat's PDF argued against a limb system; the user has
   ruled to keep it because players liked it. The playtest complaint
   ("targeting was not clear") is therefore a legibility requirement on
   the limb system, not an argument to remove it. See 3.1a.
2. **Sound: SETTLED, cut.** Which leaves Glass_Goat's premise without a
   puzzle grammar, since frequency codes were the lock he proposed. A
   replacement is now a design task, not a preference. See 3.4a.
3. **Party: SETTLED, in.** The parked scope decision is reversed. With
   the jam running to Oct 5 rather than one night, the budget argument
   is much weaker than it was, but something should still come out.
4. **Determinism versus uncertainty: OPEN, and the biggest one left.**
   Glass_Goat wants 10 HP, 20 stamina, chess. TIDESONG shipped 100 HP,
   dodge and miss rolls, and counted uncertainty as a fun pillar. The
   user is unconvinced that small is the right lever. See 3.6.

---

# Part 2e: The squad, read off the art and the rig

Two reference images and `Main_Team_Rigging.fbx` (30 MB, Blender 4.5.2
export, Auto-Rig Pro). Source path in the file:
`OTC_ARTS/Blender/1_Character_Sets/9_Struggles/Diving_Armors/Main_Team_Rigging.blend`.

## What is in the file

Three rigged characters (3 deformers, 3 meshes), 136 bones each, and
**fifteen animation clips**:

| Character | Idle | Attacks | Damaged |
|---|---|---|---|
| **Scuba** | `Scuba_Idle1`, `Scuba_Idle_Pose` | `Scuba_Axe_Kick`, `Scuba_Double_Knee` | `Scuba_Damaged1` |
| **Prototype1** | `Prototype1_Idle1` | `Prototype1_Palm_Strike`, `Prototype1_DualPalm` | `Prototype1_Damaged` |
| **Proto5** | `Proto5_Idle`, `Proto5_Still` | `Proto5_Attck1`, `Proto5_Attck2` | `Proto5_damaged` |

Plus `T_Pose`. Materials: `Diver_Lady`, `Diver_Tank1`, `DiverMask1`,
`Face`, `Eyes`, `Mouth`.

## The mapping, and why the cost system is already legible

| Render | Name | Gear tier | Sphere cost | Oz archetype |
|---|---|---|---|---|
| Left, heavy plate, gold bands, red boots | Proto5 | big armor | **3** | Tin Man |
| Middle, bare skin, fins, goggles, red hair | Scuba (`Diver_Lady`) | scuba gear | **1** | Dorothy |
| Right, orange suit, round helmet, holding a three-lens drum | Prototype1 | middle armor | **2** | Scarecrow |

The Oz reference image is the template: a huge riveted Tin Man, a small
girl in **red boots**, and a lanky **orange-coated** Scarecrow. Our
Diver_Lady has red footwear and our middle-armor diver is orange. The
archetype mapping is deliberate and visible in the silhouettes.

**This confirms the thing I hoped for and could not assume: the sphere
cost is readable off the amount of gear worn.** Bare skin costs 1, suit
costs 2, plate costs 3. No number has to be printed anywhere. After two
prototypes of failing to make numbers legible, a system where the sprite
IS the number is the single best structural answer available.

The naming carries a fiction hook for free: the squad are field-testing
**prototype diving armors**. Prototype 1 and Prototype 5 are suits;
Scuba is a person with no suit at all. It explains why the gear is
strange, why the tiers exist, and why there could be more of them later.

## The constraint that should drive the combat design

**Each character has exactly two attack animations.** Three characters
times two attacks is six abilities, which is the same kit size TIDESONG
shipped, now distributed across the party so that sphere composition
actually decides which abilities you can reach this turn.

More importantly, this inverts the failure mode. TIDESONG named an
ability "Tail Strike" and then retrofitted motion onto it, twice, and
players still said the animations did not match. Here the motion exists
first:

- **Scuba**: Axe Kick, Double Knee. Both legs, unarmed, agile.
- **Prototype1**: Palm Strike, Dual Palm. Both hands, close range.
- **Proto5**: two attacks, unnamed and unseen.

**Rule for prototype 2: ability names come from the animation list, not
the other way around.** The animation-mismatch defect class is then
impossible by construction rather than fixed by iteration.

## What is missing, and it is the critical path

1. **No movement or swim animation for anyone.** Positioning is in, so
   every character needs one. This is the first ask.
2. **No enemies at all.** The most severe playtest finding was that enemy
   attacks had no animation. There are zero enemy models or clips in this
   file. Enemy idle, wind-up, strike and hit-reaction are the highest
   priority art dependency in the project.
3. **No death animation** for any character.
4. **No non-attack ability animations**: nothing for guarding, scanning,
   healing or using the three-lens drum Prototype1 is holding.

## Two design opportunities the art hands us

**The drum.** Prototype1 is holding a large cylinder with three glowing
octagonal lenses. That is an information tool, and it suggests making
**Analyze a character rather than an ability**. The retro's finding was
that Analyze sat at 0 percent of optimal play because information
competed for the same slot as damage. Under spheres, spending 2 on the
scanner instead of 3 on the heavy is a composition choice, not a wasted
turn. Information stops being a tax.

**The Oz frame answers the framing failure.** Every Oz character wants
exactly one thing, and Dorothy's is the clearest goal statement in
fiction: get home. In the post-flood premise that is *get back to the
surface*. That is an opening that needs no lore and no exposition, and
it directly fixes "nobody knew what they were supposed to be doing or
why they were there."

## Technical note for the Godot move

The rig is Auto-Rig Pro (`c_root_master.x`, `c_arm_twist_offset`,
`arm_stretch`, FK and IK control bones) at 136 bones per character, most
of which are controls rather than deforming bones. Exported to Godot
that is a lot of skeleton for a 2.5D game. Worth agreeing with
Glass_Goat on a **deform-only export** (Auto-Rig Pro has a game-engine
export path that bakes controls out), and pinning a bone budget before
animation work scales up.

---

# Part 3: The synthesis

## 3.1 Positional combat answers four complaints with one change

Targeting unclear, enemy attacks invisible, no positioning, three
characters. These are one design, not four fixes:

- **Targeting becomes spatial.** You move to the part or the enemy you
  intend to hit. The arrow-key part list disappears, and "what am I
  aiming at" is answered by where your character is standing rather than
  by a highlighted row.
- **Enemy attacks get an animation for free**, because an attack becomes
  a move-and-strike against a position. Who is being hit is visible
  before it lands, which is what the text telegraph was faking.
- **Three characters become legible** rather than an abstract party. With
  positions, a party is three things on screen in different places, and
  a support ability that protects an ally has a visible subject.
- **Glass_Goat's swap incentive gets a home.** The combat doc says
  limited healing "incentivises swapping party members." That is
  meaningless with one character.

This is the largest scope decision on the table and it needs to be made
deliberately, not absorbed.

## 3.1a Limbs stay, so positioning must serve them rather than replace them

The earlier draft assumed positional targeting would retire the part
list. With the limb ruling that is off the table, and the better shape is
that **the limb IS the position**.

Instead of an arrow-key list of parts, the enemy occupies space and its
parts occupy distinct places within that space: the jaw is at the front,
the tail at the back, the fin above. Moving a character to a place is
what selects the part. Then:

- "What am I aiming at" is answered by where a body is standing, not by
  a highlighted row.
- Reach and approach become real: the tail is behind the enemy, so
  hitting it means getting there, which is a cost and a risk.
- A three-character party gets a natural division of labour: someone is
  in the jaw's face, someone is flanking.
- Enemy attacks acquire an animation by necessity, because an attack is
  a strike at a place a character is standing in.
- Marc's per-part effects survive intact, and Glass_Goat's objection to
  limb systems ("too many ifs and buts") is answered by making the part
  a location instead of a menu entry.

This is the version of positional combat to bring to the session.

## 3.2 It reverses an agreed scope decision, on purpose

The merge proposal parked party members explicitly:

> Post-jam. Party members: a full system of its own; the jam game is a
> solo character.

So this was not an oversight. Reopening it is a real decision, and per
the source-doc precedence rule it has to be logged as a reversal with
something coming out to pay for it. Candidates to cut in exchange:
number of dungeons, number of enemy types, the second boss, or the
environmental puzzle layer (see 3.4).

## 3.3 Cutting the song leaves a hole that Resonance already fills

The playtesters want the NPC to trade something and collectibles to do
more than lore. Marc's proposal already contains the answer, and the
merge proposal parked it:

> Resonance: successfully breaking body parts generates Resonance.
> [Parked] for the jam, successful disables refund stamina instead.

With singing cut, Resonance is the obvious replacement currency: it is
earned in combat by playing the way the design wants, it is spendable at
an NPC, and it makes the hub a shop rather than a lore stop. It also
gives the "what do I collect" question an answer that is not a verse.

## 3.4 The puzzle problem is a delivery problem, not a puzzle problem

Two prototypes, nobody found the puzzle. But the **boss fights were
puzzles and players understood those**: a limb with durability, a key
part, a phase that breaks. Nobody reported confusion about the shark.

So the instinct is fine and the vehicle is wrong. Three options:

1. **Put puzzles where attention already is**: in combat, as enemy
   structures to dismantle. Marc's enemy design philosophy already says
   each enemy revolves around one defining mechanic.
2. **Put the environmental puzzle on the critical path** so discovery is
   not required. Optional plus undiscoverable equals invisible.
3. **Teach it in the opening** and make the first one trivial.

Option 1 plus 3 is the cheapest and it protects the pillar.

## 3.4a Cutting the song leaves a puzzle-grammar hole, and the fix is a diagnosis

Glass_Goat's premise opened treasures with sound codes. With sound cut,
the setting needs a different lock, and the choice should be driven by
**why the song puzzle failed** rather than by theme.

It failed because **its entire state lived in the player's memory of a
sequence and nothing on screen held it.** Three stones and a door. Which
notes had been sung, in what order, and how many remained were all
invisible. The visual fix drew the relationship between the objects and
still did not work, because the relationship was never the missing part.
The *state* was.

The replacement should be chosen so that **the whole state of the puzzle
is readable off the objects themselves.** In the post-flood premise that
points at pre-flood human machinery: valves, pressure doors, power
routing, flooded and drained chambers. A valve is open or closed and you
can see which. A pipe carries flow or does not. A chamber is flooded or
drained. Nothing has to be remembered.

It also serves three other constraints at once: it is diegetic to
"treasures of humanity at the bottom of the sea", it is the Zelda idiom
Marc asked for, and it gives the player a reason to be a diver rather
than a fish.

## 3.5 The opening is a mechanic, not polish

The user's own reversal is correct. Budget it as a first-class item with
a gate, not as end-of-run garnish. What it must deliver in under a
minute: who you are, what you want, what stands in the way, and what the
buttons do. It can carry lore, but the lore is the passenger.

## 3.6 On small numbers: the request is right, the lever is only half right

Glass_Goat wants 10 HP and 20 stamina so results are "predictable, like
chess." The user is unconvinced. Both positions have something.

**What is genuinely right about it**, and stronger than the reason he
gave:

- **Legibility, which is this project's chronic failure.** "8 damage"
  against 100 HP means nothing. "3 damage" against 10 HP reads instantly
  as "a third of me is gone." After two prototypes where players could
  not read the numbers we showed them, a scale a human can hold in their
  head is worth more than tuning headroom.
- **Testability.** Small integers plus no rolls means exhaustive search
  replaces statistical sampling. "Is there a dominant line" stops being
  estimated over 100,000 fights and becomes solved. The whole G4 question
  gets easier, not harder.
- **There is a proof it works.** Into the Breach is fully deterministic,
  units have 3 to 5 HP, every enemy attack is telegraphed with its exact
  target before it lands, and it is three units on a grid. That is
  almost exactly the game these inputs are converging on, and it is
  widely regarded as one of the best tactics designs ever made.

**What is genuinely risky**, and the user's instinct is pointing at it:

- **Tuning granularity collapses.** At 10 HP a single point is 10
  percent of a character. There is no room to express "this ability is
  15 percent better"; everything rounds to coarse steps. Six abilities
  can easily end up all doing 2.
- **Percentages stop composing.** A 50 percent reduction on a 3-damage
  hit is 1.5, and every rounding rule becomes a visible design decision.
  TIDESONG already learned that percentage mitigation does not tune.
- **Swinginess per point goes up**, not down. With three characters at 10
  HP, an enemy hit for 4 is nearly half a body.

**The resolution.** The two things actually being asked for are *no
hidden rolls* and *the player can count*. Small numbers deliver both, but
so does a slightly larger integer scale with no randomness. The real
commitment to make is determinism; the exact ceiling is a tuning
parameter.

And the load-bearing consequence, which is worth saying at the session
because it is easy to miss: **if numbers go small, variety has to move
out of damage values and into effects and positioning.** Into the Breach
has almost no damage variety (1, 2, 3) and enormous variety in push,
pull, displacement and terrain. If we shrink the numbers and keep
expressing ability identity through damage, the kit will flatten. With
limbs and positioning both in, we have somewhere for that variety to go.

Recommended framing for the decision: **commit to determinism first**,
then pick the smallest scale that still lets six abilities feel
different, and prove it with an exhaustive-search dominance check rather
than an argument.

---

# Part 4: What the Godot move does to the kit

## 4.1 Dies

`verify/d1-recorder.js` and `verify/d1-layout.mjs` are canvas-specific.
They do not port.

## 4.2 Gets easier, which is the good news

**Godot's scene tree already is a display list.** The refactor LESSONS.md
argued for is native: `Control.get_global_rect()` gives every UI element
a box for free, and the tree can be walked headless. The layout
invariants (no two text boxes collide, every label stays inside its
panel with padding, exactly one node carries the selected style) become
a tree walk in a headless scene, with no proxying and no
reverse-engineering.

**Build this in week one**, before content exists, so layout can never
regress unseen. It was the single most expensive thing to retrofit last
time.

## 4.3 The new architectural risk

The pure-sim rule survives, but Godot makes it much easier to violate:
nodes tempt you to store state in the scene tree. The rule becomes
concrete: **the sim is plain `RefCounted` classes (or Rust structs) that
inherit from no `Node` and touch no scene.** If a bot cannot run the
whole game with `--headless` and no scene instantiated, the split has
already leaked.

## 4.4 The real question behind Godot versus Godot plus Rust

Not preference. Throughput.

TIDESONG's trustworthiness came from scale: 100,000 simulated fights,
20,000 fuzz actions, 2,000 fresh seeds per encounter, 50x soaks. GDScript
runs roughly an order of magnitude slower than the JS this ran on. If a
band sweep goes from seconds to many minutes, it stops being run on
every commit, and the instrument that made the last prototype honest
quietly dies.

So the deciding test is measurable, and should be measured before the
stack is chosen: **implement one encounter and run 10,000 fights. If that
is fast enough to sit inside a normal commit loop, GDScript is fine and
Marc gets the Godot learning he wants. If it is not, the sim core goes to
Rust via gdext and Godot stays pure presentation**, which maps cleanly
onto the split that already works.

---

# Part 5: Open questions for the Discord pass and the design session

1. **Determinism.** Chess model (10 HP, no rolls) or keep uncertainty.
   Everything downstream depends on this.
2. **Limb legibility.** Limbs are staying, so the open question is how a
   player reads what they are aiming at. Proposal in 3.1a: the limb is
   the position.
3. **Spheres.** Carry over between turns? Do enemies share the economy?
   Can one character act twice? Does a downed character's cost return?
   And does the player control all three characters, or one plus two
   allies acting on their own?
4. **Positioning.** Grid or free? Does it replace part selection or sit
   alongside it? Does moving cost a sphere?
5. **Puzzle grammar.** Confirm machinery-and-flow over the cut sound
   codes, or propose another lock whose state is readable off the object.
6. **Currency.** Resonance, salvage, or spheres themselves. What does an
   NPC trade, and for what.
7. **Premise.** Confirm the post-flood diving expedition, and who the
   three characters are (pending the "squad" link).
8. **Scope.** What comes out to pay for the party, given Oct 5 rather
   than one night.
