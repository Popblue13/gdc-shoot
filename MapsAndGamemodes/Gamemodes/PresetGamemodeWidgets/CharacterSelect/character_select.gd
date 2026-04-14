extends Control
class_name CharacterSelect

signal character_locked_in(merc_name: String)

@onready var spin_spawn: Marker3D = $PanelContainer/SubViewportContainer/SubViewport/SpinSpawn
@onready var merc_select_buttons: VBoxContainer = $MercSelectButtons
@onready var abilities_container: VBoxContainer = $Abilities
@onready var lock_in_button: Button = $LockIn

var selected_merc_name: String = ""
var current_preview_model: Node3D = null

func _ready() -> void:
	# Disable the lock-in button until a character is picked
	lock_in_button.disabled = true
	lock_in_button.pressed.connect(_on_lock_in_pressed)
	
	register_mercs()

func _process(delta: float) -> void:
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func register_mercs() -> void:
	# 1. Clear out any placeholder buttons from the editor
	for child in merc_select_buttons.get_children():
		child.queue_free()
		
	# 2. Loop through the database and generate buttons
	for merc_name in ServerDatabase.Mercs:
		var btn = Button.new()
		btn.text = merc_name.capitalize() # Makes "default" look like "Default"
		
		# Use .bind() to pass the specific dictionary key into the function
		btn.pressed.connect(_on_merc_button_pressed.bind(merc_name))
		
		merc_select_buttons.add_child(btn)

func _on_merc_button_pressed(merc_name: String) -> void:
	selected_merc_name = merc_name
	lock_in_button.disabled = false
	
	# 1. Instantiate a temporary Merc in memory to read its data
	var merc_scene: PackedScene = ServerDatabase.Mercs[merc_name]
	var temp_merc: Merc = merc_scene.instantiate()
	
	# 2. Update the UI
	_update_visual_preview(temp_merc)
	_update_abilities_ui(temp_merc)
	
	# 3. Destroy the temporary Merc so its gameplay scripts don't run in the background
	temp_merc.queue_free()

func _update_visual_preview(temp_merc: Merc) -> void:
	# Clear the old 3D model off the pedestal
	if current_preview_model:
		current_preview_model.queue_free()
		current_preview_model = null
		
	# Extract and duplicate the visual_body so we can safely delete the temp_merc later
	if temp_merc.visual_body:
		current_preview_model = temp_merc.visual_body.duplicate()
		spin_spawn.add_child(current_preview_model)
		
		# Reset its transform so it sits perfectly on the SpinSpawn Marker3D
		current_preview_model.position = Vector3.ZERO
		current_preview_model.rotation = Vector3.ZERO

func _update_abilities_ui(temp_merc: Merc) -> void:
	# Clear the old ability list
	for child in abilities_container.get_children():
		child.queue_free()
		
	# Recursively find all Ability nodes attached to the Merc
	var abilities: Array[Ability] = _find_abilities(temp_merc)
	
	if abilities.is_empty():
		var fallback_label = Label.new()
		fallback_label.text = "No abilities found."
		abilities_container.add_child(fallback_label)
		return
		
	# Generate a label for each ability
	for ability in abilities:
		var label = Label.new()
		# Format: "[Q] - Throws a grenade"
		label.text = "[%s] - %s" % [ability.trigger_key, ability.AbilityDescription]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		abilities_container.add_child(label)

# Helper function to find Ability nodes, even if they are nested deep inside the Merc
func _find_abilities(node: Node) -> Array[Ability]:
	var found_abilities: Array[Ability] = []
	for child in node.get_children():
		if child is Ability:
			found_abilities.append(child)
		# Check the children of the children
		found_abilities.append_array(_find_abilities(child)) 
	return found_abilities

func _on_lock_in_pressed() -> void:
	# Emit the string back to whatever Lobby/Map scene spawned this UI
	character_locked_in.emit(selected_merc_name)
