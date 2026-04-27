extends TextureProgressBar

@onready var gas_ready: AnimatedSprite2D = $"../GasReady"
@onready var arson_gascan: Node3D = $"../../../../../Camera3D/Held/ArsonGascan"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	self.value = arson_gascan.ammo
	#print(arson_gascan.ammo)
	if self.value == 100:
		gas_ready.show()
	else:
		gas_ready.hide()
