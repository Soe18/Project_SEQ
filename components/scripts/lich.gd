extends CharacterBody2D

var boss_name = "Kreegakaleet lu Gosata'ahm"

@export var default_vit : int = 1000
var current_vit = default_vit
@export var default_str : int = 190
var current_str = default_str
@export var default_tem : int = 150
var current_tem = default_tem
@export var default_des : int = 145
var current_des = default_des
@export var default_pbc : int = 35
var current_pbc = default_pbc
@export var default_efc : float = 1.2
var current_efc = default_efc

@export var damage_node : PackedScene

# attributo contenente le scene dei proiettili
@export var witchcraft_scene : PackedScene
@export var death_sphere_scene : PackedScene
@export var explosion_scene : PackedScene

var is_in_atk_range = false
var moving = true # variabile che gestisce lo stun
var grabbed = false # variabile che gestisce il grab
var spawning = true # variabile a true finché non finisce l'animazione di spawning, altrimenti false
var dying = false # variabile a false finché il boss è in vita, poi a true per l'animazione di death

signal take_dmg(str, atk_str, sec_stun, pbc, efc)
signal set_health_bar(vit)
signal got_grabbed(is_grabbed)

var player

enum Possible_Attacks {IDLE, WITCHCRAFT, DEATH_SPHERE, EXPLOSIONS, EVOCATION, TELEPORT}
var choosed_atk

# riferimenti ai nodi
@onready var sprite = $Sprite2D
@onready var stun_timer = $Stun

@onready var body_collider = $Body_collider

@onready var witchcraft_spawnpoint = $Witchcraft_spawnpoint
@onready var death_sphere_spawnpoint = $Death_sphere_spawnpoint

@onready var explosion_container = $Explosions_container
@onready var first_round_container = $Explosions_container/First_round
@onready var second_round_container = $Explosions_container/Second_round
@onready var third_round_container = $Explosions_container/Third_round
@onready var second_round_timer = $Explosions_container/Second_round_timer
@onready var third_round_timer = $Explosions_container/Third_round_timer
@onready var reset_explosions = $Explosions_container/Reset

@onready var evocation_container = $Evocation_container

@onready var teleport_cooldown = $Teleport_Cooldown
@onready var witchcraft_cooldown = $Witchcraft_Cooldown
@onready var death_sphere_cooldown = $Death_sphere_Cooldown
@onready var explosions_cooldown = $Explosions_Cooldown
@onready var evocation_cooldown = $Evocation_Cooldown

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

@onready var status_sprite = $Status_alert_sprite

@onready var update_atk_timer = $Update_Atk
@onready var set_idle_timer = $Inhale_time

var player_entered = true
var player_in_atk_range = false

# array da popolare nel ready, in modo da essere scalabile
var possible_teleport_locations = []
var first_round_explosions = []
var second_round_explosions = []
var third_round_explosions = []
var evocation_locations = []

# array che contiene il percorso delle scene dei nemici evocabili, da rivedere
var evocable_entities = ["res://scenes/enemies/zombie.tscn","res://scenes/enemies/skeleton.tscn","res://scenes/enemies/giant.tscn"]

# contatore per evitare l'istanzia di due nodi con lo stesso nome, casini nei connect
var evocation_count = 0

'METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
	setta la vita attuale a quella massima
	imposta il valore massimo della barra della salute al massimo
	setta la barra della salute'

func _ready():
	emit_signal("set_health_bar", current_vit)
	sprite.play("spawn")
	
	# popolo l'array con i marker del primo round di esplosioni
	for i in first_round_container.get_children():
		first_round_explosions.append(i)
	
	# popolo l'array con i marker del secondo round di esplosioni
	for i in second_round_container.get_children():
		second_round_explosions.append(i)
	
	# popolo l'array con i marker del terzo round di esplosioni
	for i in third_round_container.get_children():
		third_round_explosions.append(i)
	
	# popolo l'array con i marker delle evocazioni
	for i in evocation_container.get_children():
		evocation_locations.append(i)
	

'METODO CHE VIENE PROCESSATO PER FRAME
	controlla se il player è entrato in area e si può muovere
		allora si muove
	altrimenti se il player NON è entrato in area e si può muovere
		allora comincia a vagare
	controlla se è grabbato
		allora fa partire il metodo grab()'

