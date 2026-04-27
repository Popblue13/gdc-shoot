extends Merc

@onready var cube: MeshInstance3D = $Camera3D/WeldingMask/Cube

@onready var held: Node3D = $Camera3D/Held
@onready var models: Node3D = $Models

@onready var models_for_select: Node3D = $ModelsForSelect
var ImReal = false
@export var velocitysync: Vector3 #I need to sync the velocity because the particles will be offset otherwise.

func custom_ready():
	#models_for_select.queue_free()
	ImReal = true
	if is_multiplayer_authority():
		cube.layers = 1 << 8
		set_layer_recursively(models, 1 << 8) # sets to 9
		set_layer_recursively(held, 1 << 15) #Client side rendering over other objects sets to 16

func set_layer_recursively(node: Node, layer_number: int):
	if "layers" in node:
		node.layers = layer_number
	for child in node.get_children():
		set_layer_recursively(child, layer_number)

func custom_process(delta):
	if models_for_select:
		models_for_select.queue_free()
	
	if is_multiplayer_authority():
		velocitysync = self.velocity
		rpc("SyncVelocity", velocitysync)
	
	self.velocity = velocitysync

func debug_render_layers(node: Node):
	if node is VisualInstance3D:
		var layer_list = []
		# Godot has 20 layers in the bitmask
		for i in range(1, 21):
			# Use the bitwise AND operator to check if the bit is set
			if node.layers & (1 << (i - 1)):
				layer_list.append(i)
		
		print("Node: ", node.name, " | Active Layers: ", layer_list)
	
	for child in node.get_children():
		debug_render_layers(child)

@rpc("any_peer", "reliable")
func SyncVelocity(vel):
	self.velocity = vel
