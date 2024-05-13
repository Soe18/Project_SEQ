extends Control

var player

@onready var skill1_cooldown_time = $PanelContainer/MarginContainer/GridContainer/Control/Skill1_cooldown
@onready var skill2_cooldown_time = $PanelContainer/MarginContainer/GridContainer/Control2/Skill2_cooldown
@onready var eva_cooldown_time = $PanelContainer/MarginContainer/GridContainer/Control3/Eva_cooldown
@onready var ulti_cooldown_time = $PanelContainer/MarginContainer/GridContainer/Control4/Ulti_cooldown

var temp = false
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if player != null and not temp:
		skill1_cooldown_time.max_value = player.skill1_cooldown.wait_time
		skill2_cooldown_time.max_value = player.skill2_cooldown.wait_time
		eva_cooldown_time.max_value = player.eva_cooldown.wait_time
		ulti_cooldown_time.max_value = player.ulti_cooldown.wait_time
		temp = true

	skill1_cooldown_time.value = player.skill1_cooldown.time_left
	skill2_cooldown_time.value = player.skill2_cooldown.time_left
	eva_cooldown_time.value = player.eva_cooldown.time_left
	ulti_cooldown_time.value = player.ulti_cooldown.time_left
