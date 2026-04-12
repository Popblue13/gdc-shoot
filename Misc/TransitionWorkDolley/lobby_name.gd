extends Label

@export var min_font_size: int = 12
# Set max size to roughly the height of your Transform box (162px in your screenshot)
@export var max_font_size: int = 160 

var _last_text: String = ""

func _ready() -> void:
	# Crucial: Ensures text doesn't visibly bleed out of the box
	clip_text = true 
	_update_font_size()

# Automatically activates whenever the text is changed by any other script
func _process(_delta: float) -> void:
	if text != _last_text:
		_last_text = text
		_update_font_size()

func _update_font_size() -> void:
	if text.is_empty():
		return
		
	# Grab whatever font you assigned to this Label
	var font: Font = get_theme_font("font")
	if font == null:
		push_warning("LobbyName Label needs a font assigned to AutoSize!")
		return
		
	var low: int = min_font_size
	var high: int = max_font_size
	var best_size: int = min_font_size
	
	# Binary search: Calculates the perfect fit in a fraction of a millisecond
	while low <= high:
		var mid = low + (high - low) / 2
		
		# Measure how much space the string takes up at the 'mid' font size
		var text_size = font.get_string_size(text, horizontal_alignment, -1, mid)
		
		# Check if this size fits entirely within the Label's Transform Size
		if text_size.x <= size.x and text_size.y <= size.y:
			best_size = mid # It fits! Save this as the best size.
			low = mid + 1   # Try going a little bigger to see if it still fits.
		else:
			high = mid - 1  # Too big! Cut the size down.
			
	# Apply the mathematically perfect font size`
	add_theme_font_size_override("font_size", best_size)
