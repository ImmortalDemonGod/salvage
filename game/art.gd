# Placeholder character art, drawn in code. No textures, no imports.
#
# This file is the ART BRIEF for Glass_Goat as much as it is a placeholder:
# what matters here is the SILHOUETTE, not the detail. SPEC 2.5 rules that
# a diver's Air cost is readable off the silhouette alone with no number
# printed, so the three tiers must separate as pure black shapes at 64px:
#
#   tier 1  Scuba       Air 1   bare skin, long swim fins, ponytail, thin
#   tier 2  Prototype1  Air 2   soft suit, round helmet, three-lens drum
#   tier 3  Proto5      Air 3   plate armour, blocky, widest and tallest
#
# Rule of thumb when this is redrawn: one tier owns one silhouette idea.
# Scuba owns the horizontal fin blades at the ground. Prototype1 owns the
# two circles (helmet, drum). Proto5 owns the rectangle mass with a tiny
# head. Do not give a tier a second tier's idea.
#
# SPEC 2.6: fight one is a mutated hunter crab with three limbs (jaw at
# FRONT, claw at FLANK, tail at REAR) and a soft, plate-free underside at
# UNDER. "Breaking a limb changes the map" is a core rule, so a broken
# limb has to LOOK broken from across the board: it changes pose, loses
# its colour, and shows a wound at the break.
#
# Local unit space for every draw: origin at the ground under the figure,
# +y is DOWN, so the body is drawn in negative y. One unit = the height of
# a Proto5. `scale` is that unit in pixels; `facing` is +1 right, -1 left.
class_name Art
extends RefCounted

# ---- palette -----------------------------------------------------------
# Water is cold. Divers are warm so they pop off it. The crab is cold like
# the water except for its eyes, so the divers stay the warm things.
const WATER_DEEP := Color(0.035, 0.086, 0.145)
const WATER_MID := Color(0.070, 0.176, 0.235)
const WATER_TEAL := Color(0.110, 0.290, 0.325)
const SILT := Color(0.145, 0.239, 0.255)

const SKIN := Color(0.925, 0.706, 0.541)
const SKIN_DK := Color(0.741, 0.518, 0.376)
const HAIR := Color(0.812, 0.259, 0.145)
const SUIT := Color(0.945, 0.478, 0.153)
const SUIT_DK := Color(0.706, 0.286, 0.086)
const SUIT_DKR := Color(0.451, 0.180, 0.067)
const PLATE := Color(0.643, 0.322, 0.180)
const PLATE_LT := Color(0.812, 0.451, 0.259)
const PLATE_DK := Color(0.396, 0.184, 0.114)
const GOLD := Color(0.949, 0.769, 0.302)
const GOLD_DK := Color(0.663, 0.502, 0.157)
const GLASS := Color(0.612, 0.847, 0.859)
const GLASS_DK := Color(0.259, 0.482, 0.533)
const RUBBER := Color(0.145, 0.169, 0.208)

const SHELL := Color(0.239, 0.353, 0.435)
const SHELL_LT := Color(0.353, 0.494, 0.557)
const SHELL_DK := Color(0.133, 0.204, 0.278)
const BELLY := Color(0.855, 0.839, 0.741)
const BELLY_DK := Color(0.663, 0.647, 0.549)
const CHITIN := Color(0.545, 0.475, 0.318)
const CHITIN_DK := Color(0.353, 0.302, 0.196)
const EYE := Color(0.949, 0.639, 0.196)

const DEAD := Color(0.322, 0.310, 0.345)
const DEAD_DK := Color(0.196, 0.192, 0.227)
const WOUND := Color(0.494, 0.129, 0.153)
const WOUND_DK := Color(0.278, 0.075, 0.094)

# Limb indices, kept in the same order as Combat.LIMB_NAMES so a caller can
# pass the sim's array straight through with no translation table.
const JAW := 0
const CLAW := 1
const TAIL := 2


# ---- public ------------------------------------------------------------

# tier: 1 Scuba (Air 1), 2 Prototype1 (Air 2), 3 Proto5 (Air 3).
# pos: the ground point the figure stands on. scale: pixels per unit.
# facing: +1 faces right, -1 faces left.
static func draw_diver(ci: CanvasItem, tier: int, pos: Vector2, scale: float, facing: int) -> void:
	var xf := _xf(pos, scale, facing)
	if tier <= 1:
		_scuba(ci, xf)
	elif tier == 2:
		_proto1(ci, xf)
	else:
		_proto5(ci, xf)


