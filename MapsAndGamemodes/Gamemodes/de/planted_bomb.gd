extends StaticBody3D
class_name PlantedBomb

@onready var defuse_timer: Label3D = $palm/spinningpalm/DefuseTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer 

var planted: bool = true # Required so the Defuse Kit knows it's active
var defuse_gamemode: DE

func _ready() -> void:
	animation_player.play("idle")
	await get_tree().create_timer(1.3).timeout
	$Bombplanted.play()

func _process(_delta: float) -> void:
	# Continuously update the physical digital timer locally for all players
	if defuse_gamemode and defuse_gamemode.current_state == defuse_gamemode.RoundState.BOMB_PLANTED:
		var time = max(defuse_gamemode.round_timer, 0.0)
		var minutes := int(time) / 60
		var seconds := int(time) % 60
		defuse_timer.text = "%d:%02d" % [minutes, seconds]
		

@rpc("authority", "call_local", "reliable")
func explode():
	print("BOOM!")
	# Trigger your explosion particles, sounds, and animations here
	if animation_player.has_animation("explode"):
		animation_player.stop()
		$Bombexplosion.play()
		animation_player.play("explode")
	$palm.hide() # Hide the bomb mesh after it explodes
	$fingers.hide()
