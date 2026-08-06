# Presentation. Reads sim state, never owns it. Every UI element is a
# Control so `get_global_rect()` hands the layout invariants a box for
# free (SPEC 4.3). Built in code rather than a .tscn so the layout is
# deterministic and walkable headless before any content exists.
extends Control

const Art := preload("res://game/art.gd")

const DESIGN := Vector2(1280, 720)

# Station screen positions, side-on 2.5D: the crab faces left, divers
# approach from the left. UNDER is deliberately reachable and offensively
# empty (SPEC 2.6).
const STATION_POS := [
	Vector2(640, 400),   # FRONT  - the jaw
	Vector2(880, 250),   # FLANK  - the claw
	Vector2(880, 570),   # UNDER  - nothing
	Vector2(1090, 430),  # REAR   - the tail
	Vector2(280, 400),   # BACKLINE - safe
]
const CRAB_POS := Vector2(880, 400)

var combat: Combat
var selected := 0
var ui_stations: Array = []
var ui_divers: Array = []
var ui_air: Label
var ui_intent: Label
var ui_help: Label

func _ready() -> void:
	combat = Combat.new()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	# station markers: one Control each, so the invariants can assert they
	# never overlap and their labels stay inside them
	for i in range(5):
		var m := Panel.new()
		m.name = "station_" + Combat.STATION_NAMES[i]
		m.size = Vector2(150, 46)
		m.position = STATION_POS[i] - m.size * 0.5 + Vector2(0, 60)
		add_child(m)
		var l := Label.new()
		l.name = "label"
		l.text = Combat.STATION_NAMES[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_left = 8; l.offset_right = -8
		l.offset_top = 6; l.offset_bottom = -6
		m.add_child(l)
		ui_stations.append(m)

	# diver cards along the bottom
	for i in range(3):
		var p := Panel.new()
		p.name = "diver_card_" + str(i)
		p.size = Vector2(250, 74)
		p.position = Vector2(30 + i * 262, 624)
		add_child(p)
		var l := Label.new()
		l.name = "label"
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_left = 10; l.offset_right = -10
		l.offset_top = 8; l.offset_bottom = -8
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(l)
		ui_divers.append(p)

	var air_panel := Panel.new()
	air_panel.name = "air_panel"
	air_panel.size = Vector2(230, 54)
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
	tel.size = Vector2(700, 54)
	tel.position = Vector2(300, 24)
	add_child(tel)
	ui_intent = Label.new()
	ui_intent.name = "label"
	ui_intent.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_intent.offset_left = 12; ui_intent.offset_right = -12
	ui_intent.offset_top = 6; ui_intent.offset_bottom = -6
	tel.add_child(ui_intent)

	var help_panel := Panel.new()
	help_panel.name = "help_panel"
	help_panel.size = Vector2(1220, 40)
	help_panel.position = Vector2(30, 570)
	add_child(help_panel)
	ui_help = Label.new()
	ui_help.name = "label"
	ui_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_help.offset_left = 12; ui_help.offset_right = -12
	ui_help.offset_top = 7; ui_help.offset_bottom = -7
	help_panel.add_child(ui_help)

func _refresh() -> void:
	ui_air.text = "AIR  %d / %d" % [combat.air, combat.air_this_turn()]
	var it: Dictionary = combat.intent()
	if it.is_empty():
		ui_intent.text = "the crab is spent"
	else:
		var where: Array = []
		for s in it.stations:
			where.append(Combat.STATION_NAMES[s])
		ui_intent.text = "NEXT: the %s %s %s for %d" % [Combat.LIMB_NAMES[it.limb], it.name, "/".join(where), it.dmg]
	for i in range(3):
		var d = combat.divers[i]
		var mark := ">" if i == selected else " "
		var state := "DOWN" if d.down else "%s  %d HP" % [Combat.STATION_NAMES[d.station], d.hp]
		ui_divers[i].get_node("label").text = "%s%d %s  (%d air)\n%s" % [mark, i + 1, d.dname, d.cost, state]
	ui_help.text = "1-3 pick a diver  ·  Q W E R T move to a station  ·  SPACE attack from where you stand  ·  ENTER end turn"
	queue_redraw()

# ---- the player's door. The bot calls these same Combat methods. -------
func player_attack() -> bool:
	var ok := combat.act_attack(selected)
	if ok: _refresh()
	return ok

func player_move(station: int) -> bool:
	var ok := combat.act_move(selected, station)
	if ok: _refresh()
	return ok

func player_end_turn() -> void:
	combat.end_turn()
	_refresh()

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = (e as InputEventKey).keycode
	match k:
		KEY_1: selected = 0; _refresh()
		KEY_2: selected = 1; _refresh()
		KEY_3: selected = 2; _refresh()
		KEY_Q: player_move(Combat.FRONT)
		KEY_W: player_move(Combat.FLANK)
		KEY_E: player_move(Combat.UNDER)
		KEY_R: player_move(Combat.REAR)
		KEY_T: player_move(Combat.BACKLINE)
		KEY_SPACE: player_attack()
		KEY_ENTER: player_end_turn()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(0.04, 0.11, 0.16))
	# station rings: red while the limb they expose is live, teal once it is
	# broken or absent. This is the map changing, drawn.
	for i in range(5):
		if not combat.station_open(i):
			continue
		var limb: int = Combat.STATION_LIMB[i]
		var safe: bool = limb < 0 or combat.limb_broken[limb]
		var col := Color(0.25, 0.55, 0.6) if safe else Color(0.85, 0.35, 0.25)
		draw_arc(STATION_POS[i], 52, 0, TAU, 40, col, 2.0)
	Art.draw_crab(self, CRAB_POS + Vector2(0, 90), 1.6, combat.limb_broken)
	for i in range(combat.divers.size()):
		var d = combat.divers[i]
		if d.down:
			continue
		var p: Vector2 = STATION_POS[d.station] + Vector2(-24 + i * 34, 34)
		Art.draw_diver(self, d.cost, p, 46.0, 1)
