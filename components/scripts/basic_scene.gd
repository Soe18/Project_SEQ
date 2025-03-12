extends Node2D

var player
var selected_character
var paused = false
var connected = false
var boss_defeted_count = 0
var active_tileset : Node2D
var active_enemy_container : Node2D
@onready var Attack_Types = get_tree().get_first_node_in_group("gm").Attack_Types

# il nodo canvaslayer serve per fissare la gui allo schermo
@onready var canvas_layer = find_child("CanvasLayer") 
# contenitore della gui della scena
@onready var gui = canvas_layer.find_child("GUI")
# contenitore della gui di game over
@onready var game_over_container = gui.find_child("GameOver_container")
# contenitore della gui del combattimento
@onready var round_gui = canvas_layer.find_child("Round_GUI")
# music player che contiene le ost
@onready var ost_player = $Ost_player
# contenitore della gui di pausa
@onready var pause_gui = $CanvasLayer/Pause_GUI
# riferimento all'animation player della pause gui
@onready var pause_animation_player = $CanvasLayer/Pause_GUI/PanelContainer/VBoxContainer/AnimationPlayer
# variabile che contiene la gui specifica per quel player
var player_gui

@onready var shake_duration_timer = $Shake_duration

var tilesets = ["res://scenes/tilemaps/gray_tile_map.tscn","res://scenes/tilemaps/lightblue_tile_map.tscn", "res://scenes/tilemaps/forest_tile_map.tscn", "res://scenes/tilemaps/deep_forest_tile_map.tscn"]
var enemy_containers = ["res://scenes/miscellaneous/gray_enemy_container.tscn","res://scenes/miscellaneous/lightblue_enemy_container.tscn", "res://scenes/miscellaneous/forest_enemy_container.tscn", "res://scenes/miscellaneous/deep_forest_enemy_container.tscn"]

var portal

@warning_ignore("unused_parameter")
@warning_ignore("unused_signal")
@warning_ignore("shadowed_global_identifier")

func _ready():
	var temp : Array
	for i in tilesets.size():
		temp.append(i)
	
	#temp.shuffle()
	
	var new_tileset_order : Array
	var new_container_order : Array
	
	for i in temp:
		new_tileset_order.append(tilesets[i])
		new_container_order.append(enemy_containers[i])
	
	tilesets = new_tileset_order
	enemy_containers = new_container_order
	
	Menu.game_status = Menu.GAME_STATUSES.unopenable
	add_child(load(tilesets[boss_defeted_count]).instantiate(),true)
	active_tileset = get_child(get_child_count(true)-1)
	
	add_child(load(enemy_containers[boss_defeted_count]).instantiate(),true)
	active_enemy_container = get_child(get_child_count(true)-1)
	
	active_enemy_container.round_changed.connect(round_gui._on_round_changed)
	active_enemy_container.boss_defeted.connect(self._on_boss_defeted)
	active_enemy_container.connect_boss_with_GUI.connect(round_gui._on_boss_spawned)

func _process(_delta):
	if Input.is_action_just_pressed("fullscreen_toggle"):
		if DisplayServer.window_get_mode(0) != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	#
	#if Input.is_action_just_pressed("reload_scene"):
		## It reloads the dungeon, just for debuggin, this is ok :D
		#get_tree().get_first_node_in_group("gm").load_dungeon()
	
	if player != null:
		if not active_enemy_container.fighting:
			connected = false
		if active_enemy_container.fighting and not connected:
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
	selected_character = char
	if char == "jack":
		player_scene = load("res://scenes/characters/jack.tscn")
	elif char == "rufus":
		player_scene = load("res://scenes/characters/rufus.tscn")
	elif char == "nathan":
		player_scene = load("res://scenes/characters/nathan.tscn")
	add_child(player_scene.instantiate())
	get_child(get_child_count()-1).name = "Player"
	player = find_child("Player", true, false)
	player.scale = Vector2(1.0, 1.0)
	
	# impostazioni per la telecamera
	player.shake_camera.connect(player.find_child("Main_camera", true, false)._on_player_shake_camera)
	
	# debug: zoom diminuito
	#camera.zoom = Vector2(0.5,0.5)
	
	# condizione per collegare lo script della telecamera
	if char == "nathan":
		player.scale = Vector2(1.4, 1.4)
	activate_player_GUI() # funzione per attivare le GUI
	connect_enemies_with_player() # connetto i nemici e il player
	gui.visible = false
	canvas_layer.get_child(0).visible = true
	Menu.game_status = Menu.GAME_STATUSES.dungeon

