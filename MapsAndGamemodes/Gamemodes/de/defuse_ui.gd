extends Control
class_name DEUI

@export var timer_label: Label
@export var state_label: Label
@export var attackers_score_label: Label
@export var defenders_score_label: Label
@onready var a_remaining: Label = $HBoxContainer/ColorRect2/ARemaining
@onready var d_remaining: Label = $HBoxContainer/ColorRect/DRemaining

func _ready() -> void:
	hide()

# Called by DefuseGamemode.gd every frame
func update_timer(time_left: float, state: int) -> void:
	var lobby_id = get_parent().name
	var my_id = multiplayer.get_unique_id()
	if not ServerDatabase.Lobbies.has(lobby_id) or not my_id in ServerDatabase.Lobbies[lobby_id]:
		hide()
		return
	else:
		show()
	
	# Format time into MM:SS
	var minutes := int(time_left) / 60
	var seconds := int(time_left) % 60
	if timer_label:
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		
	if state_label:
		match state:
			0 or 1: # FREEZE
				state_label.text = "FREEZE TIME"
				state_label.modulate = Color.AQUA
			2: # ACTION
				state_label.text = "DEFEND / ATTACK"
				state_label.modulate = Color.WHITE
			3: # BOMB_PLANTED
				state_label.text = "BOMB PLANTED"
				state_label.modulate = Color.RED
			4: # ROUND_END
				state_label.text = "ROUND OVER"
				state_label.modulate = Color.YELLOW

# Called by DefuseGamemode.gd when a round is won
func update_scores(attackers: int, defenders: int) -> void:
	if attackers_score_label:
		attackers_score_label.text = str(attackers)
	if defenders_score_label:
		defenders_score_label.text = str(defenders)

func update_remaining_players(attackers : int, defenders : int):
	a_remaining.text = str(attackers)
	d_remaining.text = str(defenders)
