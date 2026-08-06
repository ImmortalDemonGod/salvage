# Presentation. Reads sim state, never owns it. Every UI element is a
# Control so `get_global_rect()` hands the layout invariants a box for
# free (SPEC 4.3). Built in code rather than a .tscn so the layout is
# deterministic and walkable headless before any content exists.
extends Control

const Art := preload("res://game/art.gd")
const Run := preload("res://sim/run.gd")
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
const LOCK_RECT := Rect2(300, 214, 640, 400)
const SCENE_PANEL_AT := Vector2(190, 220)
const SCENE_PANEL_SIZE := Vector2(900, 216)

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
		m.size = Vector2(210, 66)
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
func _voice() -> void:
	if sfx == null:
		return
	if combat != null:
		_log_at = sfx.drain(combat.log_lines, _log_at)
	elif run.puzzle != null:
		_log_at = sfx.drain(run.puzzle.log_lines, _log_at)

# Report the current beat in the window title. On the web export this is
# document.title, so the capture driver can read where the replay actually
# ended up instead of trusting the key sequence to have landed.
var _title_ticks := 0

func _process(_dt: float) -> void:
	if _title_ticks < 120:
		_title_ticks += 1
		_stamp_title()

func _stamp_title() -> void:
	var b: Dictionary = run.current()
	DisplayServer.window_set_title("SALVAGE beat=%s" % String(b.get("id", "?")))

func _refresh() -> void:
	_stamp_title()
	_voice()
	var scene_p: Control = ui_scene.get_parent()
	if run.puzzle != null:
		scene_p.position = Vector2(190, 620)
		scene_p.size = Vector2(900, 96)
	else:
		scene_p.position = SCENE_PANEL_AT
		scene_p.size = SCENE_PANEL_SIZE
	if run.puzzle != null:
		# The lock, drawn as its own state: a water line and three valves.
		ui_air.get_parent().visible = false
		ui_legend.get_parent().visible = false
		ui_goal.get_parent().visible = false
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
			want = "(placeholder) The way out sits above chamber A. Fill A, keep B dry."
		else:
			want = "(placeholder) The way out is above the waterline. Fill the chamber to the top."
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
				body.append(String(l.text))
		ui_scene.text = "\n\n".join(body)
		ui_scene.get_parent().visible = body.size() > 0
		ui_help.text = controls
		queue_redraw()
		return
	ui_scene.get_parent().visible = false
	ui_air.get_parent().visible = true
	ui_legend.get_parent().visible = true
	ui_goal.get_parent().visible = true
	ui_legend.text = "red ring = an attack lands here this turn   ·   blue = nothing does"
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
			lbl.text = "%s\nno limb here" % Combat.STATION_NAMES[i]
		elif combat.limb_broken[lb]:
			lbl.text = "%s\n%s BROKEN" % [Combat.STATION_NAMES[i], String(combat.LIMB_NAMES[lb]).to_upper()]
		else:
			var stun := "  SHUT" if int(combat.limb_stun[lb]) > 0 else ""
			var here := ""
			for d2 in combat.divers:
				if not d2.down and int(d2.station) == i and d2.id == selected:
					here = "  <- you"
			var maxhp: int = int((combat.enc.limbs[lb] as Dictionary).hp)
			lbl.text = "%s\n%s %d/%d hp%s%s" % [Combat.STATION_NAMES[i], String(combat.LIMB_NAMES[lb]).to_upper(), int(combat.limb_hp[lb]), maxhp, stun, here]
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
	for i in range(ui_divers.size()):
		var card: Panel = ui_divers[i]
		if i >= combat.divers.size():
			card.visible = false
			continue
		card.visible = true
		var d = combat.divers[i]
		var mark := ">" if i == selected else " "
		var state := "DOWN" if d.down else "at %s   %d/%d HP" % [Combat.STATION_NAMES[d.station], d.hp, d.max_hp]
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
		card.get_node("label").text = "%s%d %s  %d air per ability%s\n%s\n%s" % [mark, i + 1, d.dname, d.cost, afford, "\n".join(lines), state]
	ui_help.text = (refusal + "        ") if refusal != "" else ""
	var keys := ["Q", "W", "E", "R", "T"]
	var moves: Array = []
	for i in range(5):
		if combat.station_open(i):
			moves.append("%s=%s" % [keys[i], Combat.STATION_NAMES[i]])
	var pick := "1 diver only" if combat.divers.size() == 1 else "1-%d pick a diver" % combat.divers.size()
	ui_help.text += "%s  ·  move (1 air): %s  ·  SPACE / F use an ability  ·  ENTER end turn" % [pick, "  ".join(moves)]
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
func _after() -> void:
	if combat != null and combat.outcome != "ongoing":
		run.advance()
		combat = run.combat
		selected = 0
		_log_at = 0
	_refresh()

