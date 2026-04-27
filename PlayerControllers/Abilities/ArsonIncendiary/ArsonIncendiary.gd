extends WeaponAbility

@onready var hand: RemoteTransform3D = $Hand
@onready var grenade: RigidBody3D = $Grenade
@onready var fuse_timer: Timer = $FuseTimer
@onready var cpu_particles_3d: CPUParticles3D = $Grenade/CPUParticles3D
@onready var explosion_radius: Area3D = $Grenade/ExplosionRadius
@onready var anim_player: AnimationPlayer = $AnimationPlayer
const INCENDIARY_INSTANCE = preload("res://PlayerControllers/Abilities/ArsonIncendiary/Supplemental/IncendiaryInstance.tscn")

@export var cool_down := 5.0
#@export var fuse_time := 4.0
@export var throw_strength = 12.0
@export var damage = 70.0

var ammo = 2

var holding_about_to_throw : bool = false
var thrown : bool = false

func _ready() -> void:
	hide()

func _process(_delta: float) -> void:
	if !is_multiplayer_authority(): return
	if !currently_active: return
	if merc and merc.camera:
		global_transform = merc.camera.global_transform
	if Input.is_action_just_pressed("left_click") and ammo > 0 and !thrown:
		holding_about_to_throw = true
		anim_player.play("hold_to_throw")
		rpc("sync_animation", "hold_to_throw")
		
	if Input.is_action_just_released("left_click") and holding_about_to_throw and ammo > 0 and !thrown:
		holding_about_to_throw = false
		thrown = true
		shoot()

@rpc("any_peer", "reliable")
func sync_animation(animation):
	anim_player.play(animation)

func shoot():
	# Detach the grenade from the hand and throw it
	anim_player.play("throw")
	rpc("sync_animation", "throw")
	await anim_player.animation_finished
	ammo -= 1
	#spawnNLaunch(hand.global_position, -merc.camera.global_basis.z * throw_strength)
	rpc("spawnNLaunch", hand.global_position, -merc.camera.global_basis.z * throw_strength, merc.velocity, self.get_multiplayer_authority())
	equip() # we are re-equipping heheheha
	#hand.set_deferred("remote_path", null)
	#grenade.freeze = false
	#grenade.linear_velocity = Vector3.ZERO
	#grenade.apply_central_impulse(-merc.camera.global_basis.z * throw_strength)

@rpc("any_peer", "call_local", "reliable")
func spawnNLaunch(starting_pos, vectorImpulse, velocity, ownerID):
	print("Spawning n launching!")
	var incendiary = INCENDIARY_INSTANCE.instantiate()
	incendiary.set_multiplayer_authority(ownerID)
	incendiary.name = ("IncendiaryGrenade_" + str(ownerID))
	get_tree().root.add_child(incendiary)
	incendiary.global_position = starting_pos
	incendiary.apply_central_impulse(vectorImpulse)
	var spin_power = 8.0
	incendiary.angular_velocity = -merc.camera.global_basis.x * spin_power
	#incendiary.apply_torque_impulse(Vector3(10.0, 0, 0))
	#var spin_strength = 5.0 
	#var pitch_axis = -incendiary.global_basis.x 
	#incendiary.apply_torque_impulse(pitch_axis * spin_strength)

func equip():
	show()
	show_self.rpc(true) #tell all clients to update
	if ammo > 0:
		anim_player.play("equip")
		anim_player.queue("idle")
	else:
		hide()
		show_self.rpc(false)

func finish_equip_anim():
	thrown = false

@rpc("any_peer","call_remote","reliable")
func show_self(vis : bool):
	if vis:
		show()
		if ammo > 0:
			anim_player.play("equip")
			anim_player.queue("idle")
		else:
			hide()
	else:
		hide()

func dequip():
	hide()
	show_self.rpc(false)

@rpc("any_peer", "call_local", "reliable")
func explode():
	# Only the authority should calculate and send damage
	if is_multiplayer_authority():
		for i in explosion_radius.get_overlapping_bodies():
			if i != null and i != self and i is Merc:
				i.take_damage.rpc_id(i.name.to_int(), damage) 
	
	# Everything below this runs locally for all clients (Visuals/Cleanup)
	if cpu_particles_3d:
		cpu_particles_3d.emitting = true
	
	grenade.set_deferred("freeze", true)
	
	await cpu_particles_3d.finished
	reset_grenade()

func reset_grenade():
	
	#Kill leftover momentum so it doesn't fly off when un-frozen later
	grenade.linear_velocity = Vector3.ZERO
	grenade.angular_velocity = Vector3.ZERO
	
	grenade.global_transform = hand.global_transform
	
	#Re-link the RemoteTransform3D so the grenade follows the hand again
	hand.set_deferred("remote_path", hand.get_path_to(grenade))
	
	grenade.visible = true
	thrown = false
	
	#playing animations for smooth
	equip()

func _on_fuse_timer_timeout() -> void:
	if grenade and is_multiplayer_authority():
		explode.rpc()
