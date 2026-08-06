# Headless probe of the imported rig scene: node tree, animations, AABBs.
# Run: godot --headless --path /Users/tomriddle1/salvage --script tools/bake/probe.gd
extends SceneTree

func _init() -> void:
	var ps: PackedScene = load("res://art/rigs/Main_Team_Rigging.fbx")
	if ps == null:
		print("PROBE: FAILED TO LOAD")
		quit(1)
		return
	var inst := ps.instantiate()
	print("=== TREE ===")
	_dump(inst, 0)
	print("=== ANIMS ===")
	_dump_anims(inst)
	print("=== MESH AABBS (local + node transform) ===")
	_dump_meshes(inst)
	inst.free()
	quit(0)
	return

func _dump(n: Node, d: int) -> void:
	var info := "%s%s : %s" % ["  ".repeat(d), n.name, n.get_class()]
	if n is Node3D:
		var t := (n as Node3D).transform
		info += "  pos=%s scale=%s" % [t.origin, (n as Node3D).scale]
	if n is Skeleton3D:
		info += "  bones=%d" % (n as Skeleton3D).get_bone_count()
	print(info)
	if d < 3:
		for c in n.get_children():
			_dump(c, d + 1)
	elif n.get_child_count() > 0:
		print("%s  ... %d children" % ["  ".repeat(d), n.get_child_count()])

func _dump_anims(root: Node) -> void:
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		print("AnimationPlayer at %s" % root.get_path_to(ap))
		for anim_name in (ap as AnimationPlayer).get_animation_list():
			var a: Animation = (ap as AnimationPlayer).get_animation(anim_name)
			print("  %s  len=%.3f  tracks=%d" % [anim_name, a.length, a.get_track_count()])
			# which skeletons does it touch? sample a few track paths
			var paths := {}
			for i in range(a.get_track_count()):
				var p := str(a.track_get_path(i))
				var head := p.split(":")[0]
				paths[head] = paths.get(head, 0) + 1
			for k in paths:
				print("      -> %s (%d tracks)" % [k, paths[k]])

func _dump_meshes(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var aabb := m.get_aabb()
		var gt := m.global_transform if m.is_inside_tree() else _acc_transform(m)
		var world_aabb := gt * aabb
		print("%s  aabb_local=%s  world=%s" % [root.get_path_to(m), aabb, world_aabb])
		if m.mesh:
			for si in range(m.mesh.get_surface_count()):
				var mat := m.mesh.surface_get_material(si)
				print("    surface %d mat=%s" % [si, mat.resource_name if mat else "null"])

func _acc_transform(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
