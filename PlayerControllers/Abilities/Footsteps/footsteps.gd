extends Ability

@export var steps : Array[AudioStream] = []
@export var volume = 0

@onready var audio = $AudioStreamPlayer3D

func _ready() -> void:
	merc = get_parent()

func _process(delta: float) -> void:
	# Only the client who owns this node calculates this
	if !is_multiplayer_authority(): return
	
	var velocity_int = abs(merc.velocity.x + merc.velocity.y + merc.velocity.z)
	
	if merc.is_on_floor():
		volume = clamp(-70 + ((velocity_int) * 50), -100, 0)
	else:
		volume = -70
		
	audio.volume_db = volume
	# Use 3.0 to ensure float division
	audio.pitch_scale = clamp(velocity_int / 3.0, 0.75, 1.4)

func activate():
	pass

func _on_audio_stream_player_3d_finished() -> void:
	# Only the authority decides what plays next
	if !is_multiplayer_authority(): return
	
	if steps.size() > 0:
		var next_step_idx = randi_range(0, steps.size() - 1)
		# Call the RPC on all peers (including the authority itself)
		play_step.rpc(next_step_idx)

# This RPC can only be called by the multiplayer authority, 
# but it executes locally on every client connected.
@rpc("authority", "call_local", "unreliable")
func play_step(step_index: int) -> void:
	audio.stream = steps[step_index]
	audio.play()
