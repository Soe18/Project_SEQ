extends Control

@onready var first_btn : Button = $MarginContainer/PanelContainer/MarginContainer/BoxContainer/VBoxContainer/Button
@onready var second_btn : Button = $MarginContainer/PanelContainer/MarginContainer/BoxContainer/VBoxContainer/Button2
@onready var third_btn : Button = $MarginContainer/PanelContainer/MarginContainer/BoxContainer/VBoxContainer/Button3

var pows : Array
var rars : Array

signal new_powerup(powerup, rarity)

func _ready() -> void:
	
	first_btn.text = str(pows[0].p_name) + ", " + str(PowerupStats.rar.find_key(rars[0]))
	second_btn.text = str(pows[1].p_name) + ", " + str(PowerupStats.rar.find_key(rars[1]))
	third_btn.text = str(pows[2].p_name) + ", " + str(PowerupStats.rar.find_key(rars[2]))
	first_btn.grab_focus()

func _on_button_pressed() -> void:
	emit_signal("new_powerup", pows[0], rars[0])
	destroy()

func _on_button_2_pressed() -> void:
	emit_signal("new_powerup", pows[1], rars[1])
	destroy()

func _on_button_3_pressed() -> void:
	emit_signal("new_powerup", pows[2], rars[2])
	destroy()

func destroy():
	self.queue_free()
