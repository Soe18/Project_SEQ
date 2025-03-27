extends CharacterBody2D

@onready var target_point
var vel_multiplyer
@onready var caller

signal target_reached()

func _physics_process(delta: float) -> void:
	self.global_position = self.global_position.lerp(target_point, vel_multiplyer * delta)
	
	if global_position.distance_to(target_point) < 3:
		emit_signal("target_reached")
		queue_free()
	
	move_and_slide()
