class_name Fiend extends Merc

const MAX_ANIM_SPEED : float = 2.5
## speeds over this value wont affect anim speed scale
const MAX_SPEED_THRESHOLD : float = 20.0

@onready var animation_player: AnimationPlayer = $cat/AnimationPlayer
@onready var visual_body_mesh: MeshInstance3D = %VisualBodyMesh

@onready var prev_location : Vector3 = self.global_position

var distance : float

func custom_ready():
	visual_body_mesh.hide()
	animation_player.play("walk")

func custom_process(delta : float):
	# manually loop bc im too lazy to change it in the imported scene :)
	if !animation_player.is_playing():
		animation_player.play("walk")
		
	
	# calculating delta to get my own jacked-up velocity val, div by delta to ensure speed scale
	# scales properly with ppls computer speed
	distance = prev_location.distance_to(self.global_position) / delta
	
	animation_player.speed_scale = clamp(remap(distance, 0.1, MAX_SPEED_THRESHOLD, 0, MAX_ANIM_SPEED), 0, MAX_ANIM_SPEED)
	
	# setting prev location to set delta for next frame
	prev_location = self.global_position
