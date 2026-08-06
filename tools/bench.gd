# Q12's decision, answered with a number instead of an argument.
# Usage: godot --headless --path ~/salvage --script tools/bench.gd -- <n>
extends SceneTree

func _init() -> void:
	var n := 10000
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			n = a.to_int()
	for policy in ["casual", "greedy"]:
		var t := Time.get_ticks_usec()
		var wins := 0
		var turns := 0
		var hp := 0
		var downed := 0
		for s in range(n):
			var r: Dictionary = Bots.run_fight(s, policy)
			if r.win: wins += 1
			turns += r.turns
			hp += r.hp_lost
			downed += r.downed
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		print("%-7s %6d fights  %8.0f ms  %6.1f us/fight   win %5.1f%%  turns %4.1f  hp lost %4.1f  downed %4.2f"
			% [policy, n, ms, ms * 1000.0 / n, 100.0 * wins / n, float(turns) / n, float(hp) / n, float(downed) / n])
	quit()
