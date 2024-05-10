extends CharacterBody2D

# 39.12px radius effect
# 100px radius explosion
signal entered_body(body)
signal exited_body(body)

var direction = 15
var has_been_send = false
@onready var player = get_parent()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if has_been_send:
		velocity.x += direction
		move_and_slide()

func _on_erase_time_timeout():
	get_parent().remove_child(self)
	player.add_child(self)
	has_been_send = false
	position = Vector2(76, -21)
	$Skill2_area/Effect.play("idle")
	$Skill2_area/Skill_collider.disabled = true

func _on_effect_animation_finished():
	$Erase_time.start()
	has_been_send = true

func _on_skill_2_area_body_entered(body):
	if body != get_parent():
		has_been_send = false
		emit_signal("entered_body", body)
		$Erase_time.start()
		$Skill2_area/Effect.play("explosion")
		$Skill2_area/Skill_collider.shape.radius = 100

func _on_skill_2_area_body_exited(body):
	emit_signal("exited_body", body)

func _on_character_body_2d_send_sk_2(is_flipped):
	var new_parent = get_parent().get_parent()
	get_parent().remove_child(self)
	new_parent.add_child(self)
	velocity = Vector2(0,0)
	if is_flipped:
		$Skill2_area/Effect.flip_h = true
		position = Vector2(player.position.x-100,player.position.y-21)
		direction=-15
	else:
		$Skill2_area/Effect.flip_h = false
		position = Vector2(player.position.x+100,player.position.y-21)
		direction=15
	has_been_send = false
	$Skill2_area/Skill_collider.shape.radius = 39.12
	$Skill2_area/Skill_collider.disabled = false
	$Skill2_area/Effect.play("effect")
