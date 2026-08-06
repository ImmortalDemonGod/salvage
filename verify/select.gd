extends SceneTree
# a downed diver must never stay selected while another can act
func _init() -> void:
	var scene = preload("res://game/main.gd").new()
	scene.size = Vector2(1280, 800)
	root.add_child(scene)
	await process_frame
	scene.run.advance(); scene.combat = scene.run.combat
	for lb in range(scene.combat.limb_hp.size()):
		scene.combat.limb_hp[lb] = 0; scene.combat.limb_broken[lb] = true
	scene.combat.outcome = "victory"
	scene._after()
	await process_frame
	if scene.combat.divers.size() < 2:
		print("SELECT: skipped, this beat runs one diver")
		quit(0)
		return
	scene.selected = 0
	scene.combat.divers[0].down = true
	scene._refresh()
	var ok: bool = not scene.combat.divers[scene.selected].down
	print("SELECT: selected=%d down=%s  %s" % [scene.selected, scene.combat.divers[scene.selected].down,
		"the game hands you a diver who can act" if ok else "FINDING -- still holding a downed diver"])
	quit(0 if ok else 1)
	return
