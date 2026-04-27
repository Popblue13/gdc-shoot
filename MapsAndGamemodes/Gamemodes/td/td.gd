extends DM
class_name TD

const DEATHMATCH_SIDE_CHOICE_BUTTON = preload("res://MapsAndGamemodes/Gamemodes/dm/deathmatch side choice button.tscn")

var team_select_ui 
var master_team_database: Dictionary = {}
var has_picked_team_locally := false 

@export var red_spawn_points: Array[Node3D] = []
@export var blue_spawn_points: Array[Node3D] = []

func _init() -> void:
	# Because 'leaderboard_scene' is a variable in DM, we can overwrite 
	# it here before DM's _ready() function even fires!
	leaderboard_scene = preload("res://MapsAndGamemodes/Gamemodes/dm/LeaderBoardTDM.tscn")

func _ready() -> void:
	super._ready() # Calls DM's _ready(), which spawns the Leaderboard, CharSelect, and MatchUI
	
	team_select_ui = DEATHMATCH_SIDE_CHOICE_BUTTON.instantiate()
	add_child(team_select_ui)
	team_select_ui.hide()
	
	team_select_ui.side_chosen.connect(_on_local_team_locked_in)

# --- OVERRIDES OF DM VIRTUAL FUNCTIONS ---

func update_score_ui():
	var my_id = multiplayer.get_unique_id()
	var red_score = 0
	var blue_score = 0
	
	if leaderboard and leaderboard.stats:
		for player_data in leaderboard.stats.values():
			var kills = player_data.get("kills", 0)
			var p_team = player_data.get("team", "default")
			if p_team == "red": red_score += kills
			elif p_team == "blue": blue_score += kills
			
	if match_ui and match_ui.has_method("update_ui"):
		var my_team = master_team_database.get(my_id, "default")
		
		var my_team_score = 0
		var enemy_team_score = 0
		
		# Fixed Bug 1: Explicitly check teams so "default" doesn't inherit Blue's score
		if my_team == "red":
			my_team_score = red_score
			enemy_team_score = blue_score
		elif my_team == "blue":
			my_team_score = blue_score
			enemy_team_score = red_score
		else:
			# If they are unassigned, just show Red vs Blue statically
			my_team_score = blue_score 
			enemy_team_score = red_score
		
		# Pass my_team to trigger the VSUI color change
		match_ui.update_ui(my_team_score, enemy_team_score, max(time_left, 0.0), my_team)

func _respawn_player(player_id: int):
	var chosen_merc = master_character_database.get(player_id, "")
	var chosen_team = master_team_database.get(player_id, "")
	
	if chosen_merc == "" or chosen_team == "": 
		return 
	
	respawn_trackers[player_id]["is_dead"] = false
	if leaderboard: leaderboard.set_player_alive(player_id)
	
	if not has_node(str(player_id)):
		var spawn_pos = Vector3.ZERO
		var random_spawn = null
		
		# Check spawn arrays independently so one missing team doesn't break the other
		if chosen_team == "red" and red_spawn_points.size() > 0:
			random_spawn = red_spawn_points.pick_random()
		elif chosen_team == "blue" and blue_spawn_points.size() > 0:
			random_spawn = blue_spawn_points.pick_random()
				
		if random_spawn:
			spawn_pos = random_spawn.position 
			
		player_spawner.spawn({
			"merc_type": chosen_merc,
			"position": spawn_pos,
			"peer_id": player_id,
			"team": chosen_team # <--- PAYLOAD INJECTION ADDED HERE
		})


# --- TD SPECIFIC SERVER LOGIC ---
@rpc("authority", "call_local", "reliable")
func update_client_team_databases(new_database: Dictionary) -> void:
	master_team_database = new_database
	# Removed the loop that called ch`ild.sync_team_database() because 
	# Mercs now get their team natively on spawn!

func _on_player_left(player_id: int) -> void:
	super._on_player_left(player_id) # Let DM handle the baseline cleanup
	master_team_database.erase(player_id)
	update_client_team_databases.rpc(master_team_database)

# --- TD SPECIFIC CLIENT LOGIC ---

func _on_local_character_locked_in(chosen_merc: String):
	super._on_local_character_locked_in(chosen_merc) # Hides UI and submits
	if not has_picked_team_locally:
		team_select_ui.show()

func _on_local_team_locked_in(chosen_team: String):
	team_select_ui.hide()
	has_picked_team_locally = true 
	submit_team_choice.rpc_id(1, chosen_team)

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event) # Let DM handle the character switch key
	if Input.is_action_just_pressed("change_team"):
		if team_select_ui: 
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			team_select_ui.show()
		request_suicide_for_switch.rpc_id(1, 'team')

@rpc("any_peer", "call_remote", "reliable")
func submit_team_choice(team_name: String):
	var sender_id = multiplayer.get_remote_sender_id()
	master_team_database[sender_id] = team_name
	update_client_team_databases.rpc(master_team_database)
	
	if leaderboard and leaderboard.has_method("set_player_team"):
		leaderboard.set_player_team(sender_id, team_name)
	
	if master_character_database.has(sender_id) and respawn_trackers.has(sender_id) and respawn_trackers[sender_id]["is_dead"]:
		respawn_trackers[sender_id]["respawn_timer"] = 0.0

@rpc("any_peer", "call_remote", "reliable")
func request_suicide_for_switch(switch_type : String = "character"):
	var sender_id = multiplayer.get_remote_sender_id()
	if switch_type == "team":
		master_team_database[sender_id] = ""
		update_client_team_databases.rpc(master_team_database)
		
	super.request_suicide_for_switch(switch_type) # Let DM handle the actual death execution
