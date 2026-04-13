extends WeaponAbility

@onready var animation_player: AnimationPlayer = $firstanimation/AnimationPlayer
@onready var tracer_effect: Node3D = $TracerEffect
@onready var fire_attack_speed: Timer = $FireAttackSpeed
@onready var crosshair_002: Sprite2D = $Crosshair002
@onready var label: Label = $Crosshair002/Label

@export_category("Weapon Stats")
@export var is_auto: bool = false
@export var max_ammo: int = 12
@export var damage: float = 10.0
@export var fire_speed: float = 0.1 # Time in seconds between shots

@export_category("Weapon Nodes")
# Add ONE RayCast3D here for a Pistol/Rifle, or add MULTIPLE for a Shotgun
@export var raycasts: Array[RayCast3D] = [] 

var ammo: int

func _ready() -> void:
	ammo = max_ammo
	
	# 1. Setup the fire rate timer
	fire_attack_speed.wait_time = fire_speed
	fire_attack_speed.one_shot = true
	
	hide()
	label.text = str(ammo) + "/" + str(max_ammo)

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	if !currently_active: return
	
	crosshair_002.visible = visible
	global_transform = merc.camera.global_transform
	
	# Don't allow shooting or reloading while already reloading
	if animation_player.is_playing() and animation_player.current_animation == "reload": 
		return
		
	if Input.is_action_just_pressed("reload") and ammo < max_ammo:
		reload()

	# 2. Handle Single vs Auto fire inputs
	var trigger_pulled: bool = false
	if is_auto:
		trigger_pulled = Input.is_action_pressed("left_click") # Hold to shoot
	else:
		trigger_pulled = Input.is_action_just_pressed("left_click") # Click to shoot
		
	# 3. Check if the gun is ready to fire based on the timer
	if trigger_pulled and fire_attack_speed.is_stopped():
		shoot()

func reload():
	animation_player.play("reload")
	await animation_player.animation_finished
	ammo = max_ammo
	label.text = str(ammo) + "/" + str(max_ammo)

func shoot():
	if ammo <= 0:
		# Optional: Play a "click" sound here for empty ammo
		return
	
	# Consume 1 ammo per trigger pull (even if it's a shotgun firing 8 pellets)
	ammo = clamp(ammo - 1, 0, max_ammo)
	
	# Restart animation and start the cooldown timer
	animation_player.stop() 
	animation_player.play("fire")
	fire_attack_speed.start()
	label.text = str(ammo) + "/" + str(max_ammo)
	# 4. Fire every raycast in the array (1 for Pistol, Many for Shotgun)
	for rc in raycasts:
		if not is_instance_valid(rc): continue
		
		# Force update so the raycast is perfectly aligned with the camera this frame
		rc.force_raycast_update()

		if rc.is_colliding():
			var person_hit = rc.get_collider()
			if person_hit != null and person_hit is Merc:
				person_hit.take_damage.rpc_id(int(person_hit.name), damage)
				
			# Spawn tracer at hit point
			tracer_effect._create_tracer_effect.rpc(tracer_effect.global_position, rc.get_collision_point())
		else:
			# Spawn tracer fading off into the distance if they missed
			var miss_point = rc.global_transform * rc.target_position
			tracer_effect._create_tracer_effect.rpc(tracer_effect.global_position, miss_point)


func equip():
	show()
	animation_player.play("equip")
	show_visual_hand.rpc(true)

@rpc("any_peer","call_remote","reliable")
func show_visual_hand(vis : bool):
	if visual_hand:
		visual_hand.visible = vis
	
func dequip():
	animation_player.play("dequip")
	await animation_player.animation_finished
	hide()
	crosshair_002.hide()
	show_visual_hand.rpc(false)
