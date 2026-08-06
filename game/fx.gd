# Placeholder MOTION. Nothing in this build moved: no attack motion, no hit
# reaction, and nothing at all when the enemy swung. On the last prototype
# the most severe playtest finding was that enemy attacks read as nothing,
# and the answer then was to write better numbers, which did not work.
#
# SPEC Part 6 commits to building placeholder motion first and handing it to
# Glass_Goat as the brief, so this is that brief, in code.
#
# Driven off SfxEvents, the SAME classifier the audio uses, for the same
# reason the ring and the telegraph read one function: two renderings of one
# event cannot drift apart. G7 already proves all 12 events reach the sim's
# real log lines, so the motion is wired wherever the sound is.
#
# Pure presentation. No sim state is touched, nothing here is read back, and
# a dropped frame changes nothing but how it looks.
class_name Fx
extends RefCounted

class Effect extends RefCounted:
	var kind := ""
	var t := 0.0
	var dur := 0.4
	var at := Vector2.ZERO
	var to := Vector2.ZERO
	var text := ""
	var col := Color(1, 1, 1)
	var who := -1        # diver id, for recoil and lunge
	var limb := -1       # limb index, for the flash
	func k() -> float:   # 0..1
		return clampf(t / max(0.001, dur), 0.0, 1.0)

var live: Array = []
var shake := 0.0
var _clock := 0.0

func tick(dt: float) -> void:
	_clock += dt
	shake = max(0.0, shake - dt * 5.0)
	var keep: Array = []
	for e in live:
		e.t += dt
		if e.t < e.dur:
			keep.append(e)
	live = keep

func busy() -> bool:
	return not live.is_empty() or shake > 0.01

# a slow bob so the board is not a still image while you think
func idle(seed_i: int) -> Vector2:
	return Vector2(0, sin(_clock * 1.7 + float(seed_i) * 1.3) * 2.4)

func add(kind: String, dur: float, at: Vector2, to := Vector2.ZERO,
		text := "", col := Color(1, 1, 1), who := -1, limb := -1) -> void:
	var e := Effect.new()
	e.kind = kind; e.dur = dur; e.at = at; e.to = to
	e.text = text; e.col = col; e.who = who; e.limb = limb
	live.append(e)

func kick(amount: float) -> void:
	shake = min(1.0, shake + amount)

# how far a diver is thrown by whatever is happening to it right now
func diver_offset(id: int) -> Vector2:
	var off := Vector2.ZERO
	for e in live:
		if e.who != id:
			continue
		if e.kind == "lunge":
			# out fast, back slower: the shape of a strike
			var k: float = e.k()
			var f: float = sin(k * PI)
			off += (e.to - e.at).normalized() * 26.0 * f
		elif e.kind == "recoil":
			var k2: float = e.k()
			off += (e.to - e.at).normalized() * 18.0 * (1.0 - k2) * sin(k2 * PI * 3.0)
	return off

# 0 when calm, up to 1 at the instant a limb is struck
func limb_flash(idx: int) -> float:
	var v := 0.0
	for e in live:
		if e.limb == idx and e.kind == "flash":
			v = max(v, 1.0 - e.k())
	return v
