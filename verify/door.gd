extends SceneTree

# G14-DOOR. The player has exactly one way in: the key map in game/main.gd.
# Twice now a mechanic has existed in the sim, been driven by the bots and
# the verifiers, and been unreachable by anyone actually playing:
#
#   the overdraft   built, bot-driven, never bound to a key
#   the six kits    built, bot-driven, only slot 0 bound to a key
#
# Both passed every gate, because every gate drove the sim directly. A blind
# reviewer found the second one in one sentence: "there is nothing on screen
# indicating a second or alternate attack for either character."
#
# So this check reads the key map as text and holds it against the content:
#   1. every ability slot that any diver owns is bound to some key
#   2. every key in the map calls a function that exists
#   3. no key calls a function gated on a const that is false
#   4. every verifier that claims to drive the player drives a bound function

const Content = preload("res://content/encounters.gd")

var findings := 0

func fail(msg: String) -> void:
	findings += 1
	print("FINDING  %s" % msg)

# A comment that mentions a call is not a call. The first run of this check
# flagged its own explanatory comment.
func decomment(text: String) -> String:
	var out: Array = []
	for line in text.split("\n"):
		var cut := line.find("#")
		if cut >= 0 and line.substr(0, cut).count("\"") % 2 == 0:
			line = line.substr(0, cut)
		var slash := line.find("//")
		if slash >= 0 and line.substr(0, slash).count("\"") % 2 == 0:
			line = line.substr(0, slash)
		out.append(line)
	return "\n".join(out)

func read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		fail("CANNOT READ %s" % path)
		return ""
	return f.get_as_text()

func _init() -> void:
	var main := decomment(read("res://game/main.gd"))
	if main == "":
		_done()
		return

	# --- the key map, as the engine will actually dispatch it ---
	var map: Dictionary = {}          # KEY_NAME -> the call it makes
	var in_match := false
	var handler := main.split("func _unhandled_input")
	if handler.size() < 2:
		fail("NO INPUT HANDLER FOUND in game/main.gd -- this check is asleep")
		_done()
		return
	var body: String = String(handler[1])
	for raw in body.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("match k:"):
			in_match = true
			continue
		if in_match and line.begins_with("func "):
			break
		if not in_match:
			continue
		var m := RegEx.create_from_string("^(KEY_[A-Z0-9_]+):\\s*(.*)$").search(line)
		if m != null:
			map[m.get_string(1)] = m.get_string(2).strip_edges()
	if map.is_empty():
		fail("NO KEY MAP FOUND in game/main.gd -- this check is asleep")
		_done()
		return

	# Blocks (KEY_1: then an indented body) carry their calls on later lines.
	# Fold every player_* call in the file into a reachable set, but only if
	# it sits under the match. Simpler and stricter: scan the match region.
	var region := body.split("\nfunc ")[0]
	var bound: Dictionary = {}
	for m in RegEx.create_from_string("(player_[a-z_]+)\\s*\\(([^)]*)\\)").search_all(region):
		var fn := m.get_string(1)
		var arg := m.get_string(2).strip_edges()
		if not bound.has(fn):
			bound[fn] = []
		if arg != "" and not (arg in bound[fn]):
			bound[fn].append(arg)

	# --- 1. every ability slot any diver owns must be bound ---
	var widest := 0
	for enc_id in Content.ALL.keys():
		var probe := Combat.new(String(enc_id))
		for d in probe.divers:
			widest = max(widest, int(d.kit.size()))
	var slots: Array = bound.get("player_ability", [])
	for slot in range(widest):
		if not (str(slot) in slots):
			fail("UNREACHABLE ABILITY: a diver owns slot %d and no key calls player_ability(%d). The bots can use it; the player cannot." % [slot, slot])
	if slots.size() > widest:
		fail("KEY BOUND TO NOTHING: player_ability is bound for %d slots and the widest kit is %d" % [slots.size(), widest])

	# --- 2. every function the map calls must exist ---
	for fn in bound.keys():
		if not ("func %s(" % fn) in main:
			fail("KEY CALLS A MISSING FUNCTION: the map calls %s() and game/main.gd does not define it" % fn)

	# --- 3. no key may call into a mechanic that is switched off ---
	var sim := decomment(read("res://sim/combat.gd"))
	for m in RegEx.create_from_string("const ([A-Z_]+_ENABLED)\\s*:=\\s*(true|false)").search_all(sim):
		if m.get_string(2) != "false":
			continue
		var flag := m.get_string(1)
		var mech := flag.trim_suffix("_ENABLED").to_lower()
		for fn in bound.keys():
			if mech in fn:
				fail("KEY BOUND TO A CUT MECHANIC: %s() is on the key map and %s is false, so pressing it can never do anything" % [fn, flag])

	# --- 4. anything claiming to drive the player must drive a bound door ---
	for path in ["res://verify/differential.gd", "res://verify/layout.gd", "res://verify/capture.mjs"]:
		var text := decomment(read(path))
		if text == "":
			continue
		for m in RegEx.create_from_string("scene\\.(player_[a-z_]+)").search_all(text):
			var fn := m.get_string(1)
			if not bound.has(fn):
				fail("VERIFIER DRIVES AN UNBOUND DOOR: %s calls scene.%s() and no key reaches it, so it is not testing what a player does" % [path.get_file(), fn])

	# --- 5. every ability KIND has motion of its own ---------------------
	# The last project's defect ledger, entry 2: "all six abilities played
	# one shared nudge", and its prescribed fix was an invariant, not a
	# note. This build added motion and re-shipped the same defect, so the
	# invariant gets built this time: a kind with no branch of its own falls
	# through to the default and moves like everything else.
	var kinds: Array = []
	for enc_id2 in Content.ALL.keys():
		var probe2 := Combat.new(String(enc_id2))
		for d2 in probe2.divers:
			for ab in d2.kit:
				var kd := String(ab.kind)
				if not (kd in kinds):
					kinds.append(kd)
	# bound the region to the HIT arm itself. Taking everything AFTER it
	# swept in the card-text builder, which names the same kinds for a
	# different purpose, and the check passed a deliberate sabotage.
	# bound to _motion FIRST: the file gained a second Kind.HIT match arm
	# (_rig_react, which picks animation clips) and splitting on the bare
	# marker read that arm instead, reporting three kinds uncovered while
	# the real motion arm still covered them all
	var motion_fn := main.split("func _motion(")
	var arm := ""
	if motion_fn.size() > 1:
		var motion := String(motion_fn[motion_fn.size() - 1]).split("SfxEvents.Kind.HIT:")
		if motion.size() > 1:
			arm = String(motion[1]).split("SfxEvents.Kind.TAKE:")[0]
	if arm.strip_edges() == "":
		fail("NO MOTION ARM FOUND in game/main.gd -- this check is asleep")
	var covered: Array = []
	for kd2 in kinds:
		if arm.find("\"%s\"" % kd2) >= 0:
			covered.append(kd2)
		elif kd2 != "hit":
			fail("ABILITY MOVES LIKE EVERY OTHER: kind '%s' has no motion of its own, so it falls through to the default nudge" % kd2)
	print("motion     %d ability kind(s), %d with motion of their own" % [kinds.size(), covered.size()])

	print("door       %d key(s) mapped, %d ability slot(s) bound, widest kit %d" % [map.size(), slots.size(), widest])
	_done()

func _done() -> void:
	print("DOOR: %s" % ("clean" if findings == 0 else "%d finding(s)" % findings))
	quit(1 if findings > 0 else 0)
	return
