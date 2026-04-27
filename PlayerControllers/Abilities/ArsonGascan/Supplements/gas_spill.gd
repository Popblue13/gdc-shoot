extends Node3D

enum State {GAS, IGNITED, BURNT}
var current_state = State.GAS

@export var burn_duration: float = 8.0     # How long it stays on fire
@export var spread_delay: float = 0.2      # Time before it lights neighbors
@export var fire_damage: float = 0.05      # Damage per second
const BURNING_EFFECT = preload("res://PlayerControllers/Abilities/ArsonFlamethrower/Supplemental/BurningEffect.tscn")

@onready var area_3d: Area3D = $Area3D               # The "Damage/Detection" area
@onready var gpu_particles_3d: GPUParticles3D = $GPUParticles3D
@onready var tick_timer: Timer = $TickTimer

func _ready() -> void:
	gpu_particles_3d.emitting = false

@rpc("any_peer", "call_local", "reliable")
func ignite():
	# Only ignite if it's currently fresh gas
	if current_state != State.GAS:
		return
		
	current_state = State.IGNITED
	gpu_particles_3d.emitting = true
	print("Gas spill ignited!")

	# 1. Start the Spread Logic after a short delay
	get_tree().create_timer(spread_delay).timeout.connect(spread_fire)

	# 2. Start the Burn-out timer
	get_tree().create_timer(burn_duration).timeout.connect(extinguish)

func spread_fire():
	if current_state != State.IGNITED:
		return

	# Look for other Area3Ds overlapping this one
	var neighbors = area_3d.get_overlapping_areas()
	
	for area in neighbors:
		# Check if the neighbor is another gas spill
		# We use 'owner' to get the root node of the other spill
		var other_spill = area.get_parent() 
		if other_spill.has_method("ignite") and other_spill != self:
			other_spill.ignite()

func extinguish():
	current_state = State.BURNT
	gpu_particles_3d.emitting = false
	
	# Smoothly disappear
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 1.0)
	tween.tween_callback(queue_free)

func _on_tick_timer_timeout() -> void:
	#spread_fire()
	if is_multiplayer_authority() and current_state == State.IGNITED:
		for i in area_3d.get_overlapping_bodies():
			print(i)
			if i != null and i != self and i is Merc:
				if i.get_multiplayer_authority() != self.get_multiplayer_authority():
					i.take_damage.rpc_id(i.get_multiplayer_authority(), fire_damage)
					if i.has_node("StatusEffect_Burn"):
						RefreshAfterburn(i.get_path())
						rpc("RefreshAfterburn", i.get_path())
					else:
						GiveAfterburn(i.get_path(), self.get_multiplayer_authority())
						rpc("GiveAfterburn", i.get_path(), self.get_multiplayer_authority())


@rpc("any_peer", "reliable")
func GiveAfterburn(bodypath, ownerID): #Run on everyone, for the purposes of sync
	var body = get_node_or_null(bodypath)
	if body != null:
		var afterburn = BURNING_EFFECT.instantiate()
		afterburn.name = "StatusEffect_Burn"
		#afterburn.set_multiplayer_authority(body.name.to_int())
		#if is_multiplayer_authority():
		afterburn.set_multiplayer_authority(ownerID)
		body.add_child(afterburn)

@rpc("any_peer", "reliable")
func RefreshAfterburn(bodypath):
	var body = get_node_or_null(bodypath)
	if body != null:
		if body.has_node("StatusEffect_Burn"):
			var afterburn = body.get_node("StatusEffect_Burn")
			afterburn.renewBurnBetter(1, 10) #Run on everyone, for the purposes of sync
