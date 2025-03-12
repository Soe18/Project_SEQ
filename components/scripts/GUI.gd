extends Control

signal select_character(char)

@onready var rufus_button = self.get_child(0).get_child(0).find_child("Select_rufus")
@onready var jack_button = self.get_child(0).get_child(0).find_child("Select_jack")

@warning_ignore("unused_signal")

func _ready():
	# non best solution lo so però è la più semplice e veloce
	if rufus_button: # controllo se almeno un pulsante esiste, se si sono nell'overworld, altrimenti no
		#rufus_button.grab_focus()
		jack_button.grab_focus()

func _on_select_stancil_pressed():
	emit_signal("select_character", "jack")

func _on_select_rufus_pressed():
	emit_signal("select_character", "rufus")

func _on_select_nathan_pressed():
	emit_signal("select_character", "nathan")

func _on_retry_pressed():
	get_tree().get_first_node_in_group("gm").load_dungeon()

func _on_exit_pressed():
	get_tree().get_first_node_in_group("gm").load_map()
