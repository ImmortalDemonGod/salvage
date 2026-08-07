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
var ui_tanks: Array = []
var ui_log: Label
var ui_step: Label
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_pass_clicks_through(self)
	_refresh()

# where this encounter puts a station, falling back to the default ring
# The board sits under the HUD, and a sprite is not a Control, so nothing
# was stopping one being drawn through the help line. A reviewer looking at
# the last beat put it exactly: the words "ENTER end t" were painted on top
# of Proto5's chest, and it read as HUD chrome rather than a unit on the
# board. Declared here so verify/layout.gd can check it.
const HUD_BOTTOM := 212.0   # the lowest a diver SPRITE may reach
const PANEL_FLOOR := 262.0  # the prompt band ends at 252; readouts clamp below it
const DIVER_SCALE := 66.0
# The team's rig, baked to frames (art/baked, see REPORT.md there): the
# divers are Glass_Goat's actual characters now, not code-drawn stand-ins.
# Clay renders tinted toward the INPUTS colorway; the sprite IS the cost
# tier (bare skin 1, suit 2, plate 3), which was the whole point of the
# mapping. Frames are 352x512 with the floor anchor at y=434.
const RIG_CLIPS := {
	0: {"idle": "scuba_idle1", "hurt": "scuba_damaged1"},
	1: {"idle": "prototype1_idle1", "hurt": "prototype1_damaged"},
	2: {"idle": "proto5_idle", "hurt": "proto5_damaged"},
}
const RIG_BY_ABILITY := {
	"Axe Kick": "scuba_axe_kick", "Double Knee": "scuba_double_knee",
	"Palm Strike": "prototype1_palm_strike", "Dual Palm": "prototype1_dualpalm",
	"Piston Swing": "proto5_attck1", "Wide Sweep": "proto5_attck2",
}
const RIG_TINT := {
	0: Color(1.00, 0.85, 0.74),
	1: Color(1.00, 0.66, 0.34),
	2: Color(0.88, 0.76, 0.48),
}
const RIG_FPS := 10.0
const RIG_SCALE := 0.22
var _rig_cache: Dictionary = {}
var _danim: Dictionary = {}   # diver id -> {"clip": String, "t0": float}
# Into the Breach's turn reset, the audit's top-ranked import and the
# playtest's "playing around with the keys wastes my turn. There's no way
# to strategize". Deterministic sim, no hidden rolls, so a rewind cannot
# fish for outcomes; it only lets you finish thinking. Once per fight,
# and the snapshot is taken at each turn start.
var _turn_start: Combat = null
var _rewound := false
# Teach-by-play, the third playtest's own design: "the red ring pops up,
# boom. I don't need to show that ever again." Each lesson fires ONCE per
# session, at the moment it becomes relevant, anchored to the thing it is
# about, and fades. Not a Control, so the HUD budget is untouched.
var _taught: Dictionary = {}     # key -> clock time it fired
const TEACH_SECS := 6.0

func _teach(key: String, anchor: Vector2, text: String) -> void:
	if _taught.has(key):
		return
	_taught[key] = {"t": _clock, "at": anchor, "text": text}

func _draw_teach() -> void:
	if ui_step != null and ui_step.get_parent().visible:
		return
	var df: Font = ThemeDB.fallback_font
	for key in _taught.keys():
		var tc: Dictionary = _taught[key]
		var age: float = _clock - float(tc.t)
		if age > TEACH_SECS:
			continue
		var a: float = clampf(minf(age * 3.0, (TEACH_SECS - age) * 1.5), 0.0, 1.0)
		var at: Vector2 = tc.at
		var txt := String(tc.text)
		var tw: float = df.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		# the words live in the sky band no panel occupies; the pointer
		# line carries them to their object. Anchored raw, a station tag
		# (a Control, so above all drawing) ate half a lesson.
		var row := 0
		for k2 in _taught.keys():
			if String(k2) == String(key):
				break
			if _clock - float((_taught[k2] as Dictionary).t) <= TEACH_SECS:
				row += 1
		var tp := Vector2(clampf(at.x - tw * 0.5, 12.0, 1280.0 - tw - 12.0),
			minf(clampf(at.y - 46.0, 148.0, 206.0) + float(row) * 21.0, 224.0))
		draw_line(at + Vector2(0, -8), Vector2(tp.x + tw * 0.5, tp.y + 6.0), Color(0.95, 0.85, 0.45, 0.5 * a), 1.5)
		for off in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_string(df, tp + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.02, 0.05, 0.08, a))
		draw_string(df, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98, 0.92, 0.70, a))
const DIVER_SEAT := 20.0          # how far below the ring centre the feet sit
const CARD_TOP := 584.0
# The action bar: the third playtest's ruling made buttons a hard
# requirement ("having buttons on screen would replace the need of the
# keyboard and make it visually obvious what to do"). One geometry,
# drawn and hit-tested from the same rects (standing rule 29), enabled
# state predicted by ASKING the sim on a clone, never by a parallel
# rule that can drift.
const BAR_H := 42.0
# a vertical action menu on the LEFT, in the open water where nothing
# else lives: the first horizontal placement sat under the UNDER station
# tag, because Controls render above custom drawing and the bottom band
# is already packed. A left column is also the genre's own furniture.
const BAR_X := 24.0
const BAR_TOP := 330.0
const BAR_GAP := 6.0
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
const LOCK_TOP := 340.0
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

# One design language, in one place. PRIMARY is for the things that change
# every turn, QUIET for the things that never do, so the eye has somewhere
# to go first.
const BRASS := Color(0.44, 0.40, 0.30)
const BRASS_LIT := Color(0.90, 0.72, 0.38)
const PLATE := Color(0.085, 0.105, 0.120)
const PLATE_DEEP := Color(0.055, 0.070, 0.085)
const RIVET := Color(0.36, 0.33, 0.26, 0.55)

static func _skin(bg: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	return sb

static func skin_primary() -> StyleBoxFlat:
	# the gauges you read every turn: brightest brass, deepest plate
	var sb := _skin(Color(0.100, 0.120, 0.135, 0.96), BRASS, 4)
	sb.set_border_width_all(2)
	return sb

static func skin_quiet() -> StyleBoxFlat:
	# painted steel, no brass: the labels that never change
	return _skin(Color(0.070, 0.085, 0.098, 0.88), Color(0.26, 0.29, 0.32, 0.9), 3)

static func skin_card() -> StyleBoxFlat:
	# a suit plate: the roster, the story, the things about the people
	var sb := _skin(Color(0.088, 0.108, 0.124, 0.95), Color(0.45, 0.36, 0.22, 0.95), 5)
	sb.set_border_width_all(2)
	return sb

static func skin_station() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.070, 0.090, 0.62)
	sb.border_color = BRASS
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	return sb

# four rivets, one per corner, added as children so they sit ON the plate
func _rivet(pan: Control) -> void:
	for c in [Vector2(7, 7), Vector2(pan.size.x - 12, 7),
			Vector2(7, pan.size.y - 12), Vector2(pan.size.x - 12, pan.size.y - 12)]:
		var r := ColorRect.new()
		r.name = "rivet"
		r.color = RIVET
		r.size = Vector2(5, 5)
		r.position = c
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pan.add_child(r)

# Nothing in the HUD is clickable, so nothing in the HUD may swallow a
# click. Applied to the whole tree after it is built, so a panel added
# later cannot silently reintroduce the bug.
func _pass_clicks_through(node: Node) -> void:
	for c in node.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pass_clicks_through(c)

func _build_ui() -> void:
	# station markers: one Control each, so the invariants can assert they
	# never overlap and their labels stay inside them
	for i in range(5):
		var m := Panel.new()
		m.name = "station_" + Combat.STATION_NAMES[i]
		# the diet: 300x74 tags covered the creature they described. The
		# playtest line that forced it: "I legitimately cannot even see
		# the thing I'm supposed to be fighting." One line and a bar.
		m.size = Vector2(224, 40)
		m.position = Vector2.ZERO   # placed per encounter in _refresh
		m.add_theme_stylebox_override("panel", skin_station())
		var bg := ColorRect.new()
		bg.name = "bar_bg"
		bg.color = Color(0.03, 0.05, 0.07, 0.92)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(bg)
		var fill := ColorRect.new()
		fill.name = "bar_fill"
		fill.color = BAR_LIMB
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(fill)
		var prev := ColorRect.new()
		prev.name = "bar_preview"
		prev.color = Color(0.98, 0.90, 0.55)
		prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(prev)
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
		p.size = Vector2(320, 86)
		p.position = Vector2(24 + i * 334, CARD_TOP)
		p.add_theme_stylebox_override("panel", skin_card())
		_rivet(p)
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
	air_panel.size = Vector2(340, 84)
	air_panel.position = Vector2(30, 24)
	air_panel.add_theme_stylebox_override("panel", skin_primary())
	_rivet(air_panel)
	add_child(air_panel)
	ui_air = Label.new()
	ui_air.name = "label"
	ui_air.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_air.offset_left = 10; ui_air.offset_right = -10
	ui_air.offset_top = 6; ui_air.offset_bottom = -46
	ui_air.add_theme_font_size_override("font_size", 19)
	ui_air.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
	air_panel.add_child(ui_air)
	for i in range(Combat.AIR_PER_TURN):
		var tank := ColorRect.new()
		tank.name = "tank_%d" % i
		tank.size = Vector2(26, 30)
		tank.position = Vector2(16 + i * 34, 44)
		tank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		air_panel.add_child(tank)
		ui_tanks.append(tank)

	var tel := Panel.new()
	tel.name = "telegraph_panel"
	tel.size = Vector2(856, 52)
	tel.position = Vector2(392, 24)
	tel.add_theme_stylebox_override("panel", skin_primary())
	_rivet(tel)
	add_child(tel)
	ui_intent = Label.new()
	ui_intent.name = "label"
	ui_intent.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_intent.offset_left = 12; ui_intent.offset_right = -12
	ui_intent.offset_top = 6; ui_intent.offset_bottom = -6
	ui_intent.add_theme_font_size_override("font_size", 19)
	ui_intent.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
	tel.add_child(ui_intent)

	# built BEFORE the first _refresh, which runs on the opening scene beat
	var scene_panel := Panel.new()
	scene_panel.name = "scene_panel"
	scene_panel.size = SCENE_PANEL_SIZE
	scene_panel.position = SCENE_PANEL_AT
	scene_panel.add_theme_stylebox_override("panel", skin_card())
	_rivet(scene_panel)
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
	legend_panel.size = Vector2(640, 46)
	legend_panel.position = Vector2(30, 116)
	legend_panel.add_theme_stylebox_override("panel", skin_quiet())
	_rivet(legend_panel)
	add_child(legend_panel)
	ui_legend = Label.new()
	ui_legend.name = "label"
	ui_legend.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_legend.offset_left = 14; ui_legend.offset_right = -14
	ui_legend.offset_top = 11; ui_legend.offset_bottom = -11
	ui_legend.add_theme_font_size_override("font_size", 14)
	ui_legend.add_theme_color_override("font_color", Color(0.58, 0.68, 0.75))
	legend_panel.add_child(ui_legend)

	var goal_panel := Panel.new()
	goal_panel.name = "goal_panel"
	goal_panel.size = Vector2(548, 46)
	goal_panel.position = Vector2(700, 114)
	goal_panel.add_theme_stylebox_override("panel", skin_quiet())
	_rivet(goal_panel)
	add_child(goal_panel)
	ui_goal = Label.new()
	ui_goal.name = "label"
	ui_goal.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_goal.offset_left = 14; ui_goal.offset_right = -14
	ui_goal.offset_top = 11; ui_goal.offset_bottom = -11
	ui_goal.add_theme_color_override("font_color", Color(0.80, 0.87, 0.91))
	goal_panel.add_child(ui_goal)

	var help_panel := Panel.new()
	help_panel.name = "help_panel"
	help_panel.size = Vector2(1220, 40)
	help_panel.position = Vector2(30, 166)
	help_panel.add_theme_stylebox_override("panel", skin_quiet())
	add_child(help_panel)
	var step_panel := Panel.new()
	step_panel.name = "step_panel"
	step_panel.size = Vector2(1220, 40)
	step_panel.position = Vector2(30, 212)
	step_panel.add_theme_stylebox_override("panel", skin_primary())
	_rivet(step_panel)
	add_child(step_panel)
	ui_step = Label.new()
	ui_step.name = "label"
	ui_step.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_step.offset_left = 12; ui_step.offset_right = -12
	ui_step.offset_top = 7; ui_step.offset_bottom = -7
	ui_step.add_theme_font_size_override("font_size", 18)
	ui_step.add_theme_color_override("font_color", BRASS_LIT)
	step_panel.add_child(ui_step)
	var log_panel := Panel.new()
	log_panel.name = "log_panel"
	log_panel.size = Vector2(1232, 40)
	log_panel.position = Vector2(24, 680)
	var lst := StyleBoxFlat.new()
	lst.bg_color = Color(0.03, 0.09, 0.14, 0.92)
	lst.border_color = Color(0.34, 0.52, 0.62, 0.85)
	lst.set_border_width_all(1)
	lst.set_corner_radius_all(3)
	log_panel.add_theme_stylebox_override("panel", lst)
	_rivet(log_panel)
	add_child(log_panel)
	ui_log = Label.new()
	ui_log.name = "label"
	ui_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_log.offset_left = 12; ui_log.offset_right = -12
	ui_log.offset_top = 8; ui_log.offset_bottom = -8
	ui_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_log.add_theme_font_size_override("font_size", 15)
	ui_log.add_theme_color_override("font_color", Color(0.72, 0.82, 0.88))
	log_panel.add_child(ui_log)
	ui_help = Label.new()
	ui_help.name = "label"
	ui_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_help.offset_left = 12; ui_help.offset_right = -12
	ui_help.offset_top = 7; ui_help.offset_bottom = -7
	ui_help.add_theme_font_size_override("font_size", 14)
	ui_help.add_theme_color_override("font_color", Color(0.58, 0.68, 0.75))
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
	for i in range(max(0, src.size() - 1), src.size()):
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

