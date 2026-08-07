extends SceneTree

# The HUD budget. Second playtest: "80% of the screen is nothing but a
# panel." Third: "I legitimately cannot even see the thing I'm supposed
# to be fighting... I can't even see my prototype one character."
# Panels were measured at 47-50% of the canvas by area with only 37.5%
# of screen height clear. The ruling: the creature must be visibly
# unoccluded, so the budget is enforced by instrument, not taste:
#
#   1. visible Controls may cover at most 33% of the design canvas in a
#      fight, sampled on a grid
#   2. a window around the creature's body must contain NO Control
#   3. every visible Control must sit inside the design viewport, which
#      the log row (parked at y=718 of 720, visible only in the gallery's
#      800-tall window) silently was not

const Content = preload("res://content/encounters.gd")

var findings := 0

func fail(msg: String) -> void:
	findings += 1
	print("FINDING  %s" % msg)

func visible_controls(n: Node, out: Array) -> void:
	if n is Control and (n as Control).is_visible_in_tree() and n.name != "root_scene":
		var c := n as Control
		# containers report their children; measure leaf panels and labels
		if c.get_class() in ["Panel", "ColorRect", "Label", "TextureRect"]:
			out.append(c.get_global_rect())
	for ch in n.get_children():
		visible_controls(ch, out)

func _init() -> void:
	var scene = preload("res://game/main.gd").new()
	scene.name = "root_scene"
	scene.size = Vector2(1280, 720)
	root.add_child(scene)
	await process_frame

	for enc_id in ["crab", "spitter", "dredge"]:
		var c := Combat.new(String(enc_id))
		scene.combat = c
		scene.selected = 0
		scene._refresh()
		await process_frame
		var rects: Array = []
		visible_controls(scene, rects)

		# 3. nothing off the design canvas
		for r0 in rects:
			var r: Rect2 = r0
			if r.size.x < 3.0 or r.size.y < 3.0:
				continue
			if r.position.x < -1.0 or r.position.y < -1.0 or r.end.x > 1281.0 or r.end.y > 721.0:
				fail("%s: a Control sticks out of the 1280x720 design canvas at %s" % [enc_id, str(r)])

		# 1. grid coverage
		var cells := 0
		var covered := 0
		for gx in range(64):
			for gy in range(36):
				cells += 1
				var pt := Vector2((float(gx) + 0.5) * 20.0, (float(gy) + 0.5) * 20.0)
				for r1 in rects:
					if (r1 as Rect2).has_point(pt):
						covered += 1
						break
		var pct := 100.0 * float(covered) / float(cells)
		print("hudbudget  %-8s %5.1f%% of the canvas is HUD" % [enc_id, pct])
		if pct > 33.0:
			fail("%s: HUD covers %.1f%% of the fight screen, budget is 33%%" % [enc_id, pct])

		# 2. the creature window: body center, radius 110, must be clear
		var body: Vector2 = scene._body_at()
		var blocked := 0
		for a in range(24):
			for rr in [35.0, 65.0, 100.0]:
				var pt2: Vector2 = body + Vector2.from_angle(TAU * float(a) / 24.0) * float(rr)
				for r2 in rects:
					if (r2 as Rect2).has_point(pt2):
						blocked += 1
						break
		if blocked > 0:
			fail("%s: %d of 72 sample points on the creature's body are under a panel; the creature must be visible" % [enc_id, blocked])

	print("HUDBUDGET: %s" % ("clean" if findings == 0 else "%d finding(s)" % findings))
	quit(1 if findings > 0 else 0)
	return
