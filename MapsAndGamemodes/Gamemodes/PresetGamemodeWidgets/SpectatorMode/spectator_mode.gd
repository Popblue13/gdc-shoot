extends Control

var players_to_watch : Array[Node] = []
var idx = 0
@onready var player_watching: Label = $PlayerWatching

func _ready() -> void:
	hide()

# Call this to rebuild the list of alive players
func refresh_players() -> void:
	players_to_watch.clear()
	
	# Assuming this UI is a child of the DE map, get the map node
	var map_node = get_parent() 
	if not map_node: return
	
	# Find all active Mercs
	for child in map_node.get_children():
		if child is Merc and not child.dead:
			players_to_watch.append(child)
			
	if players_to_watch.is_empty():
		player_watching.text = "No players alive"
		return
		
	# Clamp index so it doesn't break if the list shrank
	idx = clampi(idx, 0, max(0, players_to_watch.size() - 1))
	switch_player_view()

func _process(_delta: float) -> void:
	# If we are actively spectating, check if our target died or disconnected
	if visible:
		if players_to_watch.size() > 0:
			var current_target = players_to_watch[idx]
			if not is_instance_valid(current_target) or current_target.dead:
				refresh_players() # Target died, find someone else!

func _on_right_pressed() -> void:
	refresh_players()
	if players_to_watch.is_empty(): return
	
	# Modulo math safely wraps the index back to 0 if we go over the max
	idx = (idx + 1) % players_to_watch.size()
	switch_player_view()

func _on_left_pressed() -> void:
	refresh_players()
	if players_to_watch.is_empty(): return
	
	# Safely wraps the index to the end if we go below 0
	idx = (idx - 1 + players_to_watch.size()) % players_to_watch.size()
	switch_player_view()

func switch_player_view() -> void:
	if players_to_watch.is_empty(): return
	var target = players_to_watch[idx]
	
	# Switch the camera
	if is_instance_valid(target) and target.camera:
		target.camera.make_current()
	# Look up their name in the database based on their node name (peer ID)
	var pid = target.name.to_int()
	if ServerDatabase.Players.has(pid):
		update_player_name(ServerDatabase.Players[pid]["gamertag"])
	else:
		update_player_name("Player " + str(pid))

func update_player_name(player_name: String) -> void:
	if player_watching:
		player_watching.text = player_name
