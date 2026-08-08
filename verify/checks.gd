# The per-commit verification set. Fast by construction; the expensive
# dominance search belongs in the nightly bucket (SPEC 4b).
# Usage: godot --headless --path ~/salvage --script verify/checks.gd
extends SceneTree

# preload, never rely on class_name: a newly added class_name is not
# resolvable until the project is re-imported, which has now cost three
# round trips in this run.
const Run := preload("res://sim/run.gd")
const Encounters := preload("res://content/encounters.gd")

var findings: Array = []

func fail(s: String) -> void:
	findings.append(s)

# ---- G3: bands, PINNED BEFORE ANY TUNING ------------------------------
const CASUAL_WIN_LO := 0.55
const CASUAL_WIN_HI := 0.90
const GREEDY_TURNS_MIN := 6.0
const GREEDY_HP_MIN := 8.0

# EVERY encounter is banded, not just the default one. PROGRESS says each
# new enemy must pass the bands before the next one starts, and until this
# loop existed a second anatomy could ship completely unmeasured.
# A playtest review put it plainly: "no ring is ever blue", so movement is a
# 1-air tax on nothing and the whole spatial layer switches off. Measured,
# and it was true where it mattered: the spitter left nowhere safe on 3 of 8
# turns and the dredge on 11 of 17. One turn with nowhere safe is tension.
# Two in a row means the player has no move, so that is the line.
func check_safe_ground() -> void:
	for enc_id in Encounters.ALL.keys():
		var enc: Dictionary = Encounters.ALL[enc_id]
		if bool(enc.get("teaching", false)):
			print("safe %-9s SKIPPED: a teaching beat with one place to stand" % enc_id)
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var c := Combat.new(String(enc_id))
		var turns := 0
		var nowhere := 0
		var worst_run := 0
		var run_len := 0
		while c.outcome == "ongoing" and turns < 40:
			var th: Array = c.threatened_stations()
			var free := 0
			for st in c.OPEN_STATIONS:
				if not (int(st) in th):
					free += 1
			if free == 0:
				nowhere += 1
				run_len += 1
				worst_run = max(worst_run, run_len)
			else:
				run_len = 0
			turns += 1
			for _i in range(6):
				var act: Dictionary = Bots.greedy(c, rng)
				if act.is_empty() or not Bots.apply(c, act):
					break
			c.end_turn()
		print("safe %-9s %d of %d turns had nowhere safe to stand, worst run %d" % [enc_id, nowhere, turns, worst_run])
		if worst_run >= 2:
			fail("NOWHERE TO GO: %s leaves every open station threatened for %d turns running, so moving cannot help and the blue ring means nothing" % [enc_id, worst_run])

func check_bands(n: int) -> void:
	for key in Encounters.ALL.keys():
		var enc_id := String(key)
		if bool((Encounters.ALL[key] as Dictionary).get("teaching", false)):
			print("G3 %-9s SKIPPED: declared a teaching beat, not judged as a fight" % enc_id)
			continue
		var cw := 0
		var gt := 0
		var gh := 0
		# with what the player will actually be carrying by this beat, not
		# with the whole kit the sim can build
		var kit: int = Run.abilities_at(enc_id)
		for s in range(n):
			if Bots.run_fight(s, "casual", enc_id, 40, kit).win: cw += 1
			var g: Dictionary = Bots.run_fight(s, "greedy", enc_id, 40, kit)
			gt += int(g.turns)
			gh += int(g.hp_lost)
		var wr := float(cw) / n
		var turns := float(gt) / n
		var hp := float(gh) / n
		print("G3 %-9s casual win %.1f%% (band %.0f-%.0f)   greedy turns %.1f (min %.1f)   greedy hp lost %.1f (min %.1f)   [%d abilities earned by here]"
			% [enc_id, wr * 100, CASUAL_WIN_LO * 100, CASUAL_WIN_HI * 100, turns, GREEDY_TURNS_MIN, hp, GREEDY_HP_MIN, kit])
		if wr < CASUAL_WIN_LO or wr > CASUAL_WIN_HI:
			fail("G3 %s casual win rate %.1f%% outside band %.0f-%.0f" % [enc_id, wr * 100, CASUAL_WIN_LO * 100, CASUAL_WIN_HI * 100])
		if turns < GREEDY_TURNS_MIN:
			fail("G3 %s greedy clears in %.1f turns, floor is %.1f: the fight ends before it can teach" % [enc_id, turns, GREEDY_TURNS_MIN])
		if hp < GREEDY_HP_MIN:
			fail("G3 %s greedy loses only %.1f HP, floor is %.1f" % [enc_id, hp, GREEDY_HP_MIN])