func _physics_process(_delta):
	if dying: # se sta morendo ignoro qualsiasi altro processo
		moving = false # non si deve muovere
		sprite.play("death") # faccio partire l'animazione di morte
	elif not spawning: # se non sta spawnando e non è morto allora sta combattendo
		if player_entered and moving: # se vede il player (quindi è vivo) e può muoversi (non è stunnato)
			if player and not grabbed: # se esiste il player e non è grabbato gestisco gli attacchi
				
				# se l'attacco è TELEPORT e il cooldown è finito
				if choosed_atk == Possible_Attacks.TELEPORT and teleport_cooldown.is_stopped():
					teleport() # faccio partire il metodo teleport()
				
				# se l'attacco è WITCHCRAFT e il cooldown è finito
				if choosed_atk == Possible_Attacks.WITCHCRAFT and witchcraft_cooldown.is_stopped() and stun_timer.is_stopped():
					witchcraft() # faccio partire il metodo witchcraft()
				
				# se l'attacco è DEATH_SPHERE e il cooldown è finito
				if choosed_atk == Possible_Attacks.DEATH_SPHERE and death_sphere_cooldown.is_stopped() and stun_timer.is_stopped():
					death_sphere() # faccio partire il metodo death_sphere()
				
				# se l'attacco è ESPLOSIONS e il cooldown è finito
				if choosed_atk == Possible_Attacks.EXPLOSIONS and explosions_cooldown.is_stopped() and stun_timer.is_stopped():
					sprite.play("explosions") # faccio partire l'animazione del lich, vedi _on_sprite_animation_finished
				
				# se l'attacco è EVOCATION e il cooldown è finito
				if choosed_atk == Possible_Attacks.EVOCATION and evocation_cooldown.is_stopped() and stun_timer.is_stopped():
					sprite.play("evocation") # faccio partire l'animazione del lich, vedi _on_sprite_animation_finished
		elif not player_entered and moving: # se il player non è individuabile e può muoversi allora lo muovo e basta
			if choosed_atk == Possible_Attacks.TELEPORT and teleport_cooldown.is_stopped():
					teleport()
			else:
				sprite.play("idle")
		elif not player_entered and not moving: # se il player non è dentro e non può muoversi
			sprite.play("idle") # lo metto in idle, non ha niente da fare tanto
		elif grabbed: # se è grabbato faccio partire il metodo apposito
			is_grabbed()

# METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
#	salvo la posizione attuale del player
#	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
#	se il nodo è distante dal player di almeno 12 unità
#		muovo il nodo verso il player con la velocità di 3

# -- INUTILE, LO TENGO PER PARCONDICIO -- #
func flip(distance_to_player):
	if distance_to_player.x < 0:
		pass
	elif distance_to_player.x > 0:
		pass

# METODO CHE GESTISCE LA SCELTA DELL'ATTACCO
func choose_atk():
	var rng = randi_range(0,100)
	if rng >= 0 and rng < 25:
		choosed_atk = Possible_Attacks.TELEPORT # 25%
	elif rng >= 25 and rng < 35:
		choosed_atk = Possible_Attacks.EVOCATION # 10%
	elif rng >= 35 and rng < 60:
		choosed_atk = Possible_Attacks.DEATH_SPHERE # 25%
	elif rng >= 60 and rng < 75:
		choosed_atk = Possible_Attacks.EXPLOSIONS # 15%
	else:
		choosed_atk = Possible_Attacks.WITCHCRAFT # 25%

# -------- SIGNAL DIGEST -------- #

'DIGEST DEL SEGNALE DEL PLAYER "is_in_atk_range"
{
	PARAMETRI
	boolean is_in: identifica se il nodo è entrato oppure è uscito
	Node body: identifica il nodo che è entrato o uscito
}
	se il segnale che manda al nodo è di entrata nel\'area e il nodo è questo
		allora il nodo è dentro l\'area del player
	altrimenti
		non è in range'

func _on_player_is_in_atk_range(is_in, body):
	if is_in and body == self:
		is_in_atk_range = is_in
	else:
		is_in_atk_range = false

'DIGEST DEL SEGNALE DEL PLAYER "take_dmg"
{
	PARAMETRI
	int atk_state: DEPRECATO
	int dmg: quantità del danno inflitto
	float sec: tempo dello stun
}
	se il nodo è in range e non è grabbato
		allora sottraggo alla vita il danno
		setto la barra della vita con il nuovo valore
		# print di debug #
		impedisco al nodo di muoversi mentre viene attaccato
		imposto il tempo di stun con il parametro passato
		faccio partire il timer dello stun'

