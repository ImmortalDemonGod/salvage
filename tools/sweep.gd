# Measure which numbers land G3 in band, instead of guessing at them.
#
# REWRITTEN after it went stale silently. The first version set
# TUNE.limb_hp, TUNE.jaw_dmg and TUNE.tail_dmg, and all three keys died
# when encounters became data (content/encounters.gd): nothing read them,
# so every cell measured the identical game and the tool printed a sweep
# it never performed. A knob that moves no metric is a claim about the
# knob (standing rule 6), and it rotted in the one tool whose whole job
# is moving numbers. The knobs are now the ones the sim actually reads:
# each encounter's limb HP and attack damage, scaled in place from a
# pristine copy and restored afterwards.
#
# Judged the way verify/checks.gd judges the bands: AS PLAYED, with the
# abilities earned by that beat, against the pinned band constants
# preloaded from checks.gd itself, so there is one copy of the numbers.
#
# 300 fights per cell is an exploration resolution, not a verdict: a cell
# within a few points of a band edge can flip against the 1000-fight gate
# (standing rule 10, seed counts are load bearing; the shipped dredge
# reads 54.3% here and 66% under the gate). Re-measure any cell you mean
# to act on with verify/checks.gd before believing it.
# Usage: godot --headless --path . --script tools/sweep.gd
extends SceneTree

const Encounters := preload("res://content/encounters.gd")
const Run := preload("res://sim/run.gd")
const Checks := preload("res://verify/checks.gd")

const FIGHTS := 300
const LIMB_MULT := [0.85, 1.0, 1.15, 1.3, 1.45]
const DMG_DELTA := [-1, 0, 1]

func band(n: int, enc_id: String, kit: int) -> Dictionary:
	var cw := 0
	var gt := 0
	var gh := 0
	for s in range(n):
		if Bots.run_fight(s, "casual", enc_id, 40, kit).win:
			cw += 1
		var g: Dictionary = Bots.run_fight(s, "greedy", enc_id, 40, kit)
		gt += int(g.turns)
		gh += int(g.hp_lost)
	return {"win": 100.0 * cw / n, "turns": float(gt) / n, "hp": float(gh) / n}

func _init() -> void:
	print("enc        limbs  dmg   casual%%  turns  hpLost   in band?   (band %d-%d%%, turns >= %.1f, hp >= %.1f; x1.00 +0 is the shipped game)"
		% [int(Checks.CASUAL_WIN_LO * 100), int(Checks.CASUAL_WIN_HI * 100), Checks.GREEDY_TURNS_MIN, Checks.GREEDY_HP_MIN])
	for key in Encounters.ALL.keys():
		var enc_id := String(key)
		var enc: Dictionary = Encounters.ALL[key]
		if bool(enc.get("teaching", false)):
			print("%-9s  SKIPPED: a teaching beat, not judged as a fight" % enc_id)
			continue
		var kit: int = Run.abilities_at(enc_id)
		var pristine: Dictionary = enc.duplicate(true)
		for lm in LIMB_MULT:
			for dd in DMG_DELTA:
				for i in range(enc.limbs.size()):
					(enc.limbs[i] as Dictionary).hp = int(round(float(int((pristine.limbs[i] as Dictionary).hp)) * float(lm)))
				for i in range(enc.attacks.size()):
					(enc.attacks[i] as Dictionary).dmg = max(1, int((pristine.attacks[i] as Dictionary).dmg) + int(dd))
				var r: Dictionary = band(FIGHTS, enc_id, kit)
				var ok: bool = r.win >= Checks.CASUAL_WIN_LO * 100.0 and r.win <= Checks.CASUAL_WIN_HI * 100.0 \
					and r.turns >= Checks.GREEDY_TURNS_MIN and r.hp >= Checks.GREEDY_HP_MIN
				var delta_txt := ("+" + str(dd)) if dd >= 0 else str(dd)
				print("%-9s  x%.2f  %s    %6.1f  %5.1f  %6.1f   %s   [%d abilities]"
					% [enc_id, float(lm), delta_txt, float(r.win), float(r.turns), float(r.hp), "YES" if ok else "   ", kit])
		# put the real numbers back before anything else measures them
		Encounters.ALL[key] = pristine
	quit()