func _body_at() -> Vector2:
	var ap: Array = combat.enc.art.pos
	return Vector2(float(ap[0]), float(ap[1])) + Vector2(0, 150)

func _limb_at(idx: int) -> Vector2:
	for st in range(5):
		if int(combat.STATION_LIMB[st]) == idx:
			return place(st).lerp(_body_at(), 0.55)
	return _body_at()

func _amount(line: String) -> int:
	var at := line.rfind(" for ")
	if at < 0:
		return 0
	return int(line.substr(at + 5).strip_edges())

const HURT := Color(0.95, 0.42, 0.32)
const DEALT := Color(0.96, 0.93, 0.80)

func _rig_frames(clip: String) -> Array:
	if _rig_cache.has(clip):
		return _rig_cache[clip]
	var out: Array = []
	for i in range(24):
		var path := "res://art/baked/%s/frame_%02d.png" % [clip, i]
		if not ResourceLoader.exists(path):
			break
		out.append(load(path))
	_rig_cache[clip] = out
	return out

func _rig_play(id: int, clip: String) -> void:
	if clip != "" and not _rig_frames(clip).is_empty():
		_danim[id] = {"clip": clip, "t0": _clock}

func _rig_react(ev: int, line: String, who: int) -> void:
	if who < 0:
		return
	match ev:
		SfxEvents.Kind.HIT:
			for ab in RIG_BY_ABILITY.keys():
				if line.find(String(ab)) >= 0:
					_rig_play(who, String(RIG_BY_ABILITY[ab]))
					return
		SfxEvents.Kind.TAKE, SfxEvents.Kind.DOWN:
			if RIG_CLIPS.has(who):
				_rig_play(who, String(RIG_CLIPS[who].hurt))

# the current frame for a diver: a one-shot clip while it lasts, idle after
func _rig_frame(id: int, down: bool) -> Texture2D:
	var base: Dictionary = RIG_CLIPS.get(id, RIG_CLIPS[0])
	if down:
		var hurt: Array = _rig_frames(String(base.hurt))
		return hurt[hurt.size() - 1] if not hurt.is_empty() else null
	if _danim.has(id):
		var st: Dictionary = _danim[id]
		var frames: Array = _rig_frames(String(st.clip))
		var f: int = int((_clock - float(st.t0)) * RIG_FPS)
		if f < frames.size():
			return frames[f]
		_danim.erase(id)
	var idle: Array = _rig_frames(String(base.idle))
	if idle.is_empty():
		return null
	return idle[int(_clock * 6.0 + float(id) * 2.0) % idle.size()]

func _draw_baked(id: int, foot: Vector2, s: float, alpha: float = 1.0) -> void:
	var tex: Texture2D = _rig_frame(id, alpha < 1.0)
	if tex == null:
		return
	var tint: Color = RIG_TINT.get(id, Color.WHITE)
	tint.a = alpha
	draw_texture_rect(tex, Rect2(foot - Vector2(352.0 * s * 0.5, 434.0 * s),
		Vector2(352.0 * s, 512.0 * s)), false, tint)

func _motion(lines: Array, from: int) -> void:
	for i in range(from, lines.size()):
		var line := String(lines[i])
		var ev: int = SfxEvents.classify(line)
		var who := _diver_named(line)
		var lb := _limb_named(line)
		_rig_react(ev, line, who)
		if ev == SfxEvents.Kind.BREAK and lb >= 0:
			_teach("break", _limb_at(lb), "broken limbs never swing again. Break every limb and the dive is won")
		elif ev == SfxEvents.Kind.HIT and lb >= 0:
			_teach("hit", _limb_at(lb) + Vector2(0, 24), "its health is the bar under its name. The bright chunk is your next hit")
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
						"hit_shove":
							# the strike carries THROUGH: the limb is sent
							# back the way the kick travels
							fx.add("lunge", 0.46, a, tgt, "", DEALT, who)
							fx.add("flash", 0.5, tgt + (tgt - a).normalized() * 26.0, Vector2.ZERO, "", DEALT, -1, lb)
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
							fx.add("ring", 0.70, tgt, Vector2.ZERO, "", Color(0.55, 0.78, 0.95), -1, lb)
							fx.add("float", 1.30, tgt + Vector2(0, -46), Vector2.ZERO, "SHUT: it cannot swing", Color(0.62, 0.84, 0.98))
						_:
							fx.add("lunge", 0.30, a, tgt, "", DEALT, who)
					fx.add("flash", 0.55, tgt, Vector2.ZERO, "", DEALT, -1, lb)
					if n > 0:
						fx.add("float", 1.20, tgt + Vector2(0, -30), Vector2.ZERO, "-%d" % n, DEALT)
					fx.kick(0.30 + 0.05 * n)
			SfxEvents.Kind.TAKE:
				# the enemy reached a station. THIS is the one that read as
				# nothing last time, so it gets the bolt, the recoil and the
				# shake rather than a number appearing somewhere.
				if who >= 0:
					var d = combat.divers[who]
					var src: Vector2 = _limb_at(lb) if lb >= 0 else Vector2(DESIGN.x * 0.8, DESIGN.y * 0.4)
					var dst: Vector2 = diver_foot(d)
					fx.add("body", 0.36, src, dst, "", HURT)
					fx.add("recoil", 0.42, src, dst, "", HURT, who)
					_strike(line, src, dst)
					fx.add("float", 1.30, dst + Vector2(0, -70), Vector2.ZERO, "-%d" % n, HURT)
					fx.kick(0.40 + 0.05 * n)
			SfxEvents.Kind.BREAK:
				if lb >= 0:
					fx.add("burst", 0.55, _limb_at(lb), Vector2.ZERO, "BROKEN", DEALT, -1, lb)
					fx.kick(0.5)
			SfxEvents.Kind.SHUTDOWN:
				if lb >= 0:
					fx.add("ring", 0.5, _limb_at(lb), Vector2.ZERO, "SHUT DOWN", Color(0.55, 0.78, 0.95), -1, lb)
			SfxEvents.Kind.READ:
				if lb >= 0:
					fx.add("ring", 0.6, _limb_at(lb), Vector2.ZERO, "", Color(0.62, 0.86, 0.98), -1, lb)
					fx.add("float", 1.3, _limb_at(lb) + Vector2(0, -40), Vector2.ZERO, "READ", Color(0.72, 0.90, 1.0))
			SfxEvents.Kind.PAYOFF:
				# every ring bursts at once: the whole thing goes quiet
				for st2 in range(5):
					if combat.station_open(st2):
						fx.add("burst", 0.85, place(st2), Vector2.ZERO, "", Color(0.98, 0.86, 0.42), -1, combat.STATION_LIMB[st2])
				fx.add("float", 1.6, Vector2(DESIGN.x * 0.5 - 120, DESIGN.y * 0.34), Vector2.ZERO,
					"THE WHOLE THING SEIZES", Color(0.98, 0.86, 0.42))
				fx.kick(0.9)
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
	if _dive > 0.0:
		_dive -= dt
		_hud(false)
		queue_redraw()
		if _dive <= 0.0:
			_refresh()
	if _hold > 0.0:
		_hold -= dt
		if _hold <= 0.0:
			_won = ""
			_refresh()
	# the board breathes even when nothing is happening, so a turn spent
	# thinking is not a still image
	queue_redraw()

func _stamp_title() -> void:
	var b: Dictionary = run.current()
	DisplayServer.window_set_title("SALVAGE beat=%s" % ("ending" if run.finished else String(b.get("id", "?"))))

func _draw_ending() -> void:
	var f: Font = ThemeDB.fallback_font
	var w: Vector2 = size.max(DESIGN)
	draw_rect(Rect2(Vector2.ZERO, w), Color(0.02, 0.05, 0.09, 0.86))
	var cx: float = w.x * 0.5 - 250.0
	var y: float = w.y * 0.30
	var lost := int(run.salvage_lost)
	var head := "THE PUMP TURNS OVER" if lost == 0 else "THE PUMP TURNS OVER, BARELY"
	draw_string(f, Vector2(cx, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.86, 0.93, 0.96))
	var rows: Array = [
		"dives cleared        %d of %d" % [Beats.LADDER.size(), Beats.LADDER.size()],
		"cargo crushed         %d" % lost,
		"the squad came back  %s" % ("whole" if lost == 0 else "lighter than it went down"),
	]
	for i in range(rows.size()):
		draw_string(f, Vector2(cx, y + 108 + 34 * float(i)), String(rows[i]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.78, 0.86, 0.90))
	draw_string(f, Vector2(cx, y + 232), "SALVAGE   a Team Ratateam prototype",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.66, 0.78, 0.84))
	draw_string(f, Vector2(cx, y + 262), "art Glass_Goat   ·   words Marc",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.66, 0.74, 0.80))

