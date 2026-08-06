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

func fail(s: String) -> void:
	if not (s in findings):
		findings.append(s)

func _initialize() -> void:
	root.add_child(load("res://game/main.tscn").instantiate())

func collect(n: Node, out: Array) -> void:
	if n is Control and (n as Control).visible:
		out.append(n)
	for c in n.get_children():
		collect(c, out)

# does the label's text actually fit the box it was given?
func text_overflows(l: Label) -> Vector2:
	var font: Font = ThemeDB.fallback_font
	var fs: int = ThemeDB.fallback_font_size
	var widest := 0.0
	var lines: PackedStringArray = l.text.split("\n")
	for line in lines:
		widest = max(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var needed := Vector2(widest, float(lines.size()) * float(fs) * 1.35)
	var have: Vector2 = l.get_global_rect().size
	return needed - have

func _process(_d: float) -> bool:
	frames += 1
	if frames < 3:   # let layout settle
		return false

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
			if not (String(pa.name).begins_with("station_") and String(pb.name).begins_with("station_")):
				continue
			if pa.get_global_rect().intersects(pb.get_global_rect()):
				fail("STATIONS OVERLAP: %s and %s" % [pa.name, pb.name])

	print("layout     %d Controls walked (%d labels, %d panels)" % [controls.size(), labels.size(), panels.size()])
	for f in findings:
		print("FINDING  " + f)
	print("LAYOUT: clean" if findings.is_empty() else "LAYOUT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
