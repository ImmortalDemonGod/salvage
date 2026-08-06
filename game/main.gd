# Presentation. Reads sim state, never owns it. Every UI element is a
# Control so `get_global_rect()` hands the layout invariants a box for
# free (SPEC 4.3). Built in code rather than a .tscn so the layout is
# deterministic and walkable headless before any content exists.
extends Control

const Art := preload("res://game/art.gd")
const Fx := preload("res://game/fx.gd")
const Run := preload("res://sim/run.gd")
const Beats := preload("res://content/beats.gd")
const Sfx := preload("res://game/sfx.gd")

const DESIGN := Vector2(1280, 720)

# Station screen positions, side-on 2.5D: the crab faces left, divers
# approach from the left. UNDER is deliberately reachable and offensively
# empty (SPEC 2.6).
# Stations sit ON the limb they expose. These were placed before the art
# existed and did not land on anything; the first as-played capture showed
# FLANK floating over empty shell while the claw was elsewhere, which
# silently breaks the "the limb IS the position" contract (SPEC 2.3).
# Fallback only. The real positions come from the ENCOUNTER, because a
# second hardcoded list in the scene is exactly the "two lists that agree"
# failure the station-limb contract exists to prevent, and it made the vent
# worm and the dredge stand on crab anatomy.
const STATION_POS := [
	Vector2(700, 386),   # FRONT  - the jaw
	Vector2(752, 300),   # FLANK  - the raised claw, which the art puts forward
	Vector2(880, 470),   # UNDER  - the soft belly, no limb
	Vector2(1046, 328),  # REAR   - the tail
	Vector2(300, 386),   # BACKLINE - out of reach
]
const CRAB_POS := Vector2(878, 316)
const CRAB_SCALE := 124.0

var run: Run
var combat: Combat
var selected := 0
var ui_stations: Array = []
var ui_divers: Array = []
var ui_air: Label
var ui_log: Label
var ui_intent: Label
var ui_help: Label
var ui_scene: Label
var ui_legend: Label
var ui_goal: Label
var refusal := ""
var sfx: Node
var _log_at := 0

func _ready() -> void:
	run = Run.new()
	combat = run.combat
	sfx = Sfx.new()
	add_child(sfx)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()

# where this encounter puts a station, falling back to the default ring
# The board sits under the HUD, and a sprite is not a Control, so nothing
# was stopping one being drawn through the help line. A reviewer looking at
# the last beat put it exactly: the words "ENTER end t" were painted on top
# of Proto5's chest, and it read as HUD chrome rather than a unit on the
# board. Declared here so verify/layout.gd can check it.
const HUD_BOTTOM := 196.0
const DIVER_SCALE := 66.0
const DIVER_SEAT := 20.0          # how far below the ring centre the feet sit
const CARD_TOP := 522.0
const BOARD_LIFT := Vector2(0, 0)

# Where this diver's feet go. Divers used to be offset by their index in the
# whole party -- `-22 + i * 36` -- so the third diver was pushed 50px right
# of its ring even when standing there alone, which is how Proto5 ended up
# balanced on the rim of the FLANK circle with the circle itself empty.
# Spread by position AMONG THE DIVERS SHARING THAT STATION instead.
func diver_foot(d) -> Vector2:
	var here: Array = []
	for o in combat.divers:
		if not o.down and int(o.station) == int(d.station):
			here.append(int(o.id))
	var at: int = here.find(int(d.id))
	var spread: float = 34.0
	var off: float = (float(at) - (float(here.size()) - 1.0) * 0.5) * spread
	return place(int(d.station)) + Vector2(off, DIVER_SEAT)

# the box a diver sprite occupies, so the drawing and the check agree
func diver_rect(d) -> Rect2:
	var f: Vector2 = diver_foot(d)
	return Rect2(f + Vector2(-DIVER_SCALE * 0.5, -DIVER_SCALE), Vector2(DIVER_SCALE, DIVER_SCALE))
# the area _draw_lock() paints, declared so verify/layout.gd can hold the
# Controls off it. A drawing is not a Control, so nothing was stopping a
# panel from being laid straight over the puzzle.
const LOCK_RECT := Rect2(280, 268, 700, 320)
const LOCK_TOP := 322.0
const LOCK_TALL := 168.0
const LOCK_DROP := 84.0   # valves sit this far under the tank
const SCENE_PANEL_AT := Vector2(190, 220)
const SCENE_PANEL_SIZE := Vector2(900, 262)

func place(i: int) -> Vector2:
	if combat != null:
		var places: Dictionary = combat.enc.get("places", {})
		var key := str(i)
		if places.has(key):
			var xy: Array = places[key]
			return Vector2(float(xy[0]), float(xy[1])) + BOARD_LIFT
	return STATION_POS[i] + BOARD_LIFT