func _next_step() -> String:
	_hint_station = -1
	if run.puzzle != null:
		return _lock_step(run.puzzle)
	if combat == null:
		return "press ENTER"
	var d = combat.divers[selected]
	if d.down:
		for o in combat.divers:
			if not o.down:
				return "%s is down. Press %d to take over %s." % [d.dname, int(o.id) + 1, o.dname]
		return ""
	if combat.air <= 0 and combat.can_attack(d):
		var de: Dictionary = combat.effect_at(d, 0, Combat.Tier.DESPERATE)
		if int(de.hp_cost) < int(d.hp):
			return "The tank is empty. %s can still swing, but it costs %d of their own HP. Or press ENTER to surface and refill." % [
				d.dname, int(de.hp_cost)]
	if combat.air <= 0:
		return "The tank is empty. Press ENTER to end the turn and refill it."
	if float(d.hp) / max(1.0, float(d.max_hp)) <= 0.34:
		var hurt := "%s is at %d of %d and will go down soon." % [d.dname, int(d.hp), int(d.max_hp)]
		if int(d.station) in combat.threatened_stations():
			return hurt + "   " + _escape_line(d)
		return hurt + "   Nothing is announced where they stand: keep them there and hit with SPACE."
	if not combat.can_attack(d):
		var safe_far := -1
		for st in combat.OPEN_STATIONS:
			var lbx: int = combat.STATION_LIMB[int(st)]
			if lbx < 0 or combat.limb_broken[lbx]:
				continue
			var busy := false
			for o in combat.divers:
				if not o.down and int(o.station) == int(st):
					busy = true
			if not busy:
				safe_far = int(st)
				break
		if safe_far >= 0 and combat.can_move_now(int(d.id)):
			_hint_station = safe_far
			return "Nothing in reach from this station. Move to the glowing plate (press %s), or click it.%s" % [
				["Q", "W", "E", "R", "T"][safe_far],
				" Moving is free." if combat.move_cost(int(d.id)) == 0 else " A second move costs 1 air."]
		return "Press ENTER to end the turn."
	# standing somewhere an attack is about to land
	if int(d.station) in combat.threatened_stations():
		return _escape_line(d)
	# an attack that will land on an empty station costs the squad an air
	# line, and he watched that happen repeatedly without ever being told
	# why. Warn while it can still be avoided.
	var empty_swing := false
	for it in combat.intents():
		if int(combat.limb_stun[int(it.limb)]) > 0 or combat.limb_broken[int(it.limb)]:
			continue
		var landed := false
		for st in it.stations:
			for dd in combat.divers:
				if not dd.down and int(dd.station) == int(st):
					landed = true
		if not landed:
			empty_swing = true
	var lb2: int = combat.target_limb(d)
	if empty_swing:
		return "An attack will hit empty water and tear an air line: you lose 1 air next turn. Stand in it, or accept it."
	if lb2 >= 0 and not combat.known(lb2) and combat.air >= Combat.ANALYZE_COST and int(combat.limb_hp[lb2]) > 4:
		return "Press A to read the %s first (1 air). What it turns out to be decides whether it is worth breaking." % String(combat.LIMB_NAMES[lb2]).to_upper()
	if lb2 >= 0:
		var e0: Dictionary = combat.effect_at(d, 0, combat.tier_for(d))
		var line := "Press SPACE for %s: hit the %s for %d." % [
			String(d.kit[0].name), String(combat.LIMB_NAMES[lb2]).to_upper(), int(e0.dmg)]
		if combat.tier_for(d) == Combat.Tier.STRAINED:
			line += "   Strained: the tank is nearly out, so it lands lighter."
		if d.kit.size() > 1:
			line += "   Or F for %s." % String(d.kit[1].name)
		return line
	return "Press ENTER to end the turn."

# never leave the player holding a diver who cannot act
func _hud(v: bool) -> void:
	for c in get_children():
		if c is Panel:
			(c as Panel).visible = v

func _auto_select() -> void:
	if combat == null:
		return
	var d = combat.divers[selected]
	if not d.down:
		return
	for o in combat.divers:
		if not o.down:
			selected = int(o.id)
			return

# The one place that tells a diver how to get out of the way. Every
# suggestion it makes is legal by construction: a station must be open,
# unthreatened, EMPTY and affordable, and an attack is only offered as an
# alternative if it actually stops the hit.
func _incoming(d) -> String:
	var total := 0
	var who: Array = []
	for it in combat.locked:
		if int(combat.limb_stun[int(it.limb)]) > 0 or combat.limb_broken[int(it.limb)]:
			continue
		if int(d.station) in it.stations:
			total += int(it.dmg)
			var nm := String(combat.LIMB_NAMES[int(it.limb)]).to_upper()
			if not (nm in who):
				who.append(nm)
	if total > 0:
		return "%d lands on %s this turn (%s)" % [total, d.dname, ", ".join(who)]
	return _incoming_old(d)

func _incoming_old(d) -> String:
	for it in combat.intents():
		if int(combat.limb_stun[int(it.limb)]) > 0 or combat.limb_broken[int(it.limb)]:
			continue
		if int(d.station) in it.stations:
			return "The %s lands %d on %s this turn" % [
				String(combat.LIMB_NAMES[int(it.limb)]).to_upper(), int(it.dmg), d.dname]
	return "%s is about to be hit" % d.dname

func _escape_line(d) -> String:
	var refuge := -1
	for st in combat.OPEN_STATIONS:
		if int(st) == int(d.station) or int(st) in combat.threatened_stations():
			continue
		var occupied := false
		for o in combat.divers:
			if not o.down and int(o.station) == int(st):
				occupied = true
		if not occupied:
			refuge = int(st)
			break
	var lb: int = combat.target_limb(d)
	var kill := ""
	if lb >= 0:
		for slot in range(d.kit.size()):
			var ab: Dictionary = d.kit[slot]
			var eff: Dictionary = combat.effect_at(d, slot, combat.tier_for(d))
			if String(ab.kind) == "shut" and combat.can_shut(lb):
				kill = "or press %s to shut the %s so it cannot swing" % [
					"SPACE" if slot == 0 else "F", String(combat.LIMB_NAMES[lb]).to_upper()]
				break
			if int(eff.dmg) >= int(combat.limb_hp[lb]):
				kill = "or press %s to break the %s before it swings" % [
					"SPACE" if slot == 0 else "F", String(combat.LIMB_NAMES[lb]).to_upper()]
				break
	if refuge >= 0 and combat.can_move_now(int(d.id)):
		_hint_station = refuge
		var t := "%s  ·  about to be hit: Move to the glowing plate (press %s)" % [
			_incoming(d), ["Q", "W", "E", "R", "T"][refuge]]
		return t + ("   " + kill + "." if kill != "" else ".")
	if kill != "":
		var only: String = kill.trim_prefix("or ")
		return "%s  ·  about to be hit, nowhere clear to stand. %s%s." % [
			_incoming(d), only.substr(0, 1).to_upper(), only.substr(1)]
	return "%s  ·  about to be hit, nowhere clear to stand. Take it, and break what you can." % _incoming(d)

func _lock_step(p) -> String:
	if p.solved():
		return "The way out is open. Press ENTER to go through."
	if p.stage == 2:
		if not p.reachable(p.CROSS) and not p.valve[p.CROSS]:
			# the recovery line: a naive order locks itself out, and being
			# stuck wordless was the first playtest's wound
			return "The crossover is under water. Drain chamber B to reach it."
		return "Fill A to the line. B must end dry. A valve under water cannot be turned."
	if not p.reachable(p.SEIZED) and not p.valve[p.SEIZED]:
		return "The low valve is under water. Drop the level to reach it."
	return "Fill the chamber to the line. A valve under water cannot be turned."