func _on_player_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc):
	if not spawning and not dying:
		if is_in_atk_range and !grabbed:
			var dmg = get_parent().get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc)
			current_vit -= dmg
			emit_signal("set_health_bar", current_vit)
			show_hitmarker("-" + str(dmg))
			
			# sto stronzo ha uno stun_reduction, cioè diminuisce i secondi di stun
			stun_sec -= 0.5
			# se ha culo di diminuire sotto lo 0 i secondi di stun
			if stun_sec < 0:
				stun_sec = 0 # semplicemente li riporta a 0
			
			# se ha secondi di stun e se il danno è maggiore uguale a 15 allora lo sente effettivamente
			if stun_sec > 0 and dmg >= 15: # ha pure l'armor sta merda
				moving = false
				stun_timer.wait_time = stun_sec
				stun_timer.start()
				sprite.play("damaged")

# DIGEST DEL SENGALE DEL PLAYER "grab"
# {
# 	PARAMETRI
# 	boolean is_been_grabbed: controlla se il segnale è di entrata o di uscita dalla grab
# 	booelan is_flipped: indica se il player è flippato o meno
# }
# se il segnale è di grab, il nodo non è già grabbato e il nodo è in range
# 	faccio ricevere un danno al nodo
# 	tolgo la possibilità di muoversi del nodo
# 	setto il grabbed a true
# 	lo sprite diventa invisibile
# 	disattivo le collisioni
# se il segnale è di uscita dalla grab e il nodo è grabbato
# 	il nodo potrà di nuovo muoversi
# 	setto il grabbed a false
# 	se il nodo è flipped
# 		spinge il nodo a sinistra di 450
# 	altrimenti
# 		spinge il nodo a destra di 450
# 	lo sprite diventa visibile
# 	faccio partire un timer per risettare le collisioni, se le riabilito insieme avviene un bug

func _on_player_grab(is_been_grabbed, is_flipped):
	if not spawning:
		if is_been_grabbed and !grabbed and is_in_atk_range:
			if player.char_name == "Nathan":
				emit_signal("got_grabbed", true)
			_on_inhale_time_timeout()
			choosed_atk = Possible_Attacks.IDLE
			$Update_Atk.stop()
			moving = false
			grabbed = true
			sprite.visible = false
			body_collider.disabled = true
		if !is_been_grabbed and grabbed:
			if player.char_name == "Nathan":
				emit_signal("got_grabbed", false)
			$Update_Atk.start()
			moving = true
			grabbed = false
			if is_flipped:
				position.x = player.position.x + -450
			else:
				position.x = player.position.x + 450
			sprite.visible = true
			move_and_slide()
			$GrabTime.start()

'METODO CHE TELETRASPORTA IL NODO NELLA POSIZIONE DEL PLAYER DURANTE LA GRAB
	setto la posizione uguale a quella del player'

func is_grabbed():
	position = player.position

'DIGEST DEL TIMER "Stun"
	setto il movimento a true'

func _on_stun_timeout():
	choosed_atk = Possible_Attacks.IDLE
	_on_inhale_time_timeout()

'DIGEST DEL TIMER "GrabTime", IMPOSTA UN DELAY DOPO LA GRAB
	setto le collisioni a true'

func _on_timer_timeout():
	body_collider.disabled = false

# -------- SIGNAL DIGEST -------- #

'DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO'

### TODO refactor di tutti questi metodi perché è deprecato
func _on_inhale_time_timeout():
	moving = true
	choosed_atk = Possible_Attacks.IDLE
	sprite.play("idle")

# DIGEST DI QUANDO LO SPRITE CAMBIA IL FRAME DI ANIMAZIONE
func _on_sprite_2d_frame_changed():
	# NON ULTIMATO, DEVE AVERE LE ANIMAZIONI FINITE
	if sprite.animation == "witchcraft" and sprite.frame == 5:
		launch_witchcraft()
	if sprite.animation == "death_sphere" and sprite.frame == 4:
		launch_death_sphere()
	if sprite.animation == "explosions" and sprite.frame == 3:
		explosions()

func _on_sprite_2d_animation_finished():
	if sprite.animation == "spawn":
		$Update_Atk.start()
		sprite.play("idle")
		spawning = false
	elif sprite.animation == "death":
		self.name = "Slayed"
		process_mode = Node.PROCESS_MODE_DISABLED
	elif sprite.animation == "witchcraft":
		_on_inhale_time_timeout()
	elif sprite.animation == "death_sphere":
		_on_inhale_time_timeout()
	elif sprite.animation == "evocation":
		evocation()
		_on_inhale_time_timeout()

