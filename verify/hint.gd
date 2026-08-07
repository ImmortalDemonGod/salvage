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

func k_name(c, lb: int) -> String:
	return String(c.LIMB_NAMES[lb]).to_upper()

func _audit(scene, c, enc_id: String) -> void:
	var text: String = scene._next_step()
	checked += 1
	if text.strip_edges() == "":
		fail("%s: the prompt is blank while the fight is running" % enc_id)
		return
	var d = c.divers[scene.selected]

	# any hint that tells the player to move or to hit must do so in a form
	# this check can verify. Vague direction is not allowed to hide.
	var directive := text.find("Move to") >= 0 or text.find("press ") >= 0 or text.find("Press ") >= 0
	var checkable := text.find("Move to the glowing plate (click it)") >= 0 \
		or text.find("Click the glowing plate, or arrows then ENTER") >= 0 \
		or RegEx.create_from_string("[Pp]ress (SPACE|F|A|ENTER|[0-9]) ").search(text) != null \
		or RegEx.create_from_string("[Pp]ress (SPACE|F|ENTER|[0-9])\\.").search(text) != null \
		or RegEx.create_from_string("[Pp]ress (SPACE|F|ENTER)$").search(text) != null
	if directive and not checkable:
		fail("%s: hint gives direction this check cannot verify, so nothing defends it: \"%s\"" % [enc_id, text])

	# "the glowing plate" -- the glow IS the name; the audited claims are
	# that a plate is genuinely glowing, open, empty, affordable, and
	# safe when the prompt is an escape.
	if text.find("glowing plate") >= 0:
		var st: int = int(scene._hint_station)
		if st < 0:
			fail("%s: prompt says move to the glowing plate and no plate is glowing" % enc_id)
			return
		var name := String(Combat.STATION_NAMES[st])

		if not c.station_open(st):
			fail("%s: prompt sends %s to %s, which is not open here" % [enc_id, d.dname, name])
		var escaping := text.find("about to be hit") >= 0
		if escaping and st in c.threatened_stations():
			fail("%s: prompt tells %s to ESCAPE to %s, where an attack lands this turn" % [enc_id, d.dname, name])
		for o in c.divers:
			if not o.down and int(o.station) == st and int(o.id) != int(d.id):
				fail("%s: prompt sends %s to %s, which the screen labels taken (%s is there)" % [
					enc_id, d.dname, name, o.dname])
		var blk: int = int(c.STATION_LIMB[st])
		if blk >= 0 and not c.limb_broken[blk] and bool((c.enc.limbs[blk] as Dictionary).get("blocks", false)):
			fail("%s: prompt glows %s while the %s squats on it" % [enc_id, name, c.LIMB_NAMES[blk]])
		if not c.can_move_now(scene.selected):
			fail("%s: prompt says move when %s has spent the free move and the tank cannot pay for another" % [
				enc_id, d.dname])

	# "Press A to read the JAW" -- only when it is genuinely unread, this
	# diver can reach it, and the tank can pay for it
	var r := RegEx.create_from_string("Press A to read the ([A-Z]+)").search(text)
	if r != null:
		var rl: int = c.target_limb(d)
		if rl < 0:
			fail("%s: prompt says read a limb while %s can reach none" % [enc_id, d.dname])
		elif c.known(rl):
			fail("%s: prompt says read the %s, which has already been read" % [enc_id, k_name(c, rl)])
		elif c.air < Combat.ANALYZE_COST:
			fail("%s: prompt says read a limb with %d air" % [enc_id, c.air])
		elif k_name(c, rl) != r.get_string(1):
			fail("%s: prompt says read the %s and this diver would read the %s" % [
				enc_id, r.get_string(1), k_name(c, rl)])

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
