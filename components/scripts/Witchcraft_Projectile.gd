extends CharacterBody2D

var player
var player_position : Vector2
var origin : Vector2
var first_direction
var first_enter = true
var lich_str
var lich_pbc
var lich_efc
@onready var atk_type = get_tree().get_first_node_in_group("gm").Attack_Types.PROJECTILE

@onready var sprite = $Sprite2D

@onready var time_to_live = $Time_to_live

@onready var collision = $Area_to_impact/CollisionShape2D

signal take_dmg(str, atk_str, sec_stun, pbc, efc, type, sender)

func _ready():
	sprite.play("effect")
	origin = global_position

func _physics_process(delta):
	if sprite.animation == "effect":
		go_to_player()

func go_to_player():
	var direction = global_position.direction_to(player_position)
	
	if first_enter:
		first_direction = direction
		first_enter = false
	
	if global_position.distance_to(origin) >= player_position.distance_to(origin):
		direction = first_direction
		
	velocity = direction * 800
	move_and_slide()

func _on_area_to_impact_body_entered(body):
	if body == player:
		impact()
		emit_signal("take_dmg",lich_str, 8, 0.5, lich_pbc, lich_efc, atk_type, self)

func _on_sprite_2d_animation_finished():
	queue_free()

func _on_time_to_live_timeout():
	impact()

func impact():
	sprite.offset = Vector2(280,-87)
	sprite.play("impact")
	collision.disabled = true
