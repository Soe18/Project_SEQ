extends CharacterBody2D

var player
var bullet_str
var bullet_force
var gun_stun_time = 0.3
var knockback_flag
var direction
var powerup_handler
@onready var atk_type = get_tree().get_first_node_in_group("gm").Attack_Types.PROJECTILE

var queue : Array
var MAX_LENGHT : int = 10

@onready var sprite = $Sprite2D

@onready var time_to_live = $Time_to_live

@onready var trail = $Line2D

@onready var collision = $Area_to_impact/CollisionShape2D

signal take_dmg(str, atk_str, sec_stun, pbc, efc, type)
signal inflict_knockback(amount, force, sender)

@warning_ignore("unused_signal")

func _ready():
	sprite.play("effect")

func _physics_process(_delta):
	queue.push_front(self.position)
	
	if queue.size() > MAX_LENGHT:
		queue.pop_back()
	
	if queue[0].x < queue[-1].x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
	
	trail.clear_points()
	
	for point in queue:
		trail.add_point(point)
	
	velocity = direction * bullet_force
	move_and_slide()

func _on_area_to_impact_body_entered(body):
	if body != player and "Enemy" in body.name:
		body.is_in_atk_range = true
		bullet_force = 0
		if player:
			emit_signal("take_dmg", player.default_str, bullet_str, gun_stun_time, player.current_pbc, player.current_efc, atk_type)
			if knockback_flag:
				var temp = [10]
				temp = powerup_handler.apply_powerup_boost("Alvin", temp)
				if temp == null:
					temp = [0]
					
				emit_signal("inflict_knockback", 10+temp[0], 0.7, self.global_position)
		body.is_in_atk_range = false
		queue_free()

func _on_time_to_live_timeout():
	queue_free()
