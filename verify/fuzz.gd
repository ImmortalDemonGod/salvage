# The hostile set (G1, PROGRESS.md). checks.gd asks whether the fight is worth
# playing; this asks whether it can be BROKEN. 12,000 random actions, most of
# them deliberately illegal, with every invariant re-checked after every single
# one. It enters through the same four functions the input handler calls --
# act_attack, act_move, act_overdraft, end_turn -- so anything the sim survives
# here it survives under a hostile player (SPEC 4.3, G14).
#
# Every number this prints is COUNTED, not claimed: rejected-vs-accepted, the
# illegal categories actually reached, the outcomes actually observed.
#
# Usage: godot --headless --path ~/salvage --script verify/fuzz.gd
extends SceneTree

const ACTIONS := 12000
const AIR_MAX := 5              # AIR_PER_TURN 4, plus at most one overdraft
const POST_OVER_ACTIONS := 8    # keep hammering a finished fight before reset
const FIGHT_CAP := 60
const GUIDED_PCT := 14          # share steered by Bots.greedy, to reach victory

var findings: Array = []        # stable signatures, in first-seen order
var texts: Dictionary = {}      # signature -> first full text
var hits: Dictionary = {}       # signature -> times observed
var n: Dictionary = {}          # measured counters
var air_peak := 0
var air_floor := 99

func fail(sig: String, text: String) -> void:
	if not hits.has(sig):
		findings.append(sig)
		texts[sig] = text
	hits[sig] = int(hits.get(sig, 0)) + 1

func bump(k: String) -> void:
	n[k] = int(n.get(k, 0)) + 1

func got(k: String) -> int:
	return int(n.get(k, 0))

# ---- state capture -----------------------------------------------------
func snapshot(c: Combat) -> Dictionary:
	var hp: Array = []
	var st: Array = []
	var dn: Array = []
	for d in c.divers:
		hp.append(d.hp)
		st.append(d.station)
		dn.append(d.down)
	return {
		"hp": hp, "st": st, "down": dn,
		"limb_hp": c.limb_hp.duplicate(),
		"broken": c.limb_broken.duplicate(),
		"air": c.air, "turn": c.turn, "outcome": c.outcome,
	}

func same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

func unchanged(pre: Dictionary, post: Dictionary) -> bool:
	var a1: Array = pre["hp"]
	var b1: Array = post["hp"]
	var a2: Array = pre["st"]
	var b2: Array = post["st"]
	var a3: Array = pre["down"]
	var b3: Array = post["down"]
	var a4: Array = pre["limb_hp"]
	var b4: Array = post["limb_hp"]
	var a5: Array = pre["broken"]
	var b5: Array = post["broken"]
	if not (same(a1, b1) and same(a2, b2) and same(a3, b3) and same(a4, b4) and same(a5, b5)):
		return false
	return int(pre["air"]) == int(post["air"]) \
		and int(pre["turn"]) == int(post["turn"]) \
		and String(pre["outcome"]) == String(post["outcome"])

# ---- the mirror: what the rules SAY should happen ----------------------
# Written from the rules, not from the code path, so that "accepted an illegal
# action" and "rejected a legal one" are both catchable.
func expect_attack(c: Combat, i: int) -> bool:
	var d = c.divers[i]
	if c.outcome != "ongoing" or d.down:
		return false
	if int(d.station) < 0 or int(d.station) > 4:
		return false
	if c.air < int(d.cost):
		return false
	var limb: int = Combat.STATION_LIMB[int(d.station)]
	if limb < 0:
		return false
	return not bool(c.limb_broken[limb])

func expect_move(c: Combat, i: int, s: int) -> bool:
	var d = c.divers[i]
	if c.outcome != "ongoing" or d.down:
		return false
	if c.air < Combat.MOVE_COST:
		return false
	return int(d.station) != s

func expect_overdraft(c: Combat, i: int) -> bool:
	var d = c.divers[i]
	if c.outcome != "ongoing" or d.down:
		return false
	return int(d.hp) > Combat.OVERDRAFT_HP

