extends CharacterBody2D

var player
var player_position : Vector2
var origin : Vector2
var first_direction
var first_enter = true
var fae_str
var fae_pbc
var fae_efc
@onready var atk_type = get_tree().get_first_node_in_group("gm").Attack_Types.PROJECTILE

var queue : Array
var MAX_LENGHT : int = 20

var enchantment_force = 9
var enchantment_stun_time = 5.0

var enchantment_velocity_multiplyer = 500

@onready var sprite = $Sprite2D

@onready var trail = $Line2D

@onready var time_to_live = $Time_to_live

signal take_dmg(str, atk_str, sec_stun, pbc, efc, type, sender)

func _ready():
	sprite.play("effect")
	origin = global_position

func _physics_process(_delta):
	if sprite.animation == "effect":
		go_to_player()

func go_to_player():
	var direction = global_position.direction_to(player_position)
	
	if first_enter:
		first_direction = direction
		first_enter = false
	
	if global_position.distance_to(origin) >= player_position.distance_to(origin):
		direction = first_direction
	
	queue.push_front(self.position)
	
	if queue.size() > MAX_LENGHT:
		queue.pop_back()
	
	trail.clear_points()
	
	for point in queue:
		trail.add_point(point)
	
	velocity = direction * enchantment_velocity_multiplyer
	move_and_slide()

func _on_area_to_impact_body_entered(body):
	if body == player:
		emit_signal("take_dmg",fae_str, enchantment_force, enchantment_stun_time, fae_pbc, fae_efc, atk_type, self)
		queue_free()

func _on_time_to_live_timeout():
	queue_free()
