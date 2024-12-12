extends Node
# To call game_manager, please use:
# get_tree().get_first_node_in_group("gm")

func _ready():
	# Depends on starting scene
	Menu.game_status = Menu.GAME_STATUSES.overworld

func _process(delta):
	if Input.is_action_pressed("pause") and Menu.game_status!=Menu.GAME_STATUSES.unopenable:
		Menu.pause_game()

func load_dungeon():
	Menu.game_status = Menu.GAME_STATUSES.dungeon
	get_child(0).queue_free()
	add_child(load("res://scenes/basic_scene.tscn").instantiate())

func load_map():
	Menu.game_status = Menu.GAME_STATUSES.overworld
	get_child(0).queue_free()
	add_child(load("res://overworld/scenes/maps/default_map.tscn").instantiate())
