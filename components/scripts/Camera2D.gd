extends Camera2D

var shaking = false
var shake_strenght = 2
var shake_duration_timer

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if shaking:
		shake()

func _on_player_shake_camera(is_shaking, strenght):
	shaking = is_shaking
	shake_strenght = strenght
	if not is_shaking:
		offset = Vector2(0,0)
	else:
		shake_duration_timer.start()

func shake():
	offset = Vector2(randf_range(-shake_strenght,shake_strenght),randf_range(-shake_strenght,shake_strenght))
