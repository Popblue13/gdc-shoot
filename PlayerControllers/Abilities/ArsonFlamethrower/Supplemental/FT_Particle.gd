extends Node3D

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 0.8
var initial_lifetime: float = 0.8
var DoneDamage: bool = false
var ParticleDamage: float = 0.0
var life_percent
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
const BURNING_EFFECT = preload("res://PlayerControllers/Abilities/ArsonFlamethrower/Supplemental/BurningEffect.tscn")

# Inside your VisualFlame.gd _ready function
func _ready():
	# This creates a unique copy of the material for THIS specific puff
	# so it doesn't share its life_value with the others.
	var original_mat = mesh_instance_3d.get_active_material(0)
	if original_mat:
		mesh_instance_3d.set_surface_override_material(0, original_mat.duplicate())
	
	# Force the initial state so it doesn't "pop" at scale 1.0
	var life_percent = 1.0 # It just started
	var grow_curve = inverse_lerp(1.0, 0.95, life_percent) 
	self.scale = Vector3.ONE * clamp(grow_curve * 2.0, 0.001, 2.0)
	
	# Update shader immediately
	var mat = mesh_instance_3d.get_surface_override_material(0)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("life_value", 1.0)
	
	# Random rotation
	mesh_instance_3d.rotation.z = randf_range(0, TAU)

func _physics_process(delta: float):
	# 1. Calculate where we WANT to go
	var movement = velocity * delta
	
	# 2. Check for walls using a RayCast (Space State)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + movement)
	
	# Optional: Tell the ray to ignore the player who fired it
	query.collision_mask = 1 # Only hits Layer 1
	#query.exclude = [get_multiplayer_authority()] 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Snap to the wall position so we don't poke through
		global_position = result.position + (result.normal * 0.1) 
		# Slide the velocity for the NEXT frame
		velocity = velocity.slide(result.normal) * 0.8
	else:
		# No wall, move normally
		global_position += movement
	
	# 3. Air Resistance & Visuals
	velocity = velocity.move_toward(Vector3.ZERO, 5.0 * delta)
	life_percent = lifetime / initial_lifetime
	# Starts at 0, grows rapidly to 
	var grow_curve = inverse_lerp(1.5, 0.4, life_percent) # Grows to full size in first 20% of life
	scale = Vector3.ONE * clamp(grow_curve * 1.5, 0.01, 1.5)
	
	
	# Update the shader parameters
	var mat = mesh_instance_3d.get_active_material(0)
	if mat is ShaderMaterial:
			mat.set_shader_parameter("life_value", life_percent)
	
	#scale = Vector3.ONE * (2.0 - life_percent)
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	#print(body)
	#print(get_multiplayer_authority())
	var DoDamage = true
	if is_multiplayer_authority():
		if body != null and body != self and body is Merc:
			#if body.name.to_int() != multiplayer.get_unique_id():
			if body.get_multiplayer_authority() != self.get_multiplayer_authority():
				if body.player_teams.has(self.get_multiplayer_authority()):
					var attacker_team = body.player_teams[self.get_multiplayer_authority()]
					# 3. Filter friendly fire
					if attacker_team == body.team and body.team != "default":
						DoDamage = false
				
				if !DoneDamage and DoDamage:
					DoneDamage = true
					#print("Doing " + str(ParticleDamage) + " damage.")
					var damage_mult = 1.0
					if life_percent:
						damage_mult = remap(life_percent, 1.0, 0.0, 1.0, 0.5)
					body.take_damage.rpc_id(body.get_multiplayer_authority(), ParticleDamage*damage_mult)
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


func _on_area_3d_area_entered(area: Area3D) -> void:
	if is_multiplayer_authority():
		if area.has_method("ignite"):
			area.ignite()
