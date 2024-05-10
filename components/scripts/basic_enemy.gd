extends CharacterBody2D

var var_velocity = 2
var is_in_atk_range = false
var moving = true
var grabbed = false

var initial_position

var player

'const SPEED = 300.0
const JUMP_VELOCITY = -400.0'

const MAX_HEALTH = 300

var health

func _ready():
	initial_position = position.y
	health = MAX_HEALTH
	$HealthBar.max_value = MAX_HEALTH
	set_health_bar()

func _physics_process(delta):
	if moving:
		move()
	if grabbed:
		is_grabbed()
	
func move():
	if position.y == initial_position+150:
		var_velocity = -2
	if position.y == initial_position-150:
		var_velocity = 2
	
	position.y += var_velocity
	move_and_slide()

func _on_player_is_in_atk_range(is_in, body):
	(body.name)
	if is_in and body == self:
		("entrato")
		is_in_atk_range = is_in
	else:
		is_in_atk_range = false

func _on_player_take_dmg(atk_state, dmg, sec):
	if is_in_atk_range and !grabbed:
		health -= dmg
		set_health_bar()
		print("take dmg: "+str(dmg))
		moving = false
		$Stun.wait_time = sec
		$Stun.start()
		
func _on_player_grab(is_been_grabbed, is_flipped):
	if is_been_grabbed and !grabbed and is_in_atk_range:
		_on_player_take_dmg(1, 13, 0.1)
		moving = false
		grabbed = true
		$Sprite2D.visible = false
		$CollisionShape2D.disabled = true
	if !is_been_grabbed and grabbed:
		moving = true
		grabbed = false
		if is_flipped:
			position.x += -450
		else:
			position.x += 450
		$Sprite2D.visible = true
		move_and_slide()
		$Timer.start()

func is_grabbed():
	position = player.position

func _on_stun_timeout():
	moving = true

func set_health_bar():
	$HealthBar.value = health
	if health <= 0:
		queue_free()

func _on_timer_timeout():
	$CollisionShape2D.disabled = false
