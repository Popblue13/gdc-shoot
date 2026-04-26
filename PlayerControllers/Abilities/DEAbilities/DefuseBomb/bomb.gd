extends WeaponAbility
class_name DEBOMB

var max_time_to_plant : float = 2.5 
var time_to_plant : float = 1.0

@onready var plant_raycast: RayCast3D = $PlantRaycast
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hologram_mesh: Marker3D = $HologramMesh

var planted : bool = false
var defuse_gamemode : DE

func _ready() -> void:
	max_time_to_plant = animation_player.get_animation("plant").length
	time_to_plant = max_time_to_plant

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	if !currently_active: return
	#if !defuse_gamemode: return
	if planted: return
	
	# --- RIGHT CLICK TO DROP ---
	if Input.is_action_just_pressed("right_click"): # Make sure this action is in your Input Map!
		merc.request_drop_single_ability.rpc_id(1, get_path())
		return
	
	if merc and merc.camera:
		global_transform = merc.camera.global_transform
		
	var surface_point : Vector3 = Vector3.ZERO
	var surface_normal : Vector3 = Vector3.ZERO
	
	if plant_raycast.is_colliding():
		surface_point = plant_raycast.get_collision_point()
		surface_normal = plant_raycast.get_collision_normal()
		hologram_mesh.show()
		
		var align_quat = Quaternion(Vector3.UP, surface_normal)
		hologram_mesh.global_basis = Basis(align_quat)
		hologram_mesh.global_position = surface_point
	else: 
		hologram_mesh.hide()
	
	if Input.is_action_pressed("left_click") and surface_point != Vector3.ZERO:
		if surface_normal.dot(Vector3.UP) > 0.8:
			if animation_player.current_animation != 'plant':
				animation_player.play('plant')
				
			time_to_plant -= delta
			if time_to_plant <= 0.0:
				# Tell the server to handle the actual planting!
				_request_plant_bomb.rpc_id(1, surface_point, surface_normal)
		else:
			reset_plant_state()
	else:
		reset_plant_state()

func reset_plant_state():
	animation_player.stop()
	if animation_player.current_animation != 'idle':
		animation_player.play("idle")
	time_to_plant = max_time_to_plant
	
func shoot(): 
	pass

func equip():
	if planted: return
	animation_player.play("equip")
	if merc:
		var merc_parent = merc.get_parent()
		if merc_parent is DE:
			defuse_gamemode = merc_parent

func dequip():
	if planted: return
	animation_player.play("dequip")

# This is called purely on the Server now
@rpc("any_peer", "call_local", "reliable")
func _request_plant_bomb(plant_spot: Vector3, surface_normal: Vector3):
	if not multiplayer.is_server(): return
	if planted: return
	
	planted = true
	
	# 1. Ask the Gamemode to spawn the REAL bomb into the world
	if defuse_gamemode:
		var planter_id = multiplayer.get_remote_sender_id()
		defuse_gamemode.spawn_real_bomb(planter_id, plant_spot, surface_normal)
		
	# 2. Delete this visual hand-bomb from the player's inventory completely!
	merc.remove_ability(self)
