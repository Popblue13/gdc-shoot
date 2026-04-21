extends Ability

@export_group("Sprint Settings")
@export var speed_multiplier: float = 1.5
@export var fov_multiplier: float = 1.2
@export var transition_speed: float = 10.0 # Higher = faster snap, Lower = smoother glide
@export var damage : float = 70.0
@export var cooldown : float = 5
@export var slowdown : float = 4

# Internal state tracking
var _is_sprinting: bool = false
var _is_recovering: bool = false # Tracks if we are smoothly easing back to normal
var _original_speed: float = 0.0
var _original_fov: float = 0.0
var _target_speed: float = 0.0
var _target_fov: float = 0.0
var _merc_ref: Merc = null

# Riley's stuff
@onready var chomper: Node3D = $"../chomper_bodybrandc"
@onready var explosion_radius: Area3D = $ExplosionRadius
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var tornado_dash_ability: Node3D = $"../TornadoDashAbility"
@onready var air_accel = get_parent().air_acceleration
@onready var friction = get_parent().friction

var on_cooldown : bool = false

func _physics_process(delta: float) -> void:
	if !chomper.visible: chomper.show()
	if _merc_ref == null: 
		return
	
	# 1. Listen for key release if we are currently sprinting
	if _is_sprinting:
		var key_code = OS.find_keycode_from_string(trigger_key)
		if not Input.is_physical_key_pressed(key_code):
			_stop_sprint()

	# 2. --- THE LERPING MAGIC ---
	if _is_sprinting and not on_cooldown:
		#turn off collision if still on
		if get_parent().get_collision_layer_value(2):
			get_parent().set_collision_layer_value(2,false)
		
		# make funky scaling apply
		chomper.scale.y = move_toward(chomper.scale.y, 0.1, 15*delta)
		
		# Smoothly accelerate and push FOV out
		_merc_ref.speed = lerp(_merc_ref.speed, _target_speed, transition_speed * delta)
		_merc_ref.camera_fov = lerp(_merc_ref.camera_fov, _target_fov, transition_speed * delta)
		
	elif _is_recovering:
		# Smoothly decelerate and pull FOV back in
		_merc_ref.speed = lerp(_merc_ref.speed, _original_speed, transition_speed * delta)
		_merc_ref.camera_fov = lerp(_merc_ref.camera_fov, _original_fov, transition_speed * delta)
		
		# Stop recovering once we are microscopically close to the original values 
		# (prevents math errors and endless processing)
		if abs(_merc_ref.speed - _original_speed) < 0.05 and abs(_merc_ref.camera_fov - _original_fov) < 0.5:
			_merc_ref.speed = _original_speed
			_merc_ref.camera_fov = _original_fov
			_is_recovering = false

	# Riley shenanigans
	if not _is_sprinting:
		chomper.scale.y = move_toward(chomper.scale.y, 1, 15*delta)
		
		#turn back on collision if still off
		if not get_parent().get_collision_layer_value(2):
			get_parent().set_collision_layer_value(2,true)

# This is called by Merc every single frame the key is held down
func activate() -> void:
	# If we are already sprinting, ignore the continuous stream
	if _is_sprinting:
		return
	
	if tornado_dash_ability._is_sprinting:
		return
	
	if on_cooldown: #prevents spamming dig ability
		return
	
	_merc_ref = merc
	
	# CRITICAL: Only save the original stats if we are fully idle!
	# If they rapid-tap the sprint key while recovering, we don't want to 
	# accidentally save the half-lerped speed as their new permanent base speed.
	if not _is_recovering:
		_original_speed = merc.speed
		_original_fov = merc.camera_fov
		_target_speed = _original_speed * speed_multiplier
		_target_fov = _original_fov * fov_multiplier

	_is_sprinting = true
	_is_recovering = false # Cancel any ongoing deceleration

# Triggers the smooth lerp back to normal
func _stop_sprint() -> void:
	_is_sprinting = false
	_is_recovering = true
	
	# cause damage after release
	explode()
	cooldown_timer.start(cooldown)
	get_parent().friction = friction*4
	get_parent().air_acceleration = air_accel/4
	on_cooldown = true

@rpc("any_peer", "call_local", "reliable")
func explode():
	# Only the authority should calculate and send damage
	if is_multiplayer_authority():
		for i in explosion_radius.get_overlapping_bodies():
			if i != null and i is Merc and i != get_parent():
				i.take_damage.rpc_id(i.name.to_int(), i.health) 
	

func _on_cooldown_timer_timeout() -> void:
	on_cooldown = false
	get_parent().friction = friction
	get_parent().air_acceleration = air_accel