# limb_broken: [jaw, claw, tail] of bools, as Combat.limb_broken.
# The crab always faces left; the divers ring it.
static func draw_crab(ci: CanvasItem, pos: Vector2, scale: float, limb_broken: Array) -> void:
	var xf := _xf(pos, scale, 1)
	var jaw_gone := _broken(limb_broken, JAW)
	var claw_gone := _broken(limb_broken, CLAW)
	var tail_gone := _broken(limb_broken, TAIL)
	_crab_legs_far(ci, xf)
	if tail_gone:
		_crab_tail_broken(ci, xf)
	else:
		_crab_tail(ci, xf)
	_crab_shell(ci, xf)
	_crab_belly(ci, xf)
	_crab_legs_near(ci, xf)
	if jaw_gone:
		_crab_jaw_broken(ci, xf)
	else:
		_crab_jaw(ci, xf)
	if claw_gone:
		_crab_claw_broken(ci, xf)
	else:
		_crab_claw(ci, xf)


# ---- primitives --------------------------------------------------------

static func _xf(pos: Vector2, scale: float, facing: int) -> Transform2D:
	var fx := 1.0
	if facing < 0:
		fx = -1.0
	return Transform2D(Vector2(fx * scale, 0.0), Vector2(0.0, scale), pos)


static func _pts(xf: Transform2D, local: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in local:
		out.append(xf * (p as Vector2))
	return out


# Godot's triangulator rejects self-intersecting polygons and silently
# draws NOTHING, which is how the crab became invisible while every test
# stayed green. Guard it: fall back to the convex hull so the shape still
# reads, and COUNT the failures so verify/ can assert zero rather than
# letting a hull quietly stand in for the real silhouette.
static var bad_polys := 0

static func _poly(ci: CanvasItem, xf: Transform2D, local: Array, col: Color) -> void:
	var pts: PackedVector2Array = _pts(xf, local)
	if pts.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		bad_polys += 1
		var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
		if hull.size() >= 3:
			ci.draw_colored_polygon(hull, col)
		return
	ci.draw_colored_polygon(pts, col)


static func _box(ci: CanvasItem, xf: Transform2D, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	_poly(ci, xf, [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)], col)


static func _dot(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(xf * c, r * xf.y.y, col)


static func _seg(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(xf * a, xf * b, col, w * xf.y.y)


# A tapering limb segment: width w0 at a, width w1 at b, with round caps so
# joints read as joints instead of as mitre gaps.
static func _tube(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	_poly(ci, xf, [
		a + n * w0 * 0.5,
		b + n * w1 * 0.5,
		b - n * w1 * 0.5,
		a - n * w0 * 0.5,
	], col)
	_dot(ci, xf, a, w0 * 0.5, col)
	_dot(ci, xf, b, w1 * 0.5, col)


static func _arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n: int) -> Array:
	var out: Array = []
	for i in range(n + 1):
		var t: float = a0 + (a1 - a0) * float(i) / float(n)
		out.append(Vector2(cx + rx * cos(t), cy + ry * sin(t)))
	return out


static func _place(local: Array, pivot: Vector2, ang: float, at: Vector2) -> Array:
	# Rotate a part around its own pivot and drop it somewhere else, used
	# for limb pieces that have been snapped off and fallen to the seabed.
	var out: Array = []
	for p in local:
		out.append(at + (p as Vector2 - pivot).rotated(ang))
	return out


static func _broken(flags: Array, i: int) -> bool:
	if i < flags.size():
		return bool(flags[i])
	return false


# A wound at a break: a saw-toothed band across the joint. Built as a
# zigzag front edge plus a straight back edge so it is always a simple
# polygon; a naive zigzag self-intersects and the triangulator refuses it.
static func _break_face(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, depth: float, teeth: int) -> void:
	var d := b - a
	var side := d.orthogonal().normalized()
	var pts: Array = []
	for i in range(teeth * 2 + 1):
		var t: float = float(i) / float(teeth * 2)
		var off := 0.0
		if i % 2 == 1:
			off = depth
		pts.append(a + d * t + side * off)
	pts.append(b - side * (depth * 0.42))
	pts.append(a - side * (depth * 0.42))
	_poly(ci, xf, pts, WOUND)
	_seg(ci, xf, a - side * (depth * 0.42), b - side * (depth * 0.42), 0.016, WOUND_DK)


static func _crack(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2) -> void:
	var mid := (a + b) * 0.5
	var off := (b - a).orthogonal() * 0.28
	_seg(ci, xf, a, mid + off, 0.014, WOUND_DK)
	_seg(ci, xf, mid + off, b, 0.014, WOUND_DK)


# ---- tier 1: Scuba, Air 1 ----------------------------------------------
# Silhouette idea: THIN. A stick with two long fin blades lying flat on the
# ground and a ponytail streaming back. Nothing on this figure is round or
# blocky, because those belong to the other two tiers.
static func _scuba(ci: CanvasItem, xf: Transform2D) -> void:
	# Far leg + far fin. The two fins point OPPOSITE ways on purpose: one
	# flat plank at the ground reads as a surfboard, two splayed blades read
	# as fins, and the wide low footprint is half of this tier's silhouette.
	_fin(ci, xf, Vector2(-0.085, -0.078), 0.195, -1.0, SUIT_DK)
	_tube(ci, xf, Vector2(-0.020, -0.400), Vector2(-0.078, -0.090), 0.052, 0.038, SKIN_DK)

	# tank: a single slim bottle, deliberately narrow so the outline stays thin
	_box(ci, xf, -0.108, -0.605, -0.052, -0.440, RUBBER)
	_dot(ci, xf, Vector2(-0.080, -0.612), 0.028, RUBBER)
	_seg(ci, xf, Vector2(-0.080, -0.628), Vector2(-0.010, -0.672), 0.020, RUBBER)

	# near leg + near fin
	_fin(ci, xf, Vector2(0.085, -0.078), 0.265, 1.0, SUIT)
	_tube(ci, xf, Vector2(0.020, -0.400), Vector2(0.085, -0.090), 0.058, 0.042, SKIN)

	# hips and torso: narrow, tapering to the shoulders
	_poly(ci, xf, [
		Vector2(-0.060, -0.430), Vector2(0.062, -0.430),
		Vector2(0.078, -0.560), Vector2(0.070, -0.628),
		Vector2(-0.062, -0.628), Vector2(-0.072, -0.548),
	], SKIN)
	# swimsuit band, warm accent
	_box(ci, xf, -0.068, -0.470, 0.068, -0.412, HAIR)
	_box(ci, xf, -0.066, -0.616, 0.072, -0.575, HAIR)

	# arms: one swept back, one reaching forward. Both thin.
	_tube(ci, xf, Vector2(-0.030, -0.612), Vector2(-0.155, -0.470), 0.046, 0.032, SKIN_DK)
	_tube(ci, xf, Vector2(0.040, -0.612), Vector2(0.175, -0.560), 0.048, 0.034, SKIN)
	_dot(ci, xf, Vector2(0.192, -0.556), 0.030, SKIN)

	# neck and head
	_box(ci, xf, -0.024, -0.660, 0.032, -0.612, SKIN_DK)
	_dot(ci, xf, Vector2(0.012, -0.726), 0.062, SKIN)
	# hair: cap plus a ponytail that streams backwards. The trailing spike
	# is what tells you at 64px that this one has no helmet.
	_poly(ci, xf, [
		Vector2(0.060, -0.762), Vector2(0.010, -0.794),
		Vector2(-0.048, -0.774), Vector2(-0.072, -0.724),
		Vector2(-0.160, -0.744), Vector2(-0.258, -0.796),
		Vector2(-0.248, -0.726), Vector2(-0.150, -0.664),
		Vector2(-0.050, -0.648), Vector2(-0.056, -0.734),
	], HAIR)
	# goggles: a band across the eyes, no helmet
	_poly(ci, xf, [
		Vector2(-0.060, -0.752), Vector2(0.070, -0.744),
		Vector2(0.072, -0.706), Vector2(-0.058, -0.716),
	], GLASS_DK)
	_poly(ci, xf, [
		Vector2(0.010, -0.748), Vector2(0.066, -0.742),
		Vector2(0.068, -0.712), Vector2(0.012, -0.718),
	], GLASS)


static func _fin(ci: CanvasItem, xf: Transform2D, ankle: Vector2, length: float, dir: float, col: Color) -> void:
	_poly(ci, xf, [
		ankle + Vector2(-0.046 * dir, -0.034),
		ankle + Vector2(0.032 * dir, -0.030),
		ankle + Vector2(length * dir, 0.046),
		ankle + Vector2((length + 0.014) * dir, 0.078),
		ankle + Vector2((length - 0.088) * dir, 0.078),
		ankle + Vector2(-0.054 * dir, 0.020),
	], col)


# ---- tier 2: Prototype1, Air 2 -----------------------------------------
# Silhouette idea: TWO CIRCLES. A round helmet on top and a round three-lens
# drum held out front at chest height. Bulk is midway between the other two.
static func _proto1(ci: CanvasItem, xf: Transform2D) -> void:
	# far leg and boot
	_tube(ci, xf, Vector2(-0.030, -0.440), Vector2(-0.070, -0.105), 0.100, 0.082, SUIT_DK)
	_poly(ci, xf, [
		Vector2(-0.135, -0.115), Vector2(-0.010, -0.115),
		Vector2(0.030, -0.060), Vector2(0.028, 0.000),
		Vector2(-0.140, 0.000),
	], SUIT_DKR)

	# rebreather block on the back
	_box(ci, xf, -0.250, -0.690, -0.140, -0.480, RUBBER)
	_box(ci, xf, -0.242, -0.660, -0.148, -0.628, GOLD_DK)

	# near leg and boot
	_tube(ci, xf, Vector2(0.030, -0.440), Vector2(0.060, -0.105), 0.108, 0.090, SUIT)
	_box(ci, xf, -0.012, -0.330, 0.115, -0.288, SUIT_DK)
	_poly(ci, xf, [
		Vector2(-0.010, -0.120), Vector2(0.125, -0.120),
		Vector2(0.165, -0.062), Vector2(0.162, 0.000),
		Vector2(-0.015, 0.000),
	], RUBBER)

	# hips and a soft, slightly barrelled torso
	_poly(ci, xf, [
		Vector2(-0.130, -0.420), Vector2(0.135, -0.420),
		Vector2(0.152, -0.520), Vector2(0.160, -0.610),
		Vector2(0.140, -0.668), Vector2(-0.138, -0.668),
		Vector2(-0.158, -0.610), Vector2(-0.150, -0.520),
	], SUIT)
	# suit seams and harness, so it reads as fabric and not plate
	_box(ci, xf, -0.152, -0.462, 0.150, -0.420, SUIT_DK)
	_seg(ci, xf, Vector2(-0.150, -0.560), Vector2(0.152, -0.560), 0.026, SUIT_DK)
	_seg(ci, xf, Vector2(-0.120, -0.664), Vector2(0.060, -0.470), 0.030, SUIT_DKR)

	# soft rolled shoulders
	_dot(ci, xf, Vector2(-0.140, -0.652), 0.062, SUIT_DK)
	_dot(ci, xf, Vector2(0.146, -0.652), 0.066, SUIT)

	# arms: back arm hangs, front arm carries the drum
	_tube(ci, xf, Vector2(-0.140, -0.648), Vector2(-0.185, -0.470), 0.088, 0.070, SUIT_DK)
	_tube(ci, xf, Vector2(0.140, -0.648), Vector2(0.215, -0.552), 0.092, 0.074, SUIT)
	_tube(ci, xf, Vector2(0.215, -0.552), Vector2(0.262, -0.512), 0.078, 0.066, SUIT)
	_dot(ci, xf, Vector2(0.270, -0.508), 0.044, RUBBER)

	# collar ring and round helmet
	_box(ci, xf, -0.072, -0.700, 0.078, -0.650, GOLD_DK)
	_dot(ci, xf, Vector2(0.008, -0.800), 0.118, SUIT_DK)
	_dot(ci, xf, Vector2(0.008, -0.800), 0.100, SUIT)
	# faceplate port
	_dot(ci, xf, Vector2(0.052, -0.802), 0.064, GLASS_DK)
	_dot(ci, xf, Vector2(0.058, -0.808), 0.050, GLASS)
	# top valve, the little spike that keeps the helmet from reading as a head
	_box(ci, xf, -0.030, -0.938, 0.020, -0.900, GOLD_DK)
	_seg(ci, xf, Vector2(-0.006, -0.930), Vector2(-0.150, -0.660), 0.024, RUBBER)

	_drum(ci, xf, Vector2(0.318, -0.505), 0.104)


# The three-lens drum from the reference render, drawn end-on so the three
# barrels fan out of the front. Two circles and three stubs: unmistakable.
static func _drum(ci: CanvasItem, xf: Transform2D, c: Vector2, r: float) -> void:
	for i in range(3):
		var ang: float = deg_to_rad(-32.0 + 32.0 * float(i))
		var dir := Vector2(cos(ang), sin(ang))
		var n := dir.orthogonal()
		var a := c + dir * (r * 0.55)
		var b := c + dir * (r * 1.60)
		_poly(ci, xf, [
			a + n * 0.030, b + n * 0.034,
			b - n * 0.034, a - n * 0.030,
		], RUBBER)
		_dot(ci, xf, b, 0.040, GOLD_DK)
		_dot(ci, xf, b, 0.026, GLASS)
	_dot(ci, xf, c, r, RUBBER)
	_dot(ci, xf, c, r * 0.80, GOLD_DK)
	_dot(ci, xf, c, r * 0.46, GLASS_DK)
	_dot(ci, xf, c, r * 0.24, GLASS)


# ---- tier 3: Proto5, Air 3 ---------------------------------------------
# Silhouette idea: A SLAB. Widest, tallest, all right angles, with a head
# far too small for the shoulders. Nothing tapers.
static func _proto5(ci: CanvasItem, xf: Transform2D) -> void:
	# far leg and boot
	_box(ci, xf, -0.215, -0.430, -0.070, -0.150, PLATE_DK)
	_poly(ci, xf, [
		Vector2(-0.250, -0.165), Vector2(-0.050, -0.165),
		Vector2(-0.040, 0.000), Vector2(-0.268, 0.000),
	], PLATE_DK)

	# backpack: blocky rebreather with two bottles
	_box(ci, xf, -0.345, -0.790, -0.195, -0.455, PLATE_DK)
	_box(ci, xf, -0.330, -0.735, -0.210, -0.700, GOLD_DK)
	_box(ci, xf, -0.402, -0.775, -0.332, -0.590, RUBBER)

	# near leg, knee plate, boot
	_box(ci, xf, -0.060, -0.430, 0.105, -0.150, PLATE)
	_box(ci, xf, -0.075, -0.330, 0.120, -0.268, PLATE_LT)
	_poly(ci, xf, [
		Vector2(-0.080, -0.170), Vector2(0.145, -0.170),
		Vector2(0.172, 0.000), Vector2(-0.100, 0.000),
	], PLATE)
	_box(ci, xf, -0.100, -0.055, 0.172, -0.020, GOLD_DK)

	# tassets over the hips
	_poly(ci, xf, [
		Vector2(-0.215, -0.530), Vector2(0.215, -0.530),
		Vector2(0.185, -0.395), Vector2(-0.185, -0.395),
	], PLATE_DK)
	_box(ci, xf, -0.205, -0.505, 0.205, -0.462, GOLD)

	# chest: a rectangle that widens upward
	_poly(ci, xf, [
		Vector2(-0.200, -0.530), Vector2(0.200, -0.530),
		Vector2(0.235, -0.700), Vector2(0.230, -0.815),
		Vector2(-0.235, -0.815), Vector2(-0.240, -0.700),
	], PLATE)
	# gold bands, the render's read
	_box(ci, xf, -0.238, -0.735, 0.232, -0.690, GOLD)
	_box(ci, xf, -0.212, -0.618, 0.208, -0.580, GOLD_DK)
	_box(ci, xf, -0.090, -0.812, 0.090, -0.560, PLATE_LT)

	# pauldrons: the widest thing on the board
	_poly(ci, xf, [
		Vector2(-0.180, -0.870), Vector2(-0.372, -0.855),
		Vector2(-0.418, -0.775), Vector2(-0.390, -0.690),
		Vector2(-0.180, -0.700),
	], PLATE_DK)
	_poly(ci, xf, [
		Vector2(0.175, -0.870), Vector2(0.372, -0.858),
		Vector2(0.420, -0.775), Vector2(0.392, -0.680),
		Vector2(0.175, -0.695),
	], PLATE)
	_box(ci, xf, 0.192, -0.800, 0.412, -0.760, GOLD)
	_box(ci, xf, -0.408, -0.800, -0.190, -0.760, GOLD_DK)

	# arms: thick, square, ending in blocks
	_tube(ci, xf, Vector2(-0.300, -0.762), Vector2(-0.336, -0.600), 0.130, 0.108, PLATE_DK)
	_box(ci, xf, -0.404, -0.612, -0.272, -0.462, PLATE_DK)
	_box(ci, xf, -0.398, -0.566, -0.278, -0.532, GOLD_DK)
	_tube(ci, xf, Vector2(0.302, -0.762), Vector2(0.348, -0.580), 0.145, 0.125, PLATE)
	_box(ci, xf, 0.272, -0.600, 0.424, -0.440, PLATE)
	_box(ci, xf, 0.277, -0.535, 0.420, -0.498, GOLD_DK)

	# neck and a deliberately undersized helmet
	_box(ci, xf, -0.075, -0.860, 0.075, -0.800, PLATE_DK)
	_poly(ci, xf, [
		Vector2(-0.092, -0.855), Vector2(0.100, -0.855),
		Vector2(0.112, -0.930), Vector2(0.082, -0.968),
		Vector2(-0.070, -0.968), Vector2(-0.098, -0.928),
	], PLATE)
	_box(ci, xf, -0.020, -0.912, 0.110, -0.878, GLASS_DK)
	_box(ci, xf, 0.030, -0.906, 0.106, -0.884, GLASS)
	# crest, the last centimetre of height
	_poly(ci, xf, [
		Vector2(-0.040, -0.965), Vector2(0.045, -0.965),
		Vector2(0.030, -1.000), Vector2(-0.022, -1.000),
	], GOLD)


# ---- the hunter crab ---------------------------------------------------
# Faces left. Front of the shell is at -x, tail at +x, claw raised on the
# near flank, soft belly underneath.

static func _crab_legs_far(ci: CanvasItem, xf: Transform2D) -> void:
	_crab_leg(ci, xf, Vector2(-0.300, -0.300), Vector2(-0.540, -0.430), Vector2(-0.800, -0.010), 0.052, CHITIN_DK)
	_crab_leg(ci, xf, Vector2(-0.120, -0.290), Vector2(-0.250, -0.470), Vector2(-0.400, -0.010), 0.056, CHITIN_DK)
	_crab_leg(ci, xf, Vector2(0.150, -0.290), Vector2(0.230, -0.470), Vector2(0.330, -0.010), 0.056, CHITIN_DK)
	_crab_leg(ci, xf, Vector2(0.340, -0.300), Vector2(0.520, -0.430), Vector2(0.760, -0.010), 0.052, CHITIN_DK)


static func _crab_legs_near(ci: CanvasItem, xf: Transform2D) -> void:
	_crab_leg(ci, xf, Vector2(-0.240, -0.260), Vector2(-0.430, -0.400), Vector2(-0.640, 0.000), 0.060, CHITIN)
	_crab_leg(ci, xf, Vector2(0.020, -0.250), Vector2(-0.040, -0.430), Vector2(0.070, 0.000), 0.062, CHITIN)
	_crab_leg(ci, xf, Vector2(0.290, -0.260), Vector2(0.440, -0.400), Vector2(0.610, 0.000), 0.060, CHITIN)


static func _crab_leg(ci: CanvasItem, xf: Transform2D, hip: Vector2, knee: Vector2, foot: Vector2, w: float, col: Color) -> void:
	_tube(ci, xf, hip, knee, w, w * 0.85, col)
	_tube(ci, xf, knee, foot, w * 0.85, w * 0.30, col)
	_poly(ci, xf, [
		foot + Vector2(-0.030, -0.030),
		foot + Vector2(0.030, -0.030),
		foot + Vector2(0.004, 0.006),
	], CHITIN_DK)


static func _crab_shell(ci: CanvasItem, xf: Transform2D) -> void:
	var dome: Array = _arc(0.030, -0.325, 0.575, 0.360, PI, TAU, 20)
	dome.append(Vector2(0.560, -0.290))
	dome.append(Vector2(0.120, -0.255))
	dome.append(Vector2(-0.320, -0.268))
	dome.append(Vector2(-0.520, -0.300))
	_poly(ci, xf, dome, SHELL)

	# plate seams and a lighter crown, so the shell reads as armour and the
	# belly below it reads as not-armour
	var crown: Array = _arc(0.030, -0.325, 0.470, 0.300, PI + 0.25, TAU - 0.25, 14)
	crown.append(Vector2(0.420, -0.395))
	crown.append(Vector2(0.020, -0.430))
	crown.append(Vector2(-0.380, -0.400))
	_poly(ci, xf, crown, SHELL_LT)
	_seg(ci, xf, Vector2(-0.230, -0.640), Vector2(-0.250, -0.290), 0.016, SHELL_DK)
	_seg(ci, xf, Vector2(0.210, -0.630), Vector2(0.235, -0.285), 0.016, SHELL_DK)

	# mutation: spines along the back edge
	for i in range(4):
		var bx: float = -0.140 + 0.185 * float(i)
		var by: float = -0.660 + 0.055 * abs(float(i) - 1.0)
		_poly(ci, xf, [
			Vector2(bx - 0.048, by + 0.030),
			Vector2(bx + 0.048, by + 0.030),
			Vector2(bx + 0.010, by - 0.115),
		], SHELL_DK)

	# the overhanging rim that casts the belly into its own shape
	_seg(ci, xf, Vector2(-0.520, -0.296), Vector2(0.560, -0.286), 0.030, SHELL_DK)


static func _crab_belly(ci: CanvasItem, xf: Transform2D) -> void:
	# UNDER exposes nothing (SPEC 2.6) but the underside is still the soft
	# part, so it is pale, plate-free and segmented, not chitin.
	_poly(ci, xf, [
		Vector2(-0.455, -0.290), Vector2(0.500, -0.288),
		Vector2(0.470, -0.180), Vector2(0.360, -0.128),
		Vector2(-0.300, -0.132), Vector2(-0.418, -0.190),
	], BELLY)
	for i in range(3):
		var sx: float = -0.230 + 0.230 * float(i)
		_seg(ci, xf, Vector2(sx, -0.286), Vector2(sx + 0.045, -0.140), 0.016, BELLY_DK)
	_seg(ci, xf, Vector2(-0.410, -0.196), Vector2(0.462, -0.190), 0.018, BELLY_DK)


static func _crab_jaw(ci: CanvasItem, xf: Transform2D) -> void:
	_crab_head_plate(ci, xf, SHELL, SHELL_DK)
	# upper mandible
	_poly(ci, xf, [
		Vector2(-0.660, -0.470), Vector2(-0.850, -0.452),
		Vector2(-1.030, -0.336), Vector2(-0.985, -0.288),
		Vector2(-0.800, -0.360), Vector2(-0.645, -0.392),
	], CHITIN)
	# lower mandible
	_poly(ci, xf, [
		Vector2(-0.640, -0.256), Vector2(-0.812, -0.228),
		Vector2(-0.995, -0.118), Vector2(-0.940, -0.078),
		Vector2(-0.775, -0.170), Vector2(-0.630, -0.206),
	], CHITIN)
	# teeth in the gape
	for i in range(3):
		var t: float = 0.22 + 0.28 * float(i)
		var ux: float = -0.700 - 0.290 * t
		var uy: float = -0.396 + 0.084 * t
		_poly(ci, xf, [
			Vector2(ux - 0.030, uy), Vector2(ux + 0.030, uy), Vector2(ux, uy + 0.070),
		], BELLY)
		var lx: float = -0.690 - 0.280 * t
		var ly: float = -0.212 + 0.088 * t
		_poly(ci, xf, [
			Vector2(lx - 0.030, ly), Vector2(lx + 0.030, ly), Vector2(lx, ly - 0.070),
		], BELLY)
	_crab_eyes(ci, xf, false)


static func _crab_jaw_broken(ci: CanvasItem, xf: Transform2D) -> void:
	# The gape is what made FRONT dangerous, so breaking the jaw closes the
	# gape: the upper mandible is snapped to a stub and the lower one hangs
	# dead off its hinge with the tip in the silt. Nothing is deleted, so
	# the player can still see which limb this was.
	_crab_head_plate(ci, xf, DEAD, DEAD_DK)
	# upper mandible, snapped short
	_poly(ci, xf, [
		Vector2(-0.660, -0.470), Vector2(-0.808, -0.452),
		Vector2(-0.792, -0.384), Vector2(-0.645, -0.392),
	], DEAD)
	_break_face(ci, xf, Vector2(-0.812, -0.450), Vector2(-0.795, -0.382), 0.062, 3)
	# lower mandible, still hinged but limp
	var lower: Array = [
		Vector2(-0.640, -0.256), Vector2(-0.812, -0.228),
		Vector2(-0.995, -0.118), Vector2(-0.940, -0.078),
		Vector2(-0.775, -0.170), Vector2(-0.630, -0.206),
	]
	var hinge := Vector2(-0.640, -0.230)
	var droop := deg_to_rad(-20.0)
	_poly(ci, xf, _place(lower, hinge, droop, hinge), DEAD)
	# the teeth go with it, or nobody can tell this used to be the jaw
	for i in range(3):
		var t: float = 0.22 + 0.28 * float(i)
		var lx: float = -0.690 - 0.280 * t
		var ly: float = -0.212 + 0.088 * t
		_poly(ci, xf, _place([
			Vector2(lx - 0.030, ly), Vector2(lx + 0.030, ly), Vector2(lx, ly - 0.070),
		], hinge, droop, hinge), BELLY_DK)
	_break_face(ci, xf, Vector2(-0.612, -0.192), Vector2(-0.652, -0.278), 0.060, 3)
	_crack(ci, xf, Vector2(-0.560, -0.500), Vector2(-0.660, -0.400))
	_crab_eyes(ci, xf, true)


static func _crab_head_plate(ci: CanvasItem, xf: Transform2D, col: Color, dk: Color) -> void:
	_poly(ci, xf, [
		Vector2(-0.470, -0.545), Vector2(-0.640, -0.520),
		Vector2(-0.735, -0.430), Vector2(-0.725, -0.290),
		Vector2(-0.640, -0.200), Vector2(-0.460, -0.185),
		Vector2(-0.420, -0.360),
	], col)
	_seg(ci, xf, Vector2(-0.700, -0.440), Vector2(-0.690, -0.250), 0.018, dk)


static func _crab_eyes(ci: CanvasItem, xf: Transform2D, hurt: bool) -> void:
	if hurt:
		# stalks go slack when the jaw is gone: the whole head reads dead
		_tube(ci, xf, Vector2(-0.600, -0.540), Vector2(-0.700, -0.470), 0.036, 0.028, DEAD_DK)
		_dot(ci, xf, Vector2(-0.712, -0.462), 0.042, DEAD_DK)
		_tube(ci, xf, Vector2(-0.545, -0.545), Vector2(-0.585, -0.610), 0.032, 0.026, DEAD_DK)
		_dot(ci, xf, Vector2(-0.590, -0.620), 0.036, DEAD_DK)
		return
	_tube(ci, xf, Vector2(-0.596, -0.530), Vector2(-0.722, -0.612), 0.036, 0.030, CHITIN)
	_dot(ci, xf, Vector2(-0.736, -0.622), 0.048, SHELL_DK)
	_dot(ci, xf, Vector2(-0.742, -0.630), 0.026, EYE)
	_tube(ci, xf, Vector2(-0.532, -0.542), Vector2(-0.622, -0.598), 0.032, 0.026, CHITIN)
	_dot(ci, xf, Vector2(-0.632, -0.608), 0.040, SHELL_DK)
	_dot(ci, xf, Vector2(-0.638, -0.614), 0.022, EYE)


static func _crab_claw(ci: CanvasItem, xf: Transform2D) -> void:
	# Raised and cocked over the front, which is the pose that makes FLANK
	# look dangerous before the rules have said anything. It rises at the
	# shoulder rather than crossing the shell, so the shell stays readable.
	_dot(ci, xf, Vector2(-0.290, -0.330), 0.090, CHITIN_DK)
	_tube(ci, xf, Vector2(-0.290, -0.345), Vector2(-0.395, -0.735), 0.142, 0.120, CHITIN)
	_tube(ci, xf, Vector2(-0.395, -0.735), Vector2(-0.605, -0.895), 0.134, 0.106, CHITIN)
	_dot(ci, xf, Vector2(-0.395, -0.735), 0.078, CHITIN_DK)
	_crab_pincer_at(ci, xf, Vector2(-0.605, -0.895), 0.0, CHITIN, CHITIN_DK)


static func _crab_claw_broken(ci: CanvasItem, xf: Transform2D) -> void:
	# Not deleted: collapsed. The whole arm has dropped off the shoulder and
	# the pincer lies open on the seabed, so you can still see WHICH limb
	# went and that FLANK is no longer a threat.
	var elbow := Vector2(-0.430, -0.078)
	var wrist := Vector2(-0.680, -0.098)
	_dot(ci, xf, Vector2(-0.290, -0.330), 0.086, DEAD_DK)
	_tube(ci, xf, Vector2(-0.290, -0.345), elbow, 0.142, 0.116, DEAD)
	_tube(ci, xf, elbow, wrist, 0.124, 0.100, DEAD)
	_dot(ci, xf, elbow, 0.070, DEAD_DK)
	_crab_pincer_at(ci, xf, wrist, deg_to_rad(-18.0), DEAD, DEAD_DK)
	# the joint that failed, teeth pointing away from the shell
	_break_face(ci, xf, Vector2(-0.352, -0.376), Vector2(-0.236, -0.290), 0.055, 4)
	_crack(ci, xf, Vector2(-0.330, -0.180), Vector2(-0.398, -0.098))


static func _crab_pincer_at(ci: CanvasItem, xf: Transform2D, wrist: Vector2, ang: float, col: Color, dk: Color) -> void:
	# palm
	var palm: Array = [
		Vector2(-0.575, -0.905), Vector2(-0.760, -0.965),
		Vector2(-0.840, -0.930), Vector2(-0.845, -0.855),
		Vector2(-0.760, -0.792), Vector2(-0.585, -0.800),
	]
	# fixed finger, up
	var up: Array = [
		Vector2(-0.800, -0.955), Vector2(-0.980, -1.060),
		Vector2(-1.058, -1.052), Vector2(-1.000, -0.990),
		Vector2(-0.822, -0.900),
	]
	# moving finger, down: the gape is what says "claw" and not "club"
	var dn: Array = [
		Vector2(-0.812, -0.845), Vector2(-0.985, -0.868),
		Vector2(-1.062, -0.900), Vector2(-0.990, -0.812),
		Vector2(-0.818, -0.782),
	]
	var pivot := Vector2(-0.585, -0.855)
	_poly(ci, xf, _place(palm, pivot, ang, wrist), col)
	_poly(ci, xf, _place(up, pivot, ang, wrist), col)
	_poly(ci, xf, _place(dn, pivot, ang, wrist), dk)
	var ridge: Array = _place([Vector2(-0.780, -0.930), Vector2(-0.640, -0.880)], pivot, ang, wrist)
	_seg(ci, xf, ridge[0], ridge[1], 0.026, dk)


static func _crab_tail(ci: CanvasItem, xf: Transform2D) -> void:
	# Five segments arcing up and back. SPEC 2.6: the tail sweeps REAR and
	# FLANK together, so it is drawn long enough to look like it reaches.
	var spine: Array = [
		Vector2(0.500, -0.470), Vector2(0.680, -0.520),
		Vector2(0.840, -0.605), Vector2(0.970, -0.720),
		Vector2(1.055, -0.855),
	]
	var w: Array = [0.230, 0.190, 0.150, 0.115, 0.080]
	for i in range(spine.size() - 1):
		var a: Vector2 = spine[i]
		var b: Vector2 = spine[i + 1]
		var n := (b - a).orthogonal().normalized()
		_tube(ci, xf, a, b, w[i], w[i + 1], CHITIN)
		# joint ring, so it reads as segments and not as one smooth horn
		_seg(ci, xf, b - n * w[i + 1] * 0.55, b + n * w[i + 1] * 0.55, 0.024, CHITIN_DK)
		# dorsal spike per segment: the same mutation language as the shell
		var mid := (a + b) * 0.5
		var along := (b - a).normalized() * 0.048
		_poly(ci, xf, [
			mid - along - n * w[i] * 0.35,
			mid + along - n * w[i] * 0.35,
			mid - n * (w[i] * 0.5 + 0.085),
		], CHITIN_DK)
	# barb
	_poly(ci, xf, [
		Vector2(1.020, -0.880), Vector2(1.090, -0.830),
		Vector2(1.130, -1.010),
	], CHITIN_DK)


static func _crab_tail_broken(ci: CanvasItem, xf: Transform2D) -> void:
	# Same tail, kinked at the base and dragging on the seabed. REAR is safe
	# now and the picture has to say so without a word of UI.
	var spine: Array = [
		Vector2(0.500, -0.440), Vector2(0.660, -0.330),
		Vector2(0.800, -0.180), Vector2(0.955, -0.095),
		Vector2(1.110, -0.055),
	]
	var w: Array = [0.220, 0.150, 0.130, 0.100, 0.070]
	for i in range(spine.size() - 1):
		_tube(ci, xf, spine[i], spine[i + 1], w[i], w[i + 1], DEAD)
	_break_face(ci, xf, Vector2(0.600, -0.408), Vector2(0.706, -0.272), 0.075, 5)
	_crack(ci, xf, Vector2(0.760, -0.250), Vector2(0.845, -0.140))
	_poly(ci, xf, [
		Vector2(1.090, -0.086), Vector2(1.095, -0.020),
		Vector2(1.215, -0.030),
	], DEAD_DK)
