extends Node2D

var player
var paused = false

'func _ready():
	for i in get_child_count():
		if get_child(i) != player:
			if "Enemy" in get_child(i).name:
				player.is_in_atk_range.connect(get_child(i)._on_player_is_in_atk_range)
				player.take_dmg.connect(get_child(i)._on_player_take_dmg)
				if player.char_name == "Nathan":
					player.grab.connect(get_child(i)._on_player_grab)
					player.shake_camera(player.find_child("Camera2D")._on_player_shake_camera)'

@onready var enemy_container = $Enemy_container

func _process(delta):
	if Input.is_action_just_pressed("pause") and not paused:
		paused = true
		pause_game(paused)
	elif Input.is_action_just_pressed("pause") and paused:
		paused = false
		pause_game(paused)

'ISTANZIA IL PLAYER IN BASE ALLA SELEZIONE DEL NODO GUI
	in base al pulsante selezionato carica la sua scena e la istanzia
	setta il parametro player della root con il nodo appena creato e gli setta la scala
	crea il nodo Camera2D e la istanzia come figlio del player
	se il player ha segnali con la camera aggiunge il suo script, altrimenti va avanti
	rinomina il nodo camera in Camera2D
	fa partire il metodo "connect_enemys_with_player"
	toglie l\'istanzia della GUI'

func _on_gui_select_character(char):
	var player_scene
	if char == "stencil":
		player_scene = load("res://scenes/characters/a_player.tscn")
	elif char == "rufus":
		player_scene = load("res://scenes/characters/rufus.tscn")
	elif char == "nathan":
		player_scene = load("res://scenes/characters/nathan.tscn")
	add_child(player_scene.instantiate())
	get_child(get_child_count()-1).name = "Player"
	player = find_child("Player", true, false)
	player.scale = Vector2(1, 1)
	var camera = Camera2D.new()
	if char == "nathan":
		camera.set_script(load("res://components/scripts/Camera2D.gd"))
		player.scale = Vector2(1.7, 1.7)
	player.add_child(camera,true)
	connect_enemies_with_player()
	find_child("GUI").queue_free()
	
'METODO CHE CONNETTE I SEGNALI AL PLAYER
	cicla ogni nodo figlio della root nella scena,
		se il figlio è diverso dal player e il nome di quel nodo contiene "Enemy" setta il pamaretro "player" del nemico con il player effettivo
		successivamente connette i segnali di base,
		se il player ha dei segnali particolari (tipo Nathan con "grab")'

func connect_enemies_with_player(): #connette i segnali tra il player e i nemici
	for i in enemy_container.get_child_count(): #cicla per ogni figlio della scena
		var current_node = enemy_container.get_child(i)
		if "Enemy" in current_node.name: #se il nome del nemico contiene "Enemy"
			current_node.player = player
			player.is_in_atk_range.connect(current_node._on_player_is_in_atk_range)
			player.take_dmg.connect(current_node._on_player_take_dmg)
			current_node.take_dmg.connect(player._on_enemy_take_dmg)
			if player.char_name == "Nathan":
				player.grab.connect(current_node._on_player_grab)
				player.shake_camera.connect(player.find_child("Camera2D", true, false)._on_player_shake_camera)

func pause_game(get_paused):
	for i in get_child_count():
		if get_paused:
			get_child(i).process_mode = Node.PROCESS_MODE_DISABLED
		else:
			get_child(i).process_mode = Node.PROCESS_MODE_ALWAYS
