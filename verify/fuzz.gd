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

const ACTIONS := 15000          # sized so the RANDOM share alone clears 10,000
const POST_OVER_ACTIONS := 8    # keep hammering a finished fight before reset
const FIGHT_CAP := 60
const GUIDED_PCT := 22          # share steered by Bots.greedy, purely to reach victory states

var findings: Array = []        # stable signatures, in first-seen order
var texts: Dictionary = {}      # signature -> first full text
var hits: Dictionary = {}       # signature -> times observed
var n: Dictionary = {}          # measured counters
var air_peak := 0
var air_floor := 99
# The ceiling is ASKED OF THE SIM, not written down here: a turn's refill plus
# at most one overdraft. Hardcoding 5 would turn any future air tuning into a
# false finding, and the point of a fuzzer is that its red means something.
var air_max := 5

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
		# you may push past an empty tank ONCE per fight, paying the
		# shortfall in HP, so long as it does not kill you outright
		if c._desperate.has(i):
			return false
		var short: int = int(d.cost) - c.air
		if short * Combat.STRAIN_HP >= int(d.hp):
			return false
	# A disabler standing at BACKLINE reaches whatever is winding up, with
	# no limb at its own station. Modelled independently of can_attack on
	# purpose: this function's job is to disagree with the sim when the sim
	# is wrong, so it must not simply call it. It DID lack this rule, and
	# reported 234 legal attacks as illegal the first time BACKLINE opened.
	if d.disables and int(d.station) == Combat.BACKLINE:
		# and "something is announced" is not "something can still be shut":
		# a limb already shut down or already broken is not a target. Stated
		# here as the rule, not delegated to the sim's own answer.
		for it in c.intents():
			if int(c.limb_stun[int(it.limb)]) <= 0 and not bool(c.limb_broken[int(it.limb)]) \
					and not c._no_reshut.has(int(it.limb)):
				return true
		return false
	var limb: int = c.STATION_LIMB[int(d.station)]
	if limb < 0:
		return false
	return not bool(c.limb_broken[limb])

func expect_move(c: Combat, i: int, s: int) -> bool:
	var d = c.divers[i]
	if c.outcome != "ongoing" or d.down:
		return false
	if not c.can_move_now(i):
		return false
	# a station that is not open in this encounter is not a legal
	# destination. Fight one runs on four; BACKLINE arrives with the
	# scanner in fight two.
	if not (s in c.OPEN_STATIONS):
		return false
	for o in c.divers:
		if not o.down and int(o.station) == s:
			return false
	return int(d.station) != s

# `used` is the fuzzer's OWN count of overdrafts accepted since the last
# end_turn, not the sim's flag. Reading the sim's bookkeeping to predict the
# sim's answer would make this check agree with itself by construction; the
# valve is once per turn, so the mirror counts turns independently.
func expect_overdraft(c: Combat, i: int, used: bool) -> bool:
	var d = c.divers[i]
	if not Combat.OVERDRAFT_ENABLED:
		return false
	if c.outcome != "ongoing" or d.down or used:
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

	if c.air < 0 or c.air > air_max:
		fail("air-range", "AIR OUT OF RANGE: air %d, bounds 0..%d (%d per turn plus at most one overdraft), after %s"
			% [c.air, air_max, air_max - 1, kind])
	air_peak = max(air_peak, c.air)
	air_floor = min(air_floor, c.air)

	# The limb count is CONTENT, not three. The descent has one limb, and
	# this loop indexed past the end of its array the moment the fuzz stopped
	# running only the crab. Standing rule 3: measure, never assume.
	for i in range(c.limb_hp.size()):
		if int(c.limb_hp[i]) < 0:
			fail("limb-negative", "LIMB HP NEGATIVE: %s at %d after %s"
				% [c.LIMB_NAMES[i], c.limb_hp[i], kind])
		if int(c.limb_hp[i]) > int(pre_limb[i]):
			fail("limb-healed", "LIMB HEALED: %s went %d -> %d after %s"
				% [c.LIMB_NAMES[i], pre_limb[i], c.limb_hp[i], kind])
		if bool(pre_broken[i]) and not bool(c.limb_broken[i]):
			fail("limb-unbroken", "A BROKEN LIMB CAME BACK: %s was broken and is not, after %s"
				% [c.LIMB_NAMES[i], kind])

	if not (c.outcome in ["ongoing", "victory", "defeat"]):
		fail("outcome-value", "OUTCOME IS NOT A LEGAL VALUE: '%s' after %s" % [c.outcome, kind])
	if pre_outcome != "ongoing" and c.outcome == "ongoing":
		fail("outcome-reopened", "A FINISHED FIGHT REOPENED: '%s' -> 'ongoing' after %s"
			% [pre_outcome, kind])

