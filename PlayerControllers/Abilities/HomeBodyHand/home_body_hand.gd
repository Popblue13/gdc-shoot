extends WeaponAbility
class_name HomeBodyHand
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $homebodyhand/AnimationPlayer

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if merc != null: global_transform = merc.camera.global_transform
		if Input.is_action_just_pressed("left_click"):
			if animation_player.current_animation != 'interact':
				animation_player.play("interact")
				shoot()
		if Input.is_action_just_released("left_click"):
			animation_player.play("idle")
		elif Input.is_action_just_pressed("right_click"):
			animation_player.play("wave")

func shoot():
	if ray_cast_3d.is_colliding() and merc:
		var col = ray_cast_3d.get_collider()
		if col is HomeBodyInteract:
			col.interact(merc)

func pull_headset_on():
	animation_player.play("equip_headset")
	await get_tree().create_timer(.45).timeout
	return true

func pull_headset_on_reverse():
	animation_player.play_backwards("equip_headset")
	await get_tree().create_timer(.45).timeout
	return true

func equip():
	show()

func dequip():
	hide()
