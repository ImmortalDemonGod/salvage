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
func check_bands(n: int) -> void:
	for key in Encounters.ALL.keys():
		var enc_id := String(key)
		if bool((Encounters.ALL[key] as Dictionary).get("teaching", false)):
			print("G3 %-9s SKIPPED: declared a teaching beat, not judged as a fight" % enc_id)
			continue
		var cw := 0
		var gt := 0
		var gh := 0
		for s in range(n):
			if Bots.run_fight(s, "casual", enc_id).win: cw += 1
			var g: Dictionary = Bots.run_fight(s, "greedy", enc_id)
			gt += int(g.turns)
			gh += int(g.hp_lost)
		var wr := float(cw) / n
		var turns := float(gt) / n
		var hp := float(gh) / n
		print("G3 %-9s casual win %.1f%% (band %.0f-%.0f)   greedy turns %.1f (min %.1f)   greedy hp lost %.1f (min %.1f)"
			% [enc_id, wr * 100, CASUAL_WIN_LO * 100, CASUAL_WIN_HI * 100, turns, GREEDY_TURNS_MIN, hp, GREEDY_HP_MIN])
		if wr < CASUAL_WIN_LO or wr > CASUAL_WIN_HI:
			fail("G3 %s casual win rate %.1f%% outside band %.0f-%.0f" % [enc_id, wr * 100, CASUAL_WIN_LO * 100, CASUAL_WIN_HI * 100])
		if turns < GREEDY_TURNS_MIN:
			fail("G3 %s greedy clears in %.1f turns, floor is %.1f: the fight ends before it can teach" % [enc_id, turns, GREEDY_TURNS_MIN])
		if hp < GREEDY_HP_MIN:
			fail("G3 %s greedy loses only %.1f HP, floor is %.1f" % [enc_id, hp, GREEDY_HP_MIN])

# ---- dead / dominant station (SPEC 4.2) --------------------------------
func check_stations(n: int, enc_id := "crab") -> void:
	var OPEN: Array = Combat.new(enc_id).OPEN_STATIONS
	var occ := [0, 0, 0, 0, 0]
	var total := 0
	for s in range(n):
		var c := Combat.new(enc_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		while c.outcome == "ongoing" and c.turn <= 40:
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
			fail("DEAD STATION in %s: %s is never occupied in optimal play" % [enc_id, Combat.STATION_NAMES[i]])
		if pct > 60.0 and OPEN.size() > 1:
			fail("DOMINANT STATION in %s: %s occupied %.1f%% of the time; positioning is theatre" % [enc_id, Combat.STATION_NAMES[i], pct])
	print("stations %-9s " % enc_id + "  ".join(parts))

# ---- G14: the telegraph never lies ------------------------------------
func check_telegraph(n: int) -> void:
	var checked := 0
	for s in range(n):
		var c := Combat.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = s + 9000
		while c.outcome == "ongoing" and c.turn <= 20:
			var a: Dictionary = Bots.casual(c, rng)
			if not a.is_empty(): Bots.apply(c, a)
			if c.outcome != "ongoing": break
			var announced := c.intent()
			var before: Array = []
			for d in c.divers: before.append(d.hp)
			c.end_turn()
			if announced.is_empty(): continue
			checked += 1
			for d in c.divers:
				var dealt: int = int(before[d.id]) - d.hp
				# expected is CLAMPED by remaining HP: an overkill blow deals
				# what is left, not its nominal number. The first version of this
				# check reported "announced 3, dealt 1" against a diver on 1 HP,
				# which was the detector lying, not the telegraph.
				var nominal: int = int(announced.dmg) if (d.station in announced.stations) else 0
				var expected: int = min(nominal, int(before[d.id]))
				if dealt != expected:
					fail("TELEGRAPH LIES: announced %d to %s, dealt %d" % [expected, Combat.STATION_NAMES[d.station], dealt])
					return
	print("telegraph  %d hostile slots, announced == delivered" % checked)

# G2: the slice is winnable start to finish, and a win exists from every
# reachable state. Positioning adds a real softlock risk (a diver stranded
# where it can neither act usefully nor retreat) and only playing the whole
# ladder catches it.
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
	check_bands(1000)
	check_run(40)
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
