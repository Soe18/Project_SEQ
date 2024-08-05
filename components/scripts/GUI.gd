extends Control

signal select_character(char)

func _ready():
	$Chara_selector_container/GridContainer/Select_rufus.grab_focus()
	
func _on_select_stancil_pressed():
	emit_signal("select_character", "stencil")

func _on_select_rufus_pressed():
	emit_signal("select_character", "rufus")

func _on_select_nathan_pressed():
	emit_signal("select_character", "nathan")

func _on_retry_pressed():
	get_tree().change_scene_to_file("res://scenes/basic_scene.tscn")

func _on_exit_pressed():
	get_tree().quit(0)
