extends Node3D

const FIRE_POINT = preload("res://PlayerControllers/Abilities/ArsonIncendiary/Supplemental/FirePoint.tscn")
@export var spacing: float = 1.5  # Distance between centers of fire points
@export var max_points: int = 15
@export var molotov_duration: float = 8.0
var all_points = [] # Keep a list of spawned nodes

var spawned_positions = [] # To keep track of "tiles" occupied
var spawn_queue = []       # Points waiting to grow neighbors

var point_count = 0

func _ready():
	#if !is_multiplayer_authority(): return
	# Start the first fire at impact point
	await get_tree().create_timer(0.05).timeout
	spawn_at_pos(global_position)
	# Start the "Self-Destruct" timer the moment it breaks
	get_tree().create_timer(molotov_duration).timeout.connect(start_cleanup)

func spawn_at_pos(pos: Vector3):
	# 1. Round the position to a grid to prevent tiny overlaps
	point_count += 1
	var grid_pos = Vector3(
		round(pos.x / spacing) * spacing,
		pos.y,
		round(pos.z / spacing) * spacing
	)
	
	# 2. Don't spawn if we already have fire here
	if grid_pos in spawned_positions:
		print("fire already here nuhuh")
		return
	
	# 3. Raycast down to find the floor
	var floor_pos = check_floor(grid_pos)
	if floor_pos == Vector3.ZERO:
		print("floor not found")
		return # No floor found
	
	# 4. Spawn the fire point
	var newname = (str(get_multiplayer_authority()) + "_" + str(point_count))
	SyncSpawn(floor_pos, newname)
	#SyncSpawn.rpc(floor_pos, newname)
	
	spawned_positions.append(grid_pos)
	spawn_queue.append(grid_pos)
	
	# 5. Spread to neighbors after a short delay
	if spawned_positions.size() < max_points:
		await get_tree().create_timer(0.1).timeout
		spread_from(grid_pos)

#@rpc("any_peer", "call_local", "reliable")
func SyncSpawn(pos, newname):
	print("spawning fire!")
	var f = FIRE_POINT.instantiate()
	f.set_multiplayer_authority(self.get_multiplayer_authority())
	get_parent().add_child(f)
	f.global_position = pos
	f.name = newname
	all_points.append(f)

func spread_from(origin: Vector3):
	# Define the 4 directions (Cross shape)
	# For a tighter fit, you could use 6 directions for a Hex grid
	var directions = [
		Vector3(spacing, 0, 0),
		Vector3(-spacing, 0, 0),
		Vector3(0, 0, spacing),
		Vector3(0, 0, -spacing)
	]
	
	directions.shuffle() # Makes the growth look organic/random
	
	for dir in directions:
		if spawned_positions.size() >= max_points: break
		
		var target = origin + dir
		# Check if there is a wall between origin and target
		if not is_wall_blocking(origin, target):
			spawn_at_pos(target)

func check_floor(pos: Vector3) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1, 0), pos + Vector3(0, -2, 0))
	# --- BITMASK LOGIC ---
	# We start with a mask that hits EVERYTHING (all 32 bits on)
	var full_mask = 0xFFFFFFFF 
	# Then we subtract the value of Layer 27 (2 to the power of 26)
	# This tells the ray: "Look at every layer EXCEPT 27"
	query.collision_mask = full_mask ^ (1 << (27 - 1))
	var result = space_state.intersect_ray(query)
	return result.position if result else Vector3.ZERO

func is_wall_blocking(origin: Vector3, target: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	# Raycast from origin to target at "knee height" to detect walls
	var query = PhysicsRayQueryParameters3D.create(origin + Vector3(0, 0.5, 0), target + Vector3(0, 0.5, 0))
	return space_state.intersect_ray(query).size() > 0

func start_cleanup():
	# 1. Stop any new spawning
	max_points = 0 
	
	# 2. Tell every spawned fire point to fade out
	for point in all_points:
		if is_instance_valid(point):
			# Add a tiny random delay so they don't all vanish at the exact same frame
			get_tree().create_timer(randf() * 0.5).timeout.connect(point.fade_out_and_die)
	
	# 3. Finally, delete the Master manager once the points are gone
	await get_tree().create_timer(3.0).timeout
	queue_free()
