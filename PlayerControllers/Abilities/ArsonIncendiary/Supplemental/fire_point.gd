extends Node3D

@onready var particles = $GPUParticles3D
@onready var decal: Decal = $Decal
@onready var area_3d: Area3D = $Area3D
var FireDMG = 1.0
var FireHeal = 0.25
const BURNING_EFFECT = preload("res://PlayerControllers/Abilities/ArsonFlamethrower/Supplemental/BurningEffect.tscn")

func fade_out_and_die():
	sync_fade_out_and_die()#.rpc()

#@rpc("any_peer", "call_local", "reliable")
func sync_fade_out_and_die():	# 1. Stop spawning new particles immediately
	particles.emitting = false
	
	var mat = particles.draw_pass_1.material
	var tween = create_tween()
	
	# 2. Start the Particle Fade (Fast)
	# We fade the intensity quickly so the 'heat' leaves first
	if mat is ShaderMaterial:
		tween.tween_property(mat, "shader_parameter/emission_intensity", 0.0, 1.0)
	
	# 3. Delay and then Fade the Decal (Slower)
	# We use 'parallel' to make them overlap, but 'set_delay' to let the fire lead
	if decal:
		tween.parallel().tween_property(decal, "albedo_mix", 0.0, 2.5).set_delay(0.5)
	
	# 4. Wait for the Decal to finish, then delete
	await tween.finished
	queue_free()




func _on_tick_timer_timeout() -> void:
	if is_multiplayer_authority():
		for i in area_3d.get_overlapping_bodies():
			print(i)
			if i != null and i != self and i is Merc:
				if i.get_multiplayer_authority() == self.get_multiplayer_authority():
					i.take_damage(-FireHeal)
				else:
					i.take_damage.rpc_id(i.get_multiplayer_authority(), FireDMG)
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
			afterburn.renewBurn() #Run on everyone, for the purposes of sync
