# Baked sprite frames from Main_Team_Rigging.fbx

114 PNG frames across 17 clip directories (15 authored clips + T_Pose baked
once per character), rendered by `tools/bake/bake.tscn` + `bake.gd` running
Godot 4.7.1 NON-headless (headless cannot render; a window flashes during
the run). Frames were verified by eye across all three characters and every
clip family before shipping.

## Camera (identical for every character and clip)

- Orthographic, size **3.922** world units vertical (keep-aspect height),
  position `(0, 1.364, 8.405)`, rotation `(0, 0, 0)` - a straight front
  view down -Z; the characters face +Z (confirmed by the average world
  normal of the Face surface, +0.99 Z; Scuba reads back-like from the
  front only because heavy bangs hide her face).
- Frame size **352x512**, 0.0077 world units per pixel.
- **Floor/feet anchor: y = 434 px** from the top (world y=0), x center 176.
  Scuba's swim-idle dips her fins ~0.48 below the floor line (she floats,
  intentional in the clip), which is why the bottom margin exists.
- Background: **transparent** (straight alpha PNG).
- Lighting: key directional (-32 deg, 20 deg) energy 0.95 + fill (-10 deg,
  -150 deg) energy 0.25 + white ambient 0.38, MSAA 4x.

The camera was fitted by *rendering*, not by bone math: a wide-camera pass
renders every sampled frame and unions the alpha bounding rects. Bone-based
extents are unusable on this rig - Auto-Rig Pro helper bones such as
`head_scale_fix.x` swing up to 7 world units while carrying no visible
mesh most of the time.

## What is in each directory

`frame_00.png .. frame_NN.png`, 6-12 frames per animated clip (2 for the
static poses T_Pose / Scuba_Idle_Pose / Proto5_Still). Loop clips (Idle,
Still) sample `t = i/N * len` so the last frame does not duplicate the
first; one-shots sample `t = i/(N-1) * len` so the final pose is included.
`manifest.json` records per clip: source clip name, frame count, clip
length, sampling mode, effective sampled fps, a bone-motion sanity metric,
and a tight `visible_rect_px` (the union alpha bounds in frame pixels -
useful for trimming or hit boxes). The `.png.import` sidecars are Godot's
own texture imports, generated when the project scanned the new files;
they are what lets the game use the frames directly.

## Things to know about the source clips

- **No textures, no colors.** The FBX contains zero texture references
  (binary scan: no `RelativeFilename`, no image extensions) and every
  material is flat 0.906 grey albedo, roughness 1. The frames are grey
  clay renders with readable shading. If the team wants the INPUTS.md
  colorway (red boots / orange suit / gold bands), it has to come from
  per-surface tints in `bake.gd` (Diver_Lady, Face, Eyes, Mouth,
  DiverMask1, Diver_Tank1 are separate surfaces on Scuba; the two armors
  are single-surface) or from post-processing.
- **proto5_attck2 is extreme cartoon squash-and-stretch**: the body
  elongates into a ~7-unit-tall column for one or two mid-clip frames.
  Fitting that spike would shrink every character to ~130 px, so the
  camera fits everything else (max y 3.21 from proto5_attck1) and the
  stretch peak crops at the top of frame. Flagged in manifest.
- **The clips travel in z only.** Proto5's attacks lunge up to 6.9 units
  toward +Z (at the camera) and its damaged clip knocks back 3.6 units;
  in this orthographic front view that travel is invisible, so no root
  motion cancelation was needed. The camera z (8.405) was pushed out so
  the lunge never crosses the near plane.
- Every animated clip really animates (bone-motion metric > 0 for all 14;
  the three static poses are exactly static). Proto5's clips include
  T-pose-like arm spreads as genuine wind-up frames - checked against
  neighbouring frames, they are part of the choreography.
- Each of the 15 clips exists three times in the file (`rig|X`,
  `rig_001|X`, `rig_002|X` - Blender exported one copy per armature, each
  driving all three skeletons). The bake uses the copy prefixed with the
  character's own rig node. Node map: `rig` = Scuba (Diver_Lady),
  `rig_001` = Prototype1, `rig_002` = Proto5 (Prototype_V).
- Prototype1 has a diamond-shaped ring above the helmet and Proto5 a round
  ring on top; both are real mesh (antenna / carry-handle), not rig junk.
- The "2000 fps" entries in the manifest are the 0.001 s static pose clips
  sampled twice; the number is honest, just meaningless for playback.

## Reproducing / iterating

    godot --path /Users/tomriddle1/salvage tools/bake/bake.tscn --resolution 320x180

Reruns measure again and overwrite `art/baked/`. Helper probes used during
development live in `tools/bake/` (`probe.gd`, `probe2.gd`, `facing.gd`,
`tracks.gd`, `facecheck.gd|tscn`) and run headless except facecheck.