func _build_ui() -> void:
	# station markers: one Control each, so the invariants can assert they
	# never overlap and their labels stay inside them
	for i in range(5):
		var m := Panel.new()
		m.name = "station_" + Combat.STATION_NAMES[i]
		m.size = Vector2(232, 66)
		m.position = Vector2.ZERO   # placed per encounter in _refresh
		add_child(m)
		var l := Label.new()
		l.name = "label"
		l.text = Combat.STATION_NAMES[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_left = 12; l.offset_right = -12
		l.offset_top = 10; l.offset_bottom = -10
		m.add_child(l)
		ui_stations.append(m)

	# diver cards along the bottom
	for i in range(3):
		var p := Panel.new()
		p.name = "diver_card_" + str(i)
		p.size = Vector2(392, 190)
		p.position = Vector2(24 + i * 406, CARD_TOP)
		add_child(p)
		var l := Label.new()
		l.name = "label"
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_left = 14; l.offset_right = -14
		l.offset_top = 8; l.offset_bottom = -8
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(l)
		ui_divers.append(p)

	var air_panel := Panel.new()
	air_panel.name = "air_panel"
	air_panel.size = Vector2(340, 76)
	air_panel.position = Vector2(30, 24)
	add_child(air_panel)
	ui_air = Label.new()
	ui_air.name = "label"
	ui_air.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_air.offset_left = 10; ui_air.offset_right = -10
	ui_air.offset_top = 6; ui_air.offset_bottom = -6
	air_panel.add_child(ui_air)

	var tel := Panel.new()
	tel.name = "telegraph_panel"
	tel.size = Vector2(856, 76)
	tel.position = Vector2(392, 24)
	add_child(tel)
	ui_intent = Label.new()
	ui_intent.name = "label"
	ui_intent.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_intent.offset_left = 12; ui_intent.offset_right = -12
	ui_intent.offset_top = 6; ui_intent.offset_bottom = -6
	tel.add_child(ui_intent)

	# built BEFORE the first _refresh, which runs on the opening scene beat
	var scene_panel := Panel.new()
	scene_panel.name = "scene_panel"
	scene_panel.size = SCENE_PANEL_SIZE
	scene_panel.position = SCENE_PANEL_AT
	add_child(scene_panel)
	ui_scene = Label.new()
	ui_scene.name = "label"
	ui_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_scene.offset_left = 28; ui_scene.offset_right = -28
	ui_scene.offset_top = 24; ui_scene.offset_bottom = -24
	ui_scene.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_panel.add_child(ui_scene)

	var legend_panel := Panel.new()
	legend_panel.name = "legend_panel"
	legend_panel.size = Vector2(640, 42)
	legend_panel.position = Vector2(30, 116)
	add_child(legend_panel)
	ui_legend = Label.new()
	ui_legend.name = "label"
	ui_legend.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_legend.offset_left = 14; ui_legend.offset_right = -14
	ui_legend.offset_top = 11; ui_legend.offset_bottom = -11
	legend_panel.add_child(ui_legend)

	var goal_panel := Panel.new()
	goal_panel.name = "goal_panel"
	goal_panel.size = Vector2(430, 42)
	goal_panel.position = Vector2(700, 116)
	add_child(goal_panel)
	ui_goal = Label.new()
	ui_goal.name = "label"
	ui_goal.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_goal.offset_left = 14; ui_goal.offset_right = -14
	ui_goal.offset_top = 11; ui_goal.offset_bottom = -11
	goal_panel.add_child(ui_goal)

	var help_panel := Panel.new()
	help_panel.name = "help_panel"
	help_panel.size = Vector2(1220, 40)
	help_panel.position = Vector2(30, 166)
	add_child(help_panel)
	var log_panel := Panel.new()
	log_panel.name = "log_panel"
	log_panel.size = Vector2(1232, 68)
	log_panel.position = Vector2(24, 718)
	var lst := StyleBoxFlat.new()
	lst.bg_color = Color(0.03, 0.09, 0.14, 0.92)
	lst.border_color = Color(0.34, 0.52, 0.62, 0.85)
	lst.set_border_width_all(1)
	lst.set_corner_radius_all(3)
	log_panel.add_theme_stylebox_override("panel", lst)
	add_child(log_panel)
	ui_log = Label.new()
	ui_log.name = "label"
	ui_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_log.offset_left = 12; ui_log.offset_right = -12
	ui_log.offset_top = 8; ui_log.offset_bottom = -8
	ui_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_panel.add_child(ui_log)
	ui_help = Label.new()
	ui_help.name = "label"
	ui_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_help.offset_left = 12; ui_help.offset_right = -12
	ui_help.offset_top = 7; ui_help.offset_bottom = -7
	help_panel.add_child(ui_help)

# Selecting a diver who is not on this dive left NOBODY selected: the party
# is content and changes per beat, so the index has to be clamped to it.
func _select(i: int) -> void:
	if combat == null:
		return
	selected = clampi(i, 0, combat.divers.size() - 1)

# Classification is not wiring: the log has to actually reach the voice.
# The last project's audio was fully dead in the played game while its
# tests were green, because the test asserted the disconnected side.
func _recent() -> void:
	if ui_log == null:
		return
	var src: Array = []
	if combat == null and run.puzzle == null:
		for l in run.log_lines:
			src.append(l)
	if combat != null:
		for l in combat.log_lines:
			src.append(l)
	elif run.puzzle != null:
		for l in run.puzzle.log_lines:
			src.append(l)
	var keep: Array = []
	for i in range(max(0, src.size() - 2), src.size()):
		keep.append(String(src[i]))
	# on a story beat the scene panel IS the content, and the log would sit
	# on top of it
	ui_log.get_parent().visible = not keep.is_empty() and (combat != null or run.puzzle != null)
	ui_log.text = "\n".join(keep)

func _voice() -> void:
	# motion first, off the SAME lines and the SAME classifier the audio
	# uses, so a thing you hear is a thing you see
	if combat != null:
		_motion(combat.log_lines, _log_at)
	if sfx == null:
		return
	if combat != null:
		_log_at = sfx.drain(combat.log_lines, _log_at)
	elif run.puzzle != null:
		_log_at = sfx.drain(run.puzzle.log_lines, _log_at)

# --- turning the sim's own sentences into motion ------------------------
func _diver_named(line: String) -> int:
	for d in combat.divers:
		if line.find(String(d.dname)) >= 0:
			return int(d.id)
	return -1

func _limb_named(line: String) -> int:
	for i in range(combat.LIMB_NAMES.size()):
		if line.find(String(combat.LIMB_NAMES[i])) >= 0:
			return i
	return -1

func _limb_at(idx: int) -> Vector2:
	for st in range(5):
		if int(combat.STATION_LIMB[st]) == idx:
			return place(st)
	return Vector2(DESIGN.x * 0.72, DESIGN.y * 0.45)

func _amount(line: String) -> int:
	var at := line.rfind(" for ")
	if at < 0:
		return 0
	return int(line.substr(at + 5).strip_edges())

const HURT := Color(0.95, 0.42, 0.32)
const DEALT := Color(0.96, 0.93, 0.80)

func _motion(lines: Array, from: int) -> void:
	for i in range(from, lines.size()):
		var line := String(lines[i])
		var ev: int = SfxEvents.classify(line)
		var who := _diver_named(line)
		var lb := _limb_named(line)
		var n := _amount(line)
		match ev:
			SfxEvents.Kind.HIT:
				# a diver struck a limb: move like the ability it was
				if who >= 0 and lb >= 0:
					var a: Vector2 = diver_foot(combat.divers[who])
					var tgt: Vector2 = _limb_at(lb)
					var kind := ""
					for ab in combat.divers[who].kit:
						if line.find(String(ab.name)) >= 0:
							kind = String(ab.kind)
					match kind:
						"hit_and_step":
							# it hits and then moves: a long committed lunge
							fx.add("lunge", 0.52, a, tgt, "", DEALT, who)
						"hit_wide":
							# it spills onto the neighbours, so ring them too
							fx.add("lunge", 0.30, a, tgt, "", DEALT, who)
							for st2 in combat.neighbours(int(combat.divers[who].station)):
								var lb2: int = combat.STATION_LIMB[int(st2)]
								if lb2 >= 0:
									fx.add("flash", 0.40, place(int(st2)), Vector2.ZERO, "", DEALT, -1, lb2)
						"shut":
							# no swing: a held press, and the limb rings shut
							fx.add("press", 0.44, a, tgt, "", Color(0.55, 0.78, 0.95), who)
							fx.add("ring", 0.52, tgt, Vector2.ZERO, "", Color(0.55, 0.78, 0.95), -1, lb)
						_:
							fx.add("lunge", 0.30, a, tgt, "", DEALT, who)
					fx.add("flash", 0.36, tgt, Vector2.ZERO, "", DEALT, -1, lb)
					if n > 0:
						fx.add("float", 0.95, tgt + Vector2(0, -30), Vector2.ZERO, "-%d" % n, DEALT)
					fx.kick(0.10 + 0.02 * n)
			SfxEvents.Kind.TAKE:
				# the enemy reached a station. THIS is the one that read as
				# nothing last time, so it gets the bolt, the recoil and the
				# shake rather than a number appearing somewhere.
				if who >= 0:
					var d = combat.divers[who]
					var src: Vector2 = _limb_at(lb) if lb >= 0 else Vector2(DESIGN.x * 0.8, DESIGN.y * 0.4)
					var dst: Vector2 = diver_foot(d)
					fx.add("body", 0.36, src, dst, "", HURT)
					fx.add("bolt", 0.28, src, dst, "", HURT)
					fx.add("recoil", 0.42, src, dst, "", HURT, who)
					fx.add("float", 1.05, dst + Vector2(0, -70), Vector2.ZERO, "-%d" % n, HURT)
					fx.kick(0.22 + 0.03 * n)
			SfxEvents.Kind.BREAK:
				if lb >= 0:
					fx.add("burst", 0.55, _limb_at(lb), Vector2.ZERO, "BROKEN", DEALT, -1, lb)
					fx.kick(0.5)
			SfxEvents.Kind.SHUTDOWN:
				if lb >= 0:
					fx.add("ring", 0.5, _limb_at(lb), Vector2.ZERO, "SHUT DOWN", Color(0.55, 0.78, 0.95), -1, lb)
			SfxEvents.Kind.CUT:
				fx.add("float", 1.2, Vector2(DESIGN.x * 0.30, DESIGN.y * 0.42), Vector2.ZERO, "AIR LINE CUT", HURT)
				fx.kick(0.35)
			SfxEvents.Kind.DOWN:
				if who >= 0:
					fx.add("float", 1.3, diver_foot(combat.divers[who]) + Vector2(0, -70), Vector2.ZERO, "DOWN", HURT)
					fx.kick(0.45)

# Report the current beat in the window title. On the web export this is
# document.title, so the capture driver can read where the replay actually
# ended up instead of trusting the key sequence to have landed.
var _title_ticks := 0
var _clock := 0.0
var fx := Fx.new()

func _process(dt: float) -> void:
	if _title_ticks < 120:
		_title_ticks += 1
		_stamp_title()
	_clock += dt
	fx.tick(dt)
	if _hold > 0.0:
		_hold -= dt
		if _hold <= 0.0:
			_won = ""
	# the board breathes even when nothing is happening, so a turn spent
	# thinking is not a still image
	queue_redraw()

func _stamp_title() -> void:
	var b: Dictionary = run.current()
	DisplayServer.window_set_title("SALVAGE beat=%s" % String(b.get("id", "?")))

func _draw_ending() -> void:
	var f: Font = ThemeDB.fallback_font
	var w: Vector2 = size.max(DESIGN)
	draw_rect(Rect2(Vector2.ZERO, w), Color(0.02, 0.05, 0.09, 0.86))
	var cx: float = w.x * 0.5 - 250.0
	var y: float = w.y * 0.30
	var lost := int(run.salvage_lost)
	var head := "THE PUMP TURNS OVER" if lost == 0 else "THE PUMP TURNS OVER, BARELY"
	draw_string(f, Vector2(cx, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.86, 0.93, 0.96))
	draw_string(f, Vector2(cx, y + 46), "placeholder copy, for Marc",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.55, 0.64, 0.70))
	var rows: Array = [
		"beats cleared        %d of %d" % [Beats.LADDER.size(), Beats.LADDER.size()],
		"salvage lost         %d" % lost,
		"the squad came back  %s" % ("whole" if lost == 0 else "lighter than it went down"),
	]
	for i in range(rows.size()):
		draw_string(f, Vector2(cx, y + 108 + 34 * float(i)), String(rows[i]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.78, 0.86, 0.90))
	draw_string(f, Vector2(cx, y + 232), "SALVAGE   a Team Ratateam prototype",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.66, 0.78, 0.84))
	draw_string(f, Vector2(cx, y + 262), "art Glass_Goat   ·   words Marc   ·   placeholder art and copy throughout",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.55, 0.64, 0.70))

