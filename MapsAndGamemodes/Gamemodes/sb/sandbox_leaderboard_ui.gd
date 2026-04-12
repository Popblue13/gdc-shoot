extends Control

@onready var v_box_container: VBoxContainer = $Panel/VBoxContainer

func _ready() -> void:
	hide()

func _process(delta: float) -> void:
	if Input.is_action_pressed("show_leaderboard"):
		show()
	else:
		hide()

func update_ui(stats: Dictionary) -> void:
	# 1. Clear out the old list
	for child in v_box_container.get_children():
		child.queue_free()
		
	# 2. Build the new list
	for player_id in stats.keys():
		var player_data = stats[player_id]
		
		# We completely ignore the "respawn_timer" variable here!
		var kills = player_data["kills"]
		var deaths = player_data["deaths"]
		var status = "DEAD" if player_data["is_dead"] else "ALIVE"
		
		# Create a simple text label for the leaderboard
		var label = Label.new()
		label.text = "Player %s | Kills: %d | Deaths: %d | %s" % [str(player_id), kills, deaths, status]
		
		# Add it to the VBoxContainer so it stacks neatly
		v_box_container.add_child(label)
