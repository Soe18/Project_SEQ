extends Camera2D

var shacking = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if shacking:
		shake()


func _on_player_shake_camera(is_shacking):
	shacking = is_shacking
	if is_shacking == true:
		position.y = 6
	else:
		position.y = 0

func shake():
	if position.y == 10:
		position.y = -6
	else:
		position.y = 10
