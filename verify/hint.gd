extends SceneTree

# The prompt band is the game's whole teaching surface now, and a review
# found it wrong on four of five combat screens: it named a station the
# same screen labelled "taken", and offered "or hit the JAW" as an
# equivalent to escaping when 2 damage cannot stop a 13 HP limb swinging.
#
# Being told nothing is frustrating. Being told to do something that does
# not work is worse, because the player does it, it fails, and now they do
# not trust the interface either.
#
# So every suggestion is checked against the sim, over a lot of states:
#   a station it names must be open, unthreatened, EMPTY and affordable
#   a key it names must belong to an ability that diver actually owns
#   it must never be blank while the fight is running

const Content = preload("res://content/encounters.gd")
const KEYS := ["Q", "W", "E", "R", "T"]

var findings := 0
var checked := 0

func fail(msg: String) -> void:
	findings += 1
	print("FINDING  %s" % msg)

func _init() -> void:
	var scene = preload("res://game/main.gd").new()
	scene.size = Vector2(1280, 800)
	root.add_child(scene)
	await process_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for enc_id in Content.ALL.keys():
		var c := Combat.new(String(enc_id))
		scene.combat = c
		var turns := 0
		while c.outcome == "ongoing" and turns < 26:
			turns += 1
			for i in range(c.divers.size()):
				if c.divers[i].down:
					continue
				scene.selected = i
				_audit(scene, c, String(enc_id))
			# play the turn out so the states keep moving
			for _s in range(5):
				var a: Dictionary = Bots.greedy(c, rng)
				if a.is_empty() or not Bots.apply(c, a):
					break
			c.end_turn()

	print("hints      %d suggestions audited across %d encounters" % [checked, Content.ALL.size()])
	print("HINT: %s" % ("clean" if findings == 0 else "%d finding(s)" % findings))
	quit(1 if findings > 0 else 0)
	return

func _audit(scene, c, enc_id: String) -> void:
	var text: String = scene._next_step()
	checked += 1
	if text.strip_edges() == "":
		fail("%s: the prompt is blank while the fight is running" % enc_id)
		return
	var d = c.divers[scene.selected]

	# "Move to FLANK (press W)" -- must be somewhere this diver can go
	var m := RegEx.create_from_string("Move to ([A-Z]+) \\(press ([A-Z])\\)").search(text)
	if m != null:
		var name := m.get_string(1)
		var st := Combat.STATION_NAMES.find(name)
		if st < 0:
			fail("%s: prompt names a station that does not exist: %s" % [enc_id, name])
			return
		if KEYS[st] != m.get_string(2):
			fail("%s: prompt tells the player to press %s for %s, whose key is %s" % [
				enc_id, m.get_string(2), name, KEYS[st]])
		if not c.station_open(st):
			fail("%s: prompt sends %s to %s, which is not open here" % [enc_id, d.dname, name])
		if st in c.threatened_stations():
			fail("%s: prompt sends %s to %s, where an attack lands this turn" % [enc_id, d.dname, name])
		for o in c.divers:
			if not o.down and int(o.station) == st and int(o.id) != int(d.id):
				fail("%s: prompt sends %s to %s, which the screen labels taken (%s is there)" % [
					enc_id, d.dname, name, o.dname])
		if c.air < Combat.MOVE_COST:
			fail("%s: prompt says move with %d air in the tank and a move costing %d" % [
				enc_id, c.air, Combat.MOVE_COST])

	# "press SPACE to break the JAW" -- must be an ability this diver has,
	# and it must actually do what the sentence claims
	var k := RegEx.create_from_string("press (SPACE|F) to (break|shut) the ([A-Z]+)").search(text)
	if k != null:
		var slot: int = 0 if k.get_string(1) == "SPACE" else 1
		if slot >= d.kit.size():
			fail("%s: prompt offers %s to %s, and %s has no such ability" % [
				enc_id, k.get_string(1), k.get_string(2), d.dname])
			return
		var lb: int = c.target_limb(d)
		if lb < 0:
			fail("%s: prompt offers an attack while %s has nothing to hit" % [enc_id, d.dname])
			return
		var ab: Dictionary = d.kit[slot]
		if k.get_string(2) == "break" and int(ab.dmg) < int(c.limb_hp[lb]):
			fail("%s: prompt says %s BREAKS the %s, and it does %d against %d" % [
				enc_id, String(ab.name), k.get_string(3), int(ab.dmg), int(c.limb_hp[lb])])
		if k.get_string(2) == "shut" and String(ab.kind) != "shut":
			fail("%s: prompt says %s SHUTS the %s, and it is a %s" % [
				enc_id, String(ab.name), k.get_string(3), String(ab.kind)])
		if c.air < int(d.cost):
			fail("%s: prompt offers an ability costing %d with %d air left" % [enc_id, int(d.cost), c.air])
