# Probe materials (albedo color/texture) and animated bone extents per clip.
# Run: godot --headless --path /Users/tomriddle1/salvage --script tools/bake/probe2.gd
extends SceneTree

const CHARS := {"scuba": "rig", "prototype1": "rig_001", "proto5": "rig_002"}
const CLIPS := {
	"scuba": ["Scuba_Idle1", "Scuba_Axe_Kick", "Scuba_Double_Knee", "Scuba_Damaged1"],
	"prototype1": ["Prototype1_Idle1", "Prototype1_Palm_Strike", "Prototype1_DualPalm", "Prototype1_Damaged"],
	"proto5": ["Proto5_Idle", "Proto5_Attck1", "Proto5_Attck2", "Proto5_damaged"],
}

func _init() -> void:
	var ps: PackedScene = load("res://art/rigs/Main_Team_Rigging.fbx")
	var inst := ps.instantiate()
	root.add_child(inst)

	print("=== MATERIALS ===")
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in range(m.mesh.get_surface_count()):
			var mat := m.mesh.surface_get_material(si) as BaseMaterial3D
			if mat:
				print("%s s%d %s albedo=%s tex=%s metal=%.2f rough=%.2f" % [
					m.name, si, mat.resource_name, mat.albedo_color,
					mat.albedo_texture.get_class() if mat.albedo_texture else "NONE",
					mat.metallic, mat.roughness])

	print("=== BONE EXTENTS PER CLIP (world units, camera plane) ===")
	var ap := inst.get_node("AnimationPlayer") as AnimationPlayer
	for char_key: String in CHARS.keys():
		var skel := inst.get_node(String(CHARS[char_key]) + "/Skeleton3D") as Skeleton3D
		var rig_node := inst.get_node(String(CHARS[char_key])) as Node3D
		for clip: String in CLIPS[char_key]:
			var anim_name: StringName = String(CHARS[char_key]) + "|" + clip
			if not ap.has_animation(anim_name):
				print("MISSING " + String(anim_name))
				continue
			var anim := ap.get_animation(anim_name)
			ap.play(anim_name)
			ap.speed_scale = 0.0
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			# variance check: track one hand-ish bone across time
			var probe_bone := skel.get_bone_count() / 2
			var probe_positions: Array[Vector3] = []
			for i in 13:
				var t: float = anim.length * float(i) / 12.0
				ap.seek(clampf(t, 0.0, anim.length - 0.001), true)
				var xf := rig_node.transform * skel.transform
				for b in range(skel.get_bone_count()):
					var gp := xf * skel.get_bone_global_pose(b).origin
					lo = lo.min(gp)
					hi = hi.max(gp)
				probe_positions.append(xf * skel.get_bone_global_pose(probe_bone).origin)
			var moved := 0.0
			for i in range(1, probe_positions.size()):
				moved += probe_positions[i].distance_to(probe_positions[i - 1])
			print("%s|%s  x[%.2f..%.2f] y[%.2f..%.2f] z[%.2f..%.2f] rig_pos=%s bone%d_path=%.3f" % [
				char_key, clip, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, rig_node.position, probe_bone, moved])
			ap.stop()
	inst.free()
	quit(0)
