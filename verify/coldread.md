# G10 cold read: the protocol, and the questions

BLOCKING gate. Run against the gallery (`verify/gallery.sh`) after any
change to presentation or content.

## Protocol, and the protocol is the whole trick

1. Questions are DERIVED FROM THE SPEC. Every mechanic on the teach ladder
   yields a question about the beat where it is taught.
2. The reviewer NEVER sees the spec, the code, or this file's answers.
   They see one image and answer from it.
3. Questions must not leak their own answer. "There is a puzzle here, what
   does it want" is a worse question than "list every object you could
   interact with and say what each does."
4. CANNOT TELL is forced, and must name what is missing.
5. A told-versus-assumed column is mandatory. It separates what the screen
   said from what the reviewer filled in from genre convention, which is
   the failure mode that made the last project's bot playtests worthless.
6. SCORED ON THE DIFF between runs, not the absolute count. A build with
   zero CANNOT TELL is not the target; a build whose CANNOT TELLs are
   shrinking is.

## The questions, by mechanic

| Mechanic | Question asked of the reviewer |
|---|---|
| goal | What are these people trying to do, and why? |
| combat_frame | How many actions can you take before the enemy acts? |
| stations | What can each of your characters attack from where it stands? |
| limbs | What are you attacking, and how much of it is left? |
| telegraph | What will the enemy do next, to whom, and for how much? |
| cost_tiers | Which character costs the most to use, and how can you tell? |
| conditions | Is there a way to stop an attack before it lands? |
| backline | Why would you stand somewhere you cannot attack from? |
| water_level | What is the state of this lock, and what would change it? |
| umbilical | What happens if the enemy hits nothing? |
| overdraft | Can you act when you cannot afford to? |

Plus two that belong to no mechanic and catch the framing failure:

- What would you press right now, and what do you expect to happen?
- Name anything on this screen whose purpose you cannot determine.
