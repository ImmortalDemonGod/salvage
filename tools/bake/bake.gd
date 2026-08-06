# Bakes the Main_Team_Rigging.fbx clips into 2D sprite frames.
#
# Must run NON-headless (a window flashes briefly): headless Godot uses a
# dummy rasteriser and cannot render. Pass 1 seeks every clip and measures
# world-space bone extents (this only works in a running scene tree; a
# --script SceneTree probe cannot animate). Pass 2 derives ONE camera that
# fits every pose of every character, then renders each character/clip/
# frame into an offscreen SubViewport with a transparent background and
# saves PNGs to art/baked/<character_clip>/frame_NN.png.
#
# The characters face -Z, so the camera sits at -Z looking back at them.
#
# Run: godot --path /Users/tomriddle1/salvage tools/bake/bake.tscn --resolution 320x180
extends Node

const OUT_DIR := "res://art/baked"
const FRAME_H := 512
const PAD_TOP := 0.35    # bones -> mesh surface (helmets) headroom, world m
const PAD_BOTTOM := 0.22 # fins/boots below lowest bone
const PAD_SIDE := 0.30

# character key -> rig node name inside the imported scene
const CHARS := {
	"scuba": "rig",
	"prototype1": "rig_001",
	"proto5": "rig_002",
}
# character key -> clips (unprefixed names as authored in Blender)
const CLIPS := {
	"scuba": ["Scuba_Idle1", "Scuba_Idle_Pose", "Scuba_Axe_Kick", "Scuba_Double_Knee", "Scuba_Damaged1", "T_Pose"],
	"prototype1": ["Prototype1_Idle1", "Prototype1_Palm_Strike", "Prototype1_DualPalm", "Prototype1_Damaged", "T_Pose"],
	"proto5": ["Proto5_Idle", "Proto5_Still", "Proto5_Attck1", "Proto5_Attck2", "Proto5_damaged", "T_Pose"],
}

var sub: SubViewport
var cam: Camera3D
var rig_root: Node3D
var ap: AnimationPlayer
var motion: Dictionary = {} # dir_name -> summed max-bone displacement, sanity metric

func _ready() -> void:
	_build_stage()
	_bake.call_deferred()

func _build_stage() -> void:
	sub = SubViewport.new()
	sub.size = Vector2i(FRAME_H, FRAME_H) # width finalised after measuring
	sub.own_world_3d = true
	sub.transparent_bg = true
	sub.msaa_3d = Viewport.MSAA_4X
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)

	var ps: PackedScene = load("res://art/rigs/Main_Team_Rigging.fbx")
	rig_root = ps.instantiate()
	sub.add_child(rig_root)
	ap = rig_root.get_node("AnimationPlayer")

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.05
	cam.far = 50.0
	sub.add_child(cam)
	cam.current = true

	# key light over the camera's shoulder (camera is at +Z: the characters
	# face +Z, confirmed by the Face surface's average normal), soft fill
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32, 20, 0)
	light.light_energy = 0.95
	sub.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -150, 0)
	fill.light_energy = 0.25
	sub.add_child(fill)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.38
	var we := WorldEnvironment.new()
	we.environment = env
	sub.add_child(we)

func _resolve_anim(char_node: String, clip: String) -> StringName:
	# Blender exported every clip once per armature ("rig|X", "rig_001|X",
	# "rig_002|X"); each copy drives all three skeletons. Prefer the copy
	# prefixed with this character's own rig node, else any match.
	var names := ap.get_animation_list()
	var want := char_node + "|" + clip
	for n in names:
		if n == want:
			return n
	for n in names:
		if n == clip or n.ends_with("|" + clip):
			return n
	return &""

func _frame_count(length: float) -> int:
	if length < 0.05:
		return 2 # static pose clip
	return clampi(int(round(length * 6.0)), 6, 12)

func _is_loop(clip: String) -> bool:
	return "Idle" in clip or "Still" in clip

