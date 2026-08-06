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
  board as an arc from the limb to the place it will land, with the damage
  on it. There are no hidden rolls. If it says 5, it is 5.
- **One shared tank of air.** Four points a turn for the whole squad, spent
  on moving and on abilities, and it does not carry over. Funding one
  diver's turn is paid for out of another's.
- **Break every limb to win.** Breaking one changes the board, because the
  station it exposed stops being dangerous.

## Controls

Mouse or keyboard, whichever you prefer.

| | |
|---|---|
| Click a station | move the selected diver there |
| Click it again | attack from it |
| Click a diver's card | select that diver |
| `1` `2` `3` | select a diver |
| The letter on a station | move there (1 air) |
| `SPACE` / `F` | that diver's two abilities |
| `ENTER` | end the turn, or move the story on |

A line under the telegraph always tells you what to do next.

## What this is and is not

It is a **prototype**, built to find out whether the combat reads and
whether the puzzles work. Judge the decisions, not the finish.

- **All words are placeholder** and marked as such. Marc writes the real
  ones.
- **All art is placeholder**, drawn in code. Glass_Goat's characters and
  every real animation are still to come; what is here is the brief for
  that work.
- The music is a few procedural notes, not a score.
- There is no boss, and the run stops after the dredge.
- `Prototype1`, `Proto5`, `Attck1` are working identifiers from the
  animation rig. They will not ship.

## If you are playtesting

Read [PLAYTEST.md](PLAYTEST.md) first. It has the five questions we most
want answered and the full list of what is already known, so you do not
spend your session reporting things we have written down.

## For developers

Godot 4.7.1, pure GDScript, no addons.

```
./verify/fast.sh                 # the per-commit gate set
godot --headless --path . --script verify/deep.gd    # the nightly search
./verify/gallery.sh /tmp/gal     # screenshots of every beat, as played
./tools/deploy.sh                # build, publish, and verify it serves
```

`sim/` is pure: no `Node`, no scene, no timers, so the judge bots and the
search can drive the real game. [PROGRESS.md](PROGRESS.md) is the binding
record of what is verified and what is not, including the things that are
still open.
