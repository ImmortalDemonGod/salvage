# D1 for Godot: layout invariants walked over the SCENE TREE.
#
# In the last project this was a canvas-context proxy that had to
# reverse-engineer a display list. Godot's scene tree already IS the
# display list: Control.get_global_rect() hands us every box for free.
# This is bootstrap step 3, built BEFORE content, because retrofitting it
# was the most expensive thing we did last time.
#
# Usage: godot --headless --path ~/salvage --script verify/layout.gd
extends SceneTree

const PAD := 6.0
var frames := 0
var findings: Array = []
var walked := 0

func fail(s: String) -> void:
	if not (s in findings):
		findings.append(s)

var scene: Control
var beat_idx := 0

func _initialize() -> void:
	scene = load("res://game/main.tscn").instantiate()
	root.add_child(scene)

func collect(n: Node, out: Array) -> void:
	# is_visible_in_tree(), not visible: a child Label of a hidden Panel
	# still reports visible == true, so the naive check reported station
	# labels colliding with a scene card while none of them were on screen.
	if n is Control and (n as Control).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		collect(c, out)

# does the label's text actually fit the box it was given?
func text_overflows(l: Label) -> Vector2:
	var fs: int = ThemeDB.fallback_font_size
	var have: Vector2 = l.get_global_rect().size
	# An autowrapping label is not overflowing just because one source line
	# is wider than the box; that is what wrapping is for. Ask the label how
	# many lines it ACTUALLY laid out and check the height only. MEASURE,
	# never assert (standing rule 3).
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		var laid: int = l.get_line_count()
		return Vector2(0.0, float(laid) * float(fs) * 1.35 - have.y)
	var font: Font = ThemeDB.fallback_font
	var widest := 0.0
	var lines: PackedStringArray = l.text.split("\n")
	for line in lines:
		widest = max(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return Vector2(widest, float(lines.size()) * float(fs) * 1.35) - have

func _process(_d: float) -> bool:
	frames += 1
	if frames < 3:   # let layout settle
		return false

	# Walk EVERY beat, not just the first. This checked only the opening
	# scene and reported clean while a diver card visibly overflowed in
	# combat: the run starts on a scene beat, so combat layout was never
	# looked at once.
	check_current()
	force_variants()
	check_current()
	if advance_to_next_beat():
		frames = 0
		return false
	report()
	return true

func advance_to_next_beat() -> bool:
	beat_idx += 1
	var r = scene.run
	if r.finished:
		return false
	# force the current beat complete so the run moves on
	if r.combat != null:
		for lb in range(r.combat.limb_hp.size()):
			r.combat.limb_hp[lb] = 0
			r.combat.limb_broken[lb] = true
		r.combat.outcome = "victory"
	elif r.puzzle != null:
		if not Bots.solve_puzzle(r.puzzle):
			push_error("THE LOCK CANNOT BE SOLVED by the naive policy at stage %d" % r.puzzle.stage)
	if not r.advance():
		return false
	scene.combat = r.combat
	scene.selected = 0
	scene._refresh()
	return true

# Exercise the STATES a string only appears in, not just the beats. The
# "(1 line cut)" suffix overflowed its panel and no check saw it, because
# the walk never produced a turn where a line had been cut.
func force_variants() -> void:
	var r = scene.run
	if r.combat == null:
		return
	r.combat.air_penalty = 1
	for lb in range(r.combat.limb_stun.size()):
		r.combat.limb_stun[lb] = 1
	if r.combat.divers.size() > 0:
		r.combat.divers[0].hp = 0
		r.combat.divers[0].down = true
	scene._refresh()

func check_current() -> void:
	var controls: Array = []
	collect(root, controls)
	var labels: Array = []
	var panels: Array = []
	for c in controls:
		if c is Label: labels.append(c)
		elif c is Panel: panels.append(c)

	# 1. no two labels collide
	for i in range(labels.size()):
		for j in range(i + 1, labels.size()):
			var a: Label = labels[i]
			var b: Label = labels[j]
			var ra: Rect2 = a.get_global_rect()
			var rb: Rect2 = b.get_global_rect()
			if ra.intersects(rb):
				var o: Rect2 = ra.intersection(rb)
				if o.size.x > 2.0 and o.size.y > 2.0:
					fail("LABEL COLLISION: %s over %s by %dx%d" % [a.get_parent().name, b.get_parent().name, int(o.size.x), int(o.size.y)])

	# 2. every label stays inside its owning panel, with padding
	for l in labels:
		var parent: Node = l.get_parent()
		if not (parent is Panel):
			continue
		var rl: Rect2 = l.get_global_rect()
		var rp: Rect2 = (parent as Panel).get_global_rect()
		var gaps := [rl.position.x - rp.position.x, rl.position.y - rp.position.y,
			(rp.position.x + rp.size.x) - (rl.position.x + rl.size.x),
			(rp.position.y + rp.size.y) - (rl.position.y + rl.size.y)]
		var worst: float = gaps[0]
		for g in gaps:
			worst = min(worst, float(g))
		if worst < PAD:
			fail("LABEL CLIPPED: %s sits %.1fpx from its panel edge (needs %.0f)" % [parent.name, worst, PAD])

	# 3. the text actually fits the box it was given
	for l in labels:
		var over: Vector2 = text_overflows(l)
		if over.x > 1.0 or over.y > 1.0:
			fail("TEXT OVERFLOWS: %s needs %dx%d more px for \"%s\"" % [l.get_parent().name, int(max(0.0, over.x)), int(max(0.0, over.y)), l.text.split("\n")[0].substr(0, 40)])

	# 4. station markers never overlap each other: the board must be readable
	for i in range(panels.size()):
		for j in range(i + 1, panels.size()):
			var pa: Panel = panels[i]
			var pb: Panel = panels[j]
			# ANY two visible panels overlapping is a finding, not just two
			# stations. The as-played capture showed the UNDER marker
			# sitting on the help bar while this check passed, because it
			# only ever compared stations to stations.
			var ra2: Rect2 = pa.get_global_rect()
			var rb2: Rect2 = pb.get_global_rect()
			if ra2.intersects(rb2):
				var ov: Rect2 = ra2.intersection(rb2)
				if ov.size.x > 2.0 and ov.size.y > 2.0:
					fail("PANELS OVERLAP: %s and %s by %dx%d" % [pa.name, pb.name, int(ov.size.x), int(ov.size.y)])

	# no diver may be drawn up into the HUD. A sprite is not a Control, so
	# the panel checks above cannot see this: the help line was painted
	# straight through the third diver on the last beat.
	if scene.combat != null:
		for d in scene.combat.divers:
			if d.down:
				continue
			var dr: Rect2 = scene.diver_rect(d)
			if dr.position.y < scene.HUD_BOTTOM:
				fail("DIVER DRAWN INTO THE HUD: %s at %s reaches y=%d, above the HUD floor at %d" % [
					d.dname, Combat.STATION_NAMES[int(d.station)], int(dr.position.y), int(scene.HUD_BOTTOM)])

	# Nothing in the HUD is clickable, so nothing may EAT a click. Godot
	# Controls default to MOUSE_FILTER_STOP, which is how every panel and
	# label in this game silently swallowed every mouse button for the
	# entire run: a playtester clicked to move, nothing happened, and
	# nearly quit over it.
	for c in scene.get_children():
		_no_swallow(c)

	# everything the player is meant to read has to be ON the screen
	if scene.combat != null:
		for st4 in range(5):
			if not scene.combat.station_open(st4):
				continue
			var px: float = scene.place(st4).x
			if px - 160.0 < 0.0 or px + 160.0 > 1280.0:
				fail("OFF THE SCREEN: station %s sits at x=%d, so its tag and bar run past the viewport edge" % [
					Combat.STATION_NAMES[st4], int(px)])

	# nothing may be laid over the lock drawing
	if scene.run != null and scene.run.puzzle != null:
		for p2 in panels:
			if not (p2 as Control).visible:
				continue
			var pr: Rect2 = (p2 as Control).get_global_rect()
			if pr.intersects(scene.LOCK_RECT):
				var ov2: Rect2 = pr.intersection(scene.LOCK_RECT)
				if ov2.size.x > 2.0 and ov2.size.y > 2.0:
					fail("PANEL COVERS THE LOCK: %s sits over the puzzle drawing by %dx%d" % [p2.name, int(ov2.size.x), int(ov2.size.y)])

	walked += controls.size()

func _no_swallow(node: Node) -> void:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		fail("SWALLOWS CLICKS: %s has mouse_filter %d, so a click on it never reaches the game" % [
			node.name, int((node as Control).mouse_filter)])
	for c in node.get_children():
		_no_swallow(c)

func report() -> void:
	print("layout     %d beats walked, %d Controls total" % [beat_idx, walked])
	for f in findings:
		print("FINDING  " + f)
	print("LAYOUT: clean" if findings.is_empty() else "LAYOUT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
