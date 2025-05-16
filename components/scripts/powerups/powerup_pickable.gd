extends StaticBody2D

var player
var handler
var canvas_layer

var powerup_dialog_scene = preload("res://scenes/GUI/powerup_dialog.tscn")

var pulled_powerups : Array
var pulled_rarities : Array

var player_in_range = false

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept") and player_in_range and player.can_move:
		player._on_set_idle()
		player.can_move = false
		var powerup_dialog_instance = powerup_dialog_scene.instantiate()
		powerup_dialog_instance.pows = pulled_powerups
		powerup_dialog_instance.rars = pulled_rarities
		powerup_dialog_instance.new_powerup.connect(handler.new_powerup)
		canvas_layer.add_child(powerup_dialog_instance)
		Menu.game_status = Menu.GAME_STATUSES.unopenable
		
		await powerup_dialog_instance.tree_exited
		
		Menu.game_status = Menu.GAME_STATUSES.dungeon
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
