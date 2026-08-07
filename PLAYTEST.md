# SALVAGE, for playtesters

**Play it here: https://salvage-chi.vercel.app/**

Mouse or keyboard. It runs about ten minutes. Nine beats, four fights, two
locks. There is no save; refreshing starts over.

## Controls

Everything is clickable. The buttons on the left of a fight are the whole
verb list: your abilities, reading a limb, rewinding the turn, ending it.
Click a station to move there (moving is free, once per diver per turn),
click the creature to attack from where you stand, click a diver or their
card to select them.

Keys, if you prefer them: `1` `2` `3` pick a diver, the letter on a
station moves there, `SPACE` and `F` are that diver's abilities, `A`
reads, `U` rewinds, `ENTER` ends the turn.

## What we most want to know

1. **Did you know what to do?** The game now teaches each rule once, at
   the moment it matters, then never repeats it. If you were lost, say
   where exactly.
2. **Could you tell what the enemy was about to do, and did you ever move
   BECAUSE of it?** Every attack is announced a turn ahead, and some hunt
   the station you stand on. Did dodging ever feel like your idea?
3. **Did you ever read a limb, and did it change which one you broke?**
4. **Did you use more than one diver in a turn?** Moving is free now.
   Did the squad feel like a squad?
5. **In the last fight, did you notice the crate, and did you do anything
   about it?**
6. **Where were you bored?** Name the beat.

## Known, so you do not need to report it

- **All words are placeholder** and marked as such in the source; Marc
  writes the real ones. The story is a skeleton, not a draft.
- **The divers are the team rig** (Glass_Goat's characters), clay-toned
  until the final look lands. **The creatures are still code-drawn** and
  have no animation clips of their own yet, so enemy attacks read as
  motion cues, not animations.
- The music is four procedural notes, not a score.
- There is no boss and the run stops after the dredge.
- The first real fight is deliberately forgiving; a casual player wins it
  about 60 percent of the time, measured. Attack-only button mashing is
  supposed to lose it. If you mashed your way through everything anyway,
  that is a bug we want badly.
- Character names (`Prototype1`, `Proto5`) and two ability names
  (`Attck1`, `Attck2`) are working identifiers taken from the animation
  rig. They will not ship.

## If it breaks

Tell us the beat number from the top of the screen and what you pressed.
The build reports its own position, so that is enough to reproduce it.
The page also serves /build.txt naming the exact commit you played.
