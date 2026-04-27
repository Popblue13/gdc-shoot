extends LeaderBoard
class_name DELeaderBoard

const TEAM_COLORS = {
	"red": Color.RED,
	"blue": Color.BLUE,
	"default": Color.WHITE
}

# ==========================================
# SERVER API
# ==========================================

func add_player(player_id: int) -> void:
	if not multiplayer.is_server(): return
	stats[player_id] = { "kills": 0, "deaths": 0, "is_dead": true, "team": "default" }
	_sync_stats.rpc(stats)

func set_player_team(player_id: int, team: String) -> void:
	if not multiplayer.is_server(): return
	if stats.has(player_id):
		stats[player_id]["team"] = team
		_sync_stats.rpc(stats)

func add_kill(player_id: int) -> void:
	if not multiplayer.is_server(): return
	if stats.has(player_id):
		stats[player_id]["kills"] += 1
		_sync_stats.rpc(stats)

func add_death(player_id: int) -> void:
	if not multiplayer.is_server(): return
	if stats.has(player_id):
		stats[player_id]["deaths"] += 1
		stats[player_id]["is_dead"] = true
		_sync_stats.rpc(stats)

func set_alive(player_id: int) -> void:
	if not multiplayer.is_server(): return
	if stats.has(player_id):
		stats[player_id]["is_dead"] = false
		_sync_stats.rpc(stats)

# ==========================================
# SYNC
# ==========================================

@rpc("authority", "call_local", "reliable")
func _sync_stats(new_stats: Dictionary) -> void:
	stats = new_stats
	update_ui()

# ==========================================
# UI
# ==========================================

func update_ui() -> void:
	for child in v_box_container.get_children():
		child.queue_free()
		
	for player_id in stats.keys():
		var player_data = stats[player_id]
		var kills = player_data["kills"]
		var deaths = player_data["deaths"]
		var team = player_data.get("team", "default")
		var status = "DEAD" if player_data.get("is_dead", true) else "ALIVE"
		
		var player_name = get_gamertag(player_id)
		
		var label = Label.new()
		label.text = "%s | Kills: %d | Deaths: %d | %s" % [player_name, kills, deaths, status]
		
		if TEAM_COLORS.has(team):
			label.add_theme_color_override("font_color", TEAM_COLORS[team])
			
		v_box_container.add_child(label)

@rpc("authority", "call_local", "reliable")
func show_end_game_showcase(top_players: Array) -> void:
	is_showcasing = true
	show()
	
	for child in v_box_container.get_children():
		child.queue_free()
		
	var team_scores = {"red": 0, "blue": 0}
	for p_id in stats:
		var t = stats[p_id].get("team", "default")
		if team_scores.has(t):
			team_scores[t] += stats[p_id]["kills"]
			
	var title = Label.new()
	if team_scores["red"] > team_scores["blue"]:
		title.text = "🏆 RED TEAM WINS! 🏆"
		title.add_theme_color_override("font_color", TEAM_COLORS["red"])
	elif team_scores["blue"] > team_scores["red"]:
		title.text = "🏆 BLUE TEAM WINS! 🏆"
		title.add_theme_color_override("font_color", TEAM_COLORS["blue"])
	else:
		title.text = "🤝 MATCH TIED 🤝"
		
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box_container.add_child(title)
	
	var score_label = Label.new()
	score_label.text = "FINAL SCORE -> Red: %d  |  Blue: %d" % [team_scores["red"], team_scores["blue"]]
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box_container.add_child(score_label)
	
	v_box_container.add_child(HSeparator.new())
	
	var mvp_title = Label.new()
	mvp_title.text = "--- MATCH MVPs ---"
	mvp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box_container.add_child(mvp_title)
	
	for i in range(top_players.size()):
		var p_id = top_players[i]
		var p_data = stats[p_id]
		var p_name = get_gamertag(p_id)
		
		var label = Label.new()
		label.text = "#%d: %s - %d Kills" % [i + 1, p_name, p_data["kills"]]
		
		var team = p_data.get("team", "default")
		if TEAM_COLORS.has(team):
			label.add_theme_color_override("font_color", TEAM_COLORS[team])
			
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v_box_container.add_child(label)