# ---- the invariants, re-checked after EVERY action ---------------------
func check(c: Combat, pre: Dictionary, kind: String) -> void:
	bump("sweeps")
	var pre_down: Array = pre["down"]
	var pre_broken: Array = pre["broken"]
	var pre_limb: Array = pre["limb_hp"]
	var pre_outcome: String = pre["outcome"]

	for d in c.divers:
		if int(d.hp) < 0 or int(d.hp) > int(d.max_hp):
			fail("hp-range", "HP OUT OF RANGE: %s at %d hp, bounds 0..%d, after %s"
				% [d.dname, d.hp, d.max_hp, kind])
		if int(d.station) < 0 or int(d.station) > 4:
			fail("station-range", "STATION OUT OF RANGE: %s at station %d, bounds 0..4, after %s"
				% [d.dname, d.station, kind])
	for i in range(c.divers.size()):
		var d2 = c.divers[i]
		if bool(pre_down[i]) and not bool(d2.down):
			fail("down-revived", "A DOWNED DIVER CAME BACK: %s was down and is not, after %s"
				% [d2.dname, kind])

	if c.air < 0 or c.air > AIR_MAX:
		fail("air-range", "AIR OUT OF RANGE: air %d, bounds 0..%d (%d base plus at most one overdraft), after %s"
			% [c.air, AIR_MAX, Combat.AIR_PER_TURN, kind])
	air_peak = max(air_peak, c.air)
	air_floor = min(air_floor, c.air)

	for i in range(3):
		if int(c.limb_hp[i]) < 0:
			fail("limb-negative", "LIMB HP NEGATIVE: %s at %d after %s"
				% [Combat.LIMB_NAMES[i], c.limb_hp[i], kind])
		if int(c.limb_hp[i]) > int(pre_limb[i]):
			fail("limb-healed", "LIMB HEALED: %s went %d -> %d after %s"
				% [Combat.LIMB_NAMES[i], pre_limb[i], c.limb_hp[i], kind])
		if bool(pre_broken[i]) and not bool(c.limb_broken[i]):
			fail("limb-unbroken", "A BROKEN LIMB CAME BACK: %s was broken and is not, after %s"
				% [Combat.LIMB_NAMES[i], kind])

	if not (c.outcome in ["ongoing", "victory", "defeat"]):
		fail("outcome-value", "OUTCOME IS NOT A LEGAL VALUE: '%s' after %s" % [c.outcome, kind])
	if pre_outcome != "ongoing" and c.outcome == "ongoing":
		fail("outcome-reopened", "A FINISHED FIGHT REOPENED: '%s' -> 'ongoing' after %s"
			% [pre_outcome, kind])