func _refresh() -> void:
	_stamp_title()
	_voice()
	_recent()
	if sfx != null:
		var mood := "scene"
		if run.puzzle != null: mood = "puzzle"
		elif combat != null: mood = "deep" if _depth() > 0.72 else "combat"
		sfx.set_mood(mood, _depth())
	ui_intent.get_parent().visible = true
	var hp4: Control = ui_help.get_parent()
	hp4.position = Vector2(30, 166)
	hp4.size = Vector2(1220, 40)
	var scene_p: Control = ui_scene.get_parent()
	if run.puzzle != null:
		scene_p.position = Vector2(190, 596)
		scene_p.size = Vector2(900, 108)
	else:
		scene_p.position = SCENE_PANEL_AT
		scene_p.size = SCENE_PANEL_SIZE
	if run.puzzle != null:
		# The lock, drawn as its own state: a water line and three valves.
		ui_air.get_parent().visible = false
		ui_legend.get_parent().visible = false
		ui_goal.get_parent().visible = false
		ui_intent.get_parent().visible = false
		ui_intent.text = run.state_line()
		for card in ui_divers:
			card.visible = false
		for i in range(ui_stations.size()):
			ui_stations[i].visible = false
		ui_scene.get_parent().visible = true
		# the goal has to be the goal of THIS lock. Lock 2 has two chambers
		# and stage 1's line ("fill the chamber") describes neither of them.
		var want := ""
		if run.puzzle.solved():
			want = "the way out is open"
		elif run.puzzle.stage == 2:
			want = "The way out sits above chamber A. Fill A, keep B dry."
		else:
			want = "The way out is above the waterline. Fill the chamber to the top."
		ui_scene.text = want
		var vk := ["1", "2", "3", "4"]
		var labels: Array = []
		for i in range(run.puzzle.valves()):
			labels.append("%s=%s" % [vk[i], "crossover" if (run.puzzle.stage == 2 and i == run.puzzle.CROSS) else "valve %d" % (i + 1)])
		ui_help.text = "turn a valve: " + "  ".join(labels) + "  ·  ENTER when the way is open"
		queue_redraw()
		return
	if combat == null:
		# A scene beat. The opening is a mechanic and gets rendered as one:
		# who you are, what stands in the way, what you want, and what the
		# buttons do (SPEC 3.3).
		ui_air.get_parent().visible = false
		ui_legend.get_parent().visible = false
		ui_goal.get_parent().visible = false
		ui_intent.text = run.state_line()
		for card in ui_divers:
			card.visible = false
		for i in range(ui_stations.size()):
			ui_stations[i].visible = false
		var b: Dictionary = run.current()
		var lines: Array = b.get("lines", [])
		var body: Array = []
		var controls := "ENTER to continue"
		for l in lines:
			if String(l.role) == "controls":
				controls = String(l.text)
			else:
				body.append(String(l.text).replace("(placeholder) ", ""))
		var marked := false
		for l2 in lines:
			if String(l2.get("text", "")).begins_with("(placeholder)"):
				marked = true
		ui_intent.get_parent().visible = false
		var sp3: Control = ui_scene.get_parent()
		sp3.position = Vector2(220, 392)
		sp3.size = Vector2(840, 262)
		var hp3: Control = ui_help.get_parent()
		hp3.position = Vector2(220, 668)
		hp3.size = Vector2(840, 40)
		ui_scene.text = "\n\n".join(body)
		if marked:
			ui_scene.text += "\n\n                                                          placeholder · Marc"
		ui_scene.get_parent().visible = body.size() > 0
		ui_help.text = controls
		queue_redraw()
		return
	ui_scene.get_parent().visible = false
	ui_air.get_parent().visible = true
	ui_legend.get_parent().visible = true
	ui_goal.get_parent().visible = true
	ui_legend.text = "red ring = an attack lands here this turn   ·   blue = nothing does"
	ui_legend.get_parent().visible = run.beat <= 2
	var keys2 := ["Q", "W", "E", "R", "T"]
	for i in range(ui_stations.size()):
		ui_stations[i].visible = combat.station_open(i)
		if not combat.station_open(i):
			continue
		var mk: Panel = ui_stations[i]
		# UNDER used to sit at y=470, which left no room for its own label
		# above the card row. Lifting the whole board to dodge that pushed
		# the FLANK sprite up into the HUD instead, so the station moved
		# rather than everything else.
		mk.position = place(i) - mk.size * 0.5 + Vector2(0, 56)
		# The limb IS the position, so the marker has to SAY the limb and
		# how much of it is left. A blind reviewer found no enemy health
		# readout anywhere on screen, which made the whole limb system
		# invisible.
		var lb: int = combat.STATION_LIMB[i]
		var lbl: Label = ui_stations[i].get_node("label")
		if lb < 0:
			var reach := "nothing to hit here"
			for dr in combat.divers:
				if not dr.down and int(dr.station) == i and combat.can_attack(dr):
					reach = "reaches from here"
			lbl.text = "%s  [%s]%s\n%s" % [Combat.STATION_NAMES[i], String(keys2[i]), here_free(i), reach]
		elif combat.limb_broken[lb]:
			lbl.text = "%s  [%s]%s\n%s BROKEN" % [Combat.STATION_NAMES[i], String(keys2[i]), here_free(i), String(combat.LIMB_NAMES[lb]).to_upper()]
		else:
			var stun := "  SHUT" if int(combat.limb_stun[lb]) > 0 else ""
			lbl.text = "%s  [%s]%s%s" % [Combat.STATION_NAMES[i], String(keys2[i]), stun, here_free(i)]
	# A cut line must READ as a cut line. This showed "AIR 3 / 3" after the
	# umbilical rule fired, so the pool and its ceiling shrank together and
	# the player could not tell anything had been taken from them.
	if combat.air_penalty > 0:
		ui_air.text = "AIR  %d of %d left this turn\na swing hit nobody: %d line cut" % [combat.air, Combat.AIR_PER_TURN, combat.air_penalty]
	else:
		ui_air.text = "AIR  %d of %d left this turn\none shared pool, no banking" % [combat.air, combat.air_this_turn()]
	var live := 0
	for lb in range(combat.limb_broken.size()):
		if not combat.limb_broken[lb]:
			live += 1
	ui_goal.text = "break every limb to win   ·   %d of %d still working" % [live, combat.limb_broken.size()]
	var all_it: Array = combat.intents()
	if all_it.is_empty():
		ui_intent.text = "%s   spent" % run.state_line()
	else:
		var parts: Array = []
		for it in all_it:
			var where: Array = []
			for st in it.stations:
				where.append(Combat.STATION_NAMES[st])
			var shut: bool = int(combat.limb_stun[int(it.limb)]) > 0
			parts.append("%s %s %s for %d%s" % [String(combat.LIMB_NAMES[int(it.limb)]), it.name, "/".join(where), int(it.dmg), "  (SHUT)" if shut else ""])
		ui_intent.text = "%s   NEXT: %s" % [run.state_line(), "   ".join(parts)]
	# the party size is content, not a constant: fight one runs two divers.
	# This loop assumed three and printed a raw format string on the third
	# card, which the as-played capture caught on its first frame.
	var live_cards := 0
	for d0 in combat.divers:
		live_cards += 1
	var span: float = float(live_cards) * 392.0 + float(max(0, live_cards - 1)) * 14.0
	var left: float = (DESIGN.x - span) * 0.5
	for i in range(ui_divers.size()):
		if i < live_cards:
			ui_divers[i].position = Vector2(left + float(i) * 406.0, CARD_TOP)
		var card: Panel = ui_divers[i]
		if i >= combat.divers.size():
			card.visible = false
			continue
		card.visible = true
		var d = combat.divers[i]
		var mark := ">" if i == selected else " "
		var state := "DOWN, out for this fight, back at the boat" if d.down else "at %s   %d/%d HP" % [Combat.STATION_NAMES[d.station], d.hp, d.max_hp]
		var afford := "" if combat.air >= d.cost else "   cannot afford"
		var lines: Array = []
		for slot in range(d.kit.size()):
			var ab: Dictionary = d.kit[slot]
			var key := "SPACE" if slot == 0 else "F"
			var what := ""
			match String(ab.kind):
				"hit": what = "%d dmg" % int(ab.dmg)
				"hit_and_step": what = "%d dmg, then move free" % int(ab.dmg)
				"hit_wide": what = "%d dmg here and either side" % int(ab.dmg)
				"shut": what = ("%d dmg, " % int(ab.dmg) if int(ab.dmg) > 0 else "no damage, ") + "the limb cannot attack for %d turn%s" % [int(ab.get("turns", 1)), "" if int(ab.get("turns", 1)) == 1 else "s"]
			lines.append("%s %s: %s" % [key, String(ab.name), what])
		# the target once, at the top, instead of on every ability line
		var onto := ""
		if not combat.can_attack(d):
			onto = "  ·  nothing to hit from %s" % Combat.STATION_NAMES[int(d.station)]
		else:
			var tl: int = combat.target_limb(d)
			if tl >= 0:
				onto = "  ·  hits %s %d/%d" % [String(combat.LIMB_NAMES[tl]).to_upper(),
					int(combat.limb_hp[tl]), int((combat.enc.limbs[tl] as Dictionary).hp)]
		card.get_node("label").text = "%s%d %s  %d air per ability%s\n%s%s\n%s" % [mark, i + 1, d.dname, d.cost, afford, state, onto, "\n".join(lines)]
	ui_help.text = (refusal + "        ") if refusal != "" else ""
	var keys := ["Q", "W", "E", "R", "T"]
	var moves: Array = []
	for i in range(5):
		if combat.station_open(i):
			moves.append("%s=%s" % [keys[i], Combat.STATION_NAMES[i]])
	var pick := "1 diver" if combat.divers.size() == 1 else "1-%d pick a diver" % combat.divers.size()
	var widest := 0
	for d0 in combat.divers:
		widest = max(widest, int(d0.kit.size()))
	var use := "SPACE use an ability" if widest < 2 else "SPACE / F use an ability"
	# It has to fit on one line, so it says the short true thing. The cards
	# already name each ability and its key; this line is the map of verbs.
	var mkeys: Array = []
	for i in range(5):
		if combat.station_open(i):
			mkeys.append(String(keys[i]))
	ui_help.text += "click to move, click again to attack  ·  %s  ·  the key on a station moves there (1 air)  ·  %s  ·  ENTER end turn" % [pick, use]
	queue_redraw()