var _snap_of: Combat = null
func _refresh() -> void:
	if combat != _snap_of:
		_snap_of = combat
		_turn_start = combat.clone() if combat != null and combat.outcome == "ongoing" else null
		_rewound = false
	if _dive <= 0.0:
		_hud(true)
	_auto_select()
	_stamp_title()
	_voice()
	_recent()
	if sfx != null:
		var mood := "scene"
		if run.puzzle != null: mood = "puzzle"
		elif combat != null: mood = "deep" if _depth() > 0.72 else "combat"
		sfx.set_mood(mood, _depth())
	ui_intent.get_parent().visible = true
	var hp0: Control = ui_help.get_parent()
	hp0.visible = combat == null or run.puzzle != null
	if run.puzzle != null or combat != null:
		hp0.position = Vector2(30, 166)
		hp0.size = Vector2(1220, 40)
		ui_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ui_help.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		ui_help.add_theme_font_size_override("font_size", 14)
		ui_help.add_theme_color_override("font_color", Color(0.58, 0.68, 0.75))
		hp0.add_theme_stylebox_override("panel", skin_quiet())
	var scene_p: Control = ui_scene.get_parent()
	if run.puzzle != null:
		# below the valve wheels, whose lowest rim reaches y~649
		scene_p.position = Vector2(190, 654)
		scene_p.size = Vector2(900, 62)
	else:
		scene_p.position = SCENE_PANEL_AT
		scene_p.size = SCENE_PANEL_SIZE
	if run.puzzle != null:
		# The lock, drawn as its own state: a water line and three valves.
		ui_air.get_parent().visible = false
		ui_legend.get_parent().visible = false
		ui_goal.get_parent().visible = false
		ui_intent.get_parent().visible = false
		ui_step.text = _next_step()
		ui_step.get_parent().visible = true
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
			want = "The way out sits above chamber A. Fill A to the line; B must end dry."
		else:
			want = "The way out is above the waterline. Fill the chamber to the line."
		ui_scene.text = want
		var vk := ["1", "2", "3", "4"]
		var labels: Array = []
		for i in range(run.puzzle.valves()):
			labels.append("%s=%s" % [vk[i], "crossover" if (run.puzzle.stage == 2 and i == run.puzzle.CROSS) else "valve %d" % (i + 1)])
		ui_help.text = "click a valve to turn it  ·  ENTER when the way is open"
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
		ui_step.get_parent().visible = false
		var b: Dictionary = run.current()
		var lines: Array = b.get("lines", [])
		var body: Array = []
		var controls := "that is the whole prototype  ·  refresh the page to dive again" if run.finished else "ENTER to continue"
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
		sp3.position = Vector2(200, 366)
		sp3.size = Vector2(880, 292)
		var hp3: Control = ui_help.get_parent()
		var bw: float = 300.0 if controls.length() < 24 else 660.0
		hp3.position = Vector2(640.0 - bw * 0.5, 664)
		hp3.size = Vector2(bw, 52)
		ui_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ui_help.add_theme_font_size_override("font_size", 19)
		ui_help.add_theme_color_override("font_color", BRASS_LIT)
		hp3.add_theme_stylebox_override("panel", skin_primary())
		ui_scene.text = "\n\n".join(body)
		ui_scene.get_parent().visible = body.size() > 0
		ui_help.text = controls
		queue_redraw()
		return
	ui_scene.get_parent().visible = false
	var step := _next_step()
	if refusal != "":
		step = refusal
	ui_step.text = step
	# only interrupt when there is a decision to make; a narrator on every
	# routine turn teaches the player to stop reading the one line that
	# sometimes matters
	var urgent := step.find("about to be hit") >= 0 or step.find("go down soon") >= 0 \
		or step.find("tank is empty") >= 0 or step.find("read the") >= 0 \
		or step.find("Nothing to hit") >= 0 or combat == null or refusal != ""
	ui_step.get_parent().visible = step != "" and urgent
	ui_air.get_parent().visible = true
	# the bottles: full ones lit brass, spent ones dark, ones cut off by a
	# severed line crossed out in red
	for i in range(ui_tanks.size()):
		var t: ColorRect = ui_tanks[i]
		t.visible = true
		if i < combat.air:
			t.color = BRASS_LIT
		elif i < combat.air_this_turn():
			t.color = Color(0.20, 0.19, 0.16)
		else:
			t.color = Color(0.42, 0.16, 0.13)
	ui_legend.get_parent().visible = false
	ui_goal.get_parent().visible = true
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
		# the tag stands on the far side of its station from the creature,
		# so the board's words ring the body instead of covering it. The
		# HUD budget gate samples the body and fails any tag that drifts
		# back over it.
		var body0: Vector2 = _body_at()
		# the chip is the station's GROUND PLATE: it sits under the ring,
		# under the feet of whoever stands there, never on a sprite and
		# never between the station and the creature. Cold readers saw
		# the old floating placement as the player's own health bar.
		# a plate under a belly ring has no legal room (card row below,
		# creature window above), so below-body plates start BESIDE their
		# ring, outward from the body, at ring height: adjacent and
		# findable instead of slid to a far corner
		var side_out: float = 1.0 if place(i).x >= body0.x else -1.0
		var tag_at: Vector2
		if place(i).y >= body0.y - 20.0:
			tag_at = place(i) + Vector2(side_out * 166.0 - mk.size.x * 0.5, 4.0)
		else:
			tag_at = place(i) + Vector2(0, 34.0) - Vector2(mk.size.x * 0.5, 0)
		var slide_x: float = side_out * 56.0
		for _try in range(9):
			tag_at.x = clampf(tag_at.x, 284.0, 1280.0 - mk.size.x - 8.0)
			tag_at.y = clampf(tag_at.y, 258.0, 566.0 - mk.size.y)
			var rect := Rect2(tag_at, mk.size)
			var nearest := Vector2(clampf(body0.x, rect.position.x, rect.end.x),
				clampf(body0.y, rect.position.y, rect.end.y))
			if nearest.distance_to(body0) >= 112.0:
				break
			if place(i).y < body0.y - 20.0:
				tag_at.y -= 34.0
				if tag_at.y <= 258.0:
					tag_at.x += slide_x
			elif tag_at.y < 566.0 - mk.size.y - 1.0:
				tag_at.y += 40.0
			else:
				tag_at.x += slide_x
		# plates may not stack: a plate that lands on an earlier one slides
		# straight down, and up only when the floor runs out
		for _try2 in range(5):
			var mine := Rect2(tag_at, mk.size)
			var clear := true
			for j in range(i):
				if not combat.station_open(j):
					continue
				var other := Rect2(ui_stations[j].position, ui_stations[j].size)
				if mine.grow(4.0).intersects(other):
					clear = false
			if clear:
				break
			tag_at.y += 48.0
			if tag_at.y > 566.0 - mk.size.y:
				tag_at.y -= 144.0
			tag_at.x = clampf(tag_at.x, 284.0, 1280.0 - mk.size.x - 8.0)
			tag_at.y = clampf(tag_at.y, 258.0, 566.0 - mk.size.y)
		mk.position = tag_at
		# The limb bar. This was written once and lost: the script carrying
		# it aborted on a failing anchor further down and never reached the
		# write, so limb health has been TEXT ONLY ever since -- which is
		# exactly what the playtester ran into.
		var bgr: ColorRect = mk.get_node("bar_bg")
		var flr: ColorRect = mk.get_node("bar_fill")
		var lb0: int = combat.STATION_LIMB[i]
		var show_bar := false
		bgr.visible = show_bar
		flr.visible = show_bar
		if show_bar:
			var mx: float = float(int((combat.enc.limbs[lb0] as Dictionary).hp))
			var fr: float = clampf(float(combat.limb_hp[lb0]) / max(1.0, mx), 0.0, 1.0)
			bgr.position = Vector2(8, mk.size.y - 11)
			bgr.size = Vector2(mk.size.x - 16, 7)
			flr.position = bgr.position
			flr.size = Vector2(bgr.size.x * fr, 8)
			# the preview chunk: the part of this bar the selected diver's
			# SPACE would remove, bright at the fill's leading edge
			var pv: ColorRect = mk.get_node("bar_preview")
			pv.visible = false
			var ds = combat.divers[selected]
			if not ds.down and combat.target_limb(ds) == lb0 and combat.outcome == "ongoing":
				var ef: Dictionary = combat.effect_at(ds, 0, combat.tier_for(ds))
				var would: int = combat._after_trait(lb0, int(ef.dmg)) if combat.known(lb0) else int(ef.dmg)
				if would > 0:
					var wfrac: float = clampf(float(would) / max(1.0, mx), 0.0, fr)
					pv.visible = true
					pv.position = Vector2(bgr.position.x + bgr.size.x * (fr - wfrac), bgr.position.y)
					pv.size = Vector2(bgr.size.x * wfrac, 8)
			# and it flashes white the instant it is struck
			flr.color = BAR_LIMB.lerp(Color(1, 1, 1), fx.limb_flash(lb0))
		# The limb IS the position, so the marker has to SAY the limb and
		# how much of it is left. A blind reviewer found no enemy health
		# readout anywhere on screen, which made the whole limb system
		# invisible.
		var lb: int = combat.STATION_LIMB[i]
		var lbl: Label = ui_stations[i].get_node("label")
		# the plate is the STATION: where a diver can stand, and the key
		# that walks there. The limb's name, health and trait draw on the
		# creature at the limb itself (_draw_limb_bars): two rounds of
		# cold reads proved a limb bar at a station reads as belonging to
		# whoever stands there
		lbl.text = "%s  [%s]" % [Combat.STATION_NAMES[i], String(keys2[i])]
	# A cut line must READ as a cut line. This showed "AIR 3 / 3" after the
	# umbilical rule fired, so the pool and its ceiling shrank together and
	# the player could not tell anything had been taken from them.
	var live_divers := 0
	for da in combat.divers:
		if not da.down:
			live_divers += 1
	if combat.air_penalty > 0:
		ui_air.text = "AIR  %d of 4   ·   %d line cut" % [combat.air, combat.air_penalty]
	else:
		ui_air.text = "AIR  %d of 4%s" % [combat.air, "   ·   one shared tank" if live_divers > 1 else ""]
	var live := 0
	for lb in range(combat.limb_broken.size()):
		if not combat.limb_broken[lb]:
			live += 1
	var told := ""
	for lb9 in range(combat.limb_hp.size()):
		if combat.limb_broken[lb9] or not combat.known(lb9):
			continue
		var tr9 := combat.trait_of(lb9)
		if tr9 != "":
			told = "%s  ·  %s" % [String(combat.LIMB_NAMES[lb9]).to_upper(), String(Combat.TRAITS[tr9])]
			break
	# retired in fights: the finding now rides the limb's own chip in
	# compact form, where a reviewer does not have to hunt for its limb
	ui_goal.get_parent().visible = false
	ui_goal.text = told
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
			if shut:
				parts.append("%s: SHUT DOWN, it does not swing this turn" % String(combat.LIMB_NAMES[int(it.limb)]))
			else:
				parts.append("%s %s %s for %d" % [String(combat.LIMB_NAMES[int(it.limb)]), it.name, "/".join(where), int(it.dmg)])
		# the arcs and discs on the board are the announcement; the words
		# only carry what drawing cannot: a shut limb's reprieve
		var told_shut := ""
		for pt in parts:
			if String(pt).find("SHUT DOWN") >= 0:
				told_shut = "   ·   " + String(pt)
		ui_intent.text = run.state_line() + told_shut
	# the party size is content, not a constant: fight one runs two divers.
	# This loop assumed three and printed a raw format string on the third
	# card, which the as-played capture caught on its first frame.
	var live_cards := 0
	for d0 in combat.divers:
		live_cards += 1
	for i in range(ui_divers.size()):
		ui_divers[i].position = Vector2(24.0 + float(i) * 334.0, CARD_TOP)
		var card: Panel = ui_divers[i]
		if i >= combat.divers.size():
			card.visible = false
			continue
		card.visible = true
		var d = combat.divers[i]
		card.add_theme_stylebox_override("panel", skin_primary() if i == selected else skin_card())
		var state := "DOWN this fight" if d.down else "%d/%d HP" % [d.hp, d.max_hp]
		var afford := "" if combat.air >= d.cost else "   cannot afford"
		var lines: Array = []
		for slot in range(d.kit.size()):
			var ab: Dictionary = d.kit[slot]
			var key := "SPACE" if slot == 0 else "F"
			var tier: int = combat.tier_for(d)
			var eff: Dictionary = combat.effect_at(d, slot, tier)
			var what := ""
			match String(ab.kind):
				"hit": what = "%d dmg" % int(eff.dmg)
				"hit_and_step": what = "%d dmg, then move free" % int(eff.dmg)
				"hit_wide": what = "%d dmg here and either side" % int(eff.dmg)
				"shut": what = ("%d dmg, " % int(eff.dmg) if int(eff.dmg) > 0 else "no damage, ") + "the limb cannot attack for %d turn%s" % [int(eff.turns), "" if int(eff.turns) == 1 else "s"]
			var tag := ""
			if tier == Combat.Tier.STRAINED:
				tag = "   (strained)"
			elif tier == Combat.Tier.DESPERATE:
				tag = "   (costs %d HP: the tank is empty)" % int(eff.hp_cost)
			lines.append("%s %s: %s%s" % [key, String(ab.name), what, tag])
		# the target once, at the top, instead of on every ability line
		var onto := ""
		if not combat.can_attack(d):
			onto = "  ·  nothing to hit from %s" % Combat.STATION_NAMES[int(d.station)]
		else:
			var tl: int = combat.target_limb(d)
			if tl >= 0:
				onto = "  ·  hits %s %d/%d" % [String(combat.LIMB_NAMES[tl]).to_upper(),
					int(combat.limb_hp[tl]), int((combat.enc.limbs[tl] as Dictionary).hp)]
		# the roster row says who and how healthy; the board says where
		# and what they threaten (cold readers called the rest console
		# output, and they were right)
		var num := "%d  " % (i + 1) if combat.divers.size() > 1 else ""
		card.get_node("label").text = "%s%s   %s%s" % [num, d.dname, state, afford]

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
	queue_redraw()

# ---- the player's door. The bot calls these same Combat methods. -------
# A refused input must say WHY. Silence is how a player concludes the game
# is broken rather than that they cannot afford the action.
# Half the kit was unreachable: six abilities existed in the sim and the
# bots used all six, while the player had one key. A blind reviewer put it
# plainly: "there is nothing on screen indicating a second or alternate
# attack for either character."
# Marc's Analyze step. Reading a limb costs 1 air and tells you what it
# turns out to be, which is what makes the ORDER you break things a
# decision rather than a chore.
func player_analyze() -> bool:
	var ok := combat.act_analyze(selected)
	if ok:
		refusal = ""
		_after()
	else:
		var d = combat.divers[selected]
		var lb: int = combat.target_limb(d)
		if lb >= 0 and combat.known(lb):
			refusal = "the %s has already been read" % String(combat.LIMB_NAMES[lb]).to_upper()
		elif lb < 0:
			refusal = "nothing to read from %s" % Combat.STATION_NAMES[int(d.station)]
		else:
			refusal = "not enough air to read a limb"
		_refresh()
	return ok

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
		elif not combat.can_move_now(selected): refusal = "the free move is spent and there is no air for another"
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

# ---- the action bar: ids, legality, dispatch, geometry -----------------
# Every sim-legal action has a button; the keyboard is a shortcut for the
# same dispatcher. Legality is answered by trying the action on a CLONE,
# so the greyed state can never disagree with what a press would do.
func action_legal(id: String) -> bool:
	if combat == null or combat.outcome != "ongoing":
		return false
	var c2: Combat = combat.clone()
	match id:
		"ability0": return c2.act_ability(selected, 0)
		"ability1": return c2.act_ability(selected, 1)
		"analyze": return c2.act_analyze(selected)
		"rewind": return not _rewound and _turn_start != null
		"end": return true
	return false

func _action(id: String) -> void:
	match id:
		"ability0": player_ability(0)
		"ability1": player_ability(1)
		"analyze": player_analyze()
		"rewind": rewind_turn()
		"end":
			player_end_turn()
			_refresh()

