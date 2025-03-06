extends Node2D

var markers = [] # array che contiene tutti i marker della scena
var active_markers = [] # array che si popola allo spawnare dei nemici
# array contenente i percorsi dei nemici
var possible_enemies = ["res://scenes/enemies/zombie.tscn","res://scenes/enemies/skeleton.tscn","res://scenes/enemies/giant.tscn","res://scenes/enemies/werewolf.tscn","res://scenes/enemies/fae.tscn","res://scenes/enemies/centaur.tscn"]
# [0] = Zombie
# [1] = Scheletro
# [2] = Gigante
# [3] = Mezzo-umano
# [4] = Fata
# [5] = Centauro

# array che contiene il percorso del boss
var boss_scene = "res://scenes/enemies/lich.tscn"

signal round_changed() # segnale che manda alla GUI per incrementare il counter
signal heal_between_rounds(amount) # segnale che manda al player per curarlo
signal boss_defeted() # segnale che manda allo scene_manager per evocare il portale
signal connect_boss_with_GUI(boss) # segnale che collega il boss alla barra della vita

var fighting # flag che determina quando esistono nemici
var boss_is_defeted = false # flag che determina quando il boss è stato sconfitto
var boss_spawned = false # flag che determina se il boss è spawnato
var portal_spawned = false # flag che determina se il portale è spawnato

@onready var time_between_rounds = $Round_cooldown
@onready var boss_spawner = $Boss_Spawner

func _ready():
	# popolo l'array con tutti gli spawnpoint
	for i in get_children():
		if "Spawnpoint" in i.name:
			markers.append(i)

#METODO CHE VIENE EVOCATO AD OGNI FRAME, CONTROLLA SE I NEMICI SONO ANCORA PRESENTI IN GAME
func _process(_delta):
	fighting = false
	var boss_present = false
	for i in get_children():
		if "Enemy" in i.name:
			fighting = true
		if "Enemy" in i.name and is_boss_round():
			boss_present = true
	
	if boss_spawned and not boss_present:
		boss_is_defeted = true
	
	if not boss_is_defeted:
		if not fighting and time_between_rounds.is_stopped():
			time_between_rounds.start()
	else:
		if not portal_spawned:
			emit_signal("boss_defeted")
			portal_spawned = true

# DIGEST DEL TIMER CHE DETERMINA QUANDO DEVE PARTIRE UNA NUOVA ONDATA
func _on_round_cooldown_timeout():
	emit_signal("round_changed") # invio il segnale al round_gui per incremetare l'ondata
	emit_signal("heal_between_rounds", 50) # invio il segnale al player per curarsi di una certa quantità
	fighting = true # di conseguenza i nemici spawneranno quindi combatto
	if is_boss_round() and not boss_is_defeted: # se è il round del boss e il boss non è stato sconfitto
		spawn_boss() # spawno il boss
		boss_spawned = true # ricordo che l'ho spawnato
	else: # altrimenti
		activate_markers() # evoco semplicemente i nemici normali

# METODO CHE ATTIVA I MARKER E SPAWNA I NEMICI IN BASE AL NUMERO DI ONDATA
func activate_markers():
	active_markers.clear() # pulisco i marker attivi così da poter popolarlo correttamente
	
	# prendo il numero di ondata dalla round_gui
	var round_count = get_parent().round_gui.round_count
	
	# determino il numero minimo di nemici arrotondando per difetto
	var min_count = ceil(round_count/2)
	
	if min_count < 1: # se il minimo è minore di 1
		min_count = 1 # lo metto a 1
	elif min_count > markers.size(): # se è maggiore del numero massimo di marker
		min_count = markers.size() # lo metto al massimo
	
	var max_count = round_count # il massimo di nemici è uguale al numero di round
	if max_count < 1: # se il massimo è minore di 1
		max_count = 1 # lo metto a 1
	elif max_count > markers.size(): # se è maggiore del numero massimo di marker
		max_count = markers.size() # lo metto al massimo
	
	# genero randomicamente un numero compreso tra il minimo e il massimo
	# questo è il numero di nemici di questo round
	var enemy_count = randi_range(min_count, max_count)
	
	#enemy_count = markers.size()
	#enemy_count = 1
	
	# ///////////// PRINT DI DEBUG ///////////// #
	print("round_count = " + str(round_count))
	print("min_count = " + str(min_count))
	print("max_count = " + str(max_count))
	print("enemy_count = " + str(enemy_count))
	# ///////////// PRINT DI DEBUG ///////////// #
	
	for i in enemy_count: # ciclo con i < enemy_count
		var out = false # instanzio un bool sentinella
		while not out: # finché la sentinella è falsa
			var marker = markers.pick_random() # prendo un marker casuale
			if not marker in active_markers: # se il marker NON è già stato attivato
				active_markers.append(marker) # attivo il marker
				out = true # esco appena ne ho attivato uno
	
	for i in active_markers: # ciclo i marker attivi
		var out = false # instanzio un bool sentinella
		var enemy_scene # dichiaro una variabile d'appoggio
		while not out: # finché la sentinella è falsa
			enemy_scene = possible_enemies.pick_random() # prendo un nemico casuale dalla pool
			# se l'ondata è minore di 5 E il nemico selezionato è il gigante
			if round_count < 5 and (enemy_scene == possible_enemies[2] or enemy_scene == possible_enemies[3] or enemy_scene == possible_enemies[4] or enemy_scene == possible_enemies[5]): 
				out = false # non esco e ne seleziono un altro
			else: # altrimenti
				out = true # seleziono il percorso
		
		add_child(load(enemy_scene).instantiate(),true) # insanzio come nodo figlio il nemico
		#add_child(load(possible_enemies[0]).instantiate(),true) # debug
		
		# setto la posizione del nemico spawnato al marker attivo
		get_child(get_child_count()-1).position = i.position 

# METODO CHE SPAWNA IL BOSS
func spawn_boss():
	add_child(load(boss_scene).instantiate(),true) # instanzio come nodo figlio il boss
	var active_boss = get_child(get_child_count()-1) # salvo il nodo del boss come variabile
	active_boss.position = boss_spawner.position # metto la posizione del boss nel suo marker
	# segnalo alla round_gui che il boss è spawnato e glielo passo
	emit_signal("connect_boss_with_GUI", active_boss) 

# METODO CHE CONTROLLA SE E' IL ROUND IN CUI DEVE SPAWNARE IL BOSS
func is_boss_round():
	# prendo il numero di ondata dalla round_gui
	var round_count = get_parent().round_gui.round_count 
	# se il round_count è > 0 ed è divisibile per n (ogni quanti round far spawnare il boss)
	if round_count > 0 and round_count % 10 == 0: 
		return true # ritorno vero
	else: # altrimenti
		return false # ritorno falso