func _sample_times(anim: Animation, n: int, looped: bool) -> Array[float]:
	var out: Array[float] = []
	for i in n:
		var t: float
		if looped:
			t = anim.length * float(i) / float(n)
		else:
			t = anim.length * float(i) / float(max(n - 1, 1))
		out.append(clampf(t, 0.0, maxf(anim.length - 0.002, 0.0)))
	return out

# Only bones that actually deform the mesh (bound in the Skin resource)
# count toward extents: Auto-Rig Pro control/IK bones swing far from the
# body and would inflate the camera to fit empty space.
func _deform_bones(char_key: String) -> PackedInt32Array:
	var skel := rig_root.get_node(String(CHARS[char_key]) + "/Skeleton3D") as Skeleton3D
	var out := PackedInt32Array()
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		var skin: Skin = (mi as MeshInstance3D).skin
		if skin == null:
			continue
		for i in range(skin.get_bind_count()):
			var idx := skel.find_bone(skin.get_bind_name(i))
			if idx >= 0 and not idx in out:
				out.append(idx)
	if out.is_empty():
		for b in range(skel.get_bone_count()):
			out.append(b)
	return out

# Pass 1: seek all clips, accumulate world-space bone extents + a motion
# metric per clip so a dead (never-animating) clip is caught, not shipped.
func _measure() -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for char_key: String in CHARS.keys():
		var skel := rig_root.get_node(String(CHARS[char_key]) + "/Skeleton3D") as Skeleton3D
		var bones := _deform_bones(char_key)
		print("deform bones for %s: %d of %d" % [char_key, bones.size(), skel.get_bone_count()])
		for clip: String in CLIPS[char_key]:
			var anim_name := _resolve_anim(CHARS[char_key], clip)
			if anim_name == &"":
				continue
			var anim := ap.get_animation(anim_name)
			ap.play(anim_name)
			ap.speed_scale = 0.0
			var prev_poses: PackedVector3Array = []
			var moved := 0.0
			var clip_lo := Vector3(INF, INF, INF)
			var clip_hi := Vector3(-INF, -INF, -INF)
			for t in _sample_times(anim, maxi(_frame_count(anim.length), 8), _is_loop(clip)):
				ap.seek(t, true)
				var poses := PackedVector3Array()
				var frame_max_step := 0.0
				for bi in range(bones.size()):
					var gp := skel.global_transform * skel.get_bone_global_pose(bones[bi]).origin
					clip_lo = clip_lo.min(gp)
					clip_hi = clip_hi.max(gp)
					poses.append(gp)
					if prev_poses.size() == bones.size():
						frame_max_step = maxf(frame_max_step, gp.distance_to(prev_poses[bi]))
				moved += frame_max_step
				prev_poses = poses
			ap.stop()
			lo = lo.min(clip_lo)
			hi = hi.max(clip_hi)
			print("  extent %s|%s x[%.2f..%.2f] y[%.2f..%.2f] z[%.2f..%.2f]" % [
				char_key, clip, clip_lo.x, clip_hi.x, clip_lo.y, clip_hi.y, clip_lo.z, clip_hi.z])
			motion[char_key + "_" + _strip_char_prefix(char_key, clip)] = snappedf(moved, 0.001)
	return AABB(lo, hi - lo)

