extends Control

signal select_character(char)

func _ready():
	#$Chara_selector_container/GridContainer/Select_rufus.grab_focus()
	$Chara_selector_container/GridContainer/Select_nathan.grab_focus()

func _on_select_stancil_pressed():
	emit_signal("select_character", "jack")

func _on_select_rufus_pressed():
	emit_signal("select_character", "rufus")

func _on_select_nathan_pressed():
	emit_signal("select_character", "nathan")

func _on_retry_pressed():
	# Modified :D
	get_tree().get_first_node_in_group("gm").load_dungeon()

func _on_exit_pressed():
	# Modified :D
	get_tree().get_first_node_in_group("gm").load_map()
