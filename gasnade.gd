extends OneShotAbility
@onready var gas_emit = $AudioStreamPlayer3D

func activate(abilities: Array[Ability], merc: Merc):
	gas_emit.play()