# METODO CHE CONNETTE I SEGNALI AL PLAYER
#	cicla ogni nodo figlio della root nella scena,
#		se il figlio è diverso dal player e il nome di quel nodo contiene "Enemy" setta il pamaretro "player" del nemico con il player effettivo
#		successivamente connette i segnali di base,
#		se il player ha dei segnali particolari (tipo Nathan con "grab")

func connect_enemies_with_player(): #connette i segnali tra il player e i nemici
	for i in active_enemy_container.get_child_count(): #cicla per ogni figlio della scena
		var current_node = active_enemy_container.get_child(i)
		
		#se il nome del nemico contiene "Enemy"
		if "Enemy" in current_node.name: 
			# assegno il parametro player del nemico con il player attivo
			current_node.player = player
			# segnale tra player e nemici per capire se si è in range
			player.is_in_atk_range.connect(current_node._on_player_is_in_atk_range)
			# segnale tra player e nemici per infliggere danno
			player.take_dmg.connect(current_node._on_player_take_dmg)
			# segnale tra nemici e player per infliggere danno
			current_node.take_dmg.connect(player._on_enemy_take_dmg)
			current_node.shake_camera.connect(player.find_child("Main_camera", true, false)._on_player_shake_camera)
			
			# se il player ha scelto nathan
			if player.char_name == "Nathan": # connetto il segnale della grab
				player.grab.connect(current_node._on_player_grab)
				current_node.got_grabbed.connect(player_gui._on_nathan_grab)
			elif player.char_name == "Rufus": # connetto il segnale del knockback e del cambio statistiche
				player.change_stats.connect(current_node._on_change_stats)
				player.inflict_knockback.connect(current_node.init_knockback)
			elif player.char_name == "Jack": # connetto il segnale del knockback
				player.inflict_knockback.connect(current_node.init_knockback)
			
			# se il nodo è un mezzo-umano
			if "Werewolf" in current_node.name:
				for j in active_enemy_container.get_child_count(): # cicla per ogni figlio della scena
					var node = active_enemy_container.get_child(j) # prendo il singolo nodo
					if "Enemy" in node.name: # se il nome del nemico contiene "Enemy"
						current_node.change_stats.connect(node._on_change_stats) # connetto il segnale ad ogni nemico
			
			if "Fae" in current_node.name:
				current_node.flee_locations = active_enemy_container.markers
			
			if "Centaur" in current_node.name:
				current_node.grab_player.connect(player._on_enemy_grab)
				current_node.inflict_knockback.connect(player.init_knockback)
			
			# se il nodo è il lich
			if "Lich" in current_node.name:
				# allora assegno i suoi marker di teletrasporto ai marker dell'enemy container attivo
				current_node.possible_teleport_locations = active_enemy_container.markers
			
			# se il nodo è un boss
			if "Boss" in current_node.name:
				# allora connetto il segnale della barra della vita alla gui
				current_node.set_health_bar.connect(round_gui._on_boss_set_healthbar)

func connect_player_projectile(projectile):
	for i in active_enemy_container.get_child_count(): #cicla per ogni figlio della scena
		var current_node = active_enemy_container.get_child(i)
		#se il nome del nemico contiene "Enemy"
		if "Enemy" in current_node.name: 
			projectile.take_dmg.connect(current_node._on_player_take_dmg)
			projectile.inflict_knockback.connect(current_node.init_knockback)

func calculate_dmg(str, atk_str, tem, pbc, efc, type):
	var crit = false
	var shake_amount = 0
	if tem <= 0:
		tem = 1
	# applico la formula del danno: (FORZA_ATTACCANTE * FORZA DELL'ATTACCO) / TEMPRA_BERSAGLIO
	var dmg = round((str * atk_str) / tem)
	var rng = randi_range(0, 100) # genero un numero casuale tra 0 e 100
	if pbc > rng: # se la probabilità brutto colpo è più alta del numero generato (esempio: 30 > 20)
		# aumento il danno in base all'efficienza del colpo critico (es. 15 * 1.5 = 15 + 7.5 = 22.5 = 23)
		dmg = round(dmg * efc)
		crit = true
	
	if type == Attack_Types.PHYSICAL:
		shake_amount = dmg / 3
		if shake_amount <= 0:
			shake_amount = 5
	return [dmg, crit, shake_amount]

