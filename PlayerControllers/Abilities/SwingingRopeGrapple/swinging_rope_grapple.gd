extends Ability
class_name GrappleSwingAbility

@export_category("Physics Settings")
@export var squeeze_length: float = 0.2
@export var tension_physics: float = 5.0
@export var shoot_force: float = 50.0

@onready var grapple_start: MeshInstance3D = $GrappleStart
@onready var grapple_end: RigidBody3D = $GrappleEnd
@onready var line: Path3D = $Line
@onready var grapple_area: Area3D = $GrappleEnd/Area3D

var tendons: Dictionary = {}
var is_hooked: bool = false
var retracted: bool = true
var retracting: bool = false
var rest_length: float = 1.0
var centripetal_range: float = 0.0
var centri_force: Vector3

const DAMPING_TENDON = 0.96

var _is_held: bool = false
var _was_held: bool = false

func _ready() -> void:
	for i in line.curve.point_count:
		tendons[i] = Vector3.ZERO
	
	grapple_end.hide()
	line.hide()
	release_grapple()

func activate() -> void:
	_is_held = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or not merc: return

	# State Transitions
	if _is_held and not _was_held and retracted:
		connect_grapple()
	elif not _is_held and _was_held and not retracted:
		release_grapple()

	# Swing Physics Logic
	if is_hooked:
		if (grapple_end.global_position - merc.global_position).length() > centripetal_range:
			var angle_dif = grapple_end.global_position - merc.global_position
			centri_force = ((angle_dif).dot(merc.velocity) / angle_dif.length_squared()) * angle_dif
			merc.velocity += -centri_force
			
	elif not retracting and not retracted:
		if grapple_area.has_overlapping_bodies():
			rest_length = 0.1
			is_hooked = true
			grapple_end.freeze = true
			centripetal_range = (grapple_end.global_position - merc.global_position).length()

	# Visuals & Tendon Physics
	if retracted:
		grapple_end.global_position = grapple_start.global_position
		grapple_end.hide()
		line.hide()
	else:
		tendon_puller(delta)

	# Frame Reset
	_was_held = _is_held
	_is_held = false

func connect_grapple() -> void:
	grapple_end.show()
	line.show()
	retracted = false
	grapple_end.freeze = false
	
	if merc.camera:
		grapple_end.apply_central_impulse(-merc.camera.global_basis.z * shoot_force)
		
	rest_length = 1.0

func release_grapple() -> void:
	if is_hooked: 
		merc.velocity.y += 4.0 # Give a little vertical boost on release
		
	grapple_end.freeze = true
	is_hooked = false
	retracting = true
	
	var tween = get_tree().create_tween()
	tween.tween_property(grapple_end, "global_position", grapple_start.global_position, 0.2)
	await tween.finished
	
	retracting = false
	retracted = true

func tendon_puller(delta: float) -> void:
	if tendons.is_empty(): return
		
	rest_length = abs(merc.global_position - grapple_end.global_position).length() * 0.01
	
	for i: int in line.curve.point_count:
		if i != 0 and i != line.curve.point_count - 1:
			var distance = line.curve.get_point_position(i) - line.curve.get_point_position(i + 1)
			if distance.length() > rest_length or distance.length() < squeeze_length:
				tendons[i + 1] += distance * delta * tension_physics
				tendons[i] -= (distance * delta * tension_physics)
			tendons[i] *= DAMPING_TENDON
			
		if i == 0 or i == line.curve.point_count - 1:
			tendons[i] = Vector3.ZERO
			
			if i == 0: 
				line.curve.set_point_position(i, line.to_local(grapple_start.global_position))
			if i == line.curve.point_count - 1:
				line.curve.set_point_position(i, line.to_local(grapple_end.global_position))
				
		line.curve.set_point_position(i, tendons[i] + line.curve.get_point_position(i))