# The hostile loop used to call Combat.new() with no argument every time,
# which is the crab and only ever the crab. 71 fights, one encounter, so
# three of four encounters were never fuzzed at all and BACKLINE -- closed
# on the crab -- was never once open. A new invariant about who can be hit
# where sampled nothing and survived deliberate sabotage. Rotate.
var enc_turn := 0

func next_encounter() -> Combat:
	var ids: Array = Encounters.ALL.keys()
	var id := String(ids[enc_turn % ids.size()])
	enc_turn += 1
	return Combat.new(id)

# ---- the hostile loop --------------------------------------------------
func fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260805
	var c := next_encounter()
	air_max = c.air_this_turn() + 1
	bump("fights")
	var post_over := 0
	var last_was_end := false
	var od_used := false      # the fuzzer's own once-per-turn tally
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
			var lim: int = c.STATION_LIMB[int(d.station)] if (int(d.station) >= 0 and int(d.station) <= 4) else -1
			if lim < 0 or bool(c.limb_broken[lim]):
				bump("ill_nolimb")
			expected = expect_attack(c, i)
			accepted = c.act_ability(i, rng.randi_range(0, 1))
			last_was_end = false
		elif mode == "move":
			kind = "move to %s" % Combat.STATION_NAMES[s]
			bump("try_move")
			if int(d.station) == s:
				bump("ill_same")
			if not (s in c.OPEN_STATIONS):
				bump("ill_closed")
			if not c.can_move_now(i):
				bump("ill_air")
			expected = expect_move(c, i, s)
			accepted = c.act_move(i, s)
			last_was_end = false
		elif mode == "overdraft":
			kind = "overdraft"
			bump("try_over")
			if int(d.hp) <= Combat.OVERDRAFT_HP:
				bump("ill_lowhp")
			if od_used:
				bump("ill_od_twice")
			expected = expect_overdraft(c, i, od_used)
			accepted = c.act_overdraft(i)
			if accepted:
				od_used = true
			last_was_end = false
		else:
			kind = "end_turn"
			bump("try_end")
			if last_was_end:
				bump("ill_end_repeat")
			if over_before:
				bump("end_after_over")
			# The ring is a PROMISE: red means an announced attack lands on
			# that station this turn, blue means none does. Check it end to
			# end -- anyone standing on an unthreatened station must come
			# through the enemy's turn without losing a point. The screen
			# drew "safe to stand" wherever no limb STOOD, which is a
			# different question from where an arc REACHES, so BACKLINE was
			# blue while 3 damage was announced against it.
			var threat: Array = c.threatened_stations()
			var before_hp: Dictionary = {}
			for dd in c.divers:
				if not dd.down and not (int(dd.station) in threat):
					before_hp[dd.id] = int(dd.hp)
			c.end_turn()
			for did in before_hp.keys():
				var now := int(c.divers[did].hp)
				if now < int(before_hp[did]):
					fail("blue_ring_lied", "BLUE RING LIED: %s stood on %s, which no announced attack named, and lost %d HP anyway" % [
						c.divers[did].dname, Combat.STATION_NAMES[int(c.divers[did].station)],
						int(before_hp[did]) - now])
			od_used = false
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
				c = next_encounter()
				bump("fights")
				post_over = 0
				last_was_end = false
				od_used = false
		elif c.turn > FIGHT_CAP:
			bump("capped")
			c = next_encounter()
			bump("fights")
			post_over = 0
			last_was_end = false
			od_used = false

