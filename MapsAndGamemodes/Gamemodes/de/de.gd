extends Map
class_name DE

# --- PHASE 2: STATE MACHINE VARIABLES ---
enum RoundState { WAITING_FOR_PLAYERS, FREEZE, ACTION, BOMB_PLANTED, ROUND_END }
var current_state: RoundState = RoundState.WAITING_FOR_PLAYERS
var is_match_active: bool = false
var round_timer: float = 0.0

@export var freeze_duration: float = 15.0
@export var action_duration: float = 120.0
@export var bomb_duration: float = 45.0
@export var end_duration: float = 5.0
@export var rounds_to_win: int = 13
@export var attacker_spawn_points: Array[Node3D] = []
@export var defender_spawn_points: Array[Node3D] = []
@export var before_round_start_barriers : StaticBody3D

var attackers_score: int = 0
var defenders_score: int = 0
var master_team_database: Dictionary = {}
var master_character_database: Dictionary = {}
var players_alive_this_round: Array[int] = []

var defuse_ui_scene = preload("res://MapsAndGamemodes/Gamemodes/de/DefuseUI.tscn")
var char_select_scene = preload("res://MapsAndGamemodes/Gamemodes/PresetGamemodeWidgets/CharacterSelect/CharacterSelect.tscn")
var team_select_scene = preload("res://MapsAndGamemodes/Gamemodes/dm/deathmatch side choice button.tscn")
var defuser_node_scene = "res://PlayerControllers/Abilities/DEAbilities/Defuser/Defuser.tscn"
var defuse_ui: DEUI
var char_select_ui
var team_select_ui
var has_picked_team_locally := false

var active_bomb: PlantedBomb = null # Changed from DEBOMB to PlantedBomb
var bomb_container: Node3D
var bomb_spawner: MultiplayerSpawner

# IMPORTANT: Put the exact path to your new scene here!
var planted_bomb_scene = preload("res://MapsAndGamemodes/Gamemodes/de/PlantedBomb.tscn")

func _ready() -> void:
		# 1. Create a clean folder node for the physical bomb to live in
	bomb_container = Node3D.new()
	bomb_container.name = "BombContainer"
	add_child(bomb_container)
	
	# 2. Set up the dynamic network spawner
	bomb_spawner = MultiplayerSpawner.new()
	bomb_spawner.name = "BombSpawner"
	
	# 3. Add it to the tree FIRST before assigning paths
	add_child(bomb_spawner)
	
	# 4. Tell the spawner where to put the bomb and what function to use
	bomb_spawner.spawn_path = bomb_container.get_path()
	bomb_spawner.spawn_function = _spawn_planted_bomb
	
	# Instance all UI elements exactly like in DM and TD
	defuse_ui = defuse_ui_scene.instantiate()
	add_child(defuse_ui)
	
	char_select_ui = char_select_scene.instantiate()
	add_child(char_select_ui)
	char_select_ui.hide()
	char_select_ui.character_locked_in.connect(_on_local_character_locked_in)
	
	team_select_ui = team_select_scene.instantiate()
	add_child(team_select_ui)
	team_select_ui.hide()
	team_select_ui.side_chosen.connect(_on_local_team_locked_in)

# --- PHASE 2: ROUND STATE MACHINE ---
func _process(delta: float) -> void:
	if not is_match_active: 
		return
		
	if current_state == RoundState.WAITING_FOR_PLAYERS:
		if defuse_ui:
			defuse_ui.update_timer(0.0, current_state)
			
		# Check if at least one player has locked in a valid team to start the match
		if multiplayer.is_server():
			for team in master_team_database.values():
				if team in ["red", "blue"]:
					reset_round() # This automatically shifts us into the FREEZE state
					break
		return
		
	# Both server AND client count down the timer so the UI is completely smooth every frame
	round_timer -= delta
	
	if defuse_ui:
		defuse_ui.update_timer(max(round_timer, 0.0), current_state)
		
	# Only the server enforces timeouts and shifts state
	if not multiplayer.is_server(): 
		return
		
	if round_timer <= 0.0:
		_advance_state()

func _advance_state() -> void:
	match current_state:
		RoundState.FREEZE:
			# Freeze time is over, begin the round!
			_set_state(RoundState.ACTION, action_duration)
			
		RoundState.ACTION:
			# Time ran out before the bomb was planted/defused.
			# Defenders win if time runs out!
			_round_won("blue")
			
		RoundState.BOMB_PLANTED:
			# Time ran out, the bomb detonated!
			# Attackers win on detonation!
			if is_instance_valid(active_bomb):
				active_bomb.explode.rpc()
			_round_won("red")
			
		RoundState.ROUND_END:
			# Post-round showcase is over, reset for the next round.
			reset_round()

func _set_state(new_state: RoundState, time: float) -> void:
	current_state = new_state
	round_timer = time
	_sync_state.rpc(current_state, round_timer)