# ---- the player's door. The bot calls these same Combat methods. -------
# A refused input must say WHY. Silence is how a player concludes the game
# is broken rather than that they cannot afford the action.
# Half the kit was unreachable: six abilities existed in the sim and the
# bots used all six, while the player had one key. A blind reviewer put it
# plainly: "there is nothing on screen indicating a second or alternate
# attack for either character."
func player_ability(slot: int) -> bool:
	var ok := combat.act_ability(selected, slot)
	if ok:
		refusal = ""
		_after()
	else:
		var d = combat.divers[selected]
		if slot >= d.kit.size(): refusal = "%s has no second ability" % d.dname
		elif d.down: refusal = "%s is down" % d.dname
		elif combat.air < d.cost: refusal = "not enough air: %s needs %d, you have %d" % [d.dname, d.cost, combat.air]
		elif not combat.can_attack(d): refusal = "nothing to hit from %s" % Combat.STATION_NAMES[d.station]
		else: refusal = "that action is not available"
		_refresh()
	return ok

func _dead_player_attack() -> bool:
	var ok := combat.act_attack(selected)
	if ok:
		refusal = ""
		_after()
	else:
		var d = combat.divers[selected]
		if d.down: refusal = "%s is down" % d.dname
		elif combat.air < d.cost: refusal = "not enough air: %s needs %d, you have %d" % [d.dname, d.cost, combat.air]
		elif not combat.can_attack(d): refusal = "nothing to hit from %s" % Combat.STATION_NAMES[d.station]
		else: refusal = "that action is not available"
		_refresh()
	return ok

