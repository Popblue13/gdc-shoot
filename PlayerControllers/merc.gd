class_name Merc extends CharacterBody3D

signal died(_self, killer_id: int) #Server will disable input on character
## @deprecated: Use `health_changed` and look for when `new < old`
signal took_damage
signal kill_confirmed(person_killed_id : int)
signal health_changed(old: float, new: float)

# Debug test environment import
const TEST_ENVIRONMENT := preload("res://MapsAndGamemodes/Maps/TestEnvironment/TestEnvironment.tscn")

## THIS THE BASE CLASS, DO NOT CHANGE AN OF THIS UNLESS ITS IN THE INSPECTOR
const ABILITY_UI = preload("res://Misc/UI/ability_ui.tscn")
const MERC_LABEL = preload("res://MultiplayerStuff/Client/MercLabel.tscn")
const HEALTH_BAR = preload("res://Misc/UI/health_bar.tscn")
const FOOTSTEPS = preload("res://PlayerControllers/Abilities/Footsteps/footsteps.tscn")

var health_bar: ProgressBar

@export var debug_mode : bool = false
@export_category("REQUIRED CAMERA")
@export var camera: Camera3D

@export_group("Universal Properties")
@export var health :float = 100.0:
	set(value):
		if health_bar: health_bar.health = clamp(value, 0, max_health)
		if value != health:
			var old := health
			health = value
			health_changed.emit(old, health)
		
		# TODO: Figure out if this is necessary. I included it just to make sure I'm 
		# not breaking anyone else's stuff just in case they rely on this behavior 
		# (they really shouldn't) - Connor
		else: health = value

@export var gravity: float = 9.8
@export var friction: float = .1
@export var wall_friction_enabled: bool = false
@export var air_acceleration: float = .3
@export var speed: float = 1.0
@export var visual_body: Node3D
@export var visual_hand: Node3D
@export var merc_UI_color: Color
@export var camera_fov: float = 90.0

			#and more implicitones
			#ex. position
			#scale
			#velocity
			#is_on_floor()


@export var abilities : Array[Ability]
#reminder abilities  can have their own ui

var abilites_ui: AbilitiesUI
var ability_spawner: MultiplayerSpawner
var name_label_instance
var target_position: Vector3 #what other people see
var target_rotation: Vector3

var mouse_sensitivity: float = 0.005
var can_move: bool = true
var dead: bool = false
var ability_ui 
var max_health: float

var team: String = "default":
	set(value):
		team = value
		# Automatically update the color whenever the team changes
		if name_label_instance and TEAM_COLORS.has(team):
			name_label_instance.modulate = TEAM_COLORS[team]
var player_teams: Dictionary = {}


const TEAM_COLORS = {
	"default": Color.WHITE,
	"red": Color.RED,
	"blue": Color.BLUE
}

func _enter_tree() -> void:
	ability_spawner = MultiplayerSpawner.new()
	ability_spawner.name = "AbilitySpawner"
	
	# 1. Add it to the tree FIRST
	add_child(ability_spawner)
	
	# 2. THEN set the spawn path using a relative path (".." means the parent, which is self)
	ability_spawner.spawn_path = ".."
	
	# 3. Tell the spawner to use the custom function
	ability_spawner.spawn_function = _spawn_ability
	
