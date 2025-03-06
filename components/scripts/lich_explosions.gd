extends CharacterBody2D

var lich_str
var lich_pbc
var lich_efc
var player
@onready var atk_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

@onready var sprite = $Sprite2D

@onready var area_of_effect = $Area_of_effect/CollisionShape2D

signal take_dmg(str, atk_str, sec_stun, pbc, efc)

func _ready():
	sprite.play("effect")

func _on_area_of_effect_body_entered(body):
	if body == player:
		emit_signal("take_dmg",lich_str, 17, 3, lich_pbc, lich_efc, atk_type)

func _on_sprite_2d_animation_finished():
	queue_free()

func _on_sprite_2d_frame_changed():
	if sprite.frame == 1:
		area_of_effect.set_deferred("disabled", false)
