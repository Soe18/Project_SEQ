extends AnimatedSprite2D

@onready var player
var player_in_range = false

@onready var animation_player = $AnimationPlayer

signal change_stage()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("base_atk") and player_in_range:
		self.z_index = 99
		player.can_move = false
		animation_player.play("travel")

func _on_area_of_interaction_body_entered(body):
	if body == player:
		print("entrato")
		player_in_range = true

func _on_area_of_interaction_body_exited(body):
	if body == player:
		player_in_range = false

func emit_signal_mid_animation():
	emit_signal("change_stage")

func activate_player():
	player.can_move = true
