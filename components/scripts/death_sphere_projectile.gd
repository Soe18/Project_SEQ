extends CharacterBody2D

var player
var player_position : Vector2
var origin : Vector2
var lich_str
var lich_pbc
var lich_efc

@onready var sprite = $Sprite2D

@onready var time_to_live = $Time_to_live

@onready var area_of_effect = $Area2D/CollisionShape2D

signal take_dmg(str, atk_str, sec_stun, pbc, efc)

'
effect y = -18.5
0.11

impact y = -32
0.47
'

func _ready():
	sprite.play("spawn")
	origin = global_position

func _physics_process(delta):
	if sprite.animation == "effect":
		go_to_player()

func go_to_player():
	var direction = global_position.direction_to(player_position)
	
	if global_position.distance_to(origin) >= player_position.distance_to(origin):
		impact()
		
	velocity = direction * 650
	move_and_slide()

func _on_area_to_impact_body_entered(body):
	if body == player:
		impact()

func _on_area_2d_body_entered(body):
	if body == player:
		emit_signal("take_dmg",lich_str, 25, 2, lich_pbc, lich_efc)

func _on_sprite_2d_animation_finished():
	if sprite.animation == "spawn":
		sprite.play("effect")
		sprite.offset.y = -18.5
		sprite.rotation_degrees = -90
		look_at(player.global_position)
		reparent(get_parent().get_parent())
	else:
		queue_free()

func _on_time_to_live_timeout():
	impact()

func impact():
	area_of_effect.set_deferred("disabled", false)
	rotation_degrees = 0
	sprite.rotation_degrees = 0
	sprite.offset.y = -32
	sprite.scale = Vector2(0.47,0.47)
	sprite.play("impact")