func player_move(station: int) -> bool:
	var ok := combat.act_move(selected, station)
	if ok:
		refusal = ""
	else:
		var d = combat.divers[selected]
		if not combat.station_open(station): refusal = "%s is not open here" % Combat.STATION_NAMES[station]
		elif d.station == station: refusal = "%s is already at %s" % [d.dname, Combat.STATION_NAMES[station]]
		elif combat.air < Combat.MOVE_COST: refusal = "not enough air to move"
		else: refusal = "that move is not available"
	_refresh()
	return ok

# H1: act_overdraft existed in the sim, was bound to no key, and appeared in
# no bot's legal-action list, so a whole row of the Air economy was dead code
# under a green gate.
# Unbound when OVERDRAFT_ENABLED went false. Kept so the sim entry point
# still has a presentation-side caller if the mechanic is ever revived.
func _dead_player_overdraft() -> bool:
	var ok := combat.act_overdraft(selected)
	refusal = "" if ok else "cannot burn HP for air: needs more than %d HP, and once per turn" % Combat.OVERDRAFT_HP
	_refresh()
	return ok

func player_end_turn() -> void:
	combat.end_turn()
	_after()

# A finished fight advances the ladder. The run owns progression; the
# scene only asks it to move.
# Winning cut straight to the next screen, so the moment you won was the
# moment the thing you won against vanished. Hold it.
var _hold := 0.0
var _won := ""

func _after() -> void:
	if combat != null and combat.outcome != "ongoing":
		_won = ("%s IS DISABLED" % String(combat.enc.get("title", "the enemy")).to_upper()) if combat.outcome == "victory" else "THE SQUAD IS LOST"
		_hold = 0.9
		run.advance()
		combat = run.combat
		selected = 0
		_log_at = 0
	_refresh()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and int(e.button_index) == MOUSE_BUTTON_LEFT:
		_click((e as InputEventMouseButton).position)
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = (e as InputEventKey).keycode
	match k:
		KEY_1:
			if run.puzzle != null: run.puzzle.toggle(0)
			else: _select(0)
			_refresh()
		KEY_2:
			if run.puzzle != null: run.puzzle.toggle(1)
			else: _select(1)
			_refresh()
		KEY_3:
			if run.puzzle != null: run.puzzle.toggle(2)
			else: _select(2)
			_refresh()
		KEY_4:
			if run.puzzle != null and run.puzzle.valves() > 3: run.puzzle.toggle(3)
			_refresh()
		KEY_Q: player_move(Combat.FRONT)
		KEY_W: player_move(Combat.FLANK)
		KEY_E: player_move(Combat.UNDER)
		KEY_R: player_move(Combat.REAR)
		KEY_T: player_move(Combat.BACKLINE)
		KEY_SPACE: player_ability(0)
		KEY_F: player_ability(1)
		KEY_ENTER:
			if combat == null:
				run.advance(); combat = run.combat; selected = 0; _refresh()
			else:
				player_end_turn()

# The lock, DRAWN. It was a line of text -- "chamber A 0/3 chamber B 0/3
# valve 1 SHUT ..." -- on an otherwise empty screen, which is precisely the
# failure the last project's puzzle died of and precisely what this one was
# justified as fixing: the whole state readable from a still frame. A still
# frame of a sentence is still a sentence.
#
# Everything here is read from the sim: the water heights are level_a() and
# level_b(), the valve colours are valve[], and the door lights on solved().
# Nothing is remembered by the player and nothing is remembered by the draw.
const WATER := Color(0.24, 0.66, 0.80)
const STEEL := Color(0.045, 0.075, 0.105)
const OPEN_C := Color(0.45, 0.78, 0.55)
const SHUT_C := Color(0.72, 0.34, 0.28)

func _valve_dot(at: Vector2, key: String, is_open: bool, reachable: bool) -> void:
	var col: Color = OPEN_C if is_open else SHUT_C
	if not is_open and not reachable:
		col = Color(0.38, 0.36, 0.42)      # under water: cannot be turned
	draw_circle(at, 16, col)
	draw_arc(at, 16, 0, TAU, 24, Color(0.85, 0.90, 0.95), 2.0)
	var f: Font = ThemeDB.fallback_font
	draw_string(f, at + Vector2(-5, 6), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.05, 0.09, 0.12))
	if not is_open and not reachable:
		draw_string(f, at + Vector2(-34, 38), "under water", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.72, 0.80))

func _chamber(at: Vector2, wide: float, tall: float, filled: int, cap: int, name: String) -> void:
	draw_rect(Rect2(at, Vector2(wide, tall)), STEEL)
	var h: float = tall * (float(filled) / float(max(1, cap)))
	if h > 0.0:
		draw_rect(Rect2(at + Vector2(0, tall - h), Vector2(wide, h)), WATER)
		# a moving surface, so the level is unmistakably a level
		var sy: float = at.y + tall - h
		for i in range(14):
			var x0: float = at.x + wide * float(i) / 14.0
			var bob: float = sin(_clock * 2.2 + float(i) * 0.8) * 2.4
			draw_line(Vector2(x0, sy + bob), Vector2(x0 + wide / 14.0, sy - bob),
				Color(0.72, 0.94, 1.0, 0.85), 2.0)
	draw_rect(Rect2(at, Vector2(wide, tall)), Color(0.55, 0.66, 0.74), false, 2.0)
	# the graduations, so "2 of 3" is countable and not just a bar
	for m in range(1, cap):
		var y: float = at.y + tall - tall * (float(m) / float(cap))
		draw_line(Vector2(at.x, y), Vector2(at.x + 14, y), Color(0.55, 0.66, 0.74), 1.0)
	var f: Font = ThemeDB.fallback_font
	# above the tank, clear of the pipes that run below it
	# under the tank, where nothing else is written
	draw_string(f, at + Vector2(0, tall + 26), "%s  %d of %d" % [name, filled, cap],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.86, 0.90, 0.94))

