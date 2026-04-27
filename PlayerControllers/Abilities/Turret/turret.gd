extends DestructibleProp

@export var damage = 10

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var dada : Merc
var targets := []

func hit_effect(damage):
	print("ouchies")

func destory_effect():
	get_parent().bandages +=1

@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: float):
	dada.turret_take_damage(name, damage)

@rpc("any_peer", "call_local", "reliable")
func take_real_damage(damage):
	print(multiplayer.get_unique_id())
	health -= damage
	if health <= 0 and not dead:
		dead = true
		destroy_prop.rpc()

func _physics_process(delta):
	if is_in_group("insmoke"):return
	if targets.size() > 0 and !is_in_group("insmoke"):
		if !is_instance_valid(targets[0]):
			targets.erase(0)
		if !test_cast(targets[0]) and !$LockonTimer.is_stopped():
			return
		var rotation_speed = 5.0
		
		# Calculate target Y rotation
		var target_pos = targets[0].global_position
		var direction = (target_pos - global_position).normalized()
		var target_angle = atan2(direction.x, direction.z)
		# Smoothly interpolate rotation_y
		$turret.rotation.y = rotate_toward($turret.rotation.y, target_angle, rotation_speed * delta)
		
		if $ShootTimer.is_stopped():
			print("shoot")
			shoot()

func shoot():
	$ShootTimer.start()
	$turret/turrethead/AudioStreamPlayer3D.play()
	$turret/turrethead/AudioStreamPlayer3D/OmniLight3D.visible = true
	await get_tree().create_timer(0.1).timeout
	$turret/turrethead/AudioStreamPlayer3D/OmniLight3D.visible = false
	$turret/turrethead/AudioStreamPlayer3D.pitch_scale = randf_range(0.9,1.1)
	var hit_target = $turret/turrethead/BulletCast.get_collider()
	if hit_target is Merc and !is_multiplayer_authority():
		hit_target.take_damage.rpc_id(hit_target.name.to_int(), damage)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Merc and body.team != dada.team and body != dada:
		$LockonTimer.start()
		$AudioStreamPlayer3D.play()
		targets.append(body)

func test_cast(body):
	$turret/turrethead/TestCast.target_position = to_local(body.global_position)
	if $turret/turrethead/TestCast.is_colliding():
		return true
	else:
		return false

func _on_area_3d_body_exited(body: Node3D) -> void:
	if targets.has(body):
		targets.erase(body)