# Pass 2: bone extents overstate the body badly (Auto-Rig Pro helper bones
# like head_scale_fix.x swing 7 world units while the visible mesh stays
# put), so measure what actually RENDERS: wide safety camera, render every
# sampled frame, union the alpha bounding rects, convert to world units.
func _measure_visible(ext: AABB) -> Dictionary:
	var safety_size: float = ext.size.y + 1.0
	sub.size = Vector2i(768, 768)
	cam.size = safety_size
	cam.position = Vector3(0.0, (ext.position.y + ext.end.y) * 0.5, ext.end.z + 1.5)
	cam.rotation_degrees = Vector3(0, 0, 0)
	var w := float(sub.size.x)
	var h := float(sub.size.y)
	var upp := safety_size / h
	var out := {}
	for char_key: String in CHARS.keys():
		for other_key in CHARS:
			(rig_root.get_node(CHARS[other_key]) as Node3D).visible = (other_key == char_key)
		for clip: String in CLIPS[char_key]:
			var anim_name := _resolve_anim(CHARS[char_key], clip)
			if anim_name == &"":
				continue
			var anim := ap.get_animation(anim_name)
			ap.play(anim_name)
			ap.speed_scale = 0.0
			var used := Rect2i()
			var first := true
			for t in _sample_times(anim, _frame_count(anim.length), _is_loop(clip)):
				ap.seek(t, true)
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var r := sub.get_texture().get_image().get_used_rect()
				if r.size.x > 0:
					used = r if first else used.merge(r)
					first = false
			ap.stop()
			# pixels -> world (camera is axis-aligned, KEEP_HEIGHT)
			var x0 := (float(used.position.x) - w * 0.5) * upp
			var x1 := (float(used.end.x) - w * 0.5) * upp
			var y1 := cam.position.y + (h * 0.5 - float(used.position.y)) * upp
			var y0 := cam.position.y + (h * 0.5 - float(used.end.y)) * upp
			var dir_name := char_key + "_" + _strip_char_prefix(char_key, clip)
			out[dir_name] = Rect2(x0, y0, x1 - x0, y1 - y0)
			print("  visible %s x[%.2f..%.2f] y[%.2f..%.2f]" % [dir_name, x0, x1, y0, y1])
	return out