# ---- the hostile loop --------------------------------------------------
func fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260805
	var c := Combat.new()
	bump("fights")
	var post_over := 0
	var last_was_end := false
	var acted := 0

	while acted < ACTIONS:
		acted += 1
		var pre: Dictionary = snapshot(c)
		var pre_down: Array = pre["down"]
		var over_before: bool = String(pre["outcome"]) != "ongoing"
		var i: int = rng.randi() % c.divers.size()
		var d = c.divers[i]
		var s: int = rng.randi() % 5
		var mode := ""
		var kind := ""
		var expected := false
		var accepted := false

		# Pure noise almost never breaks three limbs, so it almost never reaches
		# a VICTORY state to be hostile to. A minority of actions are steered by
		# the pinned greedy policy purely to walk the fuzzer into those states;
		# they go through the identical entry points and are counted separately.
		var guided := false
		if c.outcome == "ongoing" and rng.randi() % 100 < GUIDED_PCT:
			var g: Dictionary = Bots.greedy(c, rng)
			if not g.is_empty():
				guided = true
				bump("guided")
				i = int(g["i"])
				d = c.divers[i]
				mode = String(g["kind"])
				if mode == "move":
					s = int(g["s"])
		if not guided:
			var roll: int = rng.randi() % 100
			if roll < 30:
				mode = "attack"
			elif roll < 60:
				mode = "move"
			elif roll < 80:
				mode = "overdraft"
			else:
				mode = "end_turn"

		if over_before:
			bump("ill_over")
		if bool(pre_down[i]) and mode != "end_turn":
			bump("ill_down")

		if mode == "attack":
			kind = "attack"
			bump("try_attack")
			if c.air < int(d.cost):
				bump("ill_air")
			var lim: int = Combat.STATION_LIMB[int(d.station)] if (int(d.station) >= 0 and int(d.station) <= 4) else -1
			if lim < 0 or bool(c.limb_broken[lim]):
				bump("ill_nolimb")
			expected = expect_attack(c, i)
			accepted = c.act_attack(i)
			last_was_end = false
		elif mode == "move":
			kind = "move to %s" % Combat.STATION_NAMES[s]
			bump("try_move")
			if int(d.station) == s:
				bump("ill_same")
			if c.air < Combat.MOVE_COST:
				bump("ill_air")
			expected = expect_move(c, i, s)
			accepted = c.act_move(i, s)
			last_was_end = false
		elif mode == "overdraft":
			kind = "overdraft"
			bump("try_over")
			if int(d.hp) <= Combat.OVERDRAFT_HP:
				bump("ill_lowhp")
			expected = expect_overdraft(c, i)
			accepted = c.act_overdraft(i)
			last_was_end = false
		else:
			kind = "end_turn"
			bump("try_end")
			if last_was_end:
				bump("ill_end_repeat")
			if over_before:
				bump("end_after_over")
			c.end_turn()
			expected = true
			accepted = true
			last_was_end = true

		var post: Dictionary = snapshot(c)

		# accounting
		if kind == "end_turn":
			bump("ok_end")
		elif accepted:
			bump("accepted")
		else:
			bump("rejected")

		# the four act_ entry points must be pure no-ops when they say no,
		# and end_turn must be a no-op once the fight is over
		if not accepted and not unchanged(pre, post):
			fail("reject-mutated", "A REJECTED ACTION STILL CHANGED STATE: %s" % kind)
		if kind == "end_turn" and over_before and not unchanged(pre, post):
			fail("end-after-over", "end_turn MUTATED A FINISHED FIGHT: outcome was '%s'" % String(pre["outcome"]))

		# a down diver never acts successfully
		if kind != "end_turn" and bool(pre_down[i]) and accepted:
			fail("down-acted", "A DOWN DIVER ACTED: %s accepted %s while down" % [d.dname, kind])
		# and neither does anybody once the fight is decided
		if kind != "end_turn" and over_before and accepted:
			fail("acted-after-over", "ACTION ACCEPTED AFTER THE FIGHT ENDED: %s, outcome '%s'"
				% [kind, String(pre["outcome"])])

		# the mirror
		if kind != "end_turn":
			if expected and not accepted:
				fail("rejected-legal", "REJECTED A LEGAL ACTION: %s by %s" % [kind, d.dname])
			if accepted and not expected:
				fail("accepted-illegal", "ACCEPTED AN ILLEGAL ACTION: %s by %s" % [kind, d.dname])

		check(c, pre, kind)

		# outcomes, counted where they actually happen
		if not over_before and c.outcome != "ongoing":
			bump("end_" + c.outcome)

		if c.outcome != "ongoing":
			post_over += 1
			if post_over >= POST_OVER_ACTIONS:
				c = Combat.new()
				bump("fights")
				post_over = 0
				last_was_end = false
		elif c.turn > FIGHT_CAP:
			bump("capped")
			c = Combat.new()
			bump("fights")
			post_over = 0
			last_was_end = false

func _init() -> void:
	var t := Time.get_ticks_usec()
	fuzz()
	print(("fuzz %d actions, %d random and %d steered by Bots.greedy  %d accepted %d rejected (end_turn %d, always legal) | tried: attack %d  move %d  overdraft %d  end_turn %d"
		+ " | illegal by construction, counted: fight already over %d, downed diver %d, not enough Air %d, station with no live limb %d,"
		+ " move to the station already occupied %d, overdraft at hp<=%d %d, end_turn twice in a row %d"
		+ " | %d fights: %d victory %d defeat %d hit the %d-turn cap | %d invariant sweeps, air seen %d..%d (bound 0..%d) | ran in %.0f ms")
		% [ACTIONS, ACTIONS - got("guided"), got("guided"), got("accepted"), got("rejected"), got("ok_end"),
			got("try_attack"), got("try_move"), got("try_over"), got("try_end"),
			got("ill_over"), got("ill_down"), got("ill_air"), got("ill_nolimb"),
			got("ill_same"), Combat.OVERDRAFT_HP, got("ill_lowhp"), got("ill_end_repeat"),
			got("fights"), got("end_victory"), got("end_defeat"), got("capped"), FIGHT_CAP,
			got("sweeps"), air_floor, air_peak, AIR_MAX,
			(Time.get_ticks_usec() - t) / 1000.0])
	if findings.is_empty():
		print("FUZZ: clean")
		quit(0)
	for s in findings:
		var text: String = texts[s]
		print("FINDING  %s  [%d occurrence(s)]" % [text, int(hits.get(s, 0))])
	print("FUZZ: %d finding(s)" % findings.size())
	quit(1)
