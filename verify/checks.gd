# The per-commit verification set. Fast by construction; the expensive
# dominance search belongs in the nightly bucket (SPEC 4b).
# Usage: godot --headless --path ~/salvage --script verify/checks.gd
extends SceneTree

var findings: Array = []

func fail(s: String) -> void:
	findings.append(s)

# ---- G3: bands, PINNED BEFORE ANY TUNING ------------------------------
const CASUAL_WIN_LO := 0.55
const CASUAL_WIN_HI := 0.90
const GREEDY_TURNS_MIN := 6.0
const GREEDY_HP_MIN := 8.0

func check_bands(n: int) -> void:
	var cw := 0
	var gt := 0
	var gh := 0
	for s in range(n):
		if Bots.run_fight(s, "casual").win: cw += 1
		var g: Dictionary = Bots.run_fight(s, "greedy")
		gt += g.turns
		gh += g.hp_lost
	var wr := float(cw) / n
	var turns := float(gt) / n
	var hp := float(gh) / n
	print("G3 bands   casual win %.1f%% (band %.0f-%.0f)   greedy turns %.1f (min %.1f)   greedy hp lost %.1f (min %.1f)"
		% [wr * 100, CASUAL_WIN_LO * 100, CASUAL_WIN_HI * 100, turns, GREEDY_TURNS_MIN, hp, GREEDY_HP_MIN])
	if wr < CASUAL_WIN_LO or wr > CASUAL_WIN_HI:
		fail("G3 casual win rate %.1f%% outside band %.0f-%.0f" % [wr * 100, CASUAL_WIN_LO * 100, CASUAL_WIN_HI * 100])
	if turns < GREEDY_TURNS_MIN:
		fail("G3 greedy clears in %.1f turns, floor is %.1f: the fight ends before it can teach" % [turns, GREEDY_TURNS_MIN])
	if hp < GREEDY_HP_MIN:
		fail("G3 greedy loses only %.1f HP, floor is %.1f" % [hp, GREEDY_HP_MIN])

# ---- dead / dominant station (SPEC 4.2) --------------------------------
func check_stations(n: int) -> void:
	var occ := [0, 0, 0, 0, 0]
	var total := 0
	for s in range(n):
		var c := Combat.new()
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
		var open_here: bool = i in Combat.OPEN_STATIONS
		parts.append("%s %.1f%%%s" % [Combat.STATION_NAMES[i], pct, "" if open_here else " (closed)"])
		if not open_here:
			continue
		if pct == 0.0:
			fail("DEAD STATION: %s is never occupied in optimal play" % Combat.STATION_NAMES[i])
		if pct > 60.0:
			fail("DOMINANT STATION: %s occupied %.1f%% of the time; positioning is theatre" % [Combat.STATION_NAMES[i], pct])
	print("stations   " + "  ".join(parts))

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

func _init() -> void:
	var t := Time.get_ticks_usec()
	check_bands(1000)
	check_stations(300)
	check_telegraph(300)
	print("ran in %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	if findings.is_empty():
		print("VERIFY: clean")
		quit(0)
	for f in findings:
		print("FINDING  " + f)
	print("VERIFY: %d finding(s)" % findings.size())
	quit(1)
