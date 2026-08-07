# SALVAGE

**▶ Play it in your browser: https://salvage-chi.vercel.app/**

No install, no download. It takes about ten minutes.

A turn-based prototype for Team Ratateam's underwater jam. The water never
went down. Everything worth having is under it, and the things down there
got there first. Your rig's pump is dying, the part that fixes it is in
the drowned city, so you go down.

---

## How it plays

You control a squad of divers standing at **stations** around whatever you
are fighting. **The limb is the position**: where you stand is what you can
hit, and what can hit you.

- **Everything the enemy will do is announced a turn ahead**, drawn on the
  board with the damage on it. There are no hidden rolls. If it says 5, it
  is 5. Some attacks hunt the station you actually stand on; moving after
  the announcement is the dodge.
- **Moving is free.** Every diver's first move each turn costs nothing.
  The shared tank pays for everything else: four lines of air a turn for
  the whole squad, spent on swings and reads, and it does not carry over.
- **Break every limb to win.** Reading a limb first tells you what it is:
  brittle ones crack for double once you know where to aim, plated ones
  shrug a point off everything, and some pay out when they break. Choose
  what to disable, not just what to damage.
- **The turn can be taken back**, once a fight, while you think. There are
  no hidden rolls, so the rewind is for finishing a thought, not fishing.
- In the last dive, **the thing you came for sits on the board**. Unblocked
  swings through its station chip it. Standing there shields it with your
  body. You can win the fight and still surface with nothing.

## Controls

Mouse first. Every action is an on-screen button; the keyboard is a set of
shortcuts for the same moves.

| | |
|---|---|
| Click a station | move the selected diver there (free) |
| Click it again, or click the creature | attack from where you stand |
| Click a diver or their card | select that diver |
| The buttons on the left | abilities, read a limb, rewind, end turn |
| `1` `2` `3` | select a diver |
| `Q` `W` `E` `R` `T` | move by station letter |
| `SPACE` / `F` | that diver's two abilities |
| `A` | read the limb in front of you |
| `U` | rewind the turn, once a fight |
| `ENTER` | end the turn, or move the story on |

The game teaches each rule once, at the thing itself, then leaves you
alone. If you are ever stuck, the prompt line above the board only speaks
when there is a decision worth making.

## What this is and is not

It is a **prototype**, built to find out whether the combat reads and
whether the puzzles work. Judge the decisions, not the finish.

- **All words are placeholder** and marked as such in the source. Marc
  writes the real ones.
- **The divers are the team's own rig**, baked to frames from
  Glass_Goat's `Main_Team_Rigging.fbx`: real silhouettes, real attack
  and hit animations, clay-rendered until the final look lands. The
  creatures are still drawn in code and do not animate beyond motion
  cues; their clips do not exist yet.
- The music is a few procedural notes, not a score.
- There is no boss, and the run stops after the dredge.
- `Prototype1`, `Proto5`, `Attck1` are working identifiers from the
  animation rig. They will not ship.

## If you are playtesting

Read [PLAYTEST.md](PLAYTEST.md) first. It has the questions we most want
answered and the full list of what is already known, so you do not spend
your session reporting things we have written down.

## For developers

Godot 4.7.1, pure GDScript, no addons.

```
./verify/fast.sh                 # the per-commit gate set
godot --headless --path . --script verify/deep.gd    # the nightly search
./verify/gallery.sh /tmp/gal     # screenshots of every beat, as played
./tools/deploy.sh                # build, publish, verify the URL serves
                                 # these exact bytes, and behavior-check it
```

`sim/` is pure: no `Node`, no scene, no timers, so the judge bots and the
search can drive the real game. The gates include a masher (attack-only
play must lose somewhere and can never stalemate), a mouse-door (every
sim-legal action must have a working button), and a HUD budget (the
creature must be visibly unoccluded). [PROGRESS.md](PROGRESS.md) is the
binding record of what is verified and what is not.
