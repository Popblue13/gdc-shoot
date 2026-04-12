extends Camera3D
class_name LobbyChangerCamera

signal finished_with_all_camera_transitions
signal done_transfering_dollies

var camera_queue : Array[CameraFollowPath] = []
var current_path_following : CameraFollowPath

# Exposed so you can easily tweak transition times in the inspector
@export var transition_duration: float = 1.0

func _ready() -> void:
	process_priority = 10
func _process(delta: float) -> void:
	if current_path_following:
		# 1. Lerp Position
		var target_pos = current_path_following.path_follow_3d.global_position
		global_position = global_position.lerp(target_pos, delta * 12)
		
		# 2. Lerp Rotation (Looking at Marker3D)
		var look_target = current_path_following.marker_3d.global_position
		
		# Only rotate if we aren't perfectly inside the target (prevents look_at errors)
		if global_position.distance_squared_to(look_target) > 0.001:
			# Calculate what our transform WOULD be if we looked perfectly at the target
			var ideal_transform = global_transform.looking_at(look_target, Vector3.UP)
			
			# Slerp our current rotation quaternion to the ideal rotation quaternion
			var target_quat = ideal_transform.basis.get_rotation_quaternion()
			quaternion = quaternion.slerp(target_quat, delta * 12)

func set_dolley_sequence(queue: Array[CameraFollowPath]):
	# BUG FIX: Prevent crash if array is empty
	if queue == null or queue.is_empty(): 
		finished_with_all_camera_transitions.emit()
		return
		
	global_position = queue[0].path_follow_3d.global_position
	make_current()
	
	# Loop using the array's size so we know our index
	for i in range(queue.size()):
		var current_dolley = queue[i]
		var is_last_index = (i == queue.size() - 1)
		
		# This will set the path and wait for the transition duration
		transition_to_next_dolley(current_dolley)
		await done_transfering_dollies
		
		if is_last_index:
			current_dolley.display_lobby_name()
		
		current_dolley.ease_dolley()
		await current_dolley.done_dolley
		
		current_path_following = null
	
	finished_with_all_camera_transitions.emit()

func transition_to_next_dolley(dolley: CameraFollowPath):
	# Set the target immediately so _process takes over the lerping
	current_path_following = dolley 
	
	# Wait for the designated duration while _process handles the smooth movement
	await get_tree().create_timer(transition_duration).timeout
	
	done_transfering_dollies.emit()
