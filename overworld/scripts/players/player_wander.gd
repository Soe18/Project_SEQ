extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var collider = $CollisionShape2D

const is_player = true

var moving = true

@export var OK_MULTIPLYER : float = 350.0
var current_multiplyer = OK_MULTIPLYER
@export var ACCELERATION : float = 10000.0
@export var FRICTION : float = 7000.0

@onready var axis = Vector2.ZERO

func _physics_process(delta):
	if moving:
		move(delta)

func move(delta):
	axis = get_input_axis()
	if axis == Vector2.ZERO:
		apply_friction(FRICTION * delta)
	else:
		sprite.play("running")
		apply_movement(axis * ACCELERATION * delta)
		if axis.x < 0:
			flip_sprite(true)
		elif axis.x > 0:
			flip_sprite(false)
	move_and_slide()

func get_input_axis():
	axis.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	axis.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return axis

func apply_friction(amount):
	if velocity.length() > amount:
		velocity -= velocity.normalized() * amount
	else:
		velocity = Vector2.ZERO
		sprite.play("idle")

func apply_movement(accel):
	velocity += accel
	velocity = velocity.limit_length(current_multiplyer)

func flip_sprite(flip):
	if flip:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _on_dungeon_body_entered(_body):
	get_tree().get_first_node_in_group("gm").load_dungeon()
