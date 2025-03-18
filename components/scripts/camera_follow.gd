extends CharacterBody2D

var player
@onready var camera = $Main_camera
@export var weight : float = 3.4

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_instance_valid(player):
		#var distance = self.global_position.distance_to(player.global_position)
		self.global_position = self.global_position.lerp(player.global_position, delta * weight)
	move_and_slide()
