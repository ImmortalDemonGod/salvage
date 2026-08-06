# The run: the beat ladder made playable. Pure, no Node, no scene.
#
# Until this existed the project had one fight and no game, so G2
# (winnable start to finish) and G12 (bypass) had nothing to measure.
# The ladder in content/beats.gd IS the flow: there is no second list of
# levels that could disagree with the teaching order.
class_name Run
extends RefCounted

const Beats := preload("res://content/beats.gd")
const Puzzle := preload("res://sim/puzzle.gd")

var beat := 0
var combat: Combat = null
var puzzle: Puzzle = null
var carried_hp: Dictionary = {}    # diver name -> hp, carried across a dive
var log_lines: Array = []
var finished := false
var salvage_lost := 0
# how many abilities each diver has earned. The ladder grants it; nothing
# else may. One at the start, so the first fight teaches one verb.
var abilities := 1

func _init() -> void:
	_enter()

# has the run already completed the beat with this id?
func _passed(id: String) -> bool:
	var bs := built_beats()
	for i in range(min(beat, bs.size())):
		if String(bs[i].id) == id:
			return true
	return false

func built_beats() -> Array:
	var out: Array = []
	for b in Beats.LADDER:
		if b.get("built", false):
			out.append(b)
	return out

func current() -> Dictionary:
	var bs := built_beats()
	if beat >= bs.size():
		return {}
	return bs[beat]

# how many abilities a diver has earned by the time this encounter is met.
# Progression lives in the ladder, so read it from the ladder rather than
# letting each instrument guess.
static func abilities_at(enc_id: String) -> int:
	var n := 1
	for b in Beats.LADDER:
		n = max(n, int(b.get("grants_ability", 0)))
		if String(b.get("encounter", "")) == enc_id:
			return n
	return n

func _enter() -> void:
	var b := current()
	if b.is_empty():
		finished = true
		combat = null
		return
	puzzle = null
	if int(b.get("grants_ability", 0)) > int(abilities):
		abilities = int(b.grants_ability)
		log_lines.append("the squad brings a second way to use what it has")
	# A3: a scene beat IS the boat. Surfacing restores the squad fully;
	# nothing restores mid-dive. Before this, carried_hp was written and
	# never cleared, so 1 HP followed the squad through every later fight.
	if String(b.get("kind", "scene")) == "scene":
		carried_hp.clear()
		log_lines.append("back on the rig: the squad patches up")
	if String(b.get("kind", "scene")) == "puzzle":
		puzzle = Puzzle.new()
		puzzle.stage = int(b.get("stage", 1))
		combat = null
		log_lines.append("%s" % String(b.title))
		return
	if String(b.get("kind", "scene")) == "combat":
		combat = Combat.new(String(b.encounter), abilities)
		# HP is carried across a dive and restored only at the boat
		# (SPEC 2b A3: the dive is the unit of attrition).
		for d in combat.divers:
			if carried_hp.has(d.dname):
				d.hp = min(int(carried_hp[d.dname]), d.max_hp)
				# A2: out for the fight, back at the boat. A diver banked at
				# 0 HP was returning alive at 0 and could still act, which is
				# a state no rule authorises.
				d.down = d.hp <= 0
		log_lines.append("%s" % String(b.title))
	else:
		combat = null
		log_lines.append("%s" % String(b.title))

func _bank_hp() -> void:
	if combat == null:
		return
	for d in combat.divers:
		carried_hp[d.dname] = d.hp

# Advance when the current beat is complete. Returns true if it moved.
func advance() -> bool:
	if finished:
		return false
	var b := current()
	# A3: a scene beat IS the boat. Surfacing restores the squad fully;
	# nothing restores mid-dive. Before this, carried_hp was written and
	# never cleared, so 1 HP followed the squad through every later fight.
	if String(b.get("kind", "scene")) == "scene":
		carried_hp.clear()
		log_lines.append("back on the rig: the squad patches up")
	if String(b.get("kind", "scene")) == "puzzle":
		# a puzzle beat completes when the lock is open, not on a timer
		if puzzle == null or not puzzle.solved():
			return false
		beat += 1
		_enter()
		return true
	if String(b.get("kind", "scene")) == "combat":
		if combat == null or combat.outcome == "ongoing":
			return false
		if combat.outcome == "defeat":
			# A4: the dive fails, you surface, you KEEP progress and lose the
			# salvage. Resetting to beat 0 destroyed progress, which is the
			# opposite of the ruling. Retry this beat with a patched squad.
			log_lines.append("the dive fails; the squad surfaces and loses the salvage")
			carried_hp.clear()
			salvage_lost += 1
			_enter()
			return true
		_bank_hp()
	beat += 1
	_enter()
	return true

func state_line() -> String:
	var b := current()
	if finished:
		return "run complete"
	return "beat %d/%d  %s" % [beat + 1, built_beats().size(), String(b.get("title", "?"))]
