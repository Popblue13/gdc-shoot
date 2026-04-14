extends SprintAbility

var cash: float = 100
var cost_per_second: float = 2
var cost_mult: float = 1.0:
	set(n): cost_mult = abs(n)

signal fired(cost_per_bullet: float)
func _connect_cash(player: Merc) -> void:
	if player.has_signal("cash_updated"):
		player.cash_updated.connect(func(new: float) -> void: cash = new)

signal uses_updated(uses: int, prior: int)
var activations: int = 0:
	set(n):
		if n != activations:
			var old := activations
			activations = clamp(n, 0, 100)
			uses_updated.emit(activations, old)
func get_activations() -> int: return activations
func update_cost_mult(mult: float) -> void: cost_mult = mult

var tmpact: float = 0.0
func _physics_process(delta: float) -> void:
	if cash - (cost_per_second * cost_mult * delta) < 0: 
		if _is_sprinting: _stop_sprint()
		_is_sprinting = false
	
	if _is_sprinting:
		tmpact += delta
		if tmpact >= 1:
			activations += 10
			tmpact = 0
		fired.emit(cost_per_second * cost_mult * delta)
	
	super(delta)
