extends Camera2D

var shaking = false
var shake_strenght : float = 0.0
var shake_fade : float = 4.5

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if shaking:
		shake()
		
		if shake_strenght > 0:
			shake_strenght = lerpf(shake_strenght, 0, shake_fade * delta)

func _on_player_shake_camera(is_shaking, strenght):
	shaking = is_shaking
	if strenght != 0:
		shake_strenght = strenght
	if not is_shaking:
		offset = Vector2(0,0)

func shake():
	offset = Vector2(randf_range(-shake_strenght,shake_strenght),randf_range(-shake_strenght,shake_strenght))