func bar_buttons() -> Array:
	if combat == null or combat.outcome != "ongoing":
		return []
	var d = combat.divers[selected]
	var out: Array = []
	var tier: int = combat.tier_for(d)
	for slot in range(min(2, d.kit.size())):
		var ab: Dictionary = d.kit[slot]
		var eff: Dictionary = combat.effect_at(d, slot, tier)
		var what := ""
		match String(ab.kind):
			"hit": what = "%d dmg" % int(eff.dmg)
			"hit_shove": what = "%d dmg, pushes its swing off you" % int(eff.dmg)
			"hit_and_step": what = "%d dmg, then step free" % int(eff.dmg)
			"hit_wide": what = "%d dmg, spills to both sides" % int(eff.dmg)
			"shut": what = "shuts the limb %d turn%s" % [int(eff.turns), "" if int(eff.turns) == 1 else "s"]
		if tier == Combat.Tier.DESPERATE:
			what += "  costs %d HP" % int(eff.hp_cost)
		out.append({"id": "ability%d" % slot,
			"label": "%s  %d air  [%s]" % [String(ab.name), int(d.cost), "SPACE" if slot == 0 else "F"],
			"sub": what})
	out.append({"id": "analyze", "label": "Read limb  1 air  [A]", "sub": "what is it weak to?"})
	out.append({"id": "rewind", "label": "Rewind turn  [U]", "sub": "take the turn back, once a dive"})
	out.append({"id": "end", "label": "End turn  [ENTER]", "sub": ""})
	return out

func btn_rect(i: int, _n: int) -> Rect2:
	return Rect2(Vector2(BAR_X, BAR_TOP + float(i) * (BAR_H + BAR_GAP)), Vector2(238.0, BAR_H))

func rewind_turn() -> bool:
	if _rewound or _turn_start == null or combat == null or combat.outcome != "ongoing":
		return false
	combat = _turn_start.clone()
	if run != null:
		run.combat = combat
	_rewound = true
	refusal = ""
	combat.log_lines.append("the turn is wound back; once a dive")
	_refresh()
	return true

func player_end_turn() -> void:
	combat.end_turn()
	_turn_start = combat.clone() if combat.outcome == "ongoing" else null
	_after()

# A finished fight advances the ladder. The run owns progression; the
# scene only asks it to move.
# Winning cut straight to the next screen, so the moment you won was the
# moment the thing you won against vanished. Hold it.
var _hold := 0.0
var _dive := 0.0        # seconds left of the descent between beats
var _won := ""
var _hint_station := -1

func _after() -> void:
	if combat != null and combat.outcome != "ongoing":
		_dive = 3.2
		_hud(false)
		_won = ("%s IS DISABLED" % String(combat.enc.get("title", "the enemy")).to_upper()) if combat.outcome == "victory" else "THE SQUAD IS LOST"
		_hold = 3.2
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
		KEY_A: player_analyze()
		KEY_U:
			if combat != null:
				rewind_turn()
		KEY_SPACE: player_ability(0)
		KEY_F: player_ability(1)
		KEY_LEFT, KEY_RIGHT:
			# step along the open stations, because a player who does not
			# know the letters yet still knows the arrows
			if combat != null:
				var open: Array = combat.OPEN_STATIONS
				var at: int = open.find(int(combat.divers[selected].station))
				var step: int = -1 if k == KEY_LEFT else 1
				if at >= 0:
					player_move(int(open[posmod(at + step, open.size())]))
		KEY_UP, KEY_DOWN:
			if combat != null and combat.divers.size() > 1:
				_select(posmod(selected + (1 if k == KEY_DOWN else -1), combat.divers.size()))
				_refresh()
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
	# an OPEN wheel is bright gold and visibly TURNING; a shut one is a
	# still steel cross; an unreachable one is drowned dark. Cold readers
	# called four identical wheels with no feedback, and after the chrome
	# demotion they were right.
	var col: Color = Color(0.95, 0.82, 0.42) if is_open else Color(0.42, 0.46, 0.50)
	if not is_open and not reachable:
		col = Color(0.30, 0.28, 0.26)      # under water: cannot be turned
	draw_circle(at, 19, Color(0.10, 0.11, 0.12))
	draw_arc(at, 17, 0, TAU, 28, col, 4.0)
	# spokes, so it reads as a wheel you turn, spinning while it flows
	for k in range(4):
		var ang: float = float(k) * PI * 0.5 + (_clock * 1.6 if is_open else 0.0)
		var dirv := Vector2(cos(ang), sin(ang))
		draw_line(at + dirv * 4.0, at + dirv * 15.0, col, 3.0)
	draw_circle(at, 5.0, col)
	var f: Font = ThemeDB.fallback_font
	draw_string(f, at + Vector2(24, 6), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.86, 0.90, 0.94))
	if not is_open and not reachable:
		draw_string(f, at + Vector2(-40, -26), "under water", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.78, 0.74, 0.68))

func _chamber(at: Vector2, wide: float, tall: float, filled: int, cap: int, name: String) -> void:
	# steel walls with rivets down them, not a wireframe
	draw_rect(Rect2(at - Vector2(9, 0), Vector2(wide + 18, tall + 9)), Color(0.115, 0.130, 0.145))
	for ry in range(int(tall / 34.0)):
		var yy: float = at.y + 18.0 + float(ry) * 34.0
		draw_rect(Rect2(Vector2(at.x - 6, yy), Vector2(4, 4)), RIVET)
		draw_rect(Rect2(Vector2(at.x + wide + 2, yy), Vector2(4, 4)), RIVET)
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
	draw_rect(Rect2(at, Vector2(wide, tall)), Color(0.40, 0.46, 0.52), false, 2.0)
	# the graduations, so "2 of 3" is countable and not just a bar
	for m in range(1, cap):
		var y: float = at.y + tall - tall * (float(m) / float(cap))
		draw_line(Vector2(at.x, y), Vector2(at.x + 14, y), Color(0.55, 0.66, 0.74, 0.35), 1.0)
	var f: Font = ThemeDB.fallback_font
	# above the tank, clear of the pipes that run below it
	# under the tank, where nothing else is written
	# clear of the pipes, which run from the tank floor down to the valves
	draw_string(f, at + Vector2(10, 26), "%s  %d of %d" % [name, filled, cap],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.80, 0.86, 0.90))

