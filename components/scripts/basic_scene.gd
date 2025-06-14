extends Node2D

var player : CharacterBody2D
var selected_character
var paused : bool = false
var connected : bool = false
# serve come indice per scorrere i tileset
var boss_defeted_count : int = 2
var active_tileset : Node2D
var active_enemy_container : Node2D
@onready var Attack_Types = get_tree().get_first_node_in_group("gm").Attack_Types

# il nodo canvaslayer serve per fissare la gui allo schermo
@onready var canvas_layer : CanvasLayer = find_child("CanvasLayer") 
# contenitore della gui della scena
@onready var gui : Control = canvas_layer.find_child("GUI")
# contenitore della gui di game over
@onready var game_over_container : MarginContainer = gui.find_child("GameOver_container")
# contenitore della gui del combattimento
@onready var round_gui : Control = canvas_layer.find_child("Round_GUI")
# music player che contiene le ost
@onready var ost_player : AudioStreamPlayer = $Ost_player
# variabile che contiene la gui specifica per quel player
var player_gui
@onready var powerup_handler : Node = $Powerup_handler

@export var hitmarker_scene : PackedScene
@export var hit_particles_scene : PackedScene

# percorso che porta al nodo del camera follower
var camera_follower : String = "res://scenes/miscellaneous/camera_follower.tscn"

# array che contiene i tileset
var tilesets : Array = ["res://scenes/tilemaps/gray_tile_map.tscn",
						#"res://scenes/tilemaps/lightblue_tile_map.tscn",
						"res://scenes/tilemaps/forest_tile_map.tscn",
						"res://scenes/tilemaps/deep_forest_tile_map.tscn"
						]

var portal_scene = preload("res://scenes/miscellaneous/travel_portal.tscn")
var portal

func _ready():
	#Engine.time_scale = 0.5
	#Engine.physics_ticks_per_second = 100
	
	Menu.untangle_player.connect(self._on_untangle_player)
	
	var temp : Array
	for i in tilesets.size():
		temp.append(i)
	
	#temp.shuffle()
	
	var new_tileset_order : Array
	
	for i in temp:
		new_tileset_order.append(tilesets[i])
	
	tilesets = new_tileset_order
	
	Menu.game_status = Menu.GAME_STATUSES.unopenable
	self.add_child(load(tilesets[boss_defeted_count]).instantiate(),true)
	active_tileset = get_child(-1)
	active_enemy_container = active_tileset.find_child("Enemy_container")
	
	active_enemy_container.round_changed.connect(round_gui._on_round_changed)
	active_enemy_container.boss_defeted.connect(self._on_boss_defeted)
	active_enemy_container.connect_boss_with_GUI.connect(round_gui._on_boss_spawned)
	round_gui.powerup_spawnable.connect(active_enemy_container._on_powerup_spawnable)
	active_enemy_container.instantiate_pickup.connect(powerup_handler._on_instantiate_pickable)
	powerup_handler.spawn_pickable.connect(active_enemy_container._on_powerup_handler_spawn_pickable)
	

func _process(_delta):
	## stampa dei possibili output di danni per la formula, utile per testarla
	#if Input.is_action_just_pressed("base_atk"):
		#for i in range(10):
			#var atk = randi_range(30, 999)
			#var skill_atk = randi_range(30, 999)
			#var tem = randi_range(30, 999)
			#print("atk: "+str(atk)+", skill atk: "+str(skill_atk)+", tem: "+str(tem)+" =  "+str(self.calculate_dmg(atk, skill_atk, tem, 0, 1, null)))
	
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
	player.scene_manager = self
	
	add_child(load(camera_follower).instantiate(), true)
	get_child(get_child_count()-1).player = player
	player.camera = get_child(get_child_count()-1).camera
	# impostazioni per la telecamera
	player.shake_camera.connect(player.camera._on_player_shake_camera)
	
	# debug: zoom diminuito
	#camera.zoom = Vector2(0.5,0.5)
	
	# condizione per collegare lo script della telecamera
	if char == "nathan":
		player.scale = Vector2(1.4, 1.4)
	activate_player_GUI() # funzione per attivare le GUI
	connect_enemies_with_player() # connetto i nemici e il player
	powerup_handler.player = player
	player.powerup_handler = powerup_handler
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
			current_node.scene_manager = self
			# assegno il parametro player del nemico con il player attivo
			current_node.player = player
			# segnale tra player e nemici per capire se si è in range
			player.is_in_atk_range.connect(current_node._on_player_is_in_atk_range)
			# segnale tra player e nemici per infliggere danno
			player.take_dmg.connect(current_node._on_player_take_dmg)
			# prima controllo che abbia il segnale (se non ce l'ha vuol dire che ha solo proiettili)
			if current_node.has_signal("take_dmg"):
				# segnale tra nemici e player per infliggere danno
				current_node.take_dmg.connect(player._on_enemy_take_dmg)
			current_node.shake_camera.connect(player.camera._on_player_shake_camera)
			
			# se il player ha scelto nathan
			if player.char_name == "Nathan": # connetto il segnale della grab
				player.grab.connect(current_node._on_player_grab)
				current_node.got_grabbed.connect(player_gui._on_nathan_grab)
			elif player.char_name == "Rufus": # connetto il segnale del knockback e del cambio statistiche
				player.change_stats.connect(current_node._on_change_stats)
				player.inflict_knockback.connect(current_node.init_knockback)
			elif player.char_name == "Jack": # connetto il segnale del knockback
				player.inflict_knockback.connect(current_node.init_knockback)
			
			if "Lich" in current_node.name:
				for j in active_enemy_container.get_children():
					if "Spawnpoint" in j.name: 
						current_node.evocation_locations.append(j)
			
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

