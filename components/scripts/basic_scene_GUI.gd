extends Control

var round_count = 1
@onready var round_displayer = $MarginContainer/PanelContainer/Round_displayer

@onready var healthbar = $Boss_GUI/Health_bar
@onready var healthbar_label = $Boss_GUI/Health_bar/Health_label

@onready var animation_player = $AnimationPlayer
 
var max_health

var boss

func _ready():
	round_displayer.text = "Ondata: " + str(round_count)

func _on_round_changed():
	round_count += 1
	round_displayer.text = "Ondata: " + str(round_count)

func _on_boss_set_healthbar(vit):
	if vit <= 0:
		if get_parent().player.char_name == "Nathan":
			emit_signal("got_grabbed", false)
		boss.dying = true
		boss.update_atk_timer.stop()
		boss.set_idle_timer.stop()
		animation_player.play("delete_boss_bar")
	healthbar.value = vit
	healthbar_label.text = boss.boss_name + ": " + str(vit) + "/" + str(max_health)

func _on_boss_spawned(boss):
	animation_player.play("spawn_boss_bar")
	self.boss = boss
	max_health = boss.default_vit
	healthbar_label.text = boss.boss_name + ": " + str(boss.current_vit) + "/" + str(max_health)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "spawn_boss_bar":
		healthbar.max_value = max_health
		healthbar.value = boss.current_vit
	if anim_name == "delete_boss_bar":
		boss = null
		healthbar.max_value = 100
