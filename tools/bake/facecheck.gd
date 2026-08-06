# Renders each character's T_Pose from +Z and -Z, head-and-torso crop,
# to settle which way the characters face. Output: scratchpad facecheck dir.
extends Node

const OUT := "/private/tmp/claude-501/-Users-tomriddle1/5c14f00e-e36c-4f2d-b2bd-8a68d9a1ab15/scratchpad/facecheck"
const CHARS := {"scuba": "rig", "prototype1": "rig_001", "proto5": "rig_002"}

var sub: SubViewport
var cam: Camera3D
var rig_root: Node3D
var ap: AnimationPlayer

func _ready() -> void:
	sub = SubViewport.new()
	sub.size = Vector2i(512, 512)
	sub.own_world_3d = true
	sub.transparent_bg = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var ps: PackedScene = load("res://art/rigs/Main_Team_Rigging.fbx")
	rig_root = ps.instantiate()
	sub.add_child(rig_root)
	ap = rig_root.get_node("AnimationPlayer")
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.6
	cam.near = 0.05
	cam.far = 50.0
	sub.add_child(cam)
	cam.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 0, 0)
	light.light_energy = 0.9
	sub.add_child(light)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	sub.add_child(we)
	_go.call_deferred()

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for i in 3:
		await get_tree().process_frame
	ap.play("rig|T_Pose")
	ap.speed_scale = 0.0
	ap.seek(0.0, true)
	for char_key: String in CHARS.keys():
		for other in CHARS:
			(rig_root.get_node(CHARS[other]) as Node3D).visible = (other == char_key)
		var head_y := 1.7 if char_key != "proto5" else 2.0
		for side in [["posZ", 5.0, 0.0], ["negZ", -5.0, 180.0]]:
			cam.position = Vector3(0.0, head_y, side[1])
			cam.rotation_degrees = Vector3(0, side[2], 0)
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			sub.get_texture().get_image().save_png(OUT + "/%s_%s.png" % [char_key, side[0]])
			print("shot %s %s" % [char_key, side[0]])
	get_tree().quit(0)
