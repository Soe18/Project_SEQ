extends StaticBody2D

var player
var handler
var canvas_layer

var powerup_dialog_scene = preload("res://scenes/GUI/powerup_dialog.tscn")

@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
@onready var pickup_range: Area2D = $Pickup_range
@onready var sprite_2d: Sprite2D = $Sprite2D

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
		powerup_dialog_instance.rarity_selected.connect(self._on_dialog_rarity_selected)
		canvas_layer.add_child(powerup_dialog_instance)
		Menu.game_status = Menu.GAME_STATUSES.unopenable
		
		await powerup_dialog_instance.tree_exited
		
		Menu.game_status = Menu.GAME_STATUSES.dungeon
		player.can_move = true
		player.can_interact_with_something = false
		pickup_range.monitoring = false
		sprite_2d.visible = false
		
		gpu_particles_2d.emitting = true

func _on_pickup_range_body_entered(body: Node2D) -> void:
	if body == player:
		player_in_range = true
		player.can_interact_with_something = true

func _on_pickup_range_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_range = false
		player.can_interact_with_something = false

func _on_dialog_rarity_selected(rar) -> void:
	if rar == 0:
		gpu_particles_2d.process_material.set("color", PowerupStats.RARITY_COLORS["common"])
	if rar == 1:
		gpu_particles_2d.process_material.set("color", PowerupStats.RARITY_COLORS["uncommon"])
	if rar == 2:
		gpu_particles_2d.process_material.set("color", PowerupStats.RARITY_COLORS["rare"])
	if rar == 3:
		gpu_particles_2d.process_material.set("color", PowerupStats.RARITY_COLORS["epic"])
	if rar == 4:
		gpu_particles_2d.process_material.set("color", PowerupStats.RARITY_COLORS["legendary"])

func _on_gpu_particles_2d_finished() -> void:
	self.queue_free()