# DIGEST DEL TIMER CHE SEGNALA DI SCEGLIERE UN ATTACCO
func _on_update_atk_timeout():
	choose_atk()
	$Update_Atk.start()

# METODO CHE FA TELETRASPORTARE IL LICH IN UNO DEI WAYPOINT
func teleport():
	var current_tp = possible_teleport_locations.pick_random()
	self.global_position = current_tp.global_position
	teleport_cooldown.start()

# METODO CHE FA PARTIRE L'ANIMAZIONE DELL'ATTACCO WITCHCRAFT
func witchcraft():
	sprite.play("witchcraft")
	witchcraft_cooldown.start()

# METODO CHE INSTANZIA IL NODO WITCHCRAFT_PROJECTILE
func launch_witchcraft():
	self.add_child(witchcraft_scene.instantiate(),true)
	var witchcraft_projectile = get_child(get_child_count()-1,true)
	witchcraft_projectile.position = witchcraft_spawnpoint.position
	witchcraft_projectile.player = player
	witchcraft_projectile.player_position = player.global_position
	witchcraft_projectile.lich_str = current_str
	witchcraft_projectile.lich_pbc = current_pbc
	witchcraft_projectile.lich_efc = current_efc
	witchcraft_projectile.take_dmg.connect(player._on_enemy_take_dmg)
	witchcraft_projectile.look_at(player.global_position)
	witchcraft_projectile.reparent(get_parent())

# METODO CHE FA PARTIRE L'ANIMAZIONE DELL'ATTACCO DEATH_SPHERE
func death_sphere():
	sprite.play("death_sphere")
	death_sphere_cooldown.start()

# METODO CHE INSTANZIA IL NODO DEATH_SPHERE_PROJECTILE
func launch_death_sphere():
	add_child(death_sphere_scene.instantiate(),true)
	var death_sphere_projectile = get_child(get_child_count()-1)
	death_sphere_projectile.position = death_sphere_spawnpoint.position
	death_sphere_projectile.player = player
	death_sphere_projectile.player_position = player.global_position
	death_sphere_projectile.lich_str = current_str
	death_sphere_projectile.lich_pbc = current_pbc
	death_sphere_projectile.lich_efc = current_efc
	death_sphere_projectile.take_dmg.connect(player._on_enemy_take_dmg)

# METODO CHE FA PARTIRE IL PRIMO ROUND DI ESPLOSIONI
func explosions():
	explosion_container.reparent(get_parent())
	for i in first_round_explosions:
		if player != null:
			add_child(explosion_scene.instantiate(),true)
			var instantiate_explosion = get_child(get_child_count()-1)
			instantiate_explosion.position = i.position
			instantiate_explosion.player = player
			instantiate_explosion.lich_str = current_str
			instantiate_explosion.lich_pbc = current_pbc
			instantiate_explosion.lich_efc = current_efc
			instantiate_explosion.take_dmg.connect(player._on_enemy_take_dmg)
	second_round_timer.start() # faccio partire il timer per il secondo round
	explosions_cooldown.start() # faccio partire il cooldown
	_on_inhale_time_timeout()

# METODO CHE FA PARTIRE IL SECONDO ROUND DI ESPLOSIONI
func _on_second_round_timer_timeout():
	for i in second_round_explosions:
		if player != null:
			add_child(explosion_scene.instantiate(),true)
			var instantiate_explosion = get_child(get_child_count()-1)
			instantiate_explosion.position = i.position
			instantiate_explosion.player = player
			instantiate_explosion.lich_str = current_str
			instantiate_explosion.lich_pbc = current_pbc
			instantiate_explosion.lich_efc = current_efc
			instantiate_explosion.take_dmg.connect(player._on_enemy_take_dmg)
	third_round_timer.start() # faccio partire il timer per il terzo round

# METODO CHE FA PARTIRE IL TERZO ROUND DI ESPLOSIONI
func _on_third_round_timer_timeout():
	for i in third_round_explosions:
		if player != null:
			add_child(explosion_scene.instantiate(),true)
			var instantiate_explosion = get_child(get_child_count()-1)
			instantiate_explosion.position = i.position
			instantiate_explosion.player = player
			instantiate_explosion.lich_str = current_str
			instantiate_explosion.lich_pbc = current_pbc
			instantiate_explosion.lich_efc = current_efc
			instantiate_explosion.take_dmg.connect(player._on_enemy_take_dmg)
	reset_explosions.start() # faccio partire il timer per resettare le esplosioni

