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

func _build_ui() -> void:
	# station markers: one Control each, so the invariants can assert they
	# never overlap and their labels stay inside them
	for i in range(5):
		var m := Panel.new()
		m.name = "station_" + Combat.STATION_NAMES[i]
		m.size = Vector2(210, 66)
		m.position = STATION_POS[i] - m.size * 0.5 + Vector2(0, 56)
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
		p.size = Vector2(392, 96)
		p.position = Vector2(24 + i * 406, 600)
		add_child(p)
		var l := Label.new()
		l.name = "label"
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_left = 14; l.offset_right = -14
		l.offset_top = 12; l.offset_bottom = -12
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(l)
		ui_divers.append(p)

	var air_panel := Panel.new()
	air_panel.name = "air_panel"
	air_panel.size = Vector2(340, 54)
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
	tel.size = Vector2(856, 54)
	tel.position = Vector2(392, 24)
	add_child(tel)
	ui_intent = Label.new()
	ui_intent.name = "label"
	ui_intent.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_intent.offset_left = 12; ui_intent.offset_right = -12
	ui_intent.offset_top = 6; ui_intent.offset_bottom = -6
	tel.add_child(ui_intent)

	# built BEFORE the first _refresh, which runs on the opening scene beat
	var scene_panel := Panel.new()
	scene_panel.name = "scene_panel"
	scene_panel.size = Vector2(900, 210)
	scene_panel.position = Vector2(190, 190)
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
	legend_panel.position = Vector2(30, 96)
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
	goal_panel.position = Vector2(700, 96)
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
	help_panel.position = Vector2(30, 146)
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

func _refresh() -> void:
	_voice()
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
		ui_scene.text = run.puzzle.state_text() + "\n\n" + ("the way out is open" if run.puzzle.solved() else "(placeholder) The way out is above the waterline. Fill the chamber.")
		ui_help.text = "1 2 3 turn a valve  ·  ENTER when the way is open"
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
	ui_legend.text = "red ring = a limb that can still hit you    ·    blue ring = safe to stand"
	for i in range(ui_stations.size()):
		ui_stations[i].visible = combat.station_open(i)
		if not combat.station_open(i):
			continue
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
		ui_air.text = "AIR  %d of %d left this turn   (%d line cut)" % [combat.air, Combat.AIR_PER_TURN, combat.air_penalty]
	else:
		ui_air.text = "AIR  %d of %d left this turn" % [combat.air, combat.air_this_turn()]
	var live := 0
	for lb in range(combat.limb_broken.size()):
		if not combat.limb_broken[lb]:
			live += 1
	ui_goal.text = "break every limb to win   ·   %d of %d still working" % [live, combat.limb_broken.size()]
	var it: Dictionary = combat.intent()
	if it.is_empty():
		ui_intent.text = "%s   spent" % run.state_line()
	else:
		var where: Array = []
		for s in it.stations:
			where.append(Combat.STATION_NAMES[s])
		ui_intent.text = "%s   NEXT: the %s %s %s for %d damage" % [run.state_line(), combat.LIMB_NAMES[it.limb], it.name, "/".join(where), it.dmg]
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
		var state := "DOWN" if d.down else "%s  %d HP" % [Combat.STATION_NAMES[d.station], d.hp]
		var afford := "" if combat.air >= d.cost else "   cannot afford"
		var verb := "shuts a limb down for a turn" if d.disables else "hits for %d" % d.dmg
		card.get_node("label").text = "%s%d %s  %d air to act, %s%s\n%s" % [mark, i + 1, d.dname, d.cost, verb, afford, state]
	ui_help.text = (refusal + "        ") if refusal != "" else ""
	var keys := ["Q", "W", "E", "R", "T"]
	var moves: Array = []
	for i in range(5):
		if combat.station_open(i):
			moves.append("%s=%s" % [keys[i], Combat.STATION_NAMES[i]])
	var pick := "1 diver only" if combat.divers.size() == 1 else "1-%d pick a diver" % combat.divers.size()
	ui_help.text += "%s  ·  move (1 air): %s  ·  SPACE attack from where you stand  ·  ENTER end turn" % [pick, "  ".join(moves)]
	queue_redraw()

# ---- the player's door. The bot calls these same Combat methods. -------
# A refused input must say WHY. Silence is how a player concludes the game
# is broken rather than that they cannot afford the action.
func player_attack() -> bool:
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
		KEY_Q: player_move(Combat.FRONT)
		KEY_W: player_move(Combat.FLANK)
		KEY_E: player_move(Combat.UNDER)
		KEY_R: player_move(Combat.REAR)
		KEY_T: player_move(Combat.BACKLINE)
		KEY_SPACE: player_attack()
		KEY_ENTER:
			if combat == null:
				run.advance(); combat = run.combat; selected = 0; _refresh()
			else:
				player_end_turn()

func _draw() -> void:
	# Paint the ACTUAL rect, not the design size. With stretch/expand the
	# viewport grows past 720 and anything beyond it was left unpainted,
	# which is the flat grey band a visual reviewer flagged as the game
	# failing to fill its window.
	draw_rect(Rect2(Vector2.ZERO, size.max(DESIGN)), Color(0.04, 0.11, 0.16))
	# station rings: red while the limb they expose is live, teal once it is
	# broken or absent. This is the map changing, drawn.
	if combat == null:
		return
	for i in range(5):
		if not combat.station_open(i):
			continue
		var limb: int = combat.STATION_LIMB[i]
		var safe: bool = limb < 0 or combat.limb_broken[limb]
		var col := Color(0.25, 0.55, 0.6) if safe else Color(0.85, 0.35, 0.25)
		draw_arc(STATION_POS[i], 46, 0, TAU, 40, col, 2.0)
	# scale is PIXELS PER BODY UNIT, not a multiplier. Passing 1.6 made the
	# crab under two pixels tall, its foot triangles sub-pixel, and the
	# triangulator rejected them, so the enemy silently did not draw at all
	# while every test stayed green. Caught by the first as-played capture.
	if combat == null:
		return
	Art.draw_crab(self, CRAB_POS + Vector2(0, 150), CRAB_SCALE, combat.limb_broken)
	for i in range(combat.divers.size()):
		var d = combat.divers[i]
		if d.down:
			continue
		# above the ring, so the station card below never slices a sprite
		var p: Vector2 = STATION_POS[d.station] + Vector2(-22 + i * 36, -8)
		Art.draw_diver(self, d.cost, p, 74.0, 1)
