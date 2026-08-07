extends SceneTree

# Every sim-legal action must be reachable by mouse: the third playtest's
# ruling, in the player's words, "having buttons on screen would replace
# the need of the keyboard and make it visually obvious what to do."
# door.gd proves every action has a KEY; nothing proved a click path, and
# finding 2 of the audit sat exactly in that blind spot.
#
# Two assertions, walked across real fights:
#   1. the bar's enabled prediction equals what the sim actually does
#      when the action is attempted (tried on a clone), so the greyed
#      state can never lie about what a press would do, and
#   2. every button rect sits inside the design viewport, so there is
#      genuinely something to click.

const Content = preload("res://content/encounters.gd")

var findings := 0
var checked := 0

func fail(msg: String) -> void:
	findings += 1
	print("FINDING  %s" % msg)

func _init() -> void:
	var scene = preload("res://game/main.gd").new()
	scene.size = Vector2(1280, 720)
	root.add_child(scene)
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for enc_id in Content.ALL.keys():
		var c := Combat.new(String(enc_id))
		scene.combat = c
		var turns := 0
		while c.outcome == "ongoing" and turns < 20:
			turns += 1
			for i in range(c.divers.size()):
				if c.divers[i].down:
					continue
				scene.selected = i
				var btns: Array = scene.bar_buttons()
				var ids: Array = []
				for bi in range(btns.size()):
					var b: Dictionary = btns[bi]
					ids.append(String(b.id))
					var r: Rect2 = scene.btn_rect(bi, btns.size())
					if r.position.x < 0.0 or r.end.x > 1280.0 or r.position.y < 0.0 or r.end.y > 720.0:
						fail("%s: button '%s' sits off screen at %s" % [enc_id, String(b.id), str(r)])
					var predicted: bool = scene.action_legal(String(b.id))
					var c2: Combat = c.clone()
					var actual := false
					match String(b.id):
						"ability0": actual = c2.act_ability(i, 0)
						"ability1": actual = c2.act_ability(i, 1)
						"analyze": actual = c2.act_analyze(i)
						"rewind": actual = scene.action_legal("rewind")
						"end": actual = true
					checked += 1
					if predicted != actual:
						fail("%s: button '%s' shows %s and the sim says %s for %s on turn %d" % [
							enc_id, String(b.id), "enabled" if predicted else "disabled",
							"yes" if actual else "no", c.divers[i].dname, c.turn])
				for want in ["analyze", "rewind", "end"]:
					if not (want in ids):
						fail("%s: no button exists for '%s'" % [enc_id, want])
			for _s in range(5):
				var a: Dictionary = Bots.greedy(c, rng)
				if a.is_empty() or not Bots.apply(c, a):
					break
			c.end_turn()

	print("mousedoor  %d button states audited across %d encounters" % [checked, Content.ALL.size()])
	print("MOUSEDOOR: %s" % ("clean" if findings == 0 else "%d finding(s)" % findings))
	quit(1 if findings > 0 else 0)
	return