# DIGEST DEL SEGNALE DI RESET DELLE ESPLOSIONI
func _on_reset_timeout():
	explosion_container.reparent(self) # faccio tornare come genitore del container il lich

# METODO DELL'ATTACCO EVOCATION
func evocation():
	# calcolo la percentuale di vita in cui si trova
	var _85_health = default_vit/100 * 85
	var _70_health = default_vit/100 * 70
	var _50_health = default_vit/100 * 50
	var _30_health = default_vit/100 * 30
	var _20_health = default_vit/100 * 20
	
	if current_vit <= default_vit and current_vit > _85_health:
		#evoca uno zombie in un posto casuale
		add_child(load(evocable_entities[0]).instantiate(),true)
		var evocated_entity = get_child(get_child_count()-1,true)
		evocated_entity.position = evocation_locations.pick_random().position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
	
	if current_vit <= _85_health and current_vit > _70_health:
		#evoca due zombie uno alla posizione 0 e l'altro alla posizione 1
		add_child(load(evocable_entities[0]).instantiate(),true)
		var evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[0].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
		
		add_child(load(evocable_entities[1]).instantiate(),true)
		evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[1].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
	
	if current_vit <= _70_health and current_vit > _50_health:
		#evoca due zombie e uno scheletro nelle tre posizioni
		add_child(load(evocable_entities[0]).instantiate(),true)
		var evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[0].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
		
		add_child(load(evocable_entities[0]).instantiate(),true)
		evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[1].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
		
		add_child(load(evocable_entities[1]).instantiate(),true)
		evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[2].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
	
	if current_vit <= _50_health and current_vit > _30_health:
		#evoca un gigante nella posizione 2
		add_child(load(evocable_entities[2]).instantiate(),true)
		var evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[2].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
	
	if current_vit <= _30_health and current_vit > _20_health:
		#evoca un gigante nella posizione 2 e uno zombie nella posizione 0
		add_child(load(evocable_entities[2]).instantiate(),true)
		var evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[2].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
		
		add_child(load(evocable_entities[0]).instantiate(),true)
		evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[0].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
	
	if current_vit <= _20_health:
		#evoca tutte le entità in tutte le posizioni in ordine di indice crescente
		add_child(load(evocable_entities[0]).instantiate(),true)
		var evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[0].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
		
		add_child(load(evocable_entities[1]).instantiate(),true)
		evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[1].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
		
		add_child(load(evocable_entities[2]).instantiate(),true)
		evocated_entity = get_child(get_child_count()-1)
		evocated_entity.position = evocation_locations[2].position
		evocation_count += 1
		evocated_entity.name += "_"+str(evocation_count)
		evocated_entity.reparent(get_parent())
	
	# faccio partire il metodo dello scene manager per connettere i nemici spawnati con il player
	get_parent().get_parent().connect_enemies_with_player()
	evocation_cooldown.start() # faccio partire il cooldown



# //////////// AREA COMUNE TRA NODI //////////// #

func _on_area_of_detection_body_entered(body):
	if body == player:
		player_entered = true

func _on_area_of_detection_body_exited(body):
	if body == player:
		player_entered = false

func _on_change_stats(stat, amount, time_duration, ally_sender):
	if (is_in_atk_range and !grabbed) or time_duration == 0 or ally_sender:
		if "str" in stat:
			current_str += amount
		elif "tem" in stat:
			current_tem += amount
		elif "des" in stat:
			current_des += amount
		elif "pbc" in stat:
			current_pbc += amount
		elif "efc" in stat:
			current_efc += amount
		
		
		if time_duration != 0:
			if amount > 0:
				status_sprite.play("buff")
			else:
				status_sprite.play("debuff")
			add_child(load("res://scenes/miscellaneous/time_of_change.tscn").instantiate(),true)
			var new_timer = get_child(get_child_count()-1)
			new_timer.stat = stat
			new_timer.amount = -amount
			new_timer.wait_time = time_duration
			new_timer.start()

func _on_status_alert_sprite_animation_finished():
	status_sprite.play("idle")

func show_hitmarker(dmg):
	var hitmarker = damage_node.instantiate()
	hitmarker.position = hitmarker_spawnpoint.global_position
	
	var tween = get_tree().create_tween()
	tween.tween_property(hitmarker, 
						"position", 
						hitmarker_spawnpoint.global_position + (Vector2(randf_range(-1,1), -randf()) * 40), 
						0.75)
	
	hitmarker.get_child(0).text = dmg
	get_tree().current_scene.add_child(hitmarker)