func calculate_dmg(str, atk_str, tem, pbc, efc, type, caller):
	var crit = false
	var shake_amount = 0
	var dmg : int
	if tem <= 0:
		tem = 1
	# applico la formula del danno: (FORZA_ATTACCANTE * FORZA DELL'ATTACCO) / TEMPRA_BERSAGLIO
	dmg = round((str * atk_str) / tem)
	var rng = randi_range(0, 100) # genero un numero casuale tra 0 e 100
	if pbc > rng: # se la probabilità brutto colpo è più alta del numero generato (esempio: 30 > 20)
		# aumento il danno in base all'efficienza del colpo critico (es. 15 * 1.5 = 15 + 7.5 = 22.5 = 23)
		dmg = round(dmg * efc)
		crit = true
		if "Enemy" in caller.name:
			powerup_handler.apply_powerup_boost("Vivian")
	
	if type == Attack_Types.PHYSICAL:
		shake_amount = dmg / 3
		if shake_amount <= 0:
			shake_amount = 5
	return [dmg, crit, shake_amount]

# METODO GLOBALE PER FAR COMPARIRE L'HITMARKER 
func show_hitmarker(dmg, crit, hitmarker_spawnpoint):
	# istanzio l'hitmarker 
	var hitmarker = hitmarker_scene.instantiate()
	# lo posiziono nello spawnpoint
	hitmarker.position = hitmarker_spawnpoint.global_position
	
	# creo il tween per lo spostamento casuale
	var tween = get_tree().create_tween()
	tween.tween_property(hitmarker, 
						"position", 
						hitmarker_spawnpoint.global_position + (Vector2(randf_range(-1,1), -randf()) * 40), 
						0.75)
	
	# cambio la label nella scena (che sono sicuro sia il child 0) con il danno
	hitmarker.get_child(0).text = dmg
	# se il danno è un crit
	if crit:
		# cambio il colore della label in oro
		hitmarker.get_child(0).set("theme_override_colors/font_color", Color.GOLDENROD)
	# aggiungo l'hitmarker alla scena
	self.add_child(hitmarker)

# METODO GLOBALE PER SPAWNARE LE PARTICELLE DI HIT
func emit_hit_particles(attacker, target):
	# istanzio le particelle
	var particles : GPUParticles2D = hit_particles_scene.instantiate()
	# le posiziono sul punto di interesse (il target)
	particles.global_position = target.global_position
	# ricavo la direzione di dove indirizzarle
	var direction_of_spawning = attacker.global_position.direction_to(target.global_position)
	# metto la direzione ricavata nel process_material
	particles.process_material.direction = Vector3(direction_of_spawning.x, direction_of_spawning.y, 0)
	# aggiungo le particelle alla scena
	self.add_child(particles)
	# le riproduco 
	particles.emitting = true

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
	add_child(portal_scene.instantiate(),true)
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
	add_child(load(tilesets[boss_defeted_count]).instantiate(), true)
	active_tileset = get_child(-1)
	active_enemy_container = get_child(-1).find_child("Enemy_container")
	
	player.global_position = active_enemy_container.boss_spawner.global_position
	portal.global_position = active_enemy_container.boss_spawner.global_position
	
	# collego tutti i segnali del container ai rispettivi digest
	active_enemy_container.round_changed.connect(round_gui._on_round_changed)
	active_enemy_container.boss_defeted.connect(self._on_boss_defeted)
	active_enemy_container.connect_boss_with_GUI.connect(round_gui._on_boss_spawned)
	active_enemy_container.heal_between_rounds.connect(player._on_get_healed)
	
	round_gui.powerup_spawnable.connect(active_enemy_container._on_powerup_spawnable)
	active_enemy_container.instantiate_pickup.connect(powerup_handler._on_instantiate_pickable)
	powerup_handler.spawn_pickable.connect(active_enemy_container._on_powerup_handler_spawn_pickable)

func _on_canvas_layer_child_entered_tree(node: Node) -> void:
	if canvas_layer:
		for i in canvas_layer.get_children():
			i.visible = not i.visible

func _on_canvas_layer_child_exiting_tree(node: Node) -> void:
	if canvas_layer:
		for i in canvas_layer.get_children():
			i.visible = not i.visible

func _on_untangle_player():
	if is_instance_valid(player):
		player.global_position = active_enemy_container.boss_spawner.global_position
