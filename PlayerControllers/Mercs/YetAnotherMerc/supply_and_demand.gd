extends Ability

signal uses_updated(_uses: int, _prior: int)
func get_activations() -> int: return 0
func update_cost_mult(_p: float) -> void: return

signal total_activations_updated(activations: int)
signal reduce_activations(percent: float)

var _do_price_update: bool = true
var activations: int = 0

var cmerc: Merc = null
var total_activations: int = 0:
	set(n):
		if n != total_activations:
			total_activations = n
			total_activations_updated.emit(total_activations)

var connected: bool = false
func connect_to_abilities(merc: Merc) -> void:
	if connected: return
	cmerc = merc
	if !cmerc: return
	if !cmerc.has_signal("cash_updated"): return # Only touch YAM-Compatible playerss
	
	for ability in cmerc.abilities:
		if not (
			ability.has_signal("uses_updated") and
			ability.has_method("get_activations") and
			ability.has_method("update_cost_mult")
		): return
	
	connected = true
	for ability in cmerc.abilities:
		ability.uses_updated.connect(
			func(uses: int, prior: int) -> void: 
				if uses > prior:
					total_activations += uses - prior
					print("%s uses: %d, total: %d" % [ability.name, (uses - prior), total_activations])
		)
		
		total_activations_updated.connect(
			func(_total_activations: int) -> void:
				var tmp := get_new_mult(ability.get_activations())
				ability.update_cost_mult(tmp)
				print("updating cost mult: " + str(tmp) + " on " + ability.name)
		)
		
		reduce_activations.connect(
			func(p: float) -> void: 
				print("reducing activations from " + str(ability.activations) + " to " + str(ability.activations * p) + " on " + ability.name)
				ability.activations *= p
		)

func get_new_mult(activations: int) -> float:
	if total_activations == activations: total_activations += 1
	return 1.0 / (1 - ((1.0 * activations) / (1.0 * total_activations)))
	# Ignore the "1.0 *" bs, it's just so that godot stops complaining about int div

# Ran whenever "activated". I assume that because this is passive it is every frame
func activate() -> void:
	print("ACTIVATED!")
	connect_to_abilities(merc)
	_do_price_update = true
	return

var passed: float = 0.0
func _physics_process(delta: float) -> void:
	if !_do_price_update: return
	passed += delta
	if passed >= 1:
		@warning_ignore("narrowing_conversion")
		total_activations *= 0.85
		reduce_activations.emit(0.90)
		passed = 0
