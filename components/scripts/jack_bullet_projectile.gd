extends CharacterBody2D

var player
var bullet_str
var bullet_force
var gun_stun_time = 0.3
var knockback_flag
var direction

var queue : Array
var MAX_LENGHT : int = 10

@onready var sprite = $Sprite2D

@onready var time_to_live = $Time_to_live

@onready var trail = $Line2D

@onready var collision = $Area_to_impact/CollisionShape2D

signal take_dmg(str, atk_str, sec_stun, pbc, efc)

func _ready():
	sprite.play("effect")

func _physics_process(delta):
	queue.push_front(self.position)
	
	if queue.size() > MAX_LENGHT:
		queue.pop_back()
	
	trail.clear_points()
	
	for point in queue:
		trail.add_point(point)
	
	velocity = direction * bullet_force
	move_and_slide()

func _on_area_to_impact_body_entered(body):
	if body != player and "Enemy" in body.name:
		body.is_in_atk_range = true
		emit_signal("take_dmg",player.default_str, bullet_str, gun_stun_time, player.current_pbc, player.current_efc)
		body.is_in_atk_range = false
		queue_free()

func _on_time_to_live_timeout():
	queue_free()