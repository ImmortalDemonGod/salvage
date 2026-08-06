# Pinned judge policies. Bots enter through the SAME functions the input
# handler will call: act_attack, act_move, act_overdraft, end_turn.
# Anything else is harness drift (SPEC 4.3, G14).
class_name Bots
extends RefCounted

static func legal(c: Combat) -> Array:
	var out: Array = []
	for d in c.divers:
		if d.down:
			continue
		if c.afford(d.cost) and c.can_attack(d):
			for slot in range(d.kit.size()):
				out.append({"kind": "attack", "i": d.id, "slot": slot})
		if Combat.OVERDRAFT_ENABLED and not c.overdrafted and d.hp > Combat.OVERDRAFT_HP:
			out.append({"kind": "overdraft", "i": d.id})
		if c.afford(Combat.MOVE_COST):
			for s in c.OPEN_STATIONS:
				if s != d.station:
					out.append({"kind": "move", "i": d.id, "s": int(s)})
	return out

static func apply(c: Combat, a: Dictionary) -> bool:
	match a.kind:
		"attack": return c.act_ability(a.i, int(a.get("slot", 0)))
		"move": return c.act_move(a.i, a.s)
		"overdraft": return c.act_overdraft(a.i)
	return false

# casual: a plausible inexperienced human, not noise.
#
# JUDGE CHANGE, logged with its reason (standing rule: pinned judges may
# only change with a logged reason and a re-run of every gate that used
# them). The first version was uniform random over ALL legal actions. In
# a positional game that is roughly 3 attacks against 12 moves, so it
# attacked 20 percent of the time and spent the rest wandering. It won
# 1.4 percent of fights and a full parameter sweep found NO configuration
# that could lift it into band, because every number that lengthens the
# fight for the skilled bot also feeds the wanderer more enemy turns.
#
# That is judge pathology, not a broken game: a human who does not know
# what they are doing still mostly attacks. This version attacks when it
# can and wanders sometimes, which measures difficulty instead of noise.
const CASUAL_MOVE_CHANCE := 0.3

static func casual(c: Combat, rng: RandomNumberGenerator) -> Dictionary:
	var opts: Array = legal(c)
	if opts.is_empty() or rng.randf() < 0.12:
		return {}
	var attacks: Array = []
	var moves: Array = []
	var burns: Array = []
	for a in opts:
		if a.kind == "attack": attacks.append(a)
		elif a.kind == "overdraft": burns.append(a)
		else: moves.append(a)
	# Burning HP for air is a desperate act; a novice does it occasionally,
	# not one time in three. Leaving it in the uniform pool dropped casual
	# from 65 to 31 percent, which measured the bot's recklessness rather
	# than the fight's difficulty. Same judge pathology as the first sweep.
	if not burns.is_empty() and rng.randf() < 0.06:
		return burns[rng.randi() % burns.size()]
	var want_move: bool = attacks.is_empty() or (not moves.is_empty() and rng.randf() < CASUAL_MOVE_CHANCE)
	var pool: Array = moves if want_move else attacks
	if pool.is_empty():
		pool = opts
	# A novice presses the FIRST button most of the time. Picking uniformly
	# among six abilities halved the casual win rate the moment the kit
	# doubled, which measured the bot's indecision rather than the fight.
	# Same judge pathology as the first sweep and the overdraft.
	if not want_move and rng.randf() < 0.7:
		for a in pool:
			if int(a.get("slot", 0)) == 0:
				return a
	return pool[rng.randi() % pool.size()]

