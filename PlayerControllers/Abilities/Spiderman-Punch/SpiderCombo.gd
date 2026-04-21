extends WeaponAbility

@onready var punch: Area3D = $Punch
@onready var kick: Area3D = $Kick
@export var damage : int
@export var kick_damage : int
@export var cooldown : float
@export var longer_cooldown : float
@onready var timer: Timer = $Timer

func _ready() -> void:
	timer.wait_time = cooldown
	timer.start()

func _process(delta: float) -> void:
	if Input.is_action_pressed("left_click") && timer.is_stopped():
		do_damage(damage, punch)
		timer.wait_time = cooldown
		timer.start()
	if Input.is_action_pressed("right_click") && timer.is_stopped():
		do_damage(kick_damage, kick)
		timer.wait_time = longer_cooldown
		timer.start()

@rpc("any_peer", "call_local", "reliable")
func do_damage(damage: int, area: Area3D) -> void:
	print("PUNCH")
		# Only the authority should calculate and send damage
	if is_multiplayer_authority():
		for i in area.get_overlapping_bodies():
			if i != null and i != self and i is Merc:
				i.take_damage.rpc_id(i.name.to_int(), damage) 
func shoot():
	pass
func equip():
	pass
func dequip():
	pass