func _door(at: Vector2, wide: float, is_open: bool) -> void:
	var f: Font = ThemeDB.fallback_font
	draw_rect(Rect2(at, Vector2(wide, 22)), OPEN_C if is_open else Color(0.30, 0.28, 0.24))
	# a dashed line across the chamber marking the height the water has to
	# reach, so "fill it to the top" is a picture
	for i in range(16):
		if i % 2 == 1:
			continue
		var x0: float = at.x + wide * float(i) / 16.0
		draw_line(Vector2(x0, at.y + 26), Vector2(x0 + wide / 16.0, at.y + 26),
			Color(0.86, 0.78, 0.42, 0.75), 2.0)
	draw_string(f, at + Vector2(0, -46), "the way out" + ("  OPEN" if is_open else "  ·  fill to this line"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, OPEN_C if is_open else Color(0.86, 0.78, 0.42))

func _valve_pos(i: int) -> Vector2:
	var p = run.puzzle
	var tall := LOCK_TALL
	var top := LOCK_TOP
	if p.stage == 2:
		var ax := 300.0
		var bx := 700.0
		var wide := 240.0
		if i == p.CROSS:
			return Vector2((ax + wide + bx) * 0.5, top + tall - 26.0)
		if i == 0:
			return Vector2(ax + 60.0, top + tall + 60.0)
		if i == 1:
			return Vector2(ax + 170.0, top + tall + 60.0)
		return Vector2(bx + 110.0, top + tall + 60.0)
	var x := 430.0
	var wide1 := 420.0
	if i == 0:
		return Vector2(x + 70.0, top + tall + LOCK_DROP)
	if i == 1:
		return Vector2(x + 150.0, top + tall + LOCK_DROP)
	# the seized valve is ON the tank wall down at the floor, where the
	# water covers it, not floating unattached in the middle of the chamber
	return Vector2(x + wide1 + 26.0, top + tall - 26.0)

func _draw_rig() -> void:
	var f: Font = ThemeDB.fallback_font
	var w: Vector2 = size.max(DESIGN)
	var surf: float = 232.0
	# the surface: everything above it is air and rain-coloured
	draw_rect(Rect2(Vector2.ZERO, Vector2(w.x, surf)), Color(0.055, 0.085, 0.125))
	draw_line(Vector2(0, surf), Vector2(w.x, surf), Color(0.42, 0.62, 0.70, 0.75), 2.0)
	for i in range(46):
		var x: float = float(i) * (w.x / 46.0)
		var bob: float = sin(_clock * 1.1 + float(i) * 0.6) * 3.0
		draw_line(Vector2(x, surf + bob), Vector2(x + w.x / 46.0, surf - bob),
			Color(0.55, 0.76, 0.84, 0.30), 2.0)
	# the rig: a deck on legs, which is the thing the whole story is about
	var dx: float = w.x * 0.5 - 190.0
	draw_rect(Rect2(Vector2(dx, surf - 54), Vector2(380, 26)), Color(0.20, 0.22, 0.24))
	draw_rect(Rect2(Vector2(dx + 40, surf - 104), Vector2(96, 50)), Color(0.24, 0.26, 0.28))
	draw_rect(Rect2(Vector2(dx + 250, surf - 88), Vector2(40, 34)), Color(0.24, 0.26, 0.28))
	# the failing pump, blinking
	var lit: float = 0.35 + 0.65 * abs(sin(_clock * 2.3))
	draw_circle(Vector2(dx + 270, surf - 96), 5.0, Color(0.92, 0.44, 0.30, lit))
	for lx in [dx + 24.0, dx + 178.0, dx + 340.0]:
		draw_line(Vector2(lx, surf - 28), Vector2(lx + 10.0, surf + 96.0), Color(0.18, 0.20, 0.22), 7.0)
	# the squad on the deck, the cast the copy is talking about
	for i in range(3):
		Art.draw_diver(self, i + 1, Vector2(dx + 110.0 + float(i) * 82.0, surf - 54.0) + fx.idle(i), 54.0, 1)
	var b: Dictionary = run.current()
	var title := String(b.get("title", "")).to_upper()
	draw_string(f, Vector2(w.x * 0.5 - 300.0, surf + 84.0), title,
		HORIZONTAL_ALIGNMENT_CENTER, 600.0, 34, Color(0.88, 0.93, 0.96))
	draw_string(f, Vector2(w.x * 0.5 - 300.0, surf + 112.0), "beat %d of %d" % [run.beat + 1, Beats.LADDER.size()],
		HORIZONTAL_ALIGNMENT_CENTER, 600.0, 17, Color(0.55, 0.66, 0.72))

# _valve_pos and this function each kept their own copy of the tank
# geometry, and they had drifted: the drawing moved to top 322 while the
# click test still believed 250, so every valve was clickable 72px from
# where it was drawn. One constant, read by both -- the same fix the ring
# and the legend needed when they disagreed.
func _draw_lock(p) -> void:
	var tall := LOCK_TALL
	if p.stage == 2:
		var ax := 300.0
		var bx := 700.0
		var wide := 240.0
		var top := LOCK_TOP
		_chamber(Vector2(ax, top), wide, tall, p.level_a(), 3, "chamber A")
		_chamber(Vector2(bx, top), wide, tall, p.level_b(), 3, "chamber B")
		_door(Vector2(ax, top - 30), wide, p.solved())
		# the crossover pipe, at the BOTTOM of B because that is the whole
		# interlock: it can only be turned while B is dry
		var pipe_y := top + tall - 26.0
		draw_line(Vector2(ax + wide, pipe_y), Vector2(bx, pipe_y),
			OPEN_C if p.valve[p.CROSS] else Color(0.42, 0.48, 0.55), 9.0)
		_valve_dot(_valve_pos(p.CROSS), "4", p.valve[p.CROSS], p.reachable(p.CROSS))
		for src in [[0, ax + 60.0], [1, ax + 170.0], [2, bx + 110.0]]:
			var vp: Vector2 = _valve_pos(int(src[0]))
			draw_line(vp + Vector2(0, -18), Vector2(float(src[1]), top + tall),
				OPEN_C if p.valve[int(src[0])] else Color(0.42, 0.48, 0.55), 7.0)
		_valve_dot(_valve_pos(0), "1", p.valve[0], true)
		_valve_dot(_valve_pos(1), "2", p.valve[1], true)
		_valve_dot(_valve_pos(2), "3", p.valve[2], true)
		var f2: Font = ThemeDB.fallback_font
		draw_string(f2, Vector2(ax + 30, top + tall + 110), "1 and 2 feed A", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.72, 0.78, 0.84))
		draw_string(f2, Vector2(bx + 60, top + tall + 110), "3 feeds B", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.72, 0.78, 0.84))
		return
	var x := 430.0
	var wide := 420.0
	var top := LOCK_TOP
	_chamber(Vector2(x, top), wide, tall, p.level(), p.VALVES, "the chamber")
	_door(Vector2(x, top - 30), wide, p.solved())
	# two inlets you can always reach, and the seized one down at the floor
	for src2 in [[0, x + 70.0], [1, x + 150.0]]:
		var vp2: Vector2 = _valve_pos(int(src2[0]))
		draw_line(vp2 + Vector2(0, -18), Vector2(float(src2[1]), top + tall),
			OPEN_C if p.valve[int(src2[0])] else Color(0.42, 0.48, 0.55), 7.0)
	_valve_dot(_valve_pos(0), "1", p.valve[0], p.reachable(0))
	_valve_dot(_valve_pos(1), "2", p.valve[1], p.reachable(1))
	# a pipe for the seized valve too, so all three are visibly plumbed
	draw_line(_valve_pos(p.SEIZED) - Vector2(18, 0), Vector2(x + wide, top + tall - 26.0),
		OPEN_C if p.valve[p.SEIZED] else Color(0.42, 0.48, 0.55), 7.0)
	_valve_dot(_valve_pos(p.SEIZED), "3", p.valve[p.SEIZED], p.reachable(p.SEIZED))

# how deep we are, 0 at the rig and 1 at the bottom
func _depth() -> float:
	var n: int = Beats.LADDER.size()
	if n <= 1:
		return 0.0
	return clampf(float(run.beat) / float(n - 1), 0.0, 1.0)

func _water() -> Color:
	var d: float = _depth()
	return Color(0.055, 0.135, 0.190).lerp(Color(0.014, 0.035, 0.070), d)

