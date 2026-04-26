extends Ability

@export_group("Sprint Settings")
@export var speed_multiplier: float = 1.5
@export var fov_multiplier: float = 1.2
@export var transition_speed: float = 10.0 # Higher = faster snap, Lower = smoother glide
@export var damage = 70.0

# Internal state tracking
var _is_sprinting: bool = false
var _is_recovering: bool = false # Tracks if we are smoothly easing back to normal
var _original_speed: float = 0.0
var _original_fov: float = 0.0
var _target_speed: float = 0.0
var _target_fov: float = 0.0
var _merc_ref: Merc = null

# Riley's stuff
@onready var chomper: Node3D = $"../lowreschomp"
@onready var explosion_radius: Area3D = $ExplosionRadius
@onready var tunnel_ability: Node3D = $"../TunnelAbility"
var chomp_og_pos

func _ready() -> void:
	chomp_og_pos = chomper.position


func _physics_process(delta: float) -> void:
	if _merc_ref == null: 
		return

	# 1. Listen for key release if we are currently sprinting
	if _is_sprinting:
		var key_code = OS.find_keycode_from_string(trigger_key)
		if not Input.is_physical_key_pressed(key_code):
			_stop_sprint()

	# 2. --- THE LERPING MAGIC ---
	if _is_sprinting:
		explode(delta)
		
		# fix clipping into floor
		if chomp_og_pos and chomper.position == chomp_og_pos:
			chomper.rotate_x(-PI/2)
			chomper.position = chomp_og_pos * 0.4
			
		
		# make funky rotation apply
		chomper.rotate_z(PI/12)
		chomper.rotate_y(-PI/12)
		if chomper.rotation.x == 0:
			chomper.rotate_x(-PI/2)
		
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
		if chomp_og_pos and chomper.position != chomp_og_pos:
			chomper.rotate_x(PI/2)
			chomper.position = chomp_og_pos
			
		if chomper.rotation.x != 0:
			chomper.rotation.x = 0
		if chomper.rotation.z != 0:
			chomper.rotation.z = 0
		if chomper.rotation.y != 0:
			chomper.rotation.y = PI
			

# This is called by Merc every single frame the key is held down
func activate() -> void:
	# If we are already sprinting, ignore the continuous stream
	if _is_sprinting:
		return
	
	if tunnel_ability._is_sprinting: # if tunnel ability active already
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


@rpc("any_peer", "call_local", "reliable")
func explode(delta : float):
	# Only the authority should calculate and send damage
	if is_multiplayer_authority():
		for i in explosion_radius.get_overlapping_bodies():
			if i != null and i is Merc and i != get_parent():
				i.take_damage.rpc_id(i.name.to_int(), damage*delta) 
	
