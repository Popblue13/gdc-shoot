extends Node3D

@onready var duration_timer = $Timer
@onready var bleed_timer = $BleedTimer
@onready var sprite = $Sprite3D
var bleed_damage = -7.5

@onready var tracker
@onready var target_player = get_parent()

func _ready() -> void:
	pass
#	if target_player.team == tracker.team:
#		sprite.modulate.g = 1
#		sprite.modulate.r = 0

func _on_bleed_timer_timeout() -> void:
	if is_multiplayer_authority():return
	if target_player is Merc or target_player is DestructibleProp:
		
#		if target_player.team == tracker.team:
#			target_player.take_damage.rpc_id(target_player.name.to_int(), -bleed_damage)
#			
		
		target_player.take_damage.rpc_id(target_player.name.to_int(), bleed_damage) 

@rpc("any_peer", "call_remote", "reliable")
func _on_timer_timeout() -> void:
	queue_free()
	if !is_multiplayer_authority():return
	tracker.bandages += 1
	
