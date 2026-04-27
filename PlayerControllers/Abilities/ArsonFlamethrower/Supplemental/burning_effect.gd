extends Node3D
class_name BurnEffect

@export var AfterburnDuration: float = 1.0
@export var AfterburnMultCap: float = 5.0
@export var damage_per_tick: float = 1.0
@export var tick_rate: float = 1.0
@export var duration: float = 5.0
var duration_timer = Timer.new()
var tick_timer = Timer.new()
var particle_timer = Timer.new()
const ON_FIRE_PARTICLE_EFFECT = preload("res://PlayerControllers/Abilities/ArsonFlamethrower/Supplemental/OnFireParticleEffect.tscn")

var target

func _ready():
	target = get_parent() # Assuming it's added as a child of the Player
	
	#Timer for the dmg (every second)
	add_child(tick_timer)
	tick_timer.wait_time = tick_rate
	tick_timer.timeout.connect(_on_tick)
	tick_timer.start()
	
	#Timer for the removal of the effect
	add_child(duration_timer)
	duration_timer.wait_time = duration
	duration_timer.timeout.connect(_timer_done)
	duration_timer.start()
	
	#Timer for the particles heheheha
	add_child(particle_timer)
	particle_timer.wait_time = 0.2
	particle_timer.timeout.connect(particleTimer)
	particle_timer.start()

func _on_tick():
	if target and target.has_method("take_damage"):
		#print("My target is: " + str(target))
		if is_multiplayer_authority():
			#print("Mult Auth!")
			#print(damage_per_tick*AfterburnDuration)
			target.take_damage.rpc_id(target.get_multiplayer_authority(), damage_per_tick*AfterburnDuration)
			#target.take_damage(damage_per_tick*AfterburnDuration)

func renewBurn():
	AfterburnDuration = AfterburnDuration + 0.002
	if AfterburnDuration > AfterburnMultCap:
		AfterburnDuration = AfterburnMultCap
	particle_timer.wait_time = (0.2/AfterburnDuration) # 1 / 10 = 0.1, which is default.
	duration_timer.start() # we restarting the afterburn duration and increasing its damage by a small amount.

func renewBurnBetter(AddedBurn, NewCap):
	if NewCap > AfterburnMultCap:
		AfterburnMultCap = NewCap
	AfterburnDuration = AfterburnDuration + AddedBurn
	if AfterburnDuration > AfterburnMultCap:
		AfterburnDuration = AfterburnMultCap
	particle_timer.wait_time = (0.2/AfterburnDuration)
	duration_timer.start() # we restarting the afterburn duration and increasing its damage by a small amount.

func _timer_done():
	if is_multiplayer_authority():
		rpc("despawnMyself")
		despawnMyself()

@rpc("any_peer", "reliable")
func despawnMyself():
	queue_free()

func particleTimer():
	spawn_fire_on_body()

## Spawns fire around the parent (the player)
func spawn_fire_on_body():
	# 1. Get the player's position
	var center = get_parent().global_position
	
	# 2. Randomly pick a spot in a 'cylinder' around them
	var radius = 0.4  # Slightly wider than the player
	var height = 1.8  # About the height of a character
	
	var angle = randf() * TAU
	var dist = randf() * radius
	
	# Calculate local X and Z
	var x = cos(angle) * dist
	var z = sin(angle) * dist
	# Random height from feet (0) to head (1.8)
	var y = randf() * height
	
	var spawn_pos = center + Vector3(x, y, z)
	
	# 3. Spawn the puff
	var puff = ON_FIRE_PARTICLE_EFFECT.instantiate()
	get_tree().root.add_child(puff)
	puff.global_position = spawn_pos
	puff.animated_sprite_3d.play("default")
	
	# 4. TF2 Style: Make the fire drift slightly upward
	puff.velocity = Vector3(randf_range(-0.5, 0.5), 2.0, randf_range(-0.5, 0.5))
