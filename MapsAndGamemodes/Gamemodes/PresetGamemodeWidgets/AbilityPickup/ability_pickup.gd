extends Area3D

@export var ability_scene : PackedScene
@export var consumable := false
@onready var spin_point: Marker3D = $SpinPoint
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

@export var float_speed: float = 2.0
@export var float_height: float = 0.25
var start_y: float

func _ready() -> void:
	start_y = position.y
	
	if ability_scene:
		# Create a temporary instance just to grab the visual mesh
		var temp_ability = ability_scene.instantiate() as Ability
		if temp_ability and temp_ability.visual_hand:
			var display_mesh = temp_ability.visual_hand.duplicate()
			spin_point.add_child(display_mesh)
			display_mesh.show()
			display_mesh.position = Vector3.ZERO 
		
		# Immediately destroy the temp instance so no rogue logic runs
		temp_ability.queue_free()

func _process(_delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0
	position.y = start_y + sin(time * float_speed) * float_height

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server(): return 
	
	if body is Merc and ability_scene:
		# Pass the resource string path to the Merc instead of a node
		body.add_ability(ability_scene.resource_path)
		
		if consumable:
			_sync_destroy.rpc()

@rpc("authority", "call_local", "reliable")
func _sync_destroy() -> void:
	hide()
	collision_shape_3d.set_deferred("disabled", true)
