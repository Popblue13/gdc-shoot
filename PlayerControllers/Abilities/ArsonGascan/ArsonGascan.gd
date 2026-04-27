extends WeaponAbility

#@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_tree: AnimationTree = $AnimationStuff/AnimationTree
@export_category("Synchronized Variables")
@export var is_shooting: bool = false
@export var is_reloading: bool = false
@export var is_firing: bool = false
@export var new_equipped: bool = false

@onready var tick_timer: Timer = $TickTimer
@export var fire_rate: Timer
#@onready var ui_control: Control = $ScriptStuff/UI_Control
#@onready var ui_control: = $ScriptStuff/UI_BypassControl
#@onready var crosshair: Sprite2D = $ScriptStuff/UI_Control/Crosshair
const GAS_SPILL = preload("res://PlayerControllers/Abilities/ArsonGascan/Supplements/GasSpill.tscn")


@export_category("Weapon Stats")
@export var max_ammo: float = 100
@export var damage: float = 2.0
@export var fire_speed: float = 0.05 # Time in seconds between fire bursts
@export var regen_speed: float = 6.0   # regen speed
@export var drain_speed: float = 10.0   # drain speed
@export var start_cost: float = 20.0   # use cost

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

var ammo: float
var spawnGasCounter: int
func _ready() -> void:
	print("Ive been ready'd!")
	ammo = max_ammo
	spawnGasCounter = 0
	hide()
	#ui_control.hide()
	#ui_control.hide()
	#crosshair.hide()
	#ui_control.visible = false
	#crosshair.visible = false
	
	if weapon_mesh:
		_initial_mesh_position = weapon_mesh.position
		_initial_mesh_rotation = weapon_mesh.rotation
	
	if !is_multiplayer_authority():
		pass
		#ui_control.hide()
		#crosshair.hide()
		#ui_control.visible = false
		#crosshair.visible = false

var firstshot = false

func _process(delta: float) -> void:
	if ammo < max_ammo:
		# Add ammo based on time passed
		if !is_firing:
			ammo += regen_speed * delta
			
			# Clamp the value so it doesn't exceed max_ammo
			ammo = min(ammo, max_ammo)
		
	#print(ui_control.visible)
	if weapon_mesh:
		_apply_weapon_bob_and_tilt(delta)
	UpdateAnimations()
	if !is_multiplayer_authority(): return
	if !currently_active: return
	
	## Don't allow shooting or reloading while already reloading
	#if animation_player.is_playing() and animation_player.current_animation == "reload": 
		#return
	## 2. Handle Single vs Auto fire inputs
	var trigger_pulled: bool = false
	trigger_pulled = Input.is_action_pressed("left_click") # Hold to shoot
	#if is_auto:
		#trigger_pulled = Input.is_action_pressed("left_click") # Hold to shoot
	#else:
		#trigger_pulled = Input.is_action_just_pressed("left_click") # Click to shoot
	#
	# 3. Check if the gun is ready to fire based on the timer
	if trigger_pulled and (ammo >= start_cost or is_firing) and !new_equipped and !is_reloading:
		if firstshot == false:
			firstshot = true
			ammo -= start_cost
		#if tick_timer.is_stopped():
			#tick_timer.start()
		is_firing = true
		if ammo > 0:
			ammo -= (drain_speed * delta)
			spawnGasCounter += 1
			UpdateAnimations()
			if spawnGasCounter % 10 == 0: #Every 10 times actually spawn gas
				shoot()
		else:
			ammo = 0
			is_firing = false
			firstshot = false
			UpdateAnimations()
	else:
		is_firing = false
		firstshot = false
		UpdateAnimations()
	print(is_firing)
	print(ammo)
	
	#if Input.is_action_just_pressed("reload"):
		#print("Pressed reload")
		#print(is_reloading)
		#print(new_equipped)
		#print(ammo)
		#print(max_ammo)
	
	#if Input.is_action_just_pressed("reload") and !is_reloading and !new_equipped and ammo < max_ammo and !trigger_pulled: #Not letting them reload while shooting, to avoid fat fingers
		#reload()

func reload():
	is_reloading = true
	UpdateAnimations()

func reload_ammo():
	ammo = max_ammo

func finish_reload_anim():
	is_reloading = false
	UpdateAnimations()

#func shoot():
	##fire_rate.start()
	##ammo = ammo - 1.0
	#print("Pouring!")
	#GAS_SPILL.instantiate()

func shoot():
	
	# 1. Get the current physics world state
	var space_state = get_world_3d().direct_space_state
	
	# 2. Define the start and end of the ray
	var start_pos = global_position
	var end_pos = global_position + Vector3.DOWN * 10.0 # Casts 10 meters down
	
	# 3. Setup the query
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	
	# Optional: Tell the ray to ignore the player so it doesn't hit your own feet
	query.exclude = [self] 
	
	# 4. Execute the raycast
	var result = space_state.intersect_ray(query)
	
	# 5. Check if we hit the floor
	if result:
		spawn_gas_at.rpc(result.position, result.normal, self.get_multiplayer_authority())
		#spawn_gas_at(result.position, result.normal)

@rpc("any_peer","call_local","reliable")
func spawn_gas_at(pos: Vector3, normal: Vector3, OwnerID):
	#print("Spawning at: ", pos)
	var spill = GAS_SPILL.instantiate()
	
	# Add to the root so it stays in the world if the player moves away
	get_tree().root.add_child(spill)
	spill.global_position = pos
	spill.set_multiplayer_authority(OwnerID)
	
	# Align to the floor slope
	if normal.dot(Vector3.UP) < 0.99:
		spill.look_at(pos + normal, Vector3.RIGHT)
		spill.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))


func UpdateAnimations():
	animation_tree.set("parameters/conditions/is_firing", is_firing)
	animation_tree.set("parameters/conditions/not_firing", !is_firing)
	animation_tree.set("parameters/conditions/is_reloading", is_reloading)
	animation_tree.set("parameters/conditions/not_reloading", !is_reloading)
	animation_tree.set("parameters/conditions/new_equipped", new_equipped)

func equip():
	#print("Ive been equipped!")
	show()
	#ui_control.show()
	#crosshair.show()
	is_shooting = false
	is_reloading = false
	is_firing = false
	new_equipped = true
	UpdateAnimations()
	#animation_tree.start("ft_equip")
	show_self.rpc(true) #tell all clients to update

func finish_equip():
	new_equipped = false
	#ui_control.show()
	#crosshair.show()
	UpdateAnimations()

@rpc("any_peer","call_remote","reliable")
func show_self(vis : bool):
	if vis:
		show()
		new_equipped = true
		UpdateAnimations()
	else:
		hide()

func dequip():
	#animation_player.play("dequip")
	#await animation_player.animation_finished
	hide()
	new_equipped = false
	UpdateAnimations()
	#ui_control.hide()
	#crosshair.hide()
	#ui_control.visible = false
	#crosshair.visible = false
	show_self.rpc(false)
	#show_visual_hand.rpc(false)

# ==========================================
# SOURCE-ENGINE WEAPON SWAY & BOB
# ==========================================
func _apply_weapon_bob_and_tilt(delta: float) -> void:
	# We only want 2D horizontal velocity (ignoring jumping/falling for the bob cycle)
	if merc == null:
		return
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
