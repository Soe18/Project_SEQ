extends Node2D

var player
var paused = false
var connected = false

@onready var canvas_layer = find_child("CanvasLayer")
@onready var gui = canvas_layer.find_child("GUI")
@onready var game_over_container = gui.find_child("GameOver_container")
@onready var chara_container = gui.find_child("Chara_selector_container")
@onready var round_gui = canvas_layer.find_child("Round_GUI")
var player_gui

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
	# Gestione del menu di pausa
	if Input.is_action_just_pressed("pause") and not paused:
		paused = true
		pause_game(paused)
	elif Input.is_action_just_pressed("pause") and paused:
		paused = false
		pause_game(paused)
	
	if player != null:
		if not enemy_container.fighting:
			connected = false
		if enemy_container.fighting and not connected:
			connect_enemies_with_player()
			connected = true

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
	player.scale = Vector2(0.95, 0.95)
	
	# creo la telecamera
	var camera = Camera2D.new()
	# impostazioni per la telecamera
	camera.zoom = Vector2(1.6,1.6)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 3
	# condizione per collegare lo script della telecamera
	if char == "nathan":
		camera.set_script(load("res://components/scripts/Camera2D.gd"))
		player.scale = Vector2(1.4, 1.4)
		player.add_child(camera,true) # aggiungo la camera al player
		player.shake_camera.connect(player.find_child("Camera2D", true, false)._on_player_shake_camera)
	else:
		player.add_child(camera,true) # aggiungo la camera al player
	activate_player_GUI() # funzione per attivare le GUI
	connect_enemies_with_player() # connetto i nemici e il player
	gui.visible = false
	canvas_layer.get_child(0).visible = true
	
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
			# segnale tra player e nemici per capire se si è in range
			player.is_in_atk_range.connect(current_node._on_player_is_in_atk_range)
			# segnale tra player e nemici per infliggere danno
			player.take_dmg.connect(current_node._on_player_take_dmg)
			# segnale tra nemici e player per infliggere danno
			current_node.take_dmg.connect(player._on_enemy_take_dmg)
			# se il player ha scelto nathan
			if player.char_name == "Nathan":
				# connetto il segnale della grab
				player.grab.connect(current_node._on_player_grab)
				current_node.got_grabbed.connect(player_gui._on_nathan_grab)
			else:
				player.change_stats.connect(current_node._on_change_stats)

func pause_game(get_paused):
	if get_paused: # se non sono in pausa
		get_tree().paused = true
	else: # se sono in pausa
		get_tree().paused = false

func calculate_dmg(str, atk_str, tem, pbc, efc):
	var dmg = round((str * atk_str) / tem)
	var rng = randi_range(0, 100)
	if pbc > rng:
		dmg = round(dmg * efc)
	print(str(dmg))
	return dmg

func _on_player_death():
	gui.visible = true # la GUI diventa visibile
	game_over_container.visible = true # rendo visibile il game over
	chara_container.visible = false # nascondo i pulsanti della selezione dei personaggi
	player_gui.visible = false # nascondo la gui del player

func activate_player_GUI():
	if player.char_name == "Rufus":
		canvas_layer.add_child(load("res://scenes/GUI/rufus_gui.tscn").instantiate(),true)
	elif player.char_name == "Nathan":
		canvas_layer.add_child(load("res://scenes/GUI/nathan_gui.tscn").instantiate(),true)
	enemy_container.heal_between_rounds.connect(player._on_get_healed)
	player_gui = canvas_layer.get_child(canvas_layer.get_child_count()-1)
	player_gui.player = player
	player_gui.player_death.connect(self._on_player_death)
	player_gui.max_health = player.vit
	player_gui.healthbar.max_value = player.vit
	player_gui.healthbar.value = player.vit
	player_gui.healthbar_label.text = str(player.vit) + "/" + str(player.vit)
	player.set_health_bar.connect(player_gui._on_player_set_health_bar)
