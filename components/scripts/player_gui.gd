extends Control

var player

@onready var skill1_cooldown_time = $GridContainer/Control/Skill1_cooldown
@onready var skill2_cooldown_time = $GridContainer/Control/Skill2_cooldown
@onready var eva_cooldown_time = $GridContainer/Control/Eva_cooldown
@onready var ulti_cooldown_time = $GridContainer/Control/Ulti_cooldown

@onready var healthbar = $MarginContainer/PanelContainer/Control/Health_bar
@onready var healthbar_label = $MarginContainer/PanelContainer/Control/Health_bar/Health_label
var max_health

signal player_death()

var alive = false
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if player != null and not alive:
		skill1_cooldown_time.max_value = player.skill1_cooldown.wait_time
		skill2_cooldown_time.max_value = player.skill2_cooldown.wait_time
		eva_cooldown_time.max_value = player.eva_cooldown.wait_time
		ulti_cooldown_time.max_value = player.ulti_cooldown.wait_time
		alive = true
	
	if player != null:
		skill1_cooldown_time.value = player.skill1_cooldown.time_left
		skill2_cooldown_time.value = player.skill2_cooldown.time_left
		eva_cooldown_time.value = player.eva_cooldown.time_left
		ulti_cooldown_time.value = player.ulti_cooldown.time_left
		
	if player == null and alive:
		alive = false
		emit_signal("player_death")

func _on_player_set_health_bar(vit):
	if vit <= 0:
		player.queue_free()
	healthbar.value = vit
	healthbar_label.text = str(vit) + "/" + str(max_health)

func _on_nathan_grab(is_grabbed):
	if is_grabbed:
		player.skill2_cooldown.stop()
		skill2_cooldown_time.tint_under = Color(Color.RED,1)
		player._on_get_healed(player.bite_heal_force)
	else:
		player.skill2_cooldown.start()
		skill2_cooldown_time.tint_under = Color(Color.WHITE,1)