func _unhandled_input(e: InputEvent) -> void:
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
			if run.puzzle != null: run.puzzle.toggle(3)
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
const WATER := Color(0.20, 0.52, 0.62)
const STEEL := Color(0.16, 0.24, 0.30)
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
	draw_rect(Rect2(at, Vector2(wide, tall)), Color(0.55, 0.66, 0.74), false, 2.0)
	# the graduations, so "2 of 3" is countable and not just a bar
	for m in range(1, cap):
		var y: float = at.y + tall - tall * (float(m) / float(cap))
		draw_line(Vector2(at.x, y), Vector2(at.x + 14, y), Color(0.55, 0.66, 0.74), 1.0)
	var f: Font = ThemeDB.fallback_font
	draw_string(f, at + Vector2(0, tall + 26), "%s  %d of %d" % [name, filled, cap],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.86, 0.90, 0.94))

func _door(at: Vector2, wide: float, is_open: bool) -> void:
	var f: Font = ThemeDB.fallback_font
	draw_rect(Rect2(at, Vector2(wide, 22)), OPEN_C if is_open else Color(0.30, 0.28, 0.24))
	draw_string(f, at + Vector2(0, -12), "the way out" + ("  OPEN" if is_open else ""),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, OPEN_C if is_open else Color(0.72, 0.74, 0.78))

func _draw_lock(p) -> void:
	var tall := 210.0
	if p.stage == 2:
		var ax := 300.0
		var bx := 700.0
		var wide := 240.0
		var top := 250.0   # help line ends at 206; the sentence starts at 648
		_chamber(Vector2(ax, top), wide, tall, p.level_a(), 3, "chamber A")
		_chamber(Vector2(bx, top), wide, tall, p.level_b(), 3, "chamber B")
		_door(Vector2(ax, top - 30), wide, p.solved())
		# the crossover pipe, at the BOTTOM of B because that is the whole
		# interlock: it can only be turned while B is dry
		var pipe_y := top + tall - 26.0
		draw_line(Vector2(ax + wide, pipe_y), Vector2(bx, pipe_y),
			OPEN_C if p.valve[p.CROSS] else STEEL, 8.0)
		_valve_dot(Vector2((ax + wide + bx) * 0.5, pipe_y), "4", p.valve[p.CROSS], p.reachable(p.CROSS))
		_valve_dot(Vector2(ax + 60, top + tall + 60), "1", p.valve[0], true)
		_valve_dot(Vector2(ax + 170, top + tall + 60), "2", p.valve[1], true)
		_valve_dot(Vector2(bx + 110, top + tall + 60), "3", p.valve[2], true)
		var f2: Font = ThemeDB.fallback_font
		draw_string(f2, Vector2(ax + 30, top + tall + 110), "1 and 2 feed A", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.72, 0.78, 0.84))
		draw_string(f2, Vector2(bx + 60, top + tall + 110), "3 feeds B", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.72, 0.78, 0.84))
		return
	var x := 480.0
	var wide := 300.0
	var top := 250.0
	_chamber(Vector2(x, top), wide, tall, p.level(), p.VALVES, "the chamber")
	_door(Vector2(x, top - 30), wide, p.solved())
	# two inlets you can always reach, and the seized one down at the floor
	_valve_dot(Vector2(x + 70, top + tall + 60), "1", p.valve[0], p.reachable(0))
	_valve_dot(Vector2(x + 150, top + tall + 60), "2", p.valve[1], p.reachable(1))
	_valve_dot(Vector2(x + wide - 40, top + tall - 30), "3", p.valve[p.SEIZED], p.reachable(p.SEIZED))

func _draw() -> void:
	# Paint the ACTUAL rect, not the design size. With stretch/expand the
	# viewport grows past 720 and anything beyond it was left unpainted,
	# which is the flat grey band a visual reviewer flagged as the game
	# failing to fill its window.
	draw_rect(Rect2(Vector2.ZERO, size.max(DESIGN)), Color(0.04, 0.11, 0.16))
	if run != null and run.puzzle != null:
		_draw_lock(run.puzzle)
		return
	# station rings: red while the limb they expose is live, teal once it is
	# broken or absent. This is the map changing, drawn.
	if combat == null:
		return
	for i in range(5):
		if not combat.station_open(i):
			continue
		var col := Color(0.25, 0.55, 0.6)
		if i in combat.threatened_stations():
			col = Color(0.85, 0.35, 0.25)
		draw_arc(place(i), 46, 0, TAU, 40, col, 2.0)
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
	Art.draw_crab(self, Vector2(float(ap[0]), float(ap[1])) + Vector2(0, 150), asc, combat.limb_broken)
	Art.tint = Color(1, 1, 1)
	Art.stretch = 1.0
	for d in combat.divers:
		if d.down:
			continue
		Art.draw_diver(self, d.cost, diver_foot(d), DIVER_SCALE, 1)
