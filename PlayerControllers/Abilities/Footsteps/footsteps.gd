extends Ability

@export var steps : Array[AudioStream] = []

@onready var audio = $AudioStreamPlayer3D
@export var volume = 0

func _ready() -> void:
	merc = get_parent()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var velocity_int = abs(merc.velocity.x + merc.velocity.y + merc.velocity.z)
	if merc.is_on_floor():
		volume = clamp(-70 + ((velocity_int)*50), -100, 0)
	else:
		volume = -70
	audio.volume_db = volume
	audio.pitch_scale = clamp(velocity_int/3, 0.75, 1.4)

func activate():pass

func _on_audio_stream_player_3d_finished() -> void:
	audio.stream = steps[randi_range(0, steps.size()-1)]
	audio.play()
