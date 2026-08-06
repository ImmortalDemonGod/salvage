# Measure which numbers land G3 in band, instead of guessing at them.
# Usage: godot --headless --path ~/salvage --script tools/sweep.gd
extends SceneTree

func band(n: int) -> Dictionary:
	var cw := 0
	var gt := 0
	var gh := 0
	for s in range(n):
		if Bots.run_fight(s, "casual").win: cw += 1
		var g: Dictionary = Bots.run_fight(s, "greedy")
		gt += int(g.turns); gh += int(g.hp_lost)
	return {"win": 100.0 * cw / n, "turns": float(gt) / n, "hp": float(gh) / n}

func _init() -> void:
	print("limb        dhp          jaw/tail  casual%  turns  hpLost   in band?")
	for limbs in [[8,6,6], [14,10,10], [20,14,14], [26,18,18]]:
		for dhp in [[6,10,16], [10,16,24], [14,22,32]]:
			for en in [[4,3], [3,2], [2,2]]:
				Combat.TUNE.limb_hp = limbs
				Combat.TUNE.diver_hp = dhp
				Combat.TUNE.jaw_dmg = en[0]
				Combat.TUNE.tail_dmg = en[1]
				var r: Dictionary = band(300)
				var ok: bool = r.win >= 55.0 and r.win <= 90.0 and r.turns >= 6.0 and r.hp >= 8.0
				print("%-11s %-12s %-9s %6.1f  %5.1f  %6.1f   %s"
					% [str(limbs), str(dhp), str(en), r.win, r.turns, r.hp, "YES" if ok else ""])
	quit()
