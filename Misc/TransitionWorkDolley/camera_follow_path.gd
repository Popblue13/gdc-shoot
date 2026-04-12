extends Path3D
class_name CameraFollowPath

signal done_dolley

@export var easing_graph : Curve
@onready var path_follow_3d: PathFollow3D = $PathFollow3D
@onready var marker_3d: Marker3D = $CameraTargetPoint
@onready var lobby_name: Label = $LobbyName
@export var dur : float = 1.5

func ease_dolley():
	# DIAGNOSTIC 1: Is the node actually awake?
	if not can_process():
		printerr("🚨 ERROR: " + self.name + " (or its parent Lobby) is set to PROCESS_MODE_DISABLED! The Tween will pause forever.")
		# We force it to emit here so your whole game doesn't permanently freeze while testing
		done_dolley.emit() 
		return
	# DIAGNOSTIC 2: Did you assign the Curve in the Inspector?
	if easing_graph == null:
		printerr("🚨 ERROR: easing_graph is null! You forgot to add a Curve resource to the Inspector for this path.")
		done_dolley.emit()
		return
	# DIAGNOSTIC 3: Did the node reference break?
	if path_follow_3d == null:
		printerr("🚨 ERROR: path_follow_3d is null! Check your node paths.")
		done_dolley.emit()
		return
	
	# Kill any existing tweens on this node to prevent conflicts
	var tween = create_tween()
	tween.tween_method(
		func(t: float): path_follow_3d.progress_ratio = easing_graph.sample(t),
		0.0, 
		1.0, 
		dur
	)
	await tween.finished
	done_dolley.emit()
	await get_tree().create_timer(1.0).timeout
	path_follow_3d.progress_ratio = 0.0

func set_dolly_points(path: CameraFollowPath, path_new: CameraFollowPath):
	# 1. PREVENT CRASHES: Ensure everything exists and has points
	if path == null or path.curve == null or path.curve.point_count == 0:
		printerr("Source path is invalid or empty!")
		return
	if path_new == null or path_new.curve == null or path_new.curve.point_count == 0:
		printerr("Destination path is invalid or empty!")
		return
	if curve == null:
		return
		
	# Ensure our transition curve actually has at least 2 points to modify
	while curve.point_count < 2:
		curve.add_point(Vector3.ZERO)

	# 2. YOUR MATH: Calculate global positions first to keep it readable
	var start_global = path.to_global(path.curve.get_point_position(path.curve.point_count - 1))
	var end_global = path_new.to_global(path_new.curve.get_point_position(0))

	# Apply to local space
	curve.set_point_position(0, to_local(start_global))
	curve.set_point_position(1, to_local(end_global))
	
	# 3. PREVENT LOOPS: Zero out the bezier handles so it forms a straight, clean line
	# (You can remove this if you are actively calculating handles for a curved swoop)
	curve.set_point_in(0, Vector3.ZERO)
	curve.set_point_out(0, Vector3.ZERO)
	curve.set_point_in(1, Vector3.ZERO)
	curve.set_point_out(1, Vector3.ZERO)

func display_lobby_name():
	if lobby_name == null: return
	
	var map_name_string: String = "Unknown Map"
	
	# The 'owner' of CameraFollowPath is usually the root of the saved scene (the Lobby).
	# If owner is null (e.g., added via code without setting owner), fallback to parent.
	var lobby_node = owner if owner else get_parent()
	
	if lobby_node:
		# Search through the Lobby's children to find the Map node
		for child in lobby_node.get_children():
			if child is Map:
				map_name_string = child.map_name
				break
				
	lobby_name.text = map_name_string
	
	await get_tree().create_timer(1.0).timeout
	lobby_name.show()
	await get_tree().create_timer(3.0).timeout
	lobby_name.hide()
