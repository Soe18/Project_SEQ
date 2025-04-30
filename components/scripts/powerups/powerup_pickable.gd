extends StaticBody2D

var player
var handler

var pulled_powerups : Array
var pulled_rarities : Array

var player_in_range = false

signal new_powerup(powerup, rarity)

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("base_atk") and player_in_range:
		player.can_move = false
		handler.new_powerup(pulled_powerups[0], pulled_rarities[0])
		await get_tree().create_timer(0.1).timeout
		player.can_move = true
		player.can_interact_with_something = false
		self.queue_free()

func _on_pickup_range_body_entered(body: Node2D) -> void:
	if body == player:
		player_in_range = true
		player.can_interact_with_something = true

func _on_pickup_range_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_range = false
		player.can_interact_with_something = false
