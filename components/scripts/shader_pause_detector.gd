extends ColorRect

var speed_multiplyer : float = self.material.get("shader_parameter/speed_multiplyer")

var speed_scale : float = 0

func _process(_delta: float) -> void:
	speed_scale = (speed_scale + speed_multiplyer)
	if speed_scale == 3600:
		speed_scale = 0
	self.material.set("shader_parameter/speed_scale", speed_scale)
	
