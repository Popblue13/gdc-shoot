extends "res://PlayerControllers/Abilities/MoneyBased/base_money_user.gd"

const GoldShaderPreload := preload("res://PlayerControllers/Mercs/YetAnotherMerc/gold.gdshader")
var GoldMaterial = ShaderMaterial.new()

func money_custom_ready() -> void:
	# Hopefully this makes the mesh only invisible to me
	$MeshInstance3D.visible = !is_multiplayer_authority()
	GoldMaterial.shader = GoldShaderPreload
	
	var to_visit: Array[Variant] = self.abilities.duplicate()
	while to_visit.size() > 0:
		var cur: Variant = to_visit.pop_back()
		to_visit += cur.get_children()
		if cur is MeshInstance3D: (cur as MeshInstance3D).set_surface_override_material(0, GoldMaterial)
		if cur is RayCast3D:
			(cur as RayCast3D).set_exclude_parent_body(true)
			(cur as RayCast3D).add_exception(self)
			#self.add_collision_exception_with(cur)

	for ability in self.abilities:
		if !ability.is_in_group(MoneyAbility.GROUP_NAME): continue
		ability.equipped.connect(
			func(ab: Ability) -> void:
				last_equipped_ability = ab
				_update_ammo(last_equipped_ability)
		)
	
	return

var last_equipped_ability: Ability = null
func _update_ammo(ab: Ability) -> void:
	if !ab: return
	var bullets: float = floorf(cash / ab.net_activation_cost)
	var tmpstr: String = "%0.f" % bullets if is_finite(bullets) else "Infinite"
	$"UI/Ammo".text = "%0.2f/(%0.2f * %0.2f): %s Bullets" % [cash, ab.cost_per_activation, ab.cost_multiplier, tmpstr]

func custom_process(_delta: float) -> void:
	$"UI/Remaining Money".text = "Cash: %0.2f" % cash
	_update_ammo(last_equipped_ability)