func _ready() -> void:
	initiate_abilities() #HACK
	max_health = health
	set_collision_layer_value(2, true)
	
	var footsteps = FOOTSTEPS.instantiate()
	add_child(footsteps)
	
	# ==========================================
	# DEBUG MODE SETUP
	# ==========================================
	if debug_mode:
		# 1. Create a dummy server so RPCs and Authority work locally
		var peer = ENetMultiplayerPeer.new()
		peer.create_server(9999) # Arbitrary port
		multiplayer.multiplayer_peer = peer
		
		# Force name to 1 (Server ID) so label and damage logic work
		name = "1"
		set_multiplayer_authority(1)
		
		var debug_environment : = TEST_ENVIRONMENT.instantiate()
		add_child(debug_environment)
		debug_environment.top_level = true
		
		print("--- DEBUG MODE ACTIVE: Local Server & Floor Generated ---")
	
	# ==========================================
	# STANDARD SETUP
	# ==========================================
	target_position = global_position
	target_rotation = global_rotation
	
	_setup_synchronizer()
	
	name_label_instance = MERC_LABEL.instantiate()
	add_child(name_label_instance)
	
	name_label_instance.position = Vector3(0, 1.6, 0) 
	
	var parent_gamemode = get_parent()
	if parent_gamemode and "master_team_database" in parent_gamemode:
		sync_team_database(parent_gamemode.master_team_database)
	# Pass the player's network ID into the label so it knows whose name to grab
	name_label_instance.setup(name.to_int())
	if TEAM_COLORS.has(team):
		name_label_instance.modulate = TEAM_COLORS[team]
	
	if is_multiplayer_authority():
		var map = get_parent()
		if map is Map and camera and map.environment != null:
			camera.environment = map.environment
		
		
		camera.make_current()
		if camera: camera.fov = camera_fov
		get_tree().physics_frame.connect(check_abilities)
		custom_ready()
		abilites_ui = ABILITY_UI.instantiate()
		add_child(abilites_ui)
		abilites_ui.generate_ui(self)
		health_bar = HEALTH_BAR.instantiate()
		add_child(health_bar)
		health_bar.health = health
		health_bar.max_value = health
		
		if visual_body:
			visual_body.hide()
		if visual_hand:
			visual_hand.hide()
		
		show_visual_body_to_world.rpc()
		name_label_instance.hide() #hide it local
		
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func initiate_abilities():
	for i in abilities:
		if i == null: continue
		i.merc = self
		i.abilities = abilities

@rpc("any_peer","call_remote","reliable")
func show_visual_body_to_world():
	if visual_body:
		visual_body.show()
	if visual_hand:
		visual_hand.show()

func _setup_synchronizer() -> void:
	var synchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MercSynchronizer" # Naming it helps prevent pathing desyncs
	
	var config = SceneReplicationConfig.new()
	
	# --- ON CHANGE PROPERTIES (Zero Bandwidth Cost unless modified) ---
	var static_props = [":health", ":gravity", ":friction", ":air_acceleration", ":speed", ":team"]
	for prop in static_props:
		var path = NodePath(prop)
		config.add_property(path)
		# Only send a packet if the value actually changes
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	
	synchronizer.replication_config = config
	add_child(synchronizer)


#handling knockback. i wish i could stuff it at the bottom :(
#use this by rpc id'ing it, just like applying damage.
var knockback_dir : Vector3 = Vector3(0,0,0)
var knockback_pwr := 0
var knockback_decay := 0.3

@rpc("any_peer", "call_remote", "reliable")
func apply_knockback(vec:Vector3, power:float, decay:float):
	knockback_dir = vec
	knockback_pwr = power
	knockback_decay = decay

@rpc("any_peer", "call_remote", "reliable")
func disable_movement(time_to_unfreeze : float = 0):
	can_move = false
	if time_to_unfreeze > 0:
		var tween = create_tween()
		tween.tween_interval(time_to_unfreeze)
		await tween.finished
		enable_movement()

@rpc("any_peer", "call_remote", "reliable")
func enable_movement():
	can_move = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): 
		# --- THE LERPING MAGIC ---
		# 15 is the "lerp speed". Higher = snappier, Lower = smoother but delayed.
		var lerp_speed = 15.0 * delta
		
		# Smoothly slide the position
		global_position = global_position.lerp(target_position, lerp_speed)
		
		# Smoothly rotate. We use lerp_angle instead of normal lerp!
		# Normal lerp will cause a crazy "spin of death" when going from 359 degrees back to 0.
		global_rotation.x = lerp_angle(global_rotation.x, target_rotation.x, lerp_speed)
		global_rotation.y = lerp_angle(global_rotation.y, target_rotation.y, lerp_speed)
		global_rotation.z = lerp_angle(global_rotation.z, target_rotation.z, lerp_speed)
		
		if health_bar: health_bar.hide()
		return # Skip all the local movement code below
	
	if dead: return
	
	
	var input = Vector2.ZERO
	
	if ClientUI.chat_input.text == "" and can_move:
		input.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		input.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	
	input = input.normalized()
	
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y) * speed
	
	if is_on_floor():
		var current_friction: Vector2 = Vector2(velocity.x, velocity.z).rotated(PI) * friction
		var friction_dir = transform.basis * Vector3(current_friction.x, 0, current_friction.y)
		velocity += Vector3(current_friction.x, 0, current_friction.y)
		velocity += Vector3(movement_dir.x, 0, movement_dir.z)
		
		velocity += (knockback_dir*knockback_pwr)
		
	else:
		if is_on_wall() && wall_friction_enabled == true: 
			velocity = velocity.lerp(Vector3.ZERO, delta * 5) 
		sv_airaccelerate(movement_dir, delta)
	
	knockback_pwr *= knockback_decay

	velocity.y -= gravity * delta
	custom_process(delta)
	move_and_slide()
	if is_multiplayer_authority():
		receive_pos_from_server.rpc(global_position, global_rotation)
	
	if global_position.y < -1000:
		dead = true
		death_effects.rpc()
		die.rpc_id(1)

