extends Control

signal select_character(char)

func _on_select_stancil_pressed():
	emit_signal("select_character", "stencil")

func _on_select_rufus_pressed():
	emit_signal("select_character", "rufus")

func _on_select_nathan_pressed():
	emit_signal("select_character", "nathan")