# --- the water itself -----------------------------------------------------
# The play field was flat navy with nothing in it, so a screenshot read as
# an unfinished engine test and the enemy looked like it was floating in a
# void. The last prototype had parallax, god rays and a mote field, and the
# team's own comparison called this the single biggest step backwards.
func _draw_water() -> void:
	var d: float = _depth()
	var w: Vector2 = size.max(DESIGN)
	# a vertical gradient: brighter at the surface, black at the floor
	var top: Color = Color(0.075, 0.185, 0.245).lerp(Color(0.020, 0.055, 0.095), d)
	var bot: Color = Color(0.030, 0.075, 0.115).lerp(Color(0.005, 0.014, 0.030), d)
	var bands := 180
	for i in range(bands):
		var f: float = float(i) / float(bands - 1)
		draw_rect(Rect2(Vector2(0, floor(w.y * f)), Vector2(w.x, ceil(w.y / float(bands)) + 1.0)), top.lerp(bot, f))
	# light coming down from the surface, weaker the deeper you are
	var lit: float = (1.0 - d) * 0.5
	if lit > 0.02:
		for i in range(5):
			var x: float = w.x * (0.12 + 0.19 * float(i)) + sin(_clock * 0.25 + float(i)) * 26.0
			var pts := PackedVector2Array([
				Vector2(x - 40, 0), Vector2(x + 40, 0),
				Vector2(x + 150, w.y), Vector2(x - 20, w.y)])
			draw_colored_polygon(pts, Color(0.55, 0.85, 0.95, 0.030 * lit))
	# silt drifting up, so the frame is never completely still
	for i in range(34):
		var sx: float = fmod(float(i) * 137.5 + sin(float(i)) * 40.0, w.x)
		var sy: float = fmod(w.y - fmod(_clock * (7.0 + float(i % 5) * 3.0) + float(i) * 53.0, w.y + 60.0), w.y)
		var r: float = 1.0 + float(i % 3) * 0.9
		draw_circle(Vector2(sx, sy), r, Color(0.68, 0.86, 0.94, 0.10))

# --- bars, because a fraction is not a picture ---------------------------
func _bar(at: Vector2, wide: float, tall: float, frac: float, fill: Color) -> void:
	var f: float = clampf(frac, 0.0, 1.0)
	draw_rect(Rect2(at, Vector2(wide, tall)), Color(0.03, 0.07, 0.10, 0.85))
	if f > 0.0:
		draw_rect(Rect2(at + Vector2(1, 1), Vector2((wide - 2.0) * f, tall - 2.0)), fill)
	draw_rect(Rect2(at, Vector2(wide, tall)), Color(0.62, 0.74, 0.82, 0.55), false, 1.0)

const BAR_OK := Color(0.42, 0.78, 0.62)
const BAR_LOW := Color(0.88, 0.52, 0.30)
const BAR_LIMB := Color(0.82, 0.44, 0.34)

func _draw_windup() -> void:
	var f: Font = ThemeDB.fallback_font
	var pulse: float = 0.55 + 0.45 * sin(_clock * 4.2)
	# how much lands on each station THIS turn, totalled
	var incoming: Dictionary = {}
	for it0 in combat.intents():
		if int(combat.limb_stun[int(it0.limb)]) > 0 or combat.limb_broken[int(it0.limb)]:
			continue
		for st0 in it0.stations:
			incoming[int(st0)] = int(incoming.get(int(st0), 0)) + int(it0.dmg)
	var drawn: Array = []
	for it in combat.intents():
		var lb: int = int(it.limb)
		if int(combat.limb_stun[lb]) > 0 or combat.limb_broken[lb]:
			continue
		var src: Vector2 = _limb_at(lb)
		for st in it.stations:
			if not combat.station_open(int(st)):
				continue
			var dst: Vector2 = place(int(st))
			var dir: Vector2 = (dst - src)
			if dir.length() < 6.0:
				# it bites where it stands: ring the station instead
				var rr: float = 56.0 + 5.0 * pulse
				draw_arc(dst, rr, 0, TAU, 40, Color(0.98, 0.46, 0.34, 0.45 + 0.45 * pulse), 5.0)
				var pip0: Vector2 = dst + Vector2(46.0, -34.0)
				if int(st) in drawn:
					continue
				drawn.append(int(st))
				draw_circle(pip0, 15.0, Color(0.10, 0.05, 0.06, 0.92))
				draw_arc(pip0, 15.0, 0, TAU, 20, Color(0.98, 0.50, 0.38, 0.90), 2.0)
				draw_string(f, pip0 + Vector2(-6 if int(incoming.get(int(st), 0)) < 10 else -12, 7), str(int(incoming.get(int(st), 0))),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.82, 0.74))
				continue
			var n: Vector2 = dir.normalized()
			var a: Vector2 = src + n * 30.0
			var b: Vector2 = dst - n * 48.0
			# a bowed arc rather than a straight line: the direct route runs
			# under the station cards and arrives as disconnected strokes
			var lift: float = min(90.0, dir.length() * 0.30)
			var ctrl: Vector2 = a.lerp(b, 0.5) + Vector2(0, -lift)
			var segs := 18
			var prev: Vector2 = a
			for i in range(1, segs + 1):
				var t: float = float(i) / float(segs)
				var q: Vector2 = a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
				# taper: thin where it leaves, heavy where it lands
				draw_line(prev, q, Color(0.98, 0.46, 0.34, 0.30 + 0.55 * pulse * t),
					2.0 + 5.0 * t)
				prev = q
			# an arrowhead, so the direction is never in question
			var tipd: Vector2 = (b - prev).normalized() if (b - prev).length() > 1.0 else n
			var perp := Vector2(-tipd.y, tipd.x)
			draw_colored_polygon(PackedVector2Array([
				b, b - tipd * 20.0 + perp * 10.0, b - tipd * 20.0 - perp * 10.0]),
				Color(0.98, 0.46, 0.34, 0.55 + 0.45 * pulse))
			# anchored to the RING it lands on, never to the middle of the
			# line, so it can never read as belonging to another station
			var pip: Vector2 = dst + Vector2(46.0, -34.0)
			if int(st) in drawn:
				continue
			drawn.append(int(st))
			draw_circle(pip, 15.0, Color(0.10, 0.05, 0.06, 0.92))
			draw_arc(pip, 15.0, 0, TAU, 20, Color(0.98, 0.50, 0.38, 0.90), 2.0)
			draw_string(f, pip + Vector2(-6 if int(incoming.get(int(st), 0)) < 10 else -12, 7), str(int(incoming.get(int(st), 0))),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.82, 0.74))

# A click means the obvious thing for whatever is under it: a station moves
# the selected diver there, a diver card selects that diver, and the enemy
# means attack. Nothing here is a new rule; it is the same three verbs.
func _click(at: Vector2) -> void:
	if run.puzzle != null:
		for i in range(run.puzzle.valves()):
			if at.distance_to(_valve_pos(i)) < 30.0:
				run.puzzle.toggle(i)
				_refresh()
				return
		return
	if combat == null:
		run.advance(); combat = run.combat; selected = 0; _refresh()
		return
	for i in range(combat.divers.size()):
		var card: Control = ui_divers[i]
		if card.visible and card.get_global_rect().has_point(at):
			_select(i)
			_refresh()
			return
	for st in range(5):
		if not combat.station_open(st):
			continue
		if at.distance_to(place(st)) < 54.0:
			var d = combat.divers[selected]
			if int(d.station) == st:
				player_ability(0)
			else:
				player_move(st)
			return
	# anywhere on the creature means hit what you are standing next to
	player_ability(0)

func _draw_banner() -> void:
	var f: Font = ThemeDB.fallback_font
	var w: Vector2 = size.max(DESIGN)
	draw_rect(Rect2(Vector2.ZERO, Vector2(w.x, 26)), Color(0.86, 0.62, 0.24, 0.92))
	draw_string(f, Vector2(24, 20), _won, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.06, 0.09, 0.12))

# who is standing here, said the same way everywhere
func here_free(st: int) -> String:
	for d in combat.divers:
		if not d.down and int(d.station) == st:
			return "  ·  taken"
	return ""

