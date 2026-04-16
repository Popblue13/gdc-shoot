extends Ability
class_name GrapplePullAbility

@export_category("Grapple Settings")
@export var rope_curve: Curve
@export var noise_rope: NoiseTexture3D
@export var pull_speed: float = 40.0
@export var vertical_boost: float = 4.8

@onready var look_ray_cast: RayCast3D = $LookRayCast
@onready var grapple_start: MeshInstance3D = $GrappleStart
@onready var grapple_end: MeshInstance3D = $GrappleEnd
@onready var line: Path3D = $Line

var hook_point: Vector3 = Vector3.ZERO
var rope_amplitude: float = 0.5
var is_hooked: bool = false
var retracted: bool = true

var vel: float = 0.01
var goal: float = 0.0
var tension: float = 500.0
var damping: float = 10.0
var noise_progression: float = randf()

var _is_held: bool = false
var _was_held: bool = false

func _ready() -> void:
	grapple_end.hide()
	line.hide()

func activate() -> void:
	_is_held = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or not merc: return
	if merc.camera: 
		look_ray_cast.global_transform = merc.camera.global_transform
		
	# State Transitions based on the `activate` signal from Merc
	if _is_held and not _was_held and retracted:
		connect_grapple()
	elif not _is_held and _was_held and not retracted:
		release_grapple()
		
	# Grapple Pull Logic
	if is_hooked:
		if (hook_point - merc.global_position).length() < 1.0:
			release_grapple()
		else:
			merc.velocity += (hook_point - merc.global_position).normalized() * pull_speed * delta
			merc.velocity += delta * Vector3(0, vertical_boost, 0)
	else:
		if look_ray_cast and look_ray_cast.is_colliding() and look_ray_cast.get_child_count() > 0:
			look_ray_cast.get_child(0).global_position = look_ray_cast.get_collision_point()

	# Visuals Management
	if retracted:
		grapple_end.global_position = grapple_start.global_position
		grapple_end.hide()
		line.hide()
	else:
		amplitude_spring(delta)
		manage_rope(delta)

	# Frame Reset
	_was_held = _is_held
	_is_held = false

func connect_grapple() -> void:
	if not look_ray_cast.is_colliding(): return
	print('connections')
	rope_amplitude = 0.5
	grapple_end.show()
	line.show()
	
	var match_face_dir = max(0, merc.velocity.normalized().dot((merc.global_position - hook_point).normalized()))
	merc.velocity -= merc.velocity * Vector3(match_face_dir, match_face_dir, match_face_dir) * 0.5
	merc.velocity += Vector3(0, 2, 0)
	
	hook_point = look_ray_cast.get_collision_point()
	
	var tween = get_tree().create_tween()
	tween.tween_property(grapple_end, "global_position", hook_point, 0.1)
	retracted = false
	await tween.finished
	is_hooked = true

func release_grapple() -> void:
	if look_ray_cast: hook_point = look_ray_cast.get_collision_point()
	
	var tween = get_tree().create_tween()
	tween.tween_property(grapple_end, "global_position", grapple_start.global_position, 0.1)
	is_hooked = false
	await tween.finished
	retracted = true

func amplitude_spring(delta: float) -> void: 
	var displacement = rope_amplitude - goal
	var force = -tension * displacement - damping * vel
	vel += force * delta
	rope_amplitude += vel * delta

func manage_rope(delta: float) -> void:
	for i in line.curve.point_count:
		var ratio = float(i) / float(line.curve.point_count)
		var line_position = lerp(grapple_start.global_position, grapple_end.global_position, ratio)
		
		var offset_y = 0.0
		if rope_curve:
			offset_y = sin(ratio * 0.5 * (grapple_end.global_position - grapple_start.global_position).length()) * rope_amplitude * rope_curve.sample(ratio)
		
		var offset_noise = 0.0
		if noise_rope:
			offset_noise = noise_rope.noise.get_noise_2d(noise_progression, noise_progression)
			
		noise_progression += delta * 25
		
		line.curve.set_point_position(i, line.to_local(line_position) + (Vector3(0, offset_y, 0) * merc.transform.basis))
		if i != 0 and i != line.curve.point_count - 1:
			line.curve.set_point_position(i, line.to_local(line_position) + (Vector3(offset_noise * 0.1, offset_y, 0) * merc.transform.basis))
