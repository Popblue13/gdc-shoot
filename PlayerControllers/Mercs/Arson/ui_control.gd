extends Control

@onready var fps_canvas_layer: CanvasLayer = $FPS_CanvasLayer
@onready var camera_3d: Camera3D = $"../Camera3D"
@onready var fps_camera: Camera3D = $FPS_CanvasLayer/SubViewportContainer/SubViewport/FPS_Camera

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !is_multiplayer_authority():
		self.queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if camera_3d:
		fps_camera.global_transform = camera_3d.global_transform