func sv_airaccelerate(movement_dir, delta):
	var air_strength = 3
	movement_dir = movement_dir * air_strength
	var wish_speed = movement_dir.length()
	
	if wish_speed > 1:
		wish_speed = 1
	
	var current_speed = velocity.dot(movement_dir)
	var add_speed = wish_speed - current_speed
	if add_speed <= 0:
		return
	
	var accel_speed = 10 * 10 * delta
	if accel_speed > add_speed:
		accel_speed = add_speed
	
	velocity += accel_speed * movement_dir

func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority(): return
	if !ClientUI: return
	if ClientUI.menu.visible: return
	if dead: return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

#merc
func check_abilities() -> void:
	if abilities.size() <= 0: return
	for i in abilities:
		if i == null: continue
		if !i.is_multiplayer_authority():
			i.set_multiplayer_authority(int(name), true)
		if i.abilities !=abilities: i.abilities = abilities
		if i.merc != self: i.merc = self
		
		if i.trigger_key != 'None':
			# Convert key to the integer keycode (e.g. Q -> 81)
			var key_code = OS.find_keycode_from_string(i.trigger_key)
			
			# Finally, check the hardware state
			if Input.is_physical_key_pressed(key_code):
				i.activate()

# ==========================================
# ABILITY MANAGEMENT (SERVER ONLY)
# ==========================================

func add_ability(scene_path: String) -> void:
	if not multiplayer.is_server(): return
	
	# The spawner sends the string to all current AND future clients
	ability_spawner.spawn(scene_path)

func _spawn_ability(data: Variant) -> Node: #<SPAWN FUNCTION>
	var scene_path = data as String
	var ability_resource = load(scene_path) as PackedScene
	if not ability_resource: return null
	
	var new_ability = ability_resource.instantiate() as Ability
	
	# Ensure network authority matches the player holding it
	new_ability.set_multiplayer_authority(get_multiplayer_authority())
	
	# We must defer the setup logic until Godot finishes adding it to the tree
	new_ability.ready.connect(_on_ability_spawned.bind(new_ability))
	
	return new_ability

func _on_ability_spawned(new_ability: Ability) -> void:
	# 1. Link references
	new_ability.merc = self
	new_ability.abilities = abilities
	
	# 2. Resolve keybinds and array tracking
	if not abilities.has(new_ability):
		abilities.append(new_ability)
		
	new_ability.equip_ability(abilities)
	
	# 3. Handle visibility
	new_ability.show()
	for child in new_ability.get_children():
		if child is Node3D:
			child.show()
			
	# 4. Refresh local UI
	if abilites_ui and abilites_ui.has_method("generate_ui"):
		abilites_ui.generate_ui(self)
		
	new_ability.activate()

# Keep your remove logic relatively the same, just update the array cleanup
func remove_ability(ability: Ability) -> void:

	if not multiplayer.is_server(): return

	_sync_remove_ability.rpc(ability.get_path())

@rpc("any_peer", "call_local", "reliable")
func _sync_remove_ability(ability_path: NodePath) -> void:
	
	var ability_node = get_node_or_null(ability_path)
	if not ability_node: return
	
	if abilities.has(ability_node):
		abilities.erase(ability_node)
		ability_node.dequip_ability()
		
		if abilites_ui and abilites_ui.has_method("generate_ui"):
			abilites_ui.generate_ui(self)
		
		# Actually delete the node so the spawner registers it as gone
		if multiplayer.is_server():
			ability_node.queue_free()
		
	

# ==========================================
# ABILITY DROPPING (SERVER ONLY)
# ==========================================

