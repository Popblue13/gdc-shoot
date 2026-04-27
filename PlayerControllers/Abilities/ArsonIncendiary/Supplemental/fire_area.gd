extends Area3D

@export var damage_per_tick: int = 5
@export var heal_per_tick: int = 3
var creator: Node3D = null # We will set this when spawning
const BURNING_EFFECT = preload("res://PlayerControllers/Abilities/ArsonFlamethrower/Supplemental/BurningEffect.tscn")

func _on_damage_tick_timer_timeout() -> void:
	# Get all bodies currently standing in the fire
	var bodies = get_overlapping_bodies()
	
	for body in bodies:
		if body == creator:
			# Heal the person who threw it
			if body.has_method("heal"):
				body.heal(heal_per_tick)
			else:
				# Burn everyone else
				if body.has_method("take_damage"):
					body.take_damage(damage_per_tick)
					# If you have a separate "on_fire" status effect:
					if body.has_method("apply_status"):
						body.apply_status("burning")
					if body.has_node("StatusEffect_Burn"):
						RefreshAfterburn(body.get_path())
						rpc("RefreshAfterburn", body.get_path())
					else:
						GiveAfterburn(body.get_path(), self.get_multiplayer_authority())
						rpc("GiveAfterburn", body.get_path(), self.get_multiplayer_authority())

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
			afterburn.renewBurn() #Run on everyone, for the purposes of sync
