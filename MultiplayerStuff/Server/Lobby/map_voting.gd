extends Panel

const MAP_VOTE_BUTTON = preload("res://MultiplayerStuff/Server/Lobby/map_vote_button.tscn")
@onready var map_button_v_box: VBoxContainer = $MapButtonVBox

# Everyone keeps track of the totals for the UI
var map_votes : Dictionary = {}

# ONLY THE SERVER uses this to track who voted for what (PeerID : MapName)
var _server_player_votes : Dictionary = {}

func _ready() -> void:
	# 1. Initialize the UI and vote dictionary
	for key in ServerDatabase.Maps:
		map_votes[key] = 0 # FIX: map_votes = {key = 0} overwrites the whole dict!
		
		var butt : Button = MAP_VOTE_BUTTON.instantiate()
		butt.name = key
		butt.text = key + " (0)" # Show starting votes
		map_button_v_box.add_child(butt)
		
		# FIX: In Godot 4, use .bind() to pass arguments through connected signals
		butt.pressed.connect(_on_vote_button_pressed.bind(key))

# ==========================================
# CLIENT LOGIC
# ==========================================

func _on_vote_button_pressed(map_name: String) -> void:
	# Send the vote directly to the Server (ID 1)
	rpc_id(1, "receive_vote", map_name)

# ==========================================
# SERVER LOGIC
# ==========================================

@rpc("any_peer", "call_remote", "reliable")
func receive_vote(map_name: String) -> void:
	if not multiplayer.is_server(): return
	
	# Get the ID of the player who just clicked the button
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Store or update their vote
	_server_player_votes[sender_id] = map_name
	
	_recalculate_votes()

func _recalculate_votes() -> void:
	# 1. Reset all totals to 0
	for key in map_votes.keys():
		map_votes[key] = 0
		
	# 2. Tally up the current votes
	for peer_id in _server_player_votes:
		var voted_map = _server_player_votes[peer_id]
		if map_votes.has(voted_map):
			map_votes[voted_map] += 1
			
	# 3. Blast the new totals to all clients (including the server's local UI)
	rpc("sync_vote_totals", map_votes)

# ==========================================
# SYNC LOGIC (Runs on Everyone) technically server doesnt need this, but it helps debugging
# ==========================================

@rpc("authority", "call_local", "reliable")
func sync_vote_totals(new_totals: Dictionary) -> void:
	map_votes = new_totals
	_update_ui()

func _update_ui() -> void:
	# Loop through the buttons and update their text with the new vote counts
	for child in map_button_v_box.get_children():
		if child is Button and map_votes.has(child.name):
			child.text = child.name + " (" + str(map_votes[child.name]) + ")"
