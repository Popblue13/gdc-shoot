extends Merc
class_name HomeBody

var sitting_in_chair = false
var current_chair = null # <--- NEW: Remembers the chair!

#nothing here! other than some basic ui and text stuff!
func custom_process(delta : float): 
	if sitting_in_chair:
		velocity = Vector3.ZERO
	
func custom_ready():
	for i in abilities:
		if i is HomeBodyHand:
			i.activate()

func play_headset_anim():
	for i in abilities:
		if i is HomeBodyHand:
			await i.pull_headset_on()

func play_headset_anim_reverse():
	for i in abilities:
		if i is HomeBodyHand:
			await i.pull_headset_on()
	
func connect_headset():
	pass
