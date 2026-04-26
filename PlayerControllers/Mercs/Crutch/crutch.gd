extends Merc
@rpc("any_peer", "call_remote", "reliable")
func turret_take_damage(name, damage):
	for child in get_children():
		if child.name == name:
			child.take_real_damage(damage)