@rpc("authority", "call_local", "reliable")
func _sync_state(new_state: int, new_time: float) -> void:
	current_state = new_state as RoundState
	round_timer = new_time
	is_match_active = true
	
	if defuse_ui:
		defuse_ui.update_timer(max(round_timer, 0.0), current_state)

func reset_round() -> void:
	if not multiplayer.is_server(): return
	
	if is_instance_valid(active_bomb):
		active_bomb.queue_free()
	active_bomb = null
	
	# 1. Clear any surviving players or leftover bodies from the previous round
	for child in get_children():
		if child is Merc:
			child.queue_free()
			
	# 2. Spawn everyone for the new round
	spawn_teams_for_new_round()
	
	# 3. Put us back into the Freeze phase
	_set_state(RoundState.FREEZE, freeze_duration)

# --- ABSTRACT MAP FUNCTION IMPLEMENTATIONS ---
func start_gamemode() -> void:
	if not multiplayer.is_server(): return
	
	# Kick off the state machine into holding pattern!
	is_match_active = true
	_set_state(RoundState.WAITING_FOR_PLAYERS, 0.0)

func _on_player_joined(player_id: int) -> void:
	if not multiplayer.is_server(): return
	
	master_team_database[player_id] = "spectator" 
	master_character_database[player_id] = "default"
	
	# Sync the current time, state, and scores immediately to the new guy
	_sync_state.rpc_id(player_id, current_state, round_timer)
	_sync_scores.rpc_id(player_id, attackers_score, defenders_score)
	
	# Prompt the new player to pick character/team
	start_char_select.rpc_id(player_id)

func _on_player_left(player_id: int) -> void:
	if not multiplayer.is_server(): return
	
	master_team_database.erase(player_id)
	master_character_database.erase(player_id)
	players_alive_this_round.erase(player_id)
	
	var merc_node = get_node_or_null(str(player_id))
	if merc_node: 
		merc_node.queue_free()
		
	check_win_conditions()

func player_died(merc: Merc, killer_id: int = 0) -> void:
	if not multiplayer.is_server(): return
	var player_id = merc.name.to_int()
	
	players_alive_this_round.erase(player_id)
	merc.queue_free()
	
	check_win_conditions()

# --- PHASE 1: SPAWN LOGIC ---

func spawn_teams_for_new_round() -> void:
	if not multiplayer.is_server(): return
	
	players_alive_this_round.clear()
	
	for player_id in master_team_database.keys():
		var team = master_team_database[player_id]
		
		if team != "red" and team != "blue":
			continue 
			
		_spawn_individual_for_round(player_id, team)
		players_alive_this_round.append(player_id)

func _spawn_individual_for_round(player_id: int, team: String) -> void:
	var chosen_merc = master_character_database.get(player_id, "default")
	var spawn_pos = Vector3.ZERO
	var random_spawn = null
	
	if team == "red" and attacker_spawn_points.size() > 0:
		random_spawn = attacker_spawn_points.pick_random()
	elif team == "blue" and defender_spawn_points.size() > 0:
		random_spawn = defender_spawn_points.pick_random()
		
	if random_spawn:
		spawn_pos = random_spawn.position
		
	var existing_merc = get_node_or_null(str(player_id))
	if existing_merc:
		existing_merc.queue_free()
		
	var player : Merc = player_spawner.spawn({
		"merc_type": chosen_merc,
		"position": spawn_pos,
		"peer_id": player_id
	})
	if team == 'blue': player.add_ability(defuser_node_scene)

