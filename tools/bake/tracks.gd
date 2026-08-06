# Inspect which tracks carry the big travel in Proto5_Attck2.
# Run: godot --headless --path /Users/tomriddle1/salvage --script tools/bake/tracks.gd
extends SceneTree

func _init() -> void:
	var ps: PackedScene = load("res://art/rigs/Main_Team_Rigging.fbx")
	var inst := ps.instantiate()
	var ap := inst.get_node("AnimationPlayer") as AnimationPlayer
	for anim_name in ["rig_002|Proto5_Attck2", "rig_002|Proto5_damaged", "rig|Scuba_Axe_Kick"]:
		var a := ap.get_animation(anim_name)
		print("=== %s ===" % anim_name)
		for i in range(a.get_track_count()):
			var path := str(a.track_get_path(i))
			var ttype := a.track_get_type(i)
			if not ":" in path:
				print("  NODE-LEVEL track type=%d path=%s keys=%d" % [ttype, path, a.track_get_key_count(i)])
			# position tracks carry travel; rig scale is 100 so world span =
			# track span * 100. Report anything moving > 0.3 world units.
			if ttype == Animation.TYPE_POSITION_3D:
				var lo := Vector3(INF, INF, INF)
				var hi := Vector3(-INF, -INF, -INF)
				for k in range(a.track_get_key_count(i)):
					var v: Vector3 = a.track_get_key_value(i, k)
					lo = lo.min(v)
					hi = hi.max(v)
				var span := hi - lo
				if span.length() * 100.0 > 0.3:
					print("  pos track %s keys=%d world_span=%s" % [
						path, a.track_get_key_count(i), (span * 100.0).snapped(Vector3(0.01,0.01,0.01))])
	inst.free()
	quit(0)
