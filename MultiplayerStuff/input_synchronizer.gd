extends MultiplayerSynchronizer

@onready var player = $".."

var input_direction : Vector2

# Called when the node enters the scene tree for the first time.
func _ready():
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)

	input_direction = Input.get_vector('left',"right","forward","back")

func _physics_process(delta):
	input_direction =  Input.get_vector('left',"right","forward","back")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("jump"):
		jump.rpc()

@rpc("call_local")
func jump():
	player.do_jump = true