func drop_ability(ability: Ability) -> void:
	if not multiplayer.is_server(): return
	if not is_instance_valid(ability): return
	
	# 1. Grab the resource path before we delete the ability
	var ability_path_to_drop = ability.scene_file_path 
	
	# 2. Calculate a safe drop position (slightly above the player's feet)
	var drop_pos = global_position + Vector3(0, 1.0, 0) 
	
	# 3. Tell the Map to spawn the physical orb in the world
	var current_map = get_parent()
	if current_map and current_map.has_method("spawn_dropped_orb"):
		current_map.spawn_dropped_orb(ability_path_to_drop, drop_pos)
		
	# 4. Strip the ability from the player using the function we already wrote
	remove_ability(ability)

# When the player dies, tell the server to dump everything
@rpc("any_peer", "call_local", "reliable")
func _request_drop_inventory() -> void:
	if not multiplayer.is_server(): return
	
	# Iterate backwards when removing things from an array to avoid skipping indices!
	for i in range(abilities.size() - 1, -1, -1):
		var ability = abilities[i]
		if is_instance_valid(ability):
			drop_ability(ability)

@rpc("any_peer", "call_local", "reliable")
func request_drop_single_ability(ability_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	
	var ability_to_drop = get_node_or_null(ability_path)
	if ability_to_drop and abilities.has(ability_to_drop):
		drop_ability(ability_to_drop)

# ==========================================
# TEAM FIGHTING STUFF
# ==========================================

func sync_team_database(new_database: Dictionary) -> void:
	player_teams = new_database
	
	# Update our own team based on our multiplayer ID (Node name)
	var my_id = name.to_int()
	if player_teams.has(my_id):
		team = player_teams[my_id]
		
		# Update the UI color
		if name_label_instance and TEAM_COLORS.has(team):
			name_label_instance.modulate = TEAM_COLORS[team]

@rpc("any_peer", "call_remote", "unreliable")
func receive_pos_from_server(pos: Vector3, rot: Vector3):
	# Don't move them yet! Just update the target.
	target_position = pos
	target_rotation = rot

@rpc("any_peer", "call_remote", "reliable")
func take_damage(damage: float):
	if !is_multiplayer_authority(): return
	var attacker_id = multiplayer.get_remote_sender_id()
	# 2. Check the local database for their team
	if player_teams.has(attacker_id):
		var attacker_team = player_teams[attacker_id]
		
		# 3. Filter friendly fire
		if attacker_team == team and team != "default":
			return # Block the damage!
			
	# Apply damage if they pass the check
	health -= damage
	
	# TELL EVERYONE TO FLASH THIS PLAYER YELLOW
	_sync_flash_damage.rpc() 
	if health <= 0 and not dead and is_multiplayer_authority():
		dead = true
		death_effects.rpc()
		die.rpc_id(1, attacker_id)
	else:
		emit_signal("took_damage")


@rpc("authority", "call_local", "unreliable")
func _sync_flash_damage() -> void:
	if not visual_body: return
	
	# 1. Create a semi-transparent yellow material
	var flash_mat = StandardMaterial3D.new()
	# The 4th number (0.4) is the alpha/opacity. 0.0 is invisible, 1.0 is solid.
	flash_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.4) 
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA # Required for opacity to work
	
	# 2. Iterate through every single child inside the visual body
	_apply_overlay_recursive(visual_body, flash_mat)
	
	# 3. Wait for the flash duration
	var tween = create_tween()
	tween.tween_interval(.15)
	await tween.finished
	
	#if not visual_body: return
	# 4. Strip the overlay off everything
	if is_instance_valid(visual_body):
		_apply_overlay_recursive(visual_body, null)

# --- The Recursive Search Function ---
func _apply_overlay_recursive(current_node: Node, mat: Material) -> void:
	# If the node can be rendered in 3D, apply the overlay
	if current_node is GeometryInstance3D:
		current_node.material_overlay = mat
		
	# Recursively call this exact function on all children of the current node
	for child in current_node.get_children():
		_apply_overlay_recursive(child, mat)

@rpc("any_peer", "call_local")
func death_effects():
	pass

@rpc("authority", "call_remote", "reliable")
func die(killer_id: int = 0):
	emit_signal("died", self, killer_id)

#emits when you kill a player
@rpc("any_peer","call_remote","reliable")
func notify_kill_confirmed(id : int = 0): 
	#was not working because players had the authority`
	kill_confirmed.emit(id)

func custom_process(delta : float):
	pass #use this for addons, physics process is used for default movement
func custom_ready():
	pass