func _bake() -> void:
	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)
	for i in 3:
		await get_tree().process_frame

	var ext := _measure()
	print("MEASURED bone extents: pos=%s size=%s" % [ext.position, ext.size])
	for k in motion:
		print("  motion %s = %.3f" % [k, motion[k]])

	var vis_by_clip: Dictionary = await _measure_visible(ext)
	# One fixed camera fitting every visible pose of every character, with
	# ONE deliberate exception: proto5_attck2's cartoon squash-and-stretch
	# spike (the body elongates to y~7 for a frame or two). Fitting that
	# outlier would shrink every character to ~130px. Its stretch peak is
	# allowed to crop at the top of frame instead; noted in the manifest.
	var vis := Rect2()
	var top := -INF
	var first := true
	for k in vis_by_clip:
		var r: Rect2 = vis_by_clip[k]
		vis = r if first else vis.merge(r)
		first = false
		if k != "proto5_attck2":
			top = maxf(top, r.end.y)
	print("VISIBLE union (world): x[%.3f..%.3f] y[%.3f..%.3f], top w/o attck2 stretch %.3f" % [vis.position.x, vis.end.x, vis.position.y, vis.end.y, top])
	const PAD := 0.12
	var bottom: float = vis.position.y - PAD
	top += PAD
	var cam_size: float = top - bottom
	var half_w: float = maxf(absf(vis.position.x), absf(vis.end.x)) + PAD
	var frame_w: int = clampi(int(ceil(float(FRAME_H) * 2.0 * half_w / cam_size / 16.0)) * 16, 128, 1024)
	sub.size = Vector2i(frame_w, FRAME_H)
	cam.size = cam_size
	# front view: characters face +Z; keep the whole z range in front of
	# the near plane even when a clip lunges toward the camera
	cam.position = Vector3(0.0, (top + bottom) * 0.5, ext.end.z + 1.5)
	cam.rotation_degrees = Vector3(0, 0, 0)
	print("CAMERA size=%.3f center_y=%.3f z=%.2f frame=%dx%d" % [cam_size, cam.position.y, cam.position.z, frame_w, FRAME_H])
	await get_tree().process_frame
	await get_tree().process_frame
	var floor_px := cam.unproject_position(Vector3.ZERO)

	var manifest := {
		"source": "art/rigs/Main_Team_Rigging.fbx",
		"background": "transparent",
		"materials_note": "FBX ships no textures and flat 0.906 grey albedo on every material; frames are grey clay renders with shading only.",
		"pixel_size": [frame_w, FRAME_H],
		"camera": {
			"projection": "orthographic",
			"ortho_size_vertical_world_units": snappedf(cam.size, 0.001),
			"keep_aspect": "height",
			"position": [cam.position.x, snappedf(cam.position.y, 0.001), snappedf(cam.position.z, 0.001)],
			"rotation_degrees": [cam.rotation_degrees.x, cam.rotation_degrees.y, cam.rotation_degrees.z],
			"world_units_per_pixel": snappedf(cam.size / float(FRAME_H), 0.0001),
		},
		"floor_anchor_px": {"x": snappedf(floor_px.x, 0.1), "y": snappedf(floor_px.y, 0.1)},
		"import_fps": 30,
		"clips": {},
	}

	for char_key: String in CHARS.keys():
		for other_key in CHARS:
			(rig_root.get_node(CHARS[other_key]) as Node3D).visible = (other_key == char_key)
		for clip: String in CLIPS[char_key]:
			var anim_name := _resolve_anim(CHARS[char_key], clip)
			if anim_name == &"":
				push_error("clip not found: " + clip)
				continue
			var anim := ap.get_animation(anim_name)
			var n := _frame_count(anim.length)
			var looped := _is_loop(clip)
			var dir_name := char_key + "_" + _strip_char_prefix(char_key, clip)
			var dir_abs := out_abs + "/" + dir_name
			DirAccess.make_dir_recursive_absolute(dir_abs)
			ap.play(anim_name)
			ap.speed_scale = 0.0
			var times := _sample_times(anim, n, looped)
			for i in n:
				ap.seek(times[i], true)
				# two idle frames then wait for the draw to finish, so the
				# captured texture is guaranteed to be this pose
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := sub.get_texture().get_image()
				img.save_png(dir_abs + "/frame_%02d.png" % i)
			ap.stop()
			var entry := {
				"character": char_key,
				"source_clip": String(anim_name),
				"clip_length_s": snappedf(anim.length, 0.001),
				"frame_count": n,
				"sampling": "loop (t=i/N*len)" if looped else "oneshot (t=i/(N-1)*len)",
				"fps_sampled": snappedf(float(n) / maxf(anim.length, 0.001), 0.01),
				"bone_motion_m": motion.get(dir_name, 0.0),
			}
			if vis_by_clip.has(dir_name):
				var r: Rect2 = vis_by_clip[dir_name]
				var upp_f := cam.size / float(FRAME_H)
				var px0 := clampi(int(float(frame_w) * 0.5 + r.position.x / upp_f), 0, frame_w)
				var px1 := clampi(int(ceil(float(frame_w) * 0.5 + r.end.x / upp_f)), 0, frame_w)
				var py0 := clampi(int(float(FRAME_H) * 0.5 - (r.end.y - cam.position.y) / upp_f), 0, FRAME_H)
				var py1 := clampi(int(ceil(float(FRAME_H) * 0.5 - (r.position.y - cam.position.y) / upp_f)), 0, FRAME_H)
				entry["visible_rect_px"] = [px0, py0, px1 - px0, py1 - py0]
				if r.end.y > cam.position.y + cam.size * 0.5:
					entry["note"] = "squash-and-stretch peak extends above the frame and is cropped for a frame or two (deliberate: fitting it would shrink every character to ~130px)"
			manifest["clips"][dir_name] = entry
			print("BAKED %s (%s) %d frames, len %.3f, motion %.3f" % [dir_name, anim_name, n, anim.length, motion.get(dir_name, 0.0)])

	var f := FileAccess.open(out_abs + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "  "))
	f.close()
	print("BAKE DONE -> " + out_abs)
	get_tree().quit(0)
	return

func _strip_char_prefix(char_key: String, clip: String) -> String:
	var lower := clip.to_lower()
	for prefix in [char_key + "_", char_key]:
		if lower.begins_with(prefix):
			lower = lower.substr(prefix.length())
			break
	return lower.trim_prefix("_")
