extends WeaponAbility

#@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_tree: AnimationTree = $AnimationStuff/AnimationTree
@export_category("Synchronized Variables")
@export var is_shooting: bool = false
@export var is_reloading: bool = false
@export var is_firing: bool = false
@export var new_equipped: bool = false
var trigger_pulled: bool = false

@export var fire_rate: Timer
@export var PlayerCamera: Camera3D
var RNG1 = RandomNumberGenerator.new()
var RNG2 = RandomNumberGenerator.new()
@onready var barrel_exit: Marker3D = $Flamethrower/BarrelExit
const FT_PARTICLE = preload("res://PlayerControllers/Abilities/ArsonFlamethrower/Supplemental/FT_Particle.tscn")

@export_category("Weapon Stats")
@export var max_ammo: int = 200
@export var damage: float = 0.05
@export var fire_speed: float = 0.001 # Time in seconds between fire bursts

@export_category("Weapon Movement Juice")
@export var weapon_mesh: Node3D # ASSIGN YOUR VISUAL GUN MODEL HERE!
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.02
@export var tilt_amount: float = 0.2

var _bob_time: float = 0.0
var _initial_mesh_position: Vector3
var _initial_mesh_rotation: Vector3

var ammo: int

func _ready() -> void:
	print("Ive been ready'd!")
	ammo = max_ammo
	fire_rate.wait_time = fire_speed
	fire_rate.one_shot = true
	hide()
	
	if weapon_mesh:
		_initial_mesh_position = weapon_mesh.position
		_initial_mesh_rotation = weapon_mesh.rotation
	
	if !is_multiplayer_authority(): #If I join late and im not playing arson, I want the RNG values
		rpc_id(get_multiplayer_authority(), "syncRNGrequest")
	else: #if I am the late joiner, or I just joined, sync it.
		rpc("syncRNG", RNG1.state, RNG2.state, RNG1.seed, RNG2.seed)

@rpc("any_peer", "reliable")
func syncRNGrequest():
	var ID = multiplayer.get_remote_sender_id()
	rpc_id(ID, "syncRNG", RNG1.state, RNG2.state, RNG1.seed, RNG2.seed)

@rpc("any_peer", "reliable") #I'm doing this to synchronize the RNG variables on late joining clients
func syncRNG(RNG1State, RNG2State, RNG1Seed, RNG2Seed):
	RNG1.seed = RNG1Seed
	RNG2.seed = RNG2Seed
	RNG1.state = RNG1State
	RNG2.state = RNG2State

var time_accumulator: float = 0.0
var fire_interval: float = 0.0025 # Total time between individual puffs
var ammo_sub_counter: float = 0.0 # To handle "fractional" ammo

func _physics_process(delta: float) -> void:
	if trigger_pulled and !new_equipped and !is_reloading and ammo > 0:
		is_firing = true
		UpdateAnimations()
		
		time_accumulator += delta
		
		# This loop runs exactly enough times to match the time passed
		while time_accumulator >= fire_interval:
			if ammo <= 0:
				break
			
			# 1. Spawn the particle
			spawn_flame_puff()
			
			# 2. Handle Ammo Drain
			# If 1 puff = 1 ammo, just do: ammo -= 1
			# If you want 8 puffs per 1 ammo, do:
			ammo_sub_counter += (1.0 / 16.0) 
			if ammo_sub_counter >= 1.0:
				ammo -= 1
				ammo_sub_counter -= 1.0
			
			time_accumulator -= fire_interval
	else:
		is_firing = false
		UpdateAnimations()
		# INSTEAD OF RESETTING TO 0:
		# Limit the accumulator so they can't "store up" a burst, 
		# but don't delete the progress toward the next shot.
		time_accumulator = min(time_accumulator, fire_interval)

func _process(delta: float) -> void:
	if weapon_mesh:
		_apply_weapon_bob_and_tilt(delta)
	UpdateAnimations()
	if !is_multiplayer_authority(): return
	if !currently_active: return
	
	trigger_pulled = Input.is_action_pressed("left_click") # Hold to shoot
	
	# 3. Check if the gun is ready to fire based on the timer
	#if trigger_pulled and fire_rate.is_stopped() and !new_equipped and !is_reloading:
		#is_firing = true
		#UpdateAnimations()
		#shoot()
	#else:
		#is_firing = false
		#UpdateAnimations()
	
	#if Input.is_action_just_pressed("reload"):
		#print("Pressed reload")
		#print(is_reloading)
		#print(new_equipped)
		#print(ammo)
		#print(max_ammo)
	
	if Input.is_action_just_pressed("reload") and !is_reloading and !new_equipped and ammo < max_ammo and !trigger_pulled: #Not letting them reload while shooting, to avoid fat fingers
		reload()

