extends Control

var round_count = 0
@onready var round_displayer = $MarginContainer/PanelContainer/Round_displayer

func _ready():
	round_displayer.text = "Ondata: " + str(round_count)

func _on_round_changed():
	round_count += 1
	round_displayer.text = "Ondata: " + str(round_count)
