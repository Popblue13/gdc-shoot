@abstract class_name WeaponAbility extends Ability

@abstract func shoot()
@abstract func equip()
@abstract func dequip()

##
## DO NOT FREAKING OVERRIDE ACTIVATE FOR THE WEAPON CLASS THIS EXISTS HERE 
##
func activate():
	if !currently_active:
		currently_active = true
		for i in abilities:
			if i is WeaponAbility and i != self:
				i.dequip()
				i.currently_active = false
		equip()

func connected_process():
	pass
