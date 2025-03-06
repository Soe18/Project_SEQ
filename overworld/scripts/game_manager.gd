extends Node
# To call game_manager, please use:
# get_tree().get_first_node_in_group("gm")

enum Attack_Types {PHYSICAL, PROJECTILE}

func _ready():
	# Depends on starting scene
	Menu.game_status = Menu.GAME_STATUSES.unopenable

func _process(delta):
	if Input.is_action_pressed("pause") and Menu.game_status != Menu.GAME_STATUSES.unopenable:
		Menu.pause_game()

func load_dungeon():
	Menu.game_status = Menu.GAME_STATUSES.dungeon
	get_child(0).ost_player.stop()
	var selected_character # attributo da passare
	add_child(load("res://scenes/basic_scene.tscn").instantiate())
	if get_child(0).selected_character: # se l'attributo che devo passare è presente
		selected_character = get_child(0).selected_character # lo setto sul nuovo nodo
		get_child(get_child_count()-1)._on_gui_select_character(selected_character) # ed istanzio il nodo corrispondente
	get_child(0).queue_free()

func load_map():
	Menu.game_status = Menu.GAME_STATUSES.overworld
	var selected_character # attributo da passare
	add_child(load("res://overworld/scenes/maps/default_map.tscn").instantiate())
	if get_child(0).selected_character: # se l'attributo che devo passare è presente
		selected_character = get_child(0).selected_character # lo setto sul nuovo nodo
		get_child(get_child_count()-1)._on_gui_select_character(selected_character) # ed istanzio il nodo corrispondente
	get_child(0).queue_free()
