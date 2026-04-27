@tool
extends Node3D

@export_group("Settings")
@export var anim_player: AnimationPlayer
@export var anim_name: String = ""
@export var noise_resource: FastNoiseLite

@export_group("Mode Selection")
## If true, bakes to Position. If false, bakes to Rotation.
@export var use_position_mode: bool = false 

@export_group("Initial Transform")
@export var initial_position: Vector3 = Vector3.ZERO
@export var initial_rotation: Vector3 = Vector3.ZERO

@export_group("Intensity")
@export var jitter_speed: float = 200.0
@export var strength_x: float = 0.1
@export var strength_y: float = 0.1
@export var strength_z: float = 0.1

@export_group("Position Kick (Optional)")
@export var add_position_noise: bool = false
@export var pos_strength: float = 0.05

@export_group("Actions")
@export var CLICK_TO_BAKE: bool = false : set = _button_pressed

func _button_pressed(_val):
	CLICK_TO_BAKE = false 
	if not _is_ready(): return
	
	var anim: Animation = anim_player.get_animation(anim_name)
	var ap_root = anim_player.get_node(anim_player.root_node)
	var node_path = ap_root.get_path_to(self)
	
	# --- Determine Target Track ---
	var track_path = ""
	if use_position_mode:
		track_path = str(node_path) + ":position"
	else:
		track_path = str(node_path) + ":rotation"
		
	var track_idx = _get_or_create_track(anim, track_path)
	
	var fps = 60.0 
	var step = 1.0 / fps
	
	for i in range(int(anim.length * fps) + 1):
		var time = i * step
		if time > anim.length: time = anim.length
		
		var nx = noise_resource.get_noise_1d(time * jitter_speed)
		var ny = noise_resource.get_noise_1d((time + 100.0) * jitter_speed)
		var nz = noise_resource.get_noise_1d((time + 200.0) * jitter_speed)
		
		# This vector now uses your strength_x, y, and z for both modes
		var noise_vec = Vector3(nx * strength_x, ny * strength_y, nz * strength_z)
		
		if use_position_mode:
			# Strength values now directly affect the positional shift here
			anim.track_insert_key(track_idx, time, initial_position + noise_vec)
		else:
			# Strength values affect the rotation
			anim.track_insert_key(track_idx, time, initial_rotation + noise_vec)
		
		# Secondary position kick (Legacy from your original code)
		if add_position_noise and not use_position_mode:
			var pos_path = str(node_path) + ":position"
			var pos_idx = _get_or_create_track(anim, pos_path)
			anim.track_insert_key(pos_idx, time, initial_position + Vector3(nx * pos_strength, ny * pos_strength, nz * pos_strength))
	
	print("SUCCESS: Baked into node: ", node_path)

func _get_or_create_track(anim: Animation, path: String) -> int:
	var idx = anim.find_track(path, Animation.TYPE_VALUE)
	if idx == -1:
		idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(idx, path)
	return idx

func _is_ready() -> bool:
	if not anim_player: 
		return false
	if not anim_player.has_animation(anim_name):
		return false
	if not noise_resource:
		return false
	return true
