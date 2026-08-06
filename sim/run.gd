# The run: the beat ladder made playable. Pure, no Node, no scene.
#
# Until this existed the project had one fight and no game, so G2
# (winnable start to finish) and G12 (bypass) had nothing to measure.
# The ladder in content/beats.gd IS the flow: there is no second list of
# levels that could disagree with the teaching order.
class_name Run
extends RefCounted

const Beats := preload("res://content/beats.gd")

var beat := 0
var combat: Combat = null
var carried_hp: Dictionary = {}    # diver name -> hp, carried across a dive
var log_lines: Array = []
var finished := false

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

func _enter() -> void:
	var b := current()
	if b.is_empty():
		finished = true
		combat = null
		return
	if String(b.get("kind", "scene")) == "combat":
		combat = Combat.new(String(b.encounter))
		# HP is carried across a dive and restored only at the boat
		# (SPEC 2b A3: the dive is the unit of attrition).
		for d in combat.divers:
			if carried_hp.has(d.dname):
				d.hp = min(int(carried_hp[d.dname]), d.max_hp)
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
	if String(b.get("kind", "scene")) == "combat":
		if combat == null or combat.outcome == "ongoing":
			return false
		if combat.outcome == "defeat":
			# A4: the dive fails, you surface, progress is kept.
			log_lines.append("the dive fails; the squad surfaces")
			carried_hp.clear()
			beat = 0
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
