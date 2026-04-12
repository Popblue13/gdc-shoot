@abstract 
class_name Ability extends Node3D

var currently_active = false

const PRIORITY_KEYS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const FALLBACK_KEYS: Array[String] = [
	"E", "Q", "F", "G", "H", "V", "B", "N", "M", "T", "Y", "X", "C", "Z",
	"Shift", "Ctrl", "Alt", "Space", "CapsLock", "Enter",
]

@abstract func activate(abilities : Array[Ability], merc : Merc)

@export_category("Ability Mapping")
@export_enum(
	"Passive",
	# --- LETTERS ---
	"E", "Q", "F",
	"G", "H", "V", "B", "N", "M", "T", "Y", "X", "C", "Z",
	# --- NUMBERS ---
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
	# --- MODIFIERS ---
	"Shift", "Ctrl", "Alt", "Space", "CapsLock", "Enter",
) var trigger_key: String = "Passive"


func equip_ability(abilities: Array[Ability]) -> void:
	# Passives generally shouldn't conflict with active keybinds, 
	# so we can skip the rebinding logic for them.
	if trigger_key == "Passive":
		return
		
	var used_keys: Array[String] = []
	var has_conflict: bool = false
	
	# 1. Gather all keys currently in use by OTHER abilities
	for ability in abilities:
		# Skip checking against ourselves if we are already in the array
		if ability == self:
			continue
			
		used_keys.append(ability.trigger_key)
		
		# Check if our current key is already taken
		if ability.trigger_key == self.trigger_key:
			has_conflict = true

	# 2. If there's a conflict, find a new key
	if has_conflict:
		var new_key_found: bool = false
		
		# First pass: Check priority numbers
		for key in PRIORITY_KEYS:
			if not used_keys.has(key):
				trigger_key = key
				new_key_found = true
				break
				
		# Second pass: Check fallback keys if all numbers are taken
		if not new_key_found:
			for key in FALLBACK_KEYS:
				if not used_keys.has(key):
					trigger_key = key
					break


func dequip_ability() -> void:
	pass