func _door(at: Vector2, wide: float, is_open: bool) -> void:
	var f: Font = ThemeDB.fallback_font
	draw_rect(Rect2(at, Vector2(wide, 22)), Color(0.155, 0.165, 0.175))
	draw_rect(Rect2(at, Vector2(wide, 22)), OPEN_C if is_open else BRASS, false, 2.0)
	for k in range(int(wide / 46.0)):
		draw_rect(Rect2(at + Vector2(14.0 + float(k) * 46.0, 8), Vector2(5, 5)), RIVET)
	# a dashed line across the chamber marking the height the water has to
	# reach, so "fill it to the top" is a picture
	for i in range(16):
		if i % 2 == 1:
			continue
		var x0: float = at.x + wide * float(i) / 16.0
		draw_line(Vector2(x0, at.y + 26), Vector2(x0 + wide / 16.0, at.y + 26),
			Color(0.86, 0.78, 0.42, 0.75), 2.0)
	draw_string(f, at + Vector2(6, 44), "the way out" + ("  OPEN" if is_open else "  ·  fill to this line"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, OPEN_C if is_open else Color(0.90, 0.82, 0.48))

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
	# the rig: a deck on legs, wide enough to be a stage. The interludes
	# ARE the cutscenes this prototype gets, so the tableau earns it: a
	# full-width deck, gantry, davit, the blinking pump, deck lamps that
	# pool light under the cast, and the squad at close to combat scale.
	var dx: float = w.x * 0.5 - 300.0
	draw_rect(Rect2(Vector2(dx, surf - 54), Vector2(600, 30)), Color(0.20, 0.22, 0.24))
	draw_rect(Rect2(Vector2(dx, surf - 60), Vector2(600, 6)), Color(0.28, 0.30, 0.32))
	draw_rect(Rect2(Vector2(dx - 16, surf - 128), Vector2(96, 74)), Color(0.24, 0.26, 0.28))
	draw_rect(Rect2(Vector2(dx + 10, surf - 112), Vector2(28, 20)), Color(0.10, 0.16, 0.20))
	# the davit arm and its cable, the thing that lowers them every dive
	draw_line(Vector2(dx + 520, surf - 58), Vector2(dx + 520, surf - 150), Color(0.26, 0.28, 0.30), 8.0)
	draw_line(Vector2(dx + 516, surf - 148), Vector2(dx + 600, surf - 120), Color(0.26, 0.28, 0.30), 6.0)
	draw_line(Vector2(dx + 598, surf - 122), Vector2(dx + 598, surf - 30), Color(0.40, 0.44, 0.46, 0.8), 2.0)
	# the failing pump, blinking on its own housing
	var lit: float = 0.35 + 0.65 * abs(sin(_clock * 2.3))
	draw_rect(Rect2(Vector2(dx + 428, surf - 96), Vector2(56, 42)), Color(0.24, 0.26, 0.28))
	draw_circle(Vector2(dx + 456, surf - 104), 6.0, Color(0.92, 0.44, 0.30, lit))
	for lx in [dx + 30.0, dx + 210.0, dx + 390.0, dx + 560.0]:
		draw_line(Vector2(lx, surf - 26), Vector2(lx + 12.0, surf + 110.0), Color(0.18, 0.20, 0.22), 8.0)
	# deck lamps pooling light on the cast
	for lp in [dx + 150.0, dx + 300.0, dx + 450.0]:
		draw_circle(Vector2(lp, surf - 130), 4.0, Color(0.95, 0.88, 0.60, 0.9))
		draw_colored_polygon(PackedVector2Array([
			Vector2(lp - 6, surf - 126), Vector2(lp + 6, surf - 126),
			Vector2(lp + 52, surf - 28), Vector2(lp - 52, surf - 28)]),
			Color(0.92, 0.86, 0.60, 0.05 + 0.02 * sin(_clock * 1.7 + lp)))
	# the squad at stage scale, spaced like a poster, not a chess row
	for i in range(3):
		_draw_baked(i, Vector2(dx + 152.0 + float(i) * 148.0, surf - 52.0) + fx.idle(i), 0.26)
	var b: Dictionary = run.current()
	if _dive > 0.0:
		return
	var title := String(b.get("title", "")).to_upper()
	draw_string(f, Vector2(w.x * 0.5 - 300.0, surf + 84.0), title,
		HORIZONTAL_ALIGNMENT_CENTER, 600.0, 34, Color(0.88, 0.93, 0.96))
	draw_string(f, Vector2(w.x * 0.5 - 300.0, surf + 112.0), "dive %d of %d" % [run.beat + 1, Beats.LADDER.size()],
		HORIZONTAL_ALIGNMENT_CENTER, 600.0, 17, Color(0.55, 0.66, 0.72))

# _valve_pos and this function each kept their own copy of the tank
# geometry, and they had drifted: the drawing moved to top 322 while the
# click test still believed 250, so every valve was clickable 72px from
# where it was drawn. One constant, read by both -- the same fix the ring
# and the legend needed when they disagreed.
func _flow(a: Vector2, b: Vector2, on: bool) -> void:
	# beads sliding a to b while the pipe is open: water MOVING, so which
	# valve feeds which chamber is watchable, not decodable. "Why doesn't
	# the water flow... I could have figured this out" -- now it flows.
	if not on:
		return
	var n := int(a.distance_to(b) / 34.0) + 1
	for k in range(n):
		var ph := fposmod(_clock * 0.55 + float(k) / float(n), 1.0)
		var at := a.lerp(b, ph)
		var pulse := 0.65 + 0.35 * sin(_clock * 6.0 + float(k))
		draw_circle(at, 4.0, Color(0.55, 0.85, 0.95, 0.85 * pulse))

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
		_flow(Vector2(ax + wide, pipe_y), Vector2(bx, pipe_y), bool(p.valve[p.CROSS]))
		_valve_dot(_valve_pos(p.CROSS), "4", p.valve[p.CROSS], p.reachable(p.CROSS))
		for src in [[0, ax + 60.0], [1, ax + 170.0], [2, bx + 110.0]]:
			var vp: Vector2 = _valve_pos(int(src[0]))
			draw_line(vp + Vector2(0, -18), Vector2(float(src[1]), top + tall),
				OPEN_C if p.valve[int(src[0])] else Color(0.42, 0.48, 0.55), 7.0)
			_flow(vp + Vector2(0, -18), Vector2(float(src[1]), top + tall), bool(p.valve[int(src[0])]))
		_valve_dot(_valve_pos(0), "1", p.valve[0], true)
		_valve_dot(_valve_pos(1), "2", p.valve[1], true)
		_valve_dot(_valve_pos(2), "3", p.valve[2], true)
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
		_flow(vp2 + Vector2(0, -18), Vector2(float(src2[1]), top + tall), bool(p.valve[int(src2[0])]))
	_valve_dot(_valve_pos(0), "1", p.valve[0], p.reachable(0))
	_valve_dot(_valve_pos(1), "2", p.valve[1], p.reachable(1))
	# a pipe for the seized valve too, so all three are visibly plumbed
	draw_line(_valve_pos(p.SEIZED) - Vector2(18, 0), Vector2(x + wide, top + tall - 26.0),
		OPEN_C if p.valve[p.SEIZED] else Color(0.42, 0.48, 0.55), 7.0)
	_flow(_valve_pos(p.SEIZED) - Vector2(18, 0), Vector2(x + wide, top + tall - 26.0), bool(p.valve[p.SEIZED]))
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
# the descent: what the story keeps saying happens between beats and the
# game never showed. Silt tears upward, the light narrows, and the place
# you are going is named on the way down.
func _draw_dive(k: float) -> void:
	var f: Font = ThemeDB.fallback_font
	var w: Vector2 = size.max(DESIGN)
	var fade: float = min(1.0, k * 2.2) if k < 0.5 else min(1.0, (1.0 - k) * 2.2)
	draw_rect(Rect2(Vector2.ZERO, w), Color(0.01, 0.03, 0.055, 0.92 * fade))
	for i in range(80):
		var x: float = fmod(float(i) * 211.7, w.x)
		var y: float = fmod(float(i) * 97.3 + (1.0 - k) * 2600.0, w.y)
		var len: float = 30.0 + float(i % 5) * 26.0
		draw_line(Vector2(x, y), Vector2(x, y + len), Color(0.62, 0.82, 0.92, 0.30 * fade), 2.0)
	# the dive itself is the cutscene: the squad sinking through the
	# dark in their own bodies, lamp cones on, bubbles rising past them.
	# The rig's clips were on the board all night; now they are in the
	# transition too.
	var sink: float = w.y * 0.30 + k * -70.0
	for i in range(3):
		var sway: float = sin(_clock * 1.4 + float(i) * 2.1) * 10.0
		var foot := Vector2(w.x * 0.5 - 120.0 + float(i) * 120.0 + sway, sink + float(i % 2) * 34.0)
		# a soft lamp cone under each diver, pointing down into the dark
		draw_colored_polygon(PackedVector2Array([
			foot + Vector2(-7, -30), foot + Vector2(7, -30),
			foot + Vector2(30, 90.0), foot + Vector2(-30, 90.0)]),
			Color(0.85, 0.90, 0.70, 0.05 * fade))
		_draw_baked(i, foot, 0.17, fade)
		for bb in range(4):
			var byy: float = fposmod(float(bb) * 37.0 + _clock * 60.0, 140.0)
			draw_circle(foot + Vector2(-14.0 + float(bb % 3) * 12.0, -60.0 - byy),
				2.0 + float(bb % 2), Color(0.75, 0.90, 0.96, 0.35 * fade * (1.0 - byy / 140.0)))
	var b: Dictionary = run.current()
	if _won != "":
		draw_string(f, Vector2(w.x * 0.5 - 340.0, w.y * 0.62 - 58.0), _won,
			HORIZONTAL_ALIGNMENT_CENTER, 680.0, 30, Color(0.90, 0.72, 0.38, fade))
	var word := "SURFACING" if String(b.get("kind", "scene")) == "scene" or run.finished else "DESCENDING"
	draw_string(f, Vector2(w.x * 0.5 - 300.0, w.y * 0.62), word,
		HORIZONTAL_ALIGNMENT_CENTER, 600.0, 26, Color(0.72, 0.86, 0.92, fade))
	draw_string(f, Vector2(w.x * 0.5 - 300.0, w.y * 0.62 + 42.0), String(b.get("title", "")).to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, 600.0, 34, Color(0.92, 0.95, 0.97, fade))

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
	# the drowned city, far off and getting closer as you go down. Kept very
	# low contrast on purpose: it is the reason the frame has a floor and a
	# horizon, not something to look at instead of the fight.
	var far: Color = Color(0.10, 0.19, 0.24).lerp(Color(0.045, 0.085, 0.13), d)
	var near: Color = Color(0.075, 0.145, 0.19).lerp(Color(0.03, 0.06, 0.10), d)
	var sky: float = w.y * (0.50 + 0.10 * d)
	# a far skyline of towers: broken rooflines and antenna spikes, so the
	# city reads as a drowned city rather than placeholder blocks (the
	# cold reads called the flat rectangles greybox, and they were)
	for i in range(11):
		var bx0: float = w.x * (float(i) / 11.0) - 40.0 + sin(float(i) * 2.3) * 30.0
		var bw: float = 52.0 + float((i * 37) % 60)
		var bh: float = 60.0 + float((i * 53) % 150)
		draw_rect(Rect2(Vector2(bx0, sky - bh), Vector2(bw, bh + 40.0)), far)
		match i % 3:
			0:
				# a collapsed corner
				draw_colored_polygon(PackedVector2Array([
					Vector2(bx0, sky - bh), Vector2(bx0 + bw * 0.45, sky - bh),
					Vector2(bx0, sky - bh + 26.0)]), top.lerp(bot, 0.5))
			1:
				# an antenna mast, snapped partway
				var mx2: float = bx0 + bw * 0.6
				draw_line(Vector2(mx2, sky - bh), Vector2(mx2 + 5.0, sky - bh - 34.0), far, 3.0)
			2:
				# a water tank silhouette on the roof
				draw_rect(Rect2(Vector2(bx0 + bw * 0.2, sky - bh - 14.0), Vector2(18.0, 14.0)), far)
	# a middle skyline between them: the missing value step that made
	# depth read as binary (visual assessment F-004)
	var mid: Color = far.lerp(near, 0.5).lightened(0.05)
	for i in range(9):
		var mx0: float = w.x * (float(i) / 9.0) - 55.0 + sin(float(i) * 3.1) * 38.0
		var mw: float = 70.0 + float((i * 43) % 70)
		var mh: float = 50.0 + float((i * 61) % 110)
		var mtop: float = sky - mh * 0.6 + 60.0
		draw_rect(Rect2(Vector2(mx0, mtop), Vector2(mw, mh + 60.0)), mid)
		# dead windows: dark pits in a grid, a few of them faintly lit as
		# if something down there still has power
		for wy in range(2):
			for wx in range(int(mw / 26.0)):
				var wat := Vector2(mx0 + 8.0 + float(wx) * 26.0, mtop + 12.0 + float(wy) * 22.0)
				var lit2: bool = ((i * 7 + wx * 3 + wy) % 11) == 0
				draw_rect(Rect2(wat, Vector2(9.0, 12.0)),
					Color(0.55, 0.75, 0.55, 0.10) if lit2 else Color(0.0, 0.0, 0.0, 0.22))
	# and a nearer one, lower and darker, which gives the floor its edge
	for i in range(8):
		var cx0: float = w.x * (float(i) / 8.0) - 70.0 + cos(float(i) * 1.7) * 44.0
		var cw: float = 90.0 + float((i * 71) % 90)
		var ch: float = 40.0 + float((i * 29) % 90)
		draw_rect(Rect2(Vector2(cx0, w.y - ch - 60.0), Vector2(cw, ch + 90.0)), near)
	draw_rect(Rect2(Vector2(0, w.y - 60.0), Vector2(w.x, 60.0)), near)
	# kelp on the near band, swaying: the one living thing in the frame
	# beside the fight
	for i in range(7):
		var kx: float = w.x * (float(i) + 0.5) / 7.0 + float((i * 29) % 40)
		var kh: float = 60.0 + float((i * 47) % 80)
		var prev2 := Vector2(kx, w.y - 40.0)
		for sgm in range(4):
			var t3: float = float(sgm + 1) / 4.0
			var sway2: float = sin(_clock * 0.8 + float(i) * 1.7 + t3 * 2.0) * 10.0 * t3
			var nxt := Vector2(kx + sway2, w.y - 40.0 - kh * t3)
			draw_line(prev2, nxt, Color(0.10, 0.22, 0.16, 0.55), 4.0 - t3 * 2.0)
			prev2 = nxt

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
				var pip0: Vector2 = dst + Vector2(0.0, -64.0)
				if int(st) in drawn:
					continue
				drawn.append(int(st))
				draw_circle(pip0, 15.0, Color(0.10, 0.05, 0.06, 0.92))
				draw_arc(pip0, 15.0, 0, TAU, 20, Color(0.98, 0.50, 0.38, 0.90), 2.0)
				draw_string(f, pip0 + Vector2(-10 if int(incoming.get(int(st), 0)) < 10 else -15, 7), "-%d" % int(incoming.get(int(st), 0)),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.82, 0.74))
				continue
			var n: Vector2 = dir.normalized()
			var a: Vector2 = src + n * 30.0
			var b: Vector2 = dst - n * 48.0
			# stroke and alpha lifted: the arc is the only attacker-victim
			# link on the board and it was drowning at 2px
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
				draw_line(prev, q, Color(0.98, 0.46, 0.34, 0.48 + 0.45 * pulse * t),
					3.2 + 5.5 * t)
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
		# a solved lock opens to a click anywhere, like every other scene:
		# the mouserun gate proved the door only answered to ENTER
		if run.puzzle.solved():
			run.advance(); combat = run.combat; selected = 0; _refresh()
		return
	if combat == null:
		run.advance(); combat = run.combat; selected = 0; _refresh()
		return
	# the action bar first: it sits over nothing else clickable
	var btns: Array = bar_buttons()
	for i in range(btns.size()):
		if btn_rect(i, btns.size()).has_point(at):
			_action(String(btns[i].id))
			return
	for i in range(combat.divers.size()):
		var card: Control = ui_divers[i]
		if card.visible and card.get_global_rect().has_point(at):
			_select(i)
			_refresh()
			return
	# a diver's body selects the diver; the third playtest clicked bodies
	# expecting exactly that and moved someone instead. The SELECTED
	# diver's body falls through to the attack path: with UNDER below the
	# belly, its occupant's select radius shadowed the whole creature and
	# mouse attacks silently died (the mouserun gate caught it as fifteen
	# turns of clicks that never landed)
	for i in range(combat.divers.size()):
		var dd = combat.divers[i]
		if i != selected and not dd.down and at.distance_to(diver_foot(dd) + Vector2(0, -40)) < 30.0:
			_select(i)
			_refresh()
			return
	# the ground plates are the movement handles: labeled, keyed, and
	# glowing when the prompt points at one. They exist because UNDER now
	# sits beneath the belly, where a bare click radius and the creature's
	# own body fought over the same pixels (clicking the crab MOVED you
	# under it; the mouserun gate caught fifteen turns of that)
	for st in range(5):
		if not combat.station_open(st):
			continue
		var chip: Control = ui_stations[st]
		if chip.visible and Rect2(chip.position, chip.size).has_point(at):
			var d0 = combat.divers[selected]
			if int(d0.station) == st:
				player_ability(0)
			else:
				player_move(st)
			return
	# the creature before bare station rings: a click on the body is the
	# attack, from wherever the selected diver stands
	if at.distance_to(_body_at()) < 130.0:
		player_ability(0)
		return
	for st in range(5):
		if not combat.station_open(st):
			continue
		if at.distance_to(place(st)) < 44.0:
			var d = combat.divers[selected]
			if int(d.station) == st:
				player_ability(0)
			else:
				player_move(st)
			return

