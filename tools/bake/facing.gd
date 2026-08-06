# Ground truth for facing: average world-space normal of the Eyes/Face
# surfaces of the scuba mesh (bind pose). Eyes point where she looks.
# Run: godot --headless --path /Users/tomriddle1/salvage --script tools/bake/facing.gd
extends SceneTree

func _init() -> void:
	var ps: PackedScene = load("res://art/rigs/Main_Team_Rigging.fbx")
	var inst := ps.instantiate()
	var mi := inst.get_node("rig/Skeleton3D/Diver_Full_Gear") as MeshInstance3D
	# accumulated basis: rig(scale100) * Skeleton3D * mesh transform
	var rig := inst.get_node("rig") as Node3D
	var skel := inst.get_node("rig/Skeleton3D") as Node3D
	var xf := rig.transform * skel.transform * mi.transform
	for si in range(mi.mesh.get_surface_count()):
		var mat := mi.mesh.surface_get_material(si)
		var arrays := mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var c := Vector3.ZERO
		var n := Vector3.ZERO
		for v in verts:
			c += xf * v
		for nn in normals:
			n += xf.basis * nn
		c /= verts.size()
		n = n.normalized()
		print("surface %d %-12s centroid=%s avg_normal=%s" % [si, mat.resource_name if mat else "?", c.snapped(Vector3(0.01,0.01,0.01)), n.snapped(Vector3(0.01,0.01,0.01))])
	inst.free()
	quit(0)