# ---- dead / dominant station (SPEC 4.2) --------------------------------
# A station that is THREATENED but exposes NO LIMB is dead by construction:
# standing there costs you damage and buys you nothing. I built this same
# defect three times (the crab's claw, the worm's gut, the dredge's flank)
# before making it decidable from the data instead of waiting for the
# occupancy histogram to notice.
func check_station_design() -> void:
	for key in Encounters.ALL.keys():
		var enc: Dictionary = Encounters.ALL[key]
		var open: Array = enc.open_stations
		var limb_at: Array = Encounters.station_limb(enc)
		var threatened: Dictionary = {}
		for a in enc.attacks:
			for st in a.stations:
				threatened[int(st)] = true
		var safe := 0
		# BACKLINE is not empty when the drum is fitted: the disabler reaches
		# from there, which is the whole reason the station exists. The
		# first version of this check did not know that and fired on the
		# worm, where the occupancy histogram measures BACKLINE at 50
		# percent. When a static rule and a measurement disagree, the
		# measurement wins and the rule gets fixed.
		var drum: bool = bool(enc.get("drum", false))
		for st in open:
			var i := int(st)
			if i == Combat.BACKLINE and drum:
				continue
			var pries := false
			var probe2 := Combat.new(String(key))
			for nb in probe2.neighbours(i):
				var bl := int(probe2.STATION_LIMB[int(nb)])
				if bl >= 0 and bool((probe2.enc.limbs[bl] as Dictionary).get("blocks", false)):
					pries = true
			if limb_at[i] < 0 and threatened.has(i) and not pries:
				fail("STATION DEAD BY DESIGN in %s: %s is threatened but exposes no limb, so standing there costs damage and buys nothing"
					% [String(key), Combat.STATION_NAMES[i]])
			if limb_at[i] < 0 and not threatened.has(i):
				safe += 1
		if drum and (Combat.BACKLINE in open) and not threatened.has(Combat.BACKLINE):
			safe += 1
		if safe > 1:
			fail("DUPLICATE SAFETY in %s: %d stations are safe and expose nothing, so one dominates the other"
				% [String(key), safe])