func here_free(_st: int) -> String:
	return ""

func _draw_salvage() -> void:
	if combat.salvage_station < 0:
		return
	var at: Vector2 = place(combat.salvage_station) + Vector2(34, 26)
	if combat.salvage_crushed:
		# splinters, not absence: the loss stays visible
		for k in range(5):
			var ang := TAU * float(k) / 5.0 + 0.5
			draw_line(at + Vector2.from_angle(ang) * 6.0, at + Vector2.from_angle(ang) * 20.0,
				Color(0.45, 0.38, 0.30, 0.8), 3.0)
		return
	var w := 40.0
	var h := 28.0
	var box := Rect2(at - Vector2(w * 0.5, h), Vector2(w, h))
	# it must read against the creature's own browns: a lamp halo and a
	# breathing outline say "yours, protect it" the way the selection ring
	# says "you"
	var tpulse: float = 0.5 + 0.5 * sin(_clock * 2.6)
	draw_circle(at + Vector2(0, -h * 0.5), 34.0 + 3.0 * tpulse, Color(0.95, 0.85, 0.45, 0.10 + 0.05 * tpulse))
	draw_rect(box.grow(3.0), Color(0.98, 0.88, 0.55, 0.35 + 0.25 * tpulse), false, 2.0)
	draw_rect(box, Color(0.52, 0.42, 0.28))
	draw_rect(box, Color(0.80, 0.70, 0.45), false, 2.0)
	draw_line(box.position + Vector2(w * 0.33, 0), box.position + Vector2(w * 0.33, h), Color(0.30, 0.24, 0.16), 3.0)
	draw_line(box.position + Vector2(w * 0.66, 0), box.position + Vector2(w * 0.66, h), Color(0.30, 0.24, 0.16), 3.0)
	var df2: Font = ThemeDB.fallback_font
	draw_string(df2, box.position + Vector2(-8, h + 26.0), "the part", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.95, 0.85, 0.55, 0.9))
	var mx := float(int((combat.enc.salvage as Dictionary).hp))
	for k in range(int(mx)):
		var lit: bool = k < combat.salvage_hp
		draw_circle(box.position + Vector2(6.0 + float(k) * 5.4, -5.0), 2.2,
			Color(0.95, 0.83, 0.40, 1.0) if lit else Color(0.2, 0.22, 0.24, 0.9))
	_teach("salvage", at + Vector2(0, -h),
		"the pump part: unblocked swings here chip it. Stand here to shield it")

func _draw_affordances() -> void:
	if combat.outcome != "ongoing":
		return
	var d = combat.divers[selected]
	if d.down:
		return
	var t: float = 0.5 + 0.5 * sin(_clock * 3.2)
	# the chip the prompt is talking about glows; words and board agree
	# by light rather than by both reciting station names
	if _hint_station >= 0 and combat.station_open(_hint_station):
		var hr: Rect2 = Rect2(ui_stations[_hint_station].position, ui_stations[_hint_station].size)
		draw_rect(hr, Color(0.95, 0.85, 0.45, 0.10 + 0.05 * t))
		draw_rect(hr.grow(3.0), Color(0.95, 0.85, 0.45, 0.75 + 0.2 * t), false, 3.0)
	# 1. who is acting: a pulsing ring underfoot
	var foot: Vector2 = diver_foot(d) + fx.diver_offset(int(d.id)) + fx.idle(int(d.id))
	draw_arc(foot + Vector2(0, 4), 26.0 + 3.0 * t, 0, TAU, 30, Color(0.95, 0.85, 0.45, 0.65 + 0.3 * t), 3.0)
	# 2. where they can go: a breathing dashed halo on every legal move
	if combat.can_move_now(selected):
		for st in combat.OPEN_STATIONS:
			if int(st) == int(d.station):
				continue
			var busy := false
			for o in combat.divers:
				if not o.down and int(o.station) == int(st):
					busy = true
			if busy:
				continue
			var c0: Vector2 = place(int(st)) + Vector2(0, 22)
			draw_circle(c0, 34.0 + 3.0 * t, Color(0.45, 0.85, 0.72, 0.13 + 0.06 * t))
			draw_circle(c0, 5.0, Color(0.55, 0.90, 0.78, 0.8))
	# 3. what SPACE would do: a reticle on the target and a preview chunk
	var lb: int = combat.target_limb(d)
	if lb >= 0 and not combat.limb_broken[lb]:
		var at: Vector2 = _limb_at(lb)
		var tside: Vector2 = Vector2(14.0 if at.x >= foot.x else -14.0, -26.0)
		draw_line(foot + tside, at, Color(0.95, 0.85, 0.45, 0.55), 2.5)
		var rr: float = 22.0 + 2.0 * t
		draw_arc(at, rr, 0, TAU, 28, Color(0.95, 0.85, 0.45, 0.95), 3.5)
		for k in range(4):
			var ang: float = TAU * float(k) / 4.0
			var dv := Vector2(cos(ang), sin(ang))
			draw_line(at + dv * (rr - 5.0), at + dv * (rr + 7.0), Color(0.95, 0.85, 0.45, 0.95), 3.0)

func _teach_triggers() -> void:
	if combat == null or combat.outcome != "ongoing":
		return
	# the second ability arrives at the boat, where nothing can swing; the
	# lesson waits for the first board it can be USED on, anchored to its
	# own button ("I press F, and nothing happens" was the boat's version)
	var dd = combat.divers[selected]
	if dd.kit.size() > 1 and not dd.down:
		var btns2: Array = bar_buttons()
		for bi in range(btns2.size()):
			if String(btns2[bi].id) == "ability1":
				_teach("ability1", btn_rect(bi, btns2.size()).get_center() + Vector2(60, -6),
					"new since the boat: %s, on F or its button" % String(dd.kit[1].name))
	# lesson 1, first telegraph of the run: the arc means a place and a number
	for it in combat.locked:
		for st in it.stations:
			_teach("telegraph", place(int(st)) + Vector2(0, -30),
				"the ring is a promise: %d lands HERE when this turn ends" % int(it.dmg))
			break
		break
	# lesson 2, the first time the SELECTED diver is standing in one
	var d = combat.divers[selected]
	if not d.down and int(d.station) in combat.threatened_stations():
		# only where the lesson is actable: a clear, empty station exists.
		# On the descent there is nowhere to go and the prompt says take
		# the hit, so teaching "just move" there would be a lie.
		var can_flee := false
		for st in combat.OPEN_STATIONS:
			if int(st) == int(d.station) or int(st) in combat.threatened_stations():
				continue
			var busy := false
			for o in combat.divers:
				if not o.down and int(o.station) == int(st):
					busy = true
			if not busy:
				can_flee = true
		if can_flee and combat.can_move_now(selected):
			_teach("dodge", diver_foot(d) + Vector2(0, -70),
				"standing in a red ring costs %s the hit. Moving is free" % String(d.dname))