func reload():
	is_reloading = true
	UpdateAnimations()

func reload_ammo():
	ammo = max_ammo

func finish_reload_anim():
	is_reloading = false
	UpdateAnimations()

func shoot():
	fire_rate.start()
	print("Merc shot!")
	for i in range(6):
		spawn_flame_puff()
	ammo = ammo - 1

var puff_count: int = 0 #For counting how many particles are being spawned for sync.
func spawn_flame_puff():
	puff_count += 1
	var puff = FT_PARTICLE.instantiate()
	
	puff.ParticleDamage = damage
	# 1. Start at the nozzle
	puff.set_multiplayer_authority(self.get_multiplayer_authority())
	var puffname = "FT_Particle_" + str(self.get_multiplayer_authority()) + "_" + str(puff_count)
	puff.name = puffname
	get_tree().root.add_child(puff) # Spawn in world root
	puff.global_position = barrel_exit.global_position
	puff.ParticleDamage = damage
	# 2. Calculate Muzzle Velocity (The "Push" from the gun)
	var forward = barrel_exit.global_transform.basis.x
	var up = barrel_exit.global_transform.basis.y      # Your local Up
	var z_axis = barrel_exit.global_transform.basis.z  # Your local Side
	
	var spread_amount = 0.35
	var spread_v = up * RNG1.randf_range(-spread_amount, spread_amount)
	var spread_h = z_axis * RNG1.randf_range(-spread_amount, spread_amount)
	var direction = (forward + spread_v + spread_h).normalized()
	var muzzle_velocity = direction * 12.0
	
	# 3. INHERIT Player Velocity
	# 'arson' is your CharacterBody3D player
	var inherited_velocity = merc.velocity 
	
	# 4. Combine them
	var final_velocity = muzzle_velocity + (inherited_velocity)
	
	# 5. Send it to the puff script
	puff.velocity = final_velocity
	#print("I'm the owner: " + puff.name)
	rpc("spawn_rpc_flame_puffs", barrel_exit.global_position, final_velocity, self.get_multiplayer_authority(), puffname)

@rpc("any_peer", "reliable")
func spawn_rpc_flame_puffs(starting_pos, velocity, ID, nametoset):
	var puff = FT_PARTICLE.instantiate()
	puff.set_multiplayer_authority(ID)
	puff.name = nametoset
	get_tree().root.add_child(puff)
	#puff.global_position = starting_pos
	puff.global_position = barrel_exit.global_position
	puff.velocity = velocity
	#print("I'm the others: " + puff.name)

func spawn_flame_dmgbox():
	var puff = FT_PARTICLE.instantiate()
	
	# 1. Start at the nozzle
	if get_tree():
		get_tree().root.add_child(puff) # Spawn in world root
		puff.global_position = barrel_exit.global_position
	
	# 2. Calculate Muzzle Velocity (The "Push" from the gun)
	#var forward = -PlayerCamera.global_transform.basis.z
	var forward = barrel_exit.global_transform.basis.x
	var spread_x = RNG2.randf_range(-0.35, 0.35)
	var spread_y = RNG2.randf_range(-0.35, 0.35)
	var muzzle_velocity = (forward + Vector3(spread_x, spread_y, 0)).normalized() * 12.0
	
	# 3. INHERIT Player Velocity
	# 'arson' is your CharacterBody3D player
	var inherited_velocity = merc.velocity 
	
	# 4. Combine them
	var final_velocity = muzzle_velocity + inherited_velocity
	
	# 5. Send it to the puff script
	puff.velocity = final_velocity

func UpdateAnimations():
	animation_tree.set("parameters/conditions/is_firing", is_firing)
	animation_tree.set("parameters/conditions/not_firing", !is_firing)
	animation_tree.set("parameters/conditions/is_reloading", is_reloading)
	animation_tree.set("parameters/conditions/not_reloading", !is_reloading)
	animation_tree.set("parameters/conditions/new_equipped", new_equipped)

func equip():
	show()
	is_shooting = false
	is_reloading = false
	is_firing = false
	new_equipped = true
	UpdateAnimations()
	show_self.rpc(true) #tell all clients to update

func finish_equip():
	new_equipped = false
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
	hide()
	new_equipped = false
	UpdateAnimations()
	show_self.rpc(false)

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