func _draw_bars() -> void:
	# one per live limb, sitting on its own ring rather than in a corner
	for st in range(5):
		if not combat.station_open(st):
			continue
		var lb: int = combat.STATION_LIMB[st]
		if lb < 0 or combat.limb_broken[lb]:
			continue
		var maxhp: float = float(int((combat.enc.limbs[lb] as Dictionary).hp))
		var frac2: float = float(combat.limb_hp[lb]) / max(1.0, maxhp)
		# clamped out of the HUD: a station high on the board pushed its bar
		# up behind the control bar
		var at: Vector2 = Vector2(place(st).x - 88.0, max(place(st).y - 96.0, HUD_BOTTOM + 4.0))
		_bar(at, 176, 16, frac2, BAR_LIMB)
		# and the name of what you are breaking, on the bar itself
		var f2: Font = ThemeDB.fallback_font
		draw_string(f2, at + Vector2(6, 13), "%s %d/%d" % [String(combat.LIMB_NAMES[lb]).to_upper(),
			int(combat.limb_hp[lb]), int(maxhp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.98, 0.96, 0.94))
	# and one per diver, ON the diver, not in a card at the bottom of the screen
	for d in combat.divers:
		if d.down:
			continue
		var f: Vector2 = diver_foot(d) + fx.diver_offset(int(d.id)) + fx.idle(int(d.id))
		var frac: float = float(d.hp) / max(1.0, float(d.max_hp))
		_bar(f + Vector2(-30, -DIVER_SCALE - 4), 60, 7, frac, BAR_OK if frac > 0.34 else BAR_LOW)

func _draw() -> void:
	# Paint the ACTUAL rect, not the design size. With stretch/expand the
	# viewport grows past 720 and anything beyond it was left unpainted,
	# which is the flat grey band a visual reviewer flagged as the game
	# failing to fill its window.
	_draw_water()
	# the lock is inside the wreck, so it is lit by what you brought
	if run != null and run.finished:
		_draw_ending()
		return
	if _won != "" and combat == null:
		_draw_banner()
	if run != null and run.puzzle != null:
		_draw_lock(run.puzzle)
		return
	if combat == null and run != null and not run.finished:
		_draw_rig()
		return
	var jolt := Vector2.ZERO
	if fx.shake > 0.01:
		jolt = Vector2(sin(fx.shake * 41.0), cos(fx.shake * 37.0)) * fx.shake * 9.0
	draw_set_transform(jolt, 0.0, Vector2.ONE)
	# station rings: red while the limb they expose is live, teal once it is
	# broken or absent. This is the map changing, drawn.
	if combat == null:
		return
	var ap0: Array = combat.enc.art.pos
	var body: Vector2 = Vector2(float(ap0[0]), float(ap0[1])) + Vector2(0, 150) + fx.body_offset()
	for i in range(5):
		if not combat.station_open(i):
			continue
		# a tether from the station to the creature, so the ring reads as a
		# part of the thing rather than a circle drawn near it
		if combat.STATION_LIMB[i] >= 0:
			var pc: Vector2 = place(i)
			var dirb: Vector2 = (body - pc)
			if dirb.length() > 60.0:
				var nb: Vector2 = dirb.normalized()
				draw_line(pc + nb * 48.0, pc + nb * (dirb.length() * 0.72),
					Color(0.62, 0.72, 0.78, 0.34), 2.0)
		var occupied := false
		for d3 in combat.divers:
			if not d3.down and int(d3.station) == i:
				occupied = true
		var col := Color(0.25, 0.55, 0.6)
		if i in combat.threatened_stations():
			col = Color(0.85, 0.35, 0.25)
		# a threatened station with nobody in it is an attack about to hit
		# empty water, which costs the squad an air line. Hollow it, so the
		# miss is something you can see coming.
		draw_arc(place(i), 46, 0, TAU, 40, Color(col.r, col.g, col.b, 1.0 if occupied else 0.40), 4.0 if occupied else 2.0)
	# scale is PIXELS PER BODY UNIT, not a multiplier. Passing 1.6 made the
	# crab under two pixels tall, its foot triangles sub-pixel, and the
	# triangulator rejected them, so the enemy silently did not draw at all
	# while every test stayed green. Caught by the first as-played capture.
	if combat == null:
		return
	var art: Dictionary = combat.enc.get("art", {})
	var ap: Array = art.get("pos", [878, 316])
	var asc: float = float(art.get("scale", CRAB_SCALE))
	var tint: Array = art.get("tint", [1.0, 1.0, 1.0])
	Art.tint = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	Art.stretch = 1.0
	if String(art.get("kind", "crab")) == "worm":
		Art.stretch = 1.55        # long and thin
	elif String(art.get("kind", "crab")) == "dredge":
		Art.stretch = 0.78        # squat and blocky
	Art.draw_crab(self, Vector2(float(ap[0]), float(ap[1])) + Vector2(0, 150) + fx.body_offset() + fx.idle(7) * 1.6, asc, combat.limb_broken)
	Art.tint = Color(1, 1, 1)
	Art.stretch = 1.0
	for d in combat.divers:
		if d.down:
			continue
		Art.draw_diver(self, d.cost, diver_foot(d) + fx.diver_offset(int(d.id)) + fx.idle(int(d.id)), DIVER_SCALE, 1)
	if _won != "":
		_draw_banner()
	_draw_windup()
	_draw_bars()
	_draw_fx()

# --- the effects themselves, painted over the board ---------------------
func _draw_fx() -> void:
	var f: Font = ThemeDB.fallback_font
	for e in fx.live:
		var k: float = e.k()
		match e.kind:
			"bolt":
				# the enemy reaching you, drawn as a strike travelling from
				# the limb to the station it named. The telegraph promised
				# this exact line one turn earlier; now you watch it land.
				var head: Vector2 = e.at.lerp(e.to, min(1.0, k * 1.6))
				var tail: Vector2 = e.at.lerp(e.to, max(0.0, k * 1.6 - 0.45))
				var fade := Color(e.col.r, e.col.g, e.col.b, 1.0 - k * 0.7)
				draw_line(tail, head, fade, 7.0 - 3.0 * k)
				draw_circle(head, 13.0 * (1.0 - k * 0.5), fade)
			"flash":
				draw_arc(e.at, 46.0 + 16.0 * k, 0, TAU, 36,
					Color(e.col.r, e.col.g, e.col.b, 1.0 - k), 4.0 - 2.0 * k)
			"burst":
				var r: float = 40.0 + 90.0 * k
				draw_arc(e.at, r, 0, TAU, 40, Color(e.col.r, e.col.g, e.col.b, 1.0 - k), 5.0 * (1.0 - k))
				if e.text != "":
					draw_string(f, e.at + Vector2(-46, -60 - 26 * k), e.text,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(e.col.r, e.col.g, e.col.b, 1.0 - k))
			"ring":
				draw_arc(e.at, 52.0, 0, TAU, 40, Color(e.col.r, e.col.g, e.col.b, 1.0 - k), 3.0)
				if e.text != "":
					draw_string(f, e.at + Vector2(-52, -62), e.text,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(e.col.r, e.col.g, e.col.b, 1.0 - k))
			"float":
				# a number that leaves the thing it happened to, so damage
				# has a place as well as a value, and never climbs into the
				# HUD where it overprints the words there
				var rise: Vector2 = Vector2(e.at.x, max(e.at.y - 46.0 * k, HUD_BOTTOM + 16.0))
				var a: float = 1.0 if k < 0.6 else (1.0 - (k - 0.6) / 0.4)
				draw_string(f, rise, e.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
					Color(e.col.r, e.col.g, e.col.b, a))
