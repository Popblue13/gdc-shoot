extends WeaponAbility

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var bizarre_ball: RigidBody3D = $"Ball"
@onready var bizarre_ball_collision: CollisionShape3D = $"Ball/ExplosionDetection/CollisionShape3D"
@onready var black_hole: Node3D = $"Black Hole"
@onready var black_hole_collision: CollisionShape3D = $"Black Hole/Area3D/CollisionShape3D"
@onready var curious_crystal: RigidBody3D = $"Curious Crystal"
@onready var crystal_anim: AnimationPlayer = $"Curious Crystal/AnimationPlayer"
@onready var cpu_particles_3d: CPUParticles3D = $Ball/ExplosiveParticles
@onready var close_explosion: Area3D = $"Ball/CloseExplosion"
@onready var far_explosion: Area3D = $"Ball/FarExplosion"
@onready var hand: RemoteTransform3D = $Hand
@onready var explosion_timeout: Timer = $"Explosion Timeout"
@onready var spam_timeout: Timer = $"Spam Timeout"
@onready var crystal_timer: Timer = $"Crystal Timer"
@onready var crosshair: Sprite2D = $"Crosshair"

@export var cool_down := 0.1
@export var throw_strength = 37.0
## Please note that close_damage stacks with far_damage when hitting a target from close range.
@export var close_damage = 34.0
@export var far_damage = 13.0

@export_enum("grotesque_green", "remarkable_red", "peculiar_purple") var color := "grotesque_green"

var thrown : bool = false

var can_throw_again : bool = true

var moving_crystal : bool = false

@export var active_black_hole: bool = false

var last_ball_pos: Vector3 = Vector3.ZERO

func _ready():
	crystal_anim.play("spin")
	var target_folder = "res://PlayerControllers/Abilities/BizarreBall/" + color + "/"
	$"Curious Crystal/MeshInstance3D".mesh.material = load(target_folder + "curious_crystal.tres")
	$"Ball/MeshInstance3D".mesh.material.shader = load(target_folder + "glowing_ball.gdshader")
	$"Ball/PassiveParticles".mesh.material.shader = load(target_folder + "glowing_ball.gdshader")
	$"Ball/ExplosiveParticles".mesh.material.shader = load(target_folder + "glowing_ball.gdshader")
	$"Black Hole/PassiveParticles".mesh.material.shader = load(target_folder + "glowing_ball.gdshader")
	if color == "grotesque_green":
		crosshair.modulate = Color.LAWN_GREEN
	elif color == "peculiar_purple":
		crosshair.modulate = Color.PURPLE
	else:
		crosshair.modulate = Color.ORANGE_RED

func _process(_delta: float) -> void:
	last_ball_pos = bizarre_ball.global_position
	if !currently_active: return
	if merc and merc.camera:
		global_transform = merc.camera.global_transform
	if Input.is_action_just_pressed("left_click"):
		if thrown:
			explode.rpc()
		elif can_throw_again:
			shoot.rpc()
	if Input.is_action_just_pressed("right_click"):
		throw_crystal()
		#holding_about_to_throw = true
		#anim_player.play("hold_to_throw")
		#fuse_timer.start(fuse_time)
		
	#if Input.is_action_just_released("left_click") and holding_about_to_throw and !thrown:
		#holding_about_to_throw = false
		#thrown = true
		#shoot()

@rpc("any_peer", "call_local", "reliable")
func shoot():
	# Detach the grenade from the hand and throw it
	# anim_player.play("throw")
	# await anim_player.animation_finished
	spam_timeout.start()
	can_throw_again = false
	thrown = true
	hand.set_deferred("remote_path", null)
	bizarre_ball.freeze = false
	bizarre_ball.linear_velocity = Vector3.ZERO
	bizarre_ball.apply_central_impulse(-merc.camera.global_basis.z * throw_strength) 
	bizarre_ball_collision.set_deferred("disabled", false)
	explosion_timeout.start()

func equip():
	bizarre_ball.show()
	crosshair.show()
	
func dequip():
	crosshair.hide()

@rpc("any_peer", "call_local", "reliable")
func explode():
	# Only the authority should calculate and send damage
	if is_multiplayer_authority():
		for i in far_explosion.get_overlapping_bodies():
			if i != null and i != self and i is Merc and i != merc:
				i.take_damage.rpc_id(i.name.to_int(), far_damage)
		for i in close_explosion.get_overlapping_bodies():
			if i != null and i != self and i is Merc and i != merc:
				i.take_damage.rpc_id(i.name.to_int(), close_damage)
	
	# Everything below this runs locally for all clients (Visuals/Cleanup)
	if cpu_particles_3d:
		cpu_particles_3d.emitting = true
	
	bizarre_ball.set_deferred("freeze", true)
	
	#await cpu_particles_3d.finished
	reset_grenade()

func reset_grenade():
	
	#Kill leftover momentum so it doesn't fly off when un-frozen later
	bizarre_ball.linear_velocity = Vector3.ZERO
	bizarre_ball.angular_velocity = Vector3.ZERO
	
	bizarre_ball.global_transform = hand.global_transform
	
	#Re-link the RemoteTransform3D so the grenade follows the hand again
	hand.set_deferred("remote_path", hand.get_path_to(bizarre_ball))
	bizarre_ball_collision.set_deferred("disabled", true)
	bizarre_ball.show()
	thrown = false

func _on_explosion_detection_body_entered(body: Node3D) -> void:
	if body != null and body != merc:
		if body != null and body is Merc:
			# explode violenty
			explode.rpc()
		else:
			# make a portal
			spawn_black_hole(last_ball_pos)
			explode.rpc()
			#reset_grenade()

func spawn_black_hole(spawn_pos: Vector3):
	black_hole.global_position = spawn_pos
	black_hole.show()
	active_black_hole = true
	black_hole_collision.set_deferred("disabled", false)
	

func _on_timer_timeout() -> void:
	if thrown:
		explode.rpc()


func _on_spam_timeout_timeout() -> void:
	can_throw_again = true


func _on_area_3d_body_entered(body: Node3D) -> void:
	if active_black_hole and body != null and body is Merc:
		body.global_position = curious_crystal.global_position
		black_hole_collision.set_deferred("disabled", true)
		black_hole.hide()
		active_black_hole = false

func throw_crystal():
	curious_crystal.global_position = global_position + Vector3(0, 1, 0)
	crystal_timer.start()
	curious_crystal.freeze = false
	curious_crystal.linear_velocity = Vector3.ZERO
	curious_crystal.apply_central_impulse(-merc.camera.global_basis.z * throw_strength) 
	moving_crystal = true

func crystal_land():
	if moving_crystal:
		curious_crystal.linear_velocity = Vector3.ZERO
		curious_crystal.freeze = true
		moving_crystal = false

func _on_crystal_timer_timeout() -> void:
	crystal_land()
