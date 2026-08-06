extends SceneTree

# The masher gate. Three human playtests converged on "just click space":
# measured on Aug 6, the pure masher removed all threat and never ended a
# fight (unlosable, unwinnable, forty turns), and mash-plus-move BEAT the
# casual bot on speed. The evening ruling: the realistic masher must LOSE
# somewhere in the ladder, must never stalemate, and pure mashing must
# never finish a fight. Depth the mash line can skip is depth that does
# not exist.
#
# The sim has no RNG, so each policy is a single deterministic trajectory.

const ENCS := ["crab", "spitter", "dredge"]
var findings := 0

func fail(msg: String) -> void:
	findings += 1
	print("FINDING  %s" % msg)

# attack slot 0 with every diver until nobody can, then (optionally) the
# measured human recovery: when a diver has nothing to hit, walk them to
# the first station exposing an unbroken limb. Never dodge, never read,
# never shut on purpose, never spend a thought.
func mash_turn(c: Combat, move_when_stuck: bool) -> void:
	var acted := true
	while acted and c.outcome == "ongoing":
		acted = false
		for i in range(c.divers.size()):
			if c.divers[i].down:
				continue
			if c.act_ability(i, 0):
				acted = true
	if not move_when_stuck or c.outcome != "ongoing":
		return
	for i in range(c.divers.size()):
		var d = c.divers[i]
		if d.down:
			continue
		var lb0: int = c.target_limb(d)
		if lb0 >= 0 and not c.limb_broken[lb0]:
			continue
		for st in c.OPEN_STATIONS:
			var lb: int = c.STATION_LIMB[int(st)]
			if lb >= 0 and not c.limb_broken[lb] and c.act_move(i, int(st)):
				break

func run_policy(enc: String, move_when_stuck: bool) -> Dictionary:
	var c := Combat.new(enc)
	while c.outcome == "ongoing" and c.turn <= 40:
		mash_turn(c, move_when_stuck)
		if c.outcome != "ongoing":
			break
		c.end_turn()
	return {"outcome": String(c.outcome), "turns": c.turn}

func _init() -> void:
	var lost_somewhere := false
	for e in ENCS:
		var pure: Dictionary = run_policy(e, false)
		var mm: Dictionary = run_policy(e, true)
		print("masher %-8s pure=%s(t%d)  mash+move=%s(t%d)" % [
			e, pure.outcome, pure.turns, mm.outcome, mm.turns])
		if pure.outcome == "victory":
			fail("%s: the PURE masher wins; mashing alone may not finish a fight" % e)
		if mm.outcome == "ongoing":
			fail("%s: mash+move stalemates at the cap; unlosable-unwinnable may not exist" % e)
		if mm.outcome == "defeat":
			lost_somewhere = true
	if not lost_somewhere:
		fail("mash+move loses NOWHERE in the ladder: nothing punishes attack-only play, so the depth is optional")
	print("MASHER: %s" % ("clean" if findings == 0 else "%d finding(s)" % findings))
	quit(1 if findings > 0 else 0)