# greedy: break limbs fast, and step out of a telegraphed station when it
# is cheap to do so. Pinned BEFORE any tuning.
static func greedy(c: Combat, _rng: RandomNumberGenerator) -> Dictionary:
	var all_intents: Array = c.intents()
	var threatened: Array = []
	for it in all_intents:
		for st in it.stations:
			if not (st in threatened):
				threatened.append(st)
	var best := {}
	var best_score := -1.0
	for a in legal(c):
		var d = c.divers[a.i]
		var score := 0.0
		if a.kind == "attack":
			var ab: Dictionary = d.kit[int(a.get("slot", 0))]
			var limb: int = c.target_limb(d)
			if limb < 0:
				continue
			var adm: int = int(ab.dmg)
			score = float(min(adm, c.limb_hp[limb])) / float(d.cost)
			if String(ab.kind) == "hit_wide":
				for st in c.neighbours(d.station):
					var lb3: int = c.STATION_LIMB[int(st)]
					if lb3 >= 0 and not c.limb_broken[lb3]:
						score += float(min(adm, c.limb_hp[lb3])) / float(d.cost)
			if adm >= c.limb_hp[limb]:
				score += 3.0   # finishing a limb changes the map
			# shutting down the limb that is ABOUT to swing is worth the
			# damage it would have dealt. Without this the judge cannot see
			# prevention at all and would report the disabler dominated
			# purely because it cannot value what the disabler does.
			# shutting down a limb that is ABOUT to swing is worth the damage
			# it would have dealt to bodies actually standing in its arc
			if String(ab.kind) == "shut" and limb >= 0 and int(c.limb_stun[limb]) <= 0:
				for it in all_intents:
					if int(it.limb) != limb:
						continue
					var would := 0
					for dd in c.divers:
						if not dd.down and int(dd.station) in it.stations:
							would += int(it.dmg)
					# Weighted BELOW parity on purpose. At full weight the judge
					# stunned every turn forever: prevention scored 2.5 against
					# an attack's 2.0, and since the ranged drum deals no
					# damage the fight never progressed (41 turns, G2 0/40).
					# A shutdown buys a turn; it does not win the fight.
					score += float(would) / float(d.cost) * 0.55
		elif a.kind == "overdraft":
			# The greedy judge NEVER burns HP, deliberately. Scored at all,
			# it fired every turn air ran short and doubled its own damage
			# taken, so the difficulty floor measured the bot's recklessness
			# instead of the fight. Pinned HP-averse for the same reason the
			# last project pinned its judge heal-averse: a floor should
			# measure pressure, not self-harm.
			continue
		else:
			var limb2: int = c.STATION_LIMB[a.s]
			if limb2 >= 0 and not c.limb_broken[limb2]:
				score = 0.9
			if d.station in threatened and not (a.s in threatened):
				if float(d.hp) / float(d.max_hp) < 0.5:
					score += 0.6
		if score > best_score:
			best_score = score
			best = a
	return best if best_score > 0.0 else {}

# The puzzle policy. Deliberately naive: open what you can reach, and if
# nothing is reachable, drain. If a naive policy cannot solve the lock then
# the lock is not readable, whatever the author thinks.
static func solve_step(p) -> int:
	if p.solved():
		return -1
	if p.stage == 2:
		# open the crossover FIRST while B is dry, then everything else.
		# A naive order locks itself out, which is the point of the lock;
		# a naive policy still has to be able to recover, or the lock is
		# not readable whatever the author thinks.
		if not p.valve[p.CROSS]:
			if p.reachable(p.CROSS):
				return p.CROSS
			for i in range(p.B_VALVES):
				if i != p.CROSS and p.valve[i]:
					return i          # drain until the crossover is reachable
		for i in range(p.B_VALVES):
			if i != p.CROSS and not p.valve[i]:
				return i
		return -1
	if not p.valve[p.SEIZED] and p.reachable(p.SEIZED):
		return p.SEIZED
	for i in range(p.VALVES):
		if not p.valve[i] and p.reachable(i):
			if i == p.SEIZED or p.valve[p.SEIZED]:
				return i
	# locked out: drain something so the low valve comes back into reach
	for i in range(p.VALVES):
		if p.valve[i] and i != p.SEIZED:
			return i
	return -1

static func run_fight(seed_val: int, policy: String, enc_id := "crab", cap := 40) -> Dictionary:
	var c := Combat.new(enc_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	while c.outcome == "ongoing" and c.turn <= cap:
		var guard := 0
		while guard < 12:
			guard += 1
			var a: Dictionary = casual(c, rng) if policy == "casual" else greedy(c, rng)
			if a.is_empty() or not apply(c, a):
				break
			if c.outcome != "ongoing":
				break
		if c.outcome != "ongoing":
			break
		c.end_turn()
	var hp_lost := 0
	for d in c.divers:
		hp_lost += d.max_hp - d.hp
	return {"win": c.outcome == "victory", "turns": c.turn, "hp_lost": hp_lost, "downed": 3 - c.alive().size()}