# ---- one contained probe, on a throwaway sim ---------------------------
# The main loop keeps move targets inside 0..4, so on its own the station
# invariant could never fire and would be a check that proves nothing. This
# asks the one question that can move a diver off the board: does act_move
# validate its argument? It runs on a Combat that is thrown away immediately,
# and the engine's own index error goes to stderr, not to this report.
func probe_station_bounds() -> void:
	# 5 is one past the board; -1 is the interesting one, because GDScript
	# indexes arrays from the end for negatives, so it raises no engine error
	# at all and act_move returns TRUE on a diver that is now nowhere.
	for bad in [5, -1]:
		var c := Combat.new()
		var air_before: int = c.air
		# MEASURE the start, never assume it. This line used to compare
		# against a hardcoded 0 and fired falsely the moment encounters
		# became data and Scuba started somewhere else. Standing rule 3
		# applies to a detector's expectations, not just its labels.
		var station_before: int = int(c.divers[0].station)
		var accepted: bool = c.act_move(0, bad)
		var d = c.divers[0]
		bump("probes")
		if int(d.station) < 0 or int(d.station) > 4:
			fail("move-unvalidated", "act_move DOES NOT VALIDATE ITS STATION: act_move(0, %d) left %s at station %d, which is off the board (0..4)"
				% [bad, d.dname, d.station])
		if not accepted and (int(c.air) != air_before or int(d.station) != station_before):
			fail("move-unvalidated-silent", "act_move(0, %d) returned false yet spent %d Air and moved %s to %d: a caller cannot tell refusal from corruption"
				% [bad, air_before - int(c.air), d.dname, d.station])

func _init() -> void:
	var t := Time.get_ticks_usec()
	fuzz()
	probe_station_bounds()
	print(("fuzz %d actions, %d random and %d steered by Bots.greedy  %d accepted %d rejected (end_turn %d, always legal) | tried: attack %d  move %d  overdraft %d  end_turn %d"
		+ " | illegal by construction, counted: fight already over %d, downed diver %d, not enough Air %d, station with no live limb %d,"
		+ " move to the station already occupied %d, move to a station not open in this encounter %d, overdraft at hp<=%d %d, second overdraft in one turn %d, end_turn twice in a row %d"
		+ " | %d fights: %d victory %d defeat %d hit the %d-turn cap | %d invariant sweeps, air seen %d..%d (bound 0..%d)"
		+ " | plus %d off-the-board move probes on throwaway sims | ran in %.0f ms")
		% [ACTIONS, ACTIONS - got("guided"), got("guided"), got("accepted"), got("rejected"), got("ok_end"),
			got("try_attack"), got("try_move"), got("try_over"), got("try_end"),
			got("ill_over"), got("ill_down"), got("ill_air"), got("ill_nolimb"),
			got("ill_same"), got("ill_closed"), Combat.OVERDRAFT_HP, got("ill_lowhp"), got("ill_od_twice"), got("ill_end_repeat"),
			got("fights"), got("end_victory"), got("end_defeat"), got("capped"), FIGHT_CAP,
			got("sweeps"), air_floor, air_peak, air_max, got("probes"),
			(Time.get_ticks_usec() - t) / 1000.0])
	# quit() only REQUESTS a quit; it does not return from _init, so without
	# this the clean path falls straight through and re-quits with 1.
	if findings.is_empty():
		print("FUZZ: clean")
		quit(0)
		return
	for s in findings:
		var text: String = texts[s]
		print("FINDING  %s  [%d occurrence(s)]" % [text, int(hits.get(s, 0))])
	print("FUZZ: %d finding(s)" % findings.size())
	quit(1)
