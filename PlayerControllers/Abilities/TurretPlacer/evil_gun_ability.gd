extends WeaponAbility

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var tracer_effect: Node3D = $TracerEffect
@onready var fire_attack_speed: Timer = $FireAttackSpeed
@onready var crosshair_002: Sprite2D = $Crosshair002
@onready var label: Label = $Crosshair002/Label
@onready var turret_preview = $turretpreview

@export_category("Weapon Stats")
@export var is_auto: bool = false
@export var fire_speed: float = 0.1 # Time in seconds between shots

@export_category("Weapon Movement Juice")
@export var weapon_mesh: Node3D # ASSIGN YOUR VISUAL GUN MODEL HERE!
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.02
@export var tilt_amount: float = 0.2

var _bob_time: float = 0.0
var _initial_mesh_position: Vector3
var _initial_mesh_rotation: Vector3

@export_category("Weapon Nodes")
# Add ONE RayCast3D here for a Pistol/Rifle, or add MULTIPLE for a Shotgun
@export var raycasts: Array[RayCast3D] = [] 


func _ready() -> void:
	crosshair_002.hide()
	fire_attack_speed.wait_time = fire_speed
	fire_attack_speed.one_shot = true
	hide()
	
	# --- NEW: Save the resting position of the visual mesh ---
	if weapon_mesh:
		_initial_mesh_position = weapon_mesh.position
		_initial_mesh_rotation = weapon_mesh.rotation

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	if !currently_active: return
	
	
	# Don't allow glooting or reloading while already reloading
	if animation_player.is_playing() and animation_player.current_animation == "reload": 
		return
	# 2. Handle Single vs Auto fire inputs
	var trigger_pulled: bool = false
	if is_auto:
		trigger_pulled = Input.is_action_pressed("left_click") # Hold to gloot
	else:
		trigger_pulled = Input.is_action_just_pressed("left_click") # Click to gloot
	
	# 3. Check if the gun is ready to fire based on the timer
	if $PlacementRay.is_colliding() and get_parent().turrets >0 :
		var preview_position = $PlacementRay.get_collision_point()
		turret_preview.global_position = preview_position
		turret_preview.visible = true
		
		if trigger_pulled and fire_attack_speed.is_stopped():
			if get_parent().turrets <= 0:return
			get_parent().turrets -= 1
			var placement_position = $PlacementRay.get_collision_point()
			gloot(placement_position)
			gloot.rpc(placement_position)
		
	else:
		turret_preview.visible = false
	
	if weapon_mesh:
		_apply_weapon_bob_and_tilt(delta)

func shoot():
	pass

@rpc("any_peer", "call_remote", "reliable")
func gloot(placement_position):
	var sender_id = multiplayer.get_remote_sender_id()
	var turret_scene = load("res://PlayerControllers/Abilities/Turret/turret.tscn").instantiate()
	turret_scene.position = placement_position
	turret_scene.dada = get_parent()
	turret_scene.name = "turret_" + str(sender_id)
	turret_scene.set_multiplayer_authority(sender_id)
	get_parent().add_child(turret_scene)

func equip():
	show()
	crosshair_002.show()
	animation_player.play("equip")
	show_visual_hand.rpc(true)

@rpc("any_peer","call_remote","reliable")
func show_visual_hand(vis : bool):
	if visual_hand:
		visual_hand.visible = vis

func dequip():
	animation_player.play("dequip")
	await animation_player.animation_finished
	hide()
	crosshair_002.hide()
	show_visual_hand.rpc(false)

# ==========================================
# SOURCE-ENGINE WEAPON SWAY & BOB
# ==========================================
func _apply_weapon_bob_and_tilt(delta: float) -> void:
	# We only want 2D horizontal velocity (ignoring jumping/falling for the bob cycle)
	var horizontal_velocity = Vector3(merc.velocity.x, 0, merc.velocity.z)
	var speed = horizontal_velocity.length()
	
	# 1. BOBBING (Figure-8 pattern based on movement speed)
	if speed > 0.1 and merc.is_on_floor():
		# Advance the timer based on how fast we are moving
		_bob_time += delta * speed * bob_frequency
	else:
		# Smoothly reset the timer to 0 when we stop walking
		_bob_time = lerp(_bob_time, 0.0, delta * 5.0) 
		
	var target_pos = _initial_mesh_position
	# Up/Down motion
	target_pos.y += sin(_bob_time) * bob_amplitude 
	# Left/Right motion (Half the speed of Up/Down creates a figure-8)
	target_pos.x += cos(_bob_time * 0.5) * (bob_amplitude * 1.5) 
	
	# 2. ACCELERATION TILT (Tilts gun slightly opposite to movement direction)
	# Convert the global velocity into the camera's local point of view
	var local_vel = merc.camera.global_transform.basis.inverse() * horizontal_velocity
	var target_rot = _initial_mesh_rotation
	
	# Tilt left/right when strafing (A/D keys)
	target_rot.z += local_vel.x * tilt_amount * 0.01 
	# Tilt up/down slightly when moving forward/back (W/S keys)
	target_rot.x -= local_vel.z * tilt_amount * 0.01 
	
	# 3. LERP THE VISUALS (Smooths everything out)
	weapon_mesh.position = weapon_mesh.position.lerp(target_pos, delta * 10.0)
	weapon_mesh.rotation = weapon_mesh.rotation.lerp(target_rot, delta * 10.0)