func check_stations(n: int, enc_id := "crab") -> void:
	var probe := Combat.new(enc_id)
	var OPEN: Array = probe.OPEN_STATIONS
	# An encounter may declare ONE station a refuge: a place that exists to
	# be safe, not to act from. The judge is deliberately HP-averse and
	# per-action myopic, so it cannot price pure safety and a refuge will
	# read dead in its hands; a human under pressure is who a refuge is
	# for. The declaration is not free: the refuge must never appear in an
	# attack arc (hunts included, which can aim anywhere), and there must
	# be observed turns where it is the ONLY safe ground, or it is a dead
	# station wearing a name.
	var refuge := int(probe.enc.get("refuge", -1))
	var refuge_in_arc := false
	for a0 in probe.enc.attacks:
		if bool(a0.get("hunts", false)) or (refuge in (a0.get("stations", []) as Array)):
			refuge_in_arc = true
	var refuge_needed := false
	var occ := [0, 0, 0, 0, 0]
	var total := 0
	for s in range(n):
		var c := Combat.new(enc_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		while c.outcome == "ongoing" and c.turn <= 40:
			if refuge >= 0 and not refuge_needed:
				var th: Array = c.threatened_stations()
				var all_others := true
				for st0 in OPEN:
					if int(st0) != refuge and not (int(st0) in th):
						all_others = false
				if all_others:
					refuge_needed = true
			var guard := 0
			while guard < 12:
				guard += 1
				var a: Dictionary = Bots.greedy(c, rng)
				if a.is_empty() or not Bots.apply(c, a): break
				if c.outcome != "ongoing": break
			for d in c.divers:
				if not d.down:
					occ[d.station] += 1
					total += 1
			if c.outcome != "ongoing": break
			c.end_turn()
	var parts: Array = []
	for i in range(5):
		var pct: float = 100.0 * float(occ[i]) / float(max(1, total))
		var open_here: bool = i in OPEN
		parts.append("%s %.1f%%%s" % [Combat.STATION_NAMES[i], pct, "" if open_here else " (closed)"])
		if not open_here:
			continue
		if pct == 0.0:
			var blocked_ground := false
			var bl9: int = int(probe.STATION_LIMB[i])
			if bl9 >= 0 and bool((probe.enc.limbs[bl9] as Dictionary).get("blocks", false)):
				blocked_ground = true # a squatter's ground is for TAKING, not standing
			if (i == refuge and refuge_needed and not refuge_in_arc) or blocked_ground:
				pass
			else:
				fail("DEAD STATION in %s: %s is never occupied in optimal play" % [enc_id, Combat.STATION_NAMES[i]])
		if pct > 60.0 and OPEN.size() > 1:
			fail("DOMINANT STATION in %s: %s occupied %.1f%% of the time; positioning is theatre" % [enc_id, Combat.STATION_NAMES[i], pct])
	print("stations %-9s " % enc_id + "  ".join(parts))

# ---- G14: the telegraph never lies ------------------------------------
func check_telegraph(n: int) -> void:
	# Capture the announcement BEFORE the player acts, and test EVERY
	# encounter. The old version read intent() after the player's actions
	# and ran only on the crab, which has no drum: it was structurally
	# incapable of catching a shutdown substituting an unannounced attack,
	# and it reported 5,600 honest slots while the telegraph was lying.
	var checked := 0
	for key in Encounters.ALL.keys():
		for s in range(n):
			var c := Combat.new(String(key))
			var rng := RandomNumberGenerator.new()
			rng.seed = s + 9000
			var guard := 0
			while c.outcome == "ongoing" and guard < 30:
				guard += 1
				# duplicate(true): the shallow capture aliased the intent
				# dicts hit_shove once mutated in place, so this check
				# FOLLOWED the steer instead of testing it (Aug 8 audit).
				var announced: Array = c.intents().duplicate(true)
				var log0: int = c.log_lines.size()
				var inner := 0
				while inner < 8:
					inner += 1
					var a: Dictionary = Bots.casual(c, rng)
					if a.is_empty() or not Bots.apply(c, a):
						break
				if c.outcome != "ongoing":
					break
				# A steer (Axe Kick on a read limb) legitimately re-aims an
				# announced swing mid-turn -- but only if it SAYS so. Adopt
				# the new aim exactly when its "knocked around" line printed
				# this turn; a re-aim with no line stays a telegraph lie.
				for cur in c.intents():
					for an0 in announced:
						if int(an0.limb) != int(cur.limb) or an0.stations == cur.stations:
							continue
						var steer_line := "the %s is knocked around" % c.LIMB_NAMES[int(cur.limb)]
						for li in range(log0, c.log_lines.size()):
							if String(c.log_lines[li]).find(steer_line) >= 0:
								an0.stations = (cur.stations as Array).duplicate()
								an0.hunts = bool(cur.get("hunts", false))
								break
				var before: Array = []
				for d in c.divers:
					before.append(d.hp)
				# Snapshot the limb state BEFORE resolution: end_turn ticks
				# stun down, so reading it afterwards showed a limb that was
				# shut down during the turn as having been able to swing.
				var was_stunned: Array = c.limb_stun.duplicate()
				var was_broken: Array = c.limb_broken.duplicate()
				c.end_turn()
				if announced.is_empty():
					continue
				checked += 1
				for d in c.divers:
					var dealt: int = int(before[d.id]) - d.hp
					# EVERY announced attack can reach this diver, so the
					# expectation is the SUM. Reading only the first one
					# reported the telegraph lying when it was telling the
					# truth about a second swing.
					# Attacks resolve IN ORDER, and a diver that goes down
					# is skipped by every later swing. Summing blindly
					# expected damage the sim correctly never dealt.
					var nominal := 0
					var pool: int = int(before[d.id])
					for an in announced:
						var lb: int = int(an.limb)
						if bool(was_broken[lb]) or int(was_stunned[lb]) > 0:
							continue
						if pool <= 0:
							break
						if int(d.station) in an.stations:
							var bite: int = min(int(an.dmg), pool)
							nominal += bite
							pool -= bite
					var expected: int = nominal
					if dealt != expected:
						fail("TELEGRAPH LIES in %s: announced %d to %s, delivered %d" % [String(key), expected, Combat.STATION_NAMES[d.station], dealt])
						return
	print("telegraph  %d hostile slots across %d encounters, announced == delivered" % [checked, Encounters.ALL.size()])

# G2: the slice is winnable start to finish, and a win exists from every
# reachable state. Positioning adds a real softlock risk (a diver stranded
# where it can neither act usefully nor retreat) and only playing the whole
# ladder catches it.
# A2, A3, A4: the run rules, checked rather than trusted. An adversarial
# fidelity round found all three silently absent while every gate was green,
# because nothing looked at what happens BETWEEN fights.
func check_run_rules() -> void:
	var r := Run.new()
	var g := 0
	while (r.combat == null or r.combat.enc_id != "crab") and g < 20:
		g += 1
		_force(r)
	if r.combat == null:
		fail("A-RULES: could not reach a fight to test the run rules")
		return
	r.combat.divers[0].hp = 0
	r.combat.divers[0].down = true
	r.combat.divers[1].hp = 3
	_force(r)
	if not r.carried_hp.is_empty():
		fail("A3 VIOLATED: HP carried past the boat; the dive is not the unit of attrition")
	g = 0
	while r.combat == null and g < 20:
		g += 1
		_force(r)
	for d in r.combat.divers:
		if d.hp <= 0 and not d.down:
			fail("A2 VIOLATED: %s re-entered a fight at 0 HP and able to act" % d.dname)
		if d.hp < d.max_hp:
			fail("A3 VIOLATED: %s entered the next dive on %d of %d HP" % [d.dname, d.hp, d.max_hp])
	var before: int = r.beat
	for d in r.combat.divers:
		d.hp = 0
		d.down = true
	r.combat.outcome = "defeat"
	r.advance()
	if r.beat != before:
		fail("A4 VIOLATED: defeat moved the run from beat %d to %d instead of keeping progress" % [before, r.beat])
	if r.salvage_lost < 1:
		fail("A4 VIOLATED: a failed dive cost no salvage")
	print("A-rules    A2 down stays down, A3 the boat heals, A4 defeat keeps progress and costs salvage")

func _force(r) -> void:
	if r.combat != null:
		for i in range(r.combat.limb_hp.size()):
			r.combat.limb_hp[i] = 0
			r.combat.limb_broken[i] = true
		r.combat.outcome = "victory"
	elif r.puzzle != null:
		if not Bots.solve_puzzle(r.puzzle):
			push_error("THE LOCK CANNOT BE SOLVED by the naive policy at stage %d" % r.puzzle.stage)
	r.advance()

func check_run(n: int) -> void:
	var cleared := 0
	var worst := 0
	for s in range(n):
		var r := Run.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var acts := 0
		while not r.finished and acts < 4000:
			acts += 1
			if r.puzzle != null:
				var step: int = Bots.solve_step(r.puzzle)
				if step < 0:
					r.advance()
				else:
					r.puzzle.toggle(step)
				continue
			if r.combat == null:
				r.advance()
				continue
			var a: Dictionary = Bots.greedy(r.combat, rng)
			if a.is_empty() or not Bots.apply(r.combat, a):
				r.combat.end_turn()
			if r.combat.outcome != "ongoing":
				r.advance()
		if r.finished:
			cleared += 1
		worst = max(worst, acts)
	print("G2 run       %d/%d cleared the built ladder, worst %d actions" % [cleared, n, worst])
	if cleared < n:
		fail("G2 NOT WINNABLE: %d of %d runs failed to reach the end of the built ladder" % [n - cleared, n])

func _init() -> void:
	var t := Time.get_ticks_usec()
	check_station_design()
	check_safe_ground()
	check_bands(1000)
	check_run(40)
	check_run_rules()
	for k in Encounters.ALL.keys():
		check_stations(300, String(k))
	check_telegraph(300)
	print("ran in %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	if findings.is_empty():
		print("VERIFY: clean")
		# quit() only REQUESTS a quit; without the return the clean path falls
		# through and re-quits with 1. Found by the fuzz agent: a fully
		# green fast set was reporting a false red on its exit code.
		quit(0)
		return
	for f in findings:
		print("FINDING  " + f)
	print("VERIFY: %d finding(s)" % findings.size())
	quit(1)
