extends SceneTree

# The gallery's key sequences were hand-authored, so it reached the crab and
# stopped. Six screenshots covered four of nine beats, and G10 -- a BLOCKING
# gate -- had never cold-read either lock, the vent worm, or the dredge.
# Hand-authored strings also rot silently: nothing tells you they stopped
# reaching where they claim to reach.
#
# So derive them. Play the whole run with the same judge bots the gates use,
# and write down the KEY each action corresponds to. The output is a key
# sequence per beat that the browser can replay through real KeyboardEvents.
# This is G14 taken all the way: the bots now reach the screen through the
# player's keyboard, not just through the player's functions.
#
# Usage: godot --headless --path ~/salvage --script tools/keypath.gd

const Beats = preload("res://content/beats.gd")


const MOVE_KEY := ["KeyQ", "KeyW", "KeyE", "KeyR", "KeyT"]
const VALVE_KEY := ["Digit1", "Digit2", "Digit3", "Digit4"]
const DIVER_KEY := ["Digit1", "Digit2", "Digit3"]

var keys: Array = []
var selected := 0

# The key map picks a diver with 1/2/3, so any action by a diver who is not
# already selected costs a selection press first. Model that, or the replay
# aims every ability at whoever happened to be selected.
func select(i: int) -> void:
	if selected != i:
		keys.append(DIVER_KEY[i])
		selected = i

func _init() -> void:
	var r := Run.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out: Array = []
	var guard := 0
	var last_id := ""

	while not r.finished and guard < 4000:
		guard += 1
		var here := _beat_id(r)
		if here != last_id:
			out.append({"id": here, "keys": ",".join(keys)})
			last_id = here
		if r.combat != null:
			var c = r.combat
			if c.outcome != "ongoing":
				keys.append("Enter")       # advance past the finished fight
				selected = 0
				if not r.advance():
					break
				continue
			var a: Dictionary = Bots.greedy(c, rng)
			if a.is_empty() or String(a.get("kind", "")) == "end":
				keys.append("Enter")
				c.end_turn()
				continue
			select(int(a.i))
			match String(a.kind):
				"attack":
					keys.append("Space" if int(a.get("slot", 0)) == 0 else "KeyF")
				"move":
					keys.append(MOVE_KEY[int(a.s)])
				_:
					continue
			if not Bots.apply(c, a):
				# a refused action would desync the replay from the sim
				push_error("KEYPATH DESYNC: the bot chose %s and the sim refused it" % str(a))
				break
		elif r.puzzle != null:
			var p = r.puzzle
			if p.solved():
				keys.append("Enter")
				selected = 0
				if not r.advance():
					break
				continue
			var i: int = Bots.solve_step(p)
			if i < 0:
				push_error("KEYPATH STUCK: the naive policy cannot open the lock at stage %d" % p.stage)
				break
			keys.append(VALVE_KEY[i])
			p.toggle(i)
		else:
			# a scene beat: one press moves on
			keys.append("Enter")
			selected = 0
			if not r.advance():
				break

	# every beat in the ladder must appear, or the gallery is not covering
	# the game and saying so is the whole point of this tool
	var seen: Array = []
	for e in out:
		if not (e.id in seen):
			seen.append(e.id)
	var missing: Array = []
	for b in Beats.LADDER:
		if not (String(b.id) in seen):
			missing.append(String(b.id))

	for e in out:
		print("%s\t%s" % [e.id, e.keys])
	if not missing.is_empty():
		print("KEYPATH INCOMPLETE: never reached %s" % ", ".join(missing))
		quit(1)
		return
	print("KEYPATH: %d of %d beats reachable from the keyboard" % [seen.size(), Beats.LADDER.size()])
	quit(0)
	return

func _beat_id(r) -> String:
	var b: Dictionary = r.current()
	return String(b.get("id", "?"))
