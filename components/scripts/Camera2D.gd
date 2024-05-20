extends Camera2D

var shaking = false
var shake_strenght = 15

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if shaking:
		shake()

func _on_player_shake_camera(is_shacking):
	shaking = is_shacking
	if not is_shacking:
		offset = Vector2(0,0)

func shake():
	offset = Vector2(randf_range(-shake_strenght,shake_strenght),randf_range(-shake_strenght,shake_strenght))