# DIGEST DEL SEGNALE DELLA PLAYER_GUI CHE NOTIFICA QUANDO GLI HP SCENDONO A 0
func _on_player_death():
	ost_player.get_stream_playback().switch_to_clip_by_name(&"game_over")
	gui.visible = true # la GUI diventa visibile
	game_over_container.visible = true # rendo visibile il game over
	player_gui.visible = false # nascondo la gui del player
	Menu.game_status = Menu.GAME_STATUSES.unopenable # Azione piu' forte di quel che si pensi, non usarlo a cuor leggero
	# metto il focus sul pulsante riprova nell menu di game over
	$CanvasLayer/GUI/GameOver_container/PanelContainer/VBoxContainer/MarginContainer/HBoxContainer/Retry.grab_focus()

func activate_player_GUI():
	# il pg scelto è Rufus allora insanzia la sua GUI
	if player.char_name == "Rufus":
		canvas_layer.add_child(load("res://scenes/GUI/rufus_gui.tscn").instantiate(),true)
	# il pg scelto è Nathan allora insanzia la sua GUI
	elif player.char_name == "Nathan": 
		canvas_layer.add_child(load("res://scenes/GUI/nathan_gui.tscn").instantiate(),true)
	elif player.char_name == "Jack":
		canvas_layer.add_child(load("res://scenes/GUI/jack_gui.tscn").instantiate(),true)
	# connetto il segnale dell'enemy_container attivo con il digest _on_get_healed del player
	active_enemy_container.heal_between_rounds.connect(player._on_get_healed)
	
	# assegno i parametri della GUI:
	player_gui = canvas_layer.get_child(canvas_layer.get_child_count()-1)
	if player.char_name == "Jack":
		player.launched_flashbang.connect(player_gui._on_jack_flashbang)
	player_gui.player = player
	player_gui.player_death.connect(self._on_player_death)
	player_gui.max_health = player.default_vit
	player_gui.healthbar.max_value = player.default_vit
	player_gui.healthbar.value = player.default_vit
	player_gui.healthbar_label.text = str(player.default_vit) + "/" + str(player.default_vit)
	# connetto infine il segnale del player al digest della GUI 
	# in modo da poter aggiornare la GUI al variare della vita
	player.set_health_bar.connect(player_gui._on_player_set_health_bar)

func _on_boss_defeted():
	# istanzio il portale
	add_child(load("res://scenes/miscellaneous/travel_portal.tscn").instantiate(),true)
	# assegno alla variabile portal l'ultimo child della lista, cioè il nodo appena istanziato
	portal = get_child(get_child_count()-1)
	# metto il portale dove è spawnato il boss
	portal.global_position = active_enemy_container.boss_spawner.global_position
	# assegno il paramentro player del portale al layer attivo
	portal.player = player
	# collego il segnale del portale allo scene manager per cambiare stage
	portal.change_stage.connect(self._on_change_stage)

func _on_change_stage():
	boss_defeted_count += 1
	
	if boss_defeted_count == tilesets.size():
		boss_defeted_count = 0
	
	# libero le variabili attive per riassegnarle
	active_tileset.queue_free()
	active_enemy_container.queue_free()
	
	# istanzio un nuovo nodo tileset e assegno quest'ultimo alla variabile del tileset attivo
	add_child(load(tilesets[boss_defeted_count]).instantiate(),true)
	active_tileset = get_child(get_child_count(true)-1)
	
	# istanzio un nuovo nodo enemy_container e assegno quest'ultimo alla variabile enemy_container attivo
	add_child(load(enemy_containers[boss_defeted_count]).instantiate(),true)
	active_enemy_container = get_child(get_child_count(true)-1)
	
	# collego tutti i segnali del container ai rispettivi digest
	active_enemy_container.round_changed.connect(round_gui._on_round_changed)
	active_enemy_container.boss_defeted.connect(self._on_boss_defeted)
	active_enemy_container.connect_boss_with_GUI.connect(round_gui._on_boss_spawned)
	active_enemy_container.heal_between_rounds.connect(player._on_get_healed)