@rpc("any_peer", "call_remote", "reliable")
func submit_team_choice(team_name: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	master_team_database[sender_id] = team_name
	
	# Spawn them immediately if they lock in during the FREEZE phase
	if current_state == RoundState.FREEZE and team_name in ["red", "blue"]:
		if not players_alive_this_round.has(sender_id):
			_spawn_individual_for_round(sender_id, team_name)
			players_alive_this_round.append(sender_id)

# Called by the server when the player finishes the plant animation
func spawn_real_bomb(planter_id: int, plant_spot: Vector3, surface_normal: Vector3) -> void:
	if not multiplayer.is_server(): return

	# Package the spawn location data
	var spawn_data = {
		"pos": plant_spot,
		"normal": surface_normal
	}
	
	# This automatically triggers _spawn_planted_bomb on ALL clients
	var real_bomb = bomb_spawner.spawn(spawn_data)
	
	# Trigger the gamemode state shift!
	on_bomb_planted(planter_id, real_bomb)

# Automatically executes on Server and Clients to build the physical node
func _spawn_planted_bomb(data: Variant) -> Node:
	var spawn_data = data as Dictionary
	var bomb_instance = planted_bomb_scene.instantiate() as PlantedBomb
	
	# Set the height offset so it doesn't sink into the floor (Adjust '1.0' as needed!)
	var height_offset: float = 1.0 
	bomb_instance.position = spawn_data["pos"] + (spawn_data["normal"] * height_offset)
	
	# Align the rotation to the slope
	var align_quat = Quaternion(Vector3.UP, spawn_data["normal"])
	bomb_instance.basis = Basis(align_quat)
	
	# Link the gamemode so the timer and defuser work
	bomb_instance.defuse_gamemode = self
	
	return bomb_instance

func on_bomb_planted(planter_id: int, planted_bomb: PlantedBomb) -> void:
	if not multiplayer.is_server(): return
	if current_state != RoundState.ACTION: return
	
	# Store the bomb so we can explode it later
	active_bomb = planted_bomb 
	
	var player_name = "Unknown"
	if ServerDatabase.Players.has(planter_id):
		player_name = ServerDatabase.Players[planter_id]["gamertag"]
		
	print("Bomb has been planted by ", player_name)
	_set_state(RoundState.BOMB_PLANTED, bomb_duration)

@rpc("any_peer", "call_remote", "reliable")
func on_bomb_defused() -> void:
	if not multiplayer.is_server(): return
	if current_state != RoundState.BOMB_PLANTED: return
	
	var defuser_id = multiplayer.get_remote_sender_id()
	var player_name = "Unknown"
	if ServerDatabase.Players.has(defuser_id):
		player_name = ServerDatabase.Players[defuser_id]["gamertag"]
		
	print("Bomb has been defused by ", player_name)
	_round_won("blue")

func check_win_conditions() -> void:
	# Only check elimination wins during the Action or Bomb Planted phases
	if current_state != RoundState.ACTION and current_state != RoundState.BOMB_PLANTED:
		return
		
	var alive_attackers = 0
	var alive_defenders = 0
	
	for player_id in players_alive_this_round:
		var team = master_team_database.get(player_id, "")
		if team == "red":
			alive_attackers += 1
		elif team == "blue":
			alive_defenders += 1
			
	if current_state == RoundState.ACTION:
		# If all attackers are dead, defenders win
		if alive_attackers == 0 and alive_defenders > 0:
			_round_won("blue")
		# If all defenders are dead, attackers win
		elif alive_defenders == 0 and alive_attackers > 0:
			_round_won("red")
		# If everyone dies simultaneously (e.g. grenade), default to defenders winning
		elif alive_attackers == 0 and alive_defenders == 0:
			_round_won("blue")
			
	elif current_state == RoundState.BOMB_PLANTED:
		# If the bomb is planted, the round DOES NOT end just because attackers die!
		# The bomb can still detonate. But if all defenders die, attackers win instantly.
		if alive_defenders == 0:
			_round_won("red")

func _round_won(winning_team: String) -> void:
	if winning_team == "red":
		attackers_score += 1
	elif winning_team == "blue":
		defenders_score += 1
		
	_sync_scores.rpc(attackers_score, defenders_score)
	
	# Check for Match Win
	if attackers_score >= rounds_to_win or defenders_score >= rounds_to_win:
			print(winning_team.capitalize() + " win the match!")
			is_match_active = false # Stop the timer
			_game_ended() # Call the abstract Map function to notify the Lobby
			return # Exit the function so we don't start the ROUND_END state
		
	_set_state(RoundState.ROUND_END, end_duration)

@rpc("authority", "call_local", "reliable")
func _sync_scores(a_score: int, d_score: int) -> void:
	attackers_score = a_score
	defenders_score = d_score
	if defuse_ui:
		defuse_ui.update_scores(attackers_score, defenders_score)

# --- PHASE 5: CLIENT UI & SELECTION LOGIC ---

func _on_local_character_locked_in(chosen_merc: String):
	char_select_ui.hide()
	submit_character_choice.rpc_id(1, chosen_merc)
	# Daisy-chain into team select
	if not has_picked_team_locally:
		team_select_ui.show()

func _on_local_team_locked_in(chosen_team: String):
	team_select_ui.hide()
	has_picked_team_locally = true 
	submit_team_choice.rpc_id(1, chosen_team)

@rpc("authority", "call_remote", "reliable")
func start_char_select():
	if char_select_ui:
		char_select_ui.show()

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("change_character"):
		if char_select_ui: 
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			char_select_ui.show()
		request_suicide_for_switch.rpc_id(1, "character")
		
	elif Input.is_action_just_pressed("change_team"):
		if team_select_ui: 
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			team_select_ui.show()
		request_suicide_for_switch.rpc_id(1, "team")

@rpc("any_peer", "call_remote", "reliable")
func submit_character_choice(merc_type: String):
	var sender_id = multiplayer.get_remote_sender_id()
	master_character_database[sender_id] = merc_type

@rpc("any_peer", "call_remote", "reliable")
func request_suicide_for_switch(switch_type: String = "character"):
	var sender_id = multiplayer.get_remote_sender_id()
	
	if switch_type == "character":
		master_character_database[sender_id] = ""
	elif switch_type == "team":
		master_team_database[sender_id] = ""
	
	var merc_node = get_node_or_null(str(sender_id))
	if merc_node and not merc_node.dead:
		merc_node.health = 0
		merc_node.dead = true
		if merc_node.has_method("death_effects"):
			merc_node.death_effects.rpc()
		merc_node.emit_signal("died", merc_node)