func _draw_actionbar() -> void:
	if combat == null or combat.outcome != "ongoing":
		return
	var btns: Array = bar_buttons()
	var df: Font = ThemeDB.fallback_font
	for i in range(btns.size()):
		var b: Dictionary = btns[i]
		var r: Rect2 = btn_rect(i, btns.size())
		var on: bool = action_legal(String(b.id))
		var face := Color(0.19, 0.24, 0.19, 0.94) if on else Color(0.10, 0.12, 0.13, 0.88)
		var edge := Color(0.78, 0.86, 0.66, 0.9) if on else Color(0.42, 0.46, 0.48, 0.7)
		var ink := Color(0.95, 0.97, 0.91) if on else Color(0.74, 0.77, 0.79)
		draw_rect(r, face)
		draw_rect(r, edge, false, 2.0)
		var txt := String(b.label)
		var sub := String(b.get("sub", ""))
		if sub == "":
			var tw: float = df.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(df, r.position + Vector2((r.size.x - tw) * 0.5, 26.0), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
		else:
			draw_string(df, r.position + Vector2(10.0, 18.0), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
			var sink := Color(ink.r, ink.g, ink.b, ink.a * 0.92)
			draw_string(df, r.position + Vector2(10.0, 34.0), sub,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sink)

func _draw_traits() -> void:
	for st in range(5):
		if not combat.station_open(st):
			continue
		var lb: int = combat.STATION_LIMB[st]
		if lb < 0 or combat.limb_broken[lb] or not combat.known(lb):
			continue
		var at: Vector2 = _limb_at(lb)
		match combat.trait_of(lb):
			"brittle":
				# cracks: three jagged lines across the limb
				for k in range(3):
					var o := Vector2(-26.0 + float(k) * 22.0, -8.0 + float(k % 2) * 10.0)
					draw_line(at + o, at + o + Vector2(9, 13), Color(0.95, 0.97, 1.0, 0.85), 2.0)
					draw_line(at + o + Vector2(9, 13), at + o + Vector2(4, 24), Color(0.95, 0.97, 1.0, 0.85), 2.0)
			"plated":
				# a bolted plate sitting proud of the limb
				draw_rect(Rect2(at + Vector2(-24, -10), Vector2(48, 26)), Color(0.42, 0.46, 0.52, 0.92))
				draw_rect(Rect2(at + Vector2(-24, -10), Vector2(48, 26)), Color(0.72, 0.78, 0.84), false, 2.0)
				for k in range(3):
					draw_circle(at + Vector2(-14.0 + float(k) * 14.0, 3.0), 2.4, Color(0.80, 0.84, 0.88))
			"leaking":
				# bubbles streaming up, on the clock so they rise
				for k in range(5):
					var yy: float = fmod(_clock * 34.0 + float(k) * 17.0, 60.0)
					draw_circle(at + Vector2(-8.0 + float(k % 3) * 9.0, -yy), 2.6 + float(k % 2), Color(0.72, 0.92, 1.0, 0.8 - yy / 90.0))
			"pressurised":
				# a hot pulse under the shell
				var th: float = 0.5 + 0.5 * sin(_clock * 3.4)
				draw_circle(at, 17.0 + 4.0 * th, Color(0.98, 0.70, 0.30, 0.18 + 0.20 * th))
				draw_circle(at, 8.0, Color(0.98, 0.78, 0.40, 0.55 + 0.30 * th))

# the limb readout lives ON the creature at the limb it describes: name,
# bar, and the read's finding in compact form. Drawn, not a Control, so
# it rides the z-order of the board it belongs to.
func _draw_limb_bars() -> void:
	var df: Font = ThemeDB.fallback_font
	for lb in range(combat.limb_hp.size()):
		var st := -1
		for s2 in range(5):
			if combat.STATION_LIMB[s2] == lb:
				st = s2
		if st < 0:
			continue
		var at: Vector2 = _limb_at(lb)
		if combat.limb_broken[lb]:
			draw_string(df, at + Vector2(-34, -14), "BROKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.60, 0.66, 0.70, 0.9))
			continue
		var mx: float = float(int((combat.enc.limbs[lb] as Dictionary).hp))
		var fr: float = clampf(float(combat.limb_hp[lb]) / max(1.0, mx), 0.0, 1.0)
		var suffix := ""
		if int(combat.limb_stun[lb]) > 0:
			suffix = "  SHUT %d" % int(combat.limb_stun[lb])
		elif not combat.known(lb):
			suffix = "  not read"
		else:
			match combat.trait_of(lb):
				"brittle": suffix = "  takes x2"
				"plated": suffix = "  -1 dmg"
				"leaking": suffix = "  +2 air"
				"pressurised": suffix = "  bursts"
		var label := "%s %d/%d%s" % [String(combat.LIMB_NAMES[lb]).to_upper(), int(combat.limb_hp[lb]), int(mx), suffix]
		var tw: float = df.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var tx: float = clampf(at.x - tw * 0.5, 8.0, 1280.0 - tw - 8.0)
		# lifted clear of the reticle that shares this anchor
		for off in [Vector2(1, 1), Vector2(-1, -1)]:
			draw_string(df, Vector2(tx, at.y - 34.0) + off, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.02, 0.05, 0.08, 0.9))
		draw_string(df, Vector2(tx, at.y - 34.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.98, 0.88, 0.82))
		var bw := 56.0
		var bx: float = at.x - bw * 0.5
		draw_rect(Rect2(Vector2(bx - 1, at.y - 29), Vector2(bw + 2, 7)), Color(0.03, 0.05, 0.07, 0.92))
		var bcol := BAR_LIMB.lerp(Color(1, 1, 1), fx.limb_flash(lb))
		draw_rect(Rect2(Vector2(bx, at.y - 28), Vector2(bw * fr, 5)), bcol)
		# the preview chunk: what the selected diver's SPACE would remove
		var ds = combat.divers[selected]
		if not ds.down and combat.target_limb(ds) == lb and combat.outcome == "ongoing":
			var ef: Dictionary = combat.effect_at(ds, 0, combat.tier_for(ds))
			var would: int = combat._after_trait(lb, int(ef.dmg))
			if would > 0:
				var wf: float = clampf(float(would) / max(1.0, mx), 0.0, fr)
				draw_rect(Rect2(Vector2(bx + bw * (fr - wf), at.y - 28), Vector2(bw * wf, 5)),
					Color(0.99, 0.90, 0.55))

func _draw_bars() -> void:
	# The limb bars used to be painted on the board, and the station tags
	# are UI nodes, so a tag drew straight over a neighbouring station's bar
	# and the GUT readout vanished behind the FLANK tag. Everything about a
	# station now lives IN that station's tag. Here, only the divers.
	# one per diver, ON the diver, not in a card at the bottom of the screen
	for d in combat.divers:
		if d.down:
			continue
		var f: Vector2 = diver_foot(d) + fx.diver_offset(int(d.id)) + fx.idle(int(d.id))
		var frac: float = float(d.hp) / max(1.0, float(d.max_hp))
		# clamped under the prompt band, which is new and lower than the old
		# control strip: Proto5's bar was being cut in half by it
		# ABOVE the head at ordinary stations; BELOW the feet at belly
		# stations, where above-the-head is the creature's body and the
		# plate reads as a fourth limb (round three, twice). Belly plates
		# sit BESIDE their ring, so below-feet ground there is clear.
		var belly_here: bool = combat != null and place(int(d.station)).y >= _body_at().y - 20.0
		var by: float = (min(f.y + 30.0, 560.0)) if belly_here else max(f.y - DIVER_SCALE - 8.0, PANEL_FLOOR)
		var df: Font = ThemeDB.fallback_font
		var plate := "%s %d/%d" % [String(d.dname), int(d.hp), int(d.max_hp)]
		var pw: float = df.get_string_size(plate, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10.0
		var bw: float = max(104.0, pw)
		# keep the whole plate on screen while it is at it
		var bx: float = clampf(f.x - bw * 0.5, 4.0, 1280.0 - bw - 4.0)
		_bar(Vector2(bx, by), bw, 13, frac, BAR_OK if frac > 0.34 else BAR_LOW)
		draw_string(df, Vector2(bx + 5.0, by + 11.0), plate,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.96, 0.98, 1.0))

func _draw() -> void:
	# Paint the ACTUAL rect, not the design size. With stretch/expand the
	# viewport grows past 720 and anything beyond it was left unpainted,
	# which is the flat grey band a visual reviewer flagged as the game
	# failing to fill its window.
	_draw_water()
	# the lock is inside the wreck, so it is lit by what you brought
	if run != null and run.finished:
		_draw_ending()
		_overlay_dive()
		return

	if run != null and run.puzzle != null:
		_draw_lock(run.puzzle)
		_overlay_dive()
		return
	if combat == null and run != null and not run.finished:
		_draw_rig()
		# the descent between beats draws over EVERY destination. It only
		# ever drew over fights, so half the game's transitions (into
		# boats, locks, the ending) never rendered for anyone, which is
		# what "the transitions are too short to explain anything" was
		# actually reporting
		_overlay_dive()
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
	var body_at: Vector2 = Vector2(float(ap[0]), float(ap[1])) + Vector2(0, 150) + fx.body_offset() + fx.idle(7) * 1.6
	var lamps := 0
	for dl in combat.divers:
		if not dl.down:
			lamps += 1
	if lamps > 0:
		for ring in range(7):
			var rr: float = 90.0 + float(ring) * 34.0
			draw_circle(body_at + Vector2(0, -30), rr,
				Color(0.66, 0.86, 0.94, 0.013 * float(lamps) * (1.0 - float(ring) / 7.0)))
	# and the creature itself is lifted out of the dark by that light
	Art.kind = String(art.get("kind", "crab"))
	Art.tint = Art.tint.lightened(0.025 * float(lamps))
	Art.draw_crab(self, body_at, asc, combat.limb_broken)
	Art.tint = Color(1, 1, 1)
	Art.stretch = 1.0
	# lamp cones first, under everything, so they light the water rather
	# than painting over the things in it
	for d in combat.divers:
		if d.down:
			continue
		var lf: Vector2 = diver_foot(d) + fx.diver_offset(int(d.id)) + fx.idle(int(d.id))
		var head: Vector2 = lf + Vector2(0, -DIVER_SCALE * 0.72)
		var ap1: Array = combat.enc.art.pos
		var aim: Vector2 = (Vector2(float(ap1[0]), float(ap1[1])) + Vector2(0, 150) - head)
		if aim.length() < 1.0:
			continue
		var an: Vector2 = aim.normalized()
		var side := Vector2(-an.y, an.x)
		var reach: float = min(aim.length() * 0.92, 340.0)
		draw_colored_polygon(PackedVector2Array([
			head + side * 7.0, head - side * 7.0,
			head + an * reach - side * (36.0 + reach * 0.16),
			head + an * reach + side * (36.0 + reach * 0.16)]),
			Color(0.72, 0.90, 0.98, 0.055))
		draw_circle(head, 5.0, Color(0.88, 0.96, 1.0, 0.55))
	for d in combat.divers:
		var foot: Vector2 = diver_foot(d) + fx.diver_offset(int(d.id)) + fx.idle(int(d.id))
		if d.down:
			# down means surfaced: the roster row says where they went, and
			# a ghost standing at a station contradicted it in one glance
			continue
		_draw_baked(int(d.id), foot, RIG_SCALE)
	_draw_salvage()
	_draw_affordances()
	_draw_traits()
	_draw_actionbar()
	_teach_triggers()
	_draw_teach()
	_draw_windup()
	_draw_limb_bars()
	_draw_bars()
	_draw_fx()
	_overlay_dive()

func _overlay_dive() -> void:
	if _dive > 0.0:
		_draw_dive(1.0 - clampf(_dive / 3.2, 0.0, 1.0))

# --- the effects themselves, painted over the board ---------------------
# the strike signature: which drawn animation an enemy verb produces.
# One vocabulary, listed once; an attack name outside it falls back to
# the bolt, and the door gate's motion check keeps player kinds honest.
func _strike(line: String, src: Vector2, dst: Vector2) -> void:
	if line.find(" snaps ") >= 0 or line.find(" pinches ") >= 0:
		fx.add("clap", 0.42, dst, src, "", HURT)
	elif line.find(" sweeps ") >= 0 or line.find(" lashes ") >= 0 or line.find(" swings ") >= 0:
		fx.add("swipe", 0.5, src, dst, "", HURT)
	elif line.find(" sprays ") >= 0 or line.find(" vents ") >= 0 or line.find(" hisses ") >= 0:
		fx.add("cone", 0.55, src, dst, "", Color(0.85, 0.92, 0.60))
	elif line.find(" hammers ") >= 0:
		fx.add("slam", 0.48, dst + Vector2(0, -90), dst, "", HURT)
	elif line.find(" lunges ") >= 0 or line.find(" chases ") >= 0 or line.find(" curls ") >= 0:
		fx.add("surge", 0.5, src, dst, "", HURT)
	else:
		fx.add("bolt", 0.28, src, dst, "", HURT)

func _draw_fx() -> void:
	var f: Font = ThemeDB.fallback_font
	for e in fx.live:
		var k: float = e.k()
		match e.kind:
			"clap":
				# two jaws closing over the landing point
				var gap: float = 34.0 * (1.0 - min(1.0, k * 1.4))
				var jaw_c := Color(e.col.r, e.col.g, e.col.b, 1.0 - k * 0.6)
				var toward: Vector2 = (e.to - e.at).normalized()
				var side_v := Vector2(-toward.y, toward.x)
				for sgn in [1.0, -1.0]:
					var base: Vector2 = e.at + side_v * (gap + 10.0) * sgn
					draw_colored_polygon(PackedVector2Array([
						base + side_v * 16.0 * sgn - toward * 20.0,
						base + side_v * 16.0 * sgn + toward * 20.0,
						e.at + side_v * gap * sgn]), jaw_c)
			"swipe":
				# a crescent traveling through the station, the sweep as an
				# object rather than a nudge
				var ang0: float = (e.to - e.at).angle() - 1.1
				var swept: float = ang0 + 2.2 * min(1.0, k * 1.3)
				var sw_c := Color(e.col.r, e.col.g, e.col.b, 1.0 - k * 0.7)
				draw_arc(e.to, 44.0, ang0, swept, 22, sw_c, 9.0 * (1.0 - k * 0.5))
				draw_circle(e.to + Vector2.from_angle(swept) * 44.0, 7.0 * (1.0 - k * 0.4), sw_c)
			"cone":
				# a spray of droplets from the limb toward the station
				var dirn: Vector2 = (e.to - e.at).normalized()
				var perp := Vector2(-dirn.y, dirn.x)
				var cn := Color(e.col.r, e.col.g, e.col.b, (1.0 - k) * 0.9)
				for i in range(9):
					var t2: float = fposmod(k * 1.5 + float(i) / 9.0, 1.0)
					var spread: float = (float(i % 5) - 2.0) * 9.0 * t2
					draw_circle(e.at.lerp(e.to, t2) + perp * spread, 4.0 - 2.0 * t2, cn)
			"slam":
				# a piston falling onto the station and a shock ring on land
				var drop: Vector2 = e.at.lerp(e.to, min(1.0, k * 1.5))
				var sl_c := Color(e.col.r, e.col.g, e.col.b, 1.0 - k * 0.5)
				draw_rect(Rect2(drop - Vector2(9.0, 34.0), Vector2(18.0, 34.0)), sl_c)
				if k > 0.66:
					draw_arc(e.to, 20.0 + 70.0 * (k - 0.66) * 3.0, 0, TAU, 30,
						Color(e.col.r, e.col.g, e.col.b, (1.0 - k) * 1.4), 4.0)
			"surge":
				# the body itself arriving: a bow wave ahead of the motion
				var head2: Vector2 = e.at.lerp(e.to, min(1.0, k * 1.2))
				var dirn2: Vector2 = (e.to - e.at).normalized()
				var pp := Vector2(-dirn2.y, dirn2.x)
				var sg := Color(e.col.r, e.col.g, e.col.b, (1.0 - k) * 0.8)
				draw_line(head2 + pp * 26.0 - dirn2 * 18.0, head2 + dirn2 * 14.0, sg, 5.0)
				draw_line(head2 - pp * 26.0 - dirn2 * 18.0, head2 + dirn2 * 14.0, sg, 5.0)
				for i in range(4):
					draw_circle(head2 - dirn2 * (26.0 + 16.0 * float(i)) + pp * (float(i % 2) * 12.0 - 6.0),
						3.5 - 0.6 * float(i), Color(0.75, 0.88, 0.95, (1.0 - k) * 0.5))
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
