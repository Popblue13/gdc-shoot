extends WeaponAbility

const BUGGER_BULLET = preload("res://PlayerControllers/Abilities/shiftmiddlemousebutton/BuggerBullet.tscn")

@onready var animation_player: AnimationPlayer = $firstanimation/AnimationPlayer
@onready var fire_attack_speed: Timer = $FireAttackSpeed
@onready var crosshair_002: Sprite2D = $Crosshair002
@onready var label: Label = $Crosshair002/Label
@onready var bullet_spawner: MultiplayerSpawner = $MultiplayerSpawner

@export_category("Weapon Stats")
var max_ammo = 3
@export var damage: float = 10.0
@export var fire_speed: float = 0.1

@export_category("Weapon Movement Juice")
@export var weapon_mesh: Node3D 
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.02
@export var tilt_amount: float = 0.2

@export_category("Weapon Nodes")
@export var raycasts: Array[RayCast3D] = [] 

@export_category("Grapple Settings")
@export var rope_curve: Curve
@export var noise_rope: NoiseTexture3D
@export var pull_speed: float = 40.0
@export var vertical_boost: float = 4.8
@export var grapple_range_multiplier: int = 1

@export_category("Grapple Nodes")
# ASSIGN THESE IN THE INSPECTOR (Add them as children of your Weapon)
@export var look_ray_cast: RayCast3D 
@export var grapple_start: Node3D # Using Marker3D or Node3D for the barrel tip is usually best
@export var grapple_end: Node3D
@export var line: Path3D

# --- Internal Variables ---
var ammo: int
var idx = 0

var _bob_time: float = 0.0
var _initial_mesh_position: Vector3
var _initial_mesh_rotation: Vector3

# Grapple State
var hook_point: Vector3 = Vector3.ZERO
var rope_amplitude: float = 0.5
var is_hooked: bool = false
var retracted: bool = true

var vel: float = 0.01
var goal: float = 0.0
var tension: float = 500.0
var damping: float = 10.0
var noise_progression: float = randf()

func _ready() -> void:
	ammo = max_ammo
	fire_attack_speed.wait_time = fire_speed
	fire_attack_speed.one_shot = true
	hide()
	label.text = str(ammo) + "/" + str(max_ammo)
	
	bullet_spawner.spawn_function = spawn_bullet
	
	if weapon_mesh:
		_initial_mesh_position = weapon_mesh.position
		_initial_mesh_rotation = weapon_mesh.rotation

	# Setup Grapple
	if grapple_end and line and look_ray_cast:
		grapple_end.hide()
		line.hide()
		look_ray_cast.target_position.z *= grapple_range_multiplier

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	if !currently_active: return
	
	crosshair_002.visible = visible
	global_transform = merc.camera.global_transform
	
	if animation_player.is_playing() and animation_player.current_animation == "reload": 
		return
		
	if Input.is_action_just_pressed("reload") and ammo < max_ammo:
		reload()

	if Input.is_action_just_pressed("left_click"):
		if is_hooked:
			# Let the player click again to drop the grapple early
			release_grapple()
		else:
			shoot()
			
	if weapon_mesh:
		_apply_weapon_bob_and_tilt(delta)


# Handle Grapple Physics and Rope Visuals
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or not merc: return
	
	# Grapple Pull Logic
	if is_hooked:
		if (hook_point - merc.global_position).length() < 1.0:
			release_grapple()
		else:
			merc.velocity += (hook_point - merc.global_position).normalized() * pull_speed * delta
			merc.velocity += delta * Vector3(0, vertical_boost, 0)

	# Visuals Management
	if retracted:
		if grapple_end and grapple_start:
			grapple_end.global_position = grapple_start.global_position
			grapple_end.hide()
			line.hide()
	else:
		amplitude_spring(delta)
		manage_rope(delta)

func reload():
	# If the player reloads while grappling, cancel the grapple
	if not retracted:
		release_grapple()
		
	animation_player.play("reload")
	await animation_player.animation_finished
	ammo = max_ammo
	label.text = str(ammo) + "/" + str(max_ammo)

func shoot():
	if ammo <= 0:
		return
		
	match ammo:
		3:
			bullet_spawner.spawn({"is_freeze" = true})
		2:
			bullet_spawner.spawn({"is_freeze" = false})
		1:
			connect_grapple()
			
	ammo = clamp(ammo - 1, 0, max_ammo)
	
	animation_player.stop() 
	animation_player.play("fire")
	fire_attack_speed.start()
	label.text = str(ammo) + "/" + str(max_ammo)

func spawn_bullet(data : Dictionary):
	var bullet : Area3D = BUGGER_BULLET.instantiate()
	bullet.freeze_bullet = data["is_freeze"]
	bullet.position = grapple_start.global_position
	bullet.rotation = merc.camera.global_rotation
	
	return bullet

# ==========================================
# GRAPPLE LOGIC
# ==========================================
func connect_grapple() -> void:
	if not look_ray_cast.is_colliding(): 
		return # Missed the grapple, but ammo is still consumed

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
	if not retracted:
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
	if not line or not line.curve: return
	
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

func equip():
	show()
	animation_player.play("equip")
	show_visual_hand.rpc(true)

@rpc("any_peer","call_remote","reliable")
func show_visual_hand(vis : bool):
	if visual_hand:
		visual_hand.visible = vis
	
func dequip():
	if not retracted:
		release_grapple() # Make sure to release if we swap weapons!
		
	animation_player.play("dequip")
	await animation_player.animation_finished
	hide()
	crosshair_002.hide()
	show_visual_hand.rpc(false)

# ==========================================
# SOURCE-ENGINE WEAPON SWAY & BOB
# ==========================================
func _apply_weapon_bob_and_tilt(delta: float) -> void:
	var horizontal_velocity = Vector3(merc.velocity.x, 0, merc.velocity.z)
	var speed = horizontal_velocity.length()
	
	if speed > 0.1 and merc.is_on_floor():
		_bob_time += delta * speed * bob_frequency
	else:
		_bob_time = lerp(_bob_time, 0.0, delta * 5.0) 
		
	var target_pos = _initial_mesh_position
	target_pos.y += sin(_bob_time) * bob_amplitude 
	target_pos.x += cos(_bob_time * 0.5) * (bob_amplitude * 1.5) 
	
	var local_vel = merc.camera.global_transform.basis.inverse() * horizontal_velocity
	var target_rot = _initial_mesh_rotation
	
	target_rot.z += local_vel.x * tilt_amount * 0.01 
	target_rot.x -= local_vel.z * tilt_amount * 0.01 
	
	weapon_mesh.position = weapon_mesh.position.lerp(target_pos, delta * 10.0)
	weapon_mesh.rotation = weapon_mesh.rotation.lerp(target_rot, delta * 10.0)
