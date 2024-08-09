extends CharacterBody2D

@export var default_vit : int = 150
var current_vit = default_vit
@export var default_str : int = 125
var current_str = default_str
@export var default_tem : int = 121
var current_tem = default_tem
@export var default_des : int = 145
var current_des = default_des
@export var default_pbc : int = 30
var current_pbc = default_pbc
@export var default_efc : float = 1.5
var current_efc = default_efc

@export var damage_node : PackedScene

var var_velocity = 2
var is_in_atk_range = false
var moving = true
var grabbed = false

signal take_dmg(str, atk_str, sec_stun, pbc, efc)
signal got_grabbed(is_grabbed)

var target_position
var player

enum Possible_Attacks {IDLE, BASIC_ATK, SPRINT}
var choosed_atk
var sprinting = false

@onready var navigation_agent = $NavigationAgent2D

@onready var sprite = $Sprite2D
@onready var basic_atk_effect = $Basic_atk_Area/Effect
@onready var basic_atk_collider = $Basic_atk_Area/Skill_collider
@onready var stun_timer = $Stun

@onready var body_collider = $Body_collider

@onready var sprint_area = $Sprint_Area
@onready var sprint_collider = $Sprint_Area/Skill_collider

@onready var healthbar = $Control/HealthBar

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

@onready var area_of_detection = $Area_of_detection

@onready var status_sprite = $Status_alert_sprite

var player_entered = true
var player_in_atk_range = false

var health

'METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
	setta la vita attuale a quella massima
	imposta il valore massimo della barra della salute al massimo
	setta la barra della salute'

func _ready():
	health = default_vit
	healthbar.max_value = default_vit
	set_health_bar()
	sprite.play("idle")

'METODO CHE VIENE PROCESSATO PER FRAME
	controlla se il player è entrato in area e si può muovere
		allora si muove
	altrimenti se il player NON è entrato in area e si può muovere
		allora comincia a vagare
	controlla se è grabbato
		allora fa partire il metodo grab()'

func _physics_process(_delta):
	if sprinting:
		sprint_to_player()
	elif player_entered and moving:
		chase_player()
		if choosed_atk == Possible_Attacks.BASIC_ATK and $Basic_atk_Cooldown.is_stopped():
			basic_atk()
		if choosed_atk == Possible_Attacks.SPRINT and $Sprint_Cooldown.is_stopped() and not sprinting and $Stun.is_stopped():
			sprint()
	elif not player_entered and moving:
		if player:
			if not navigation_agent.is_navigation_finished():
				sprite.play("running")
				target_position = navigation_agent.target_position
				velocity = global_position.direction_to(target_position) * 150
				move_and_slide()
			else:
				sprite.play("idle")
	elif not player_entered and not moving:
		sprite.play("idle")
	elif grabbed:
		is_grabbed()

'METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
	salvo la posizione attuale del player
	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
	se il nodo è distante dal player di almeno 12 unità
		muovo il nodo verso il player con la velocità di 3'

func flip(distance_to_player):
	if distance_to_player.x < 0:
		basic_atk_effect.position = Vector2(-49, 12)
		basic_atk_effect.flip_h = false
		body_collider.position = Vector2(19, 16)
		sprite.flip_h = true
		basic_atk_collider.position = Vector2(-42, 16)
		body_collider.rotation_degrees = -11
		body_collider.position.x = 7
	elif distance_to_player.x > 0:
		basic_atk_effect.position = Vector2(49, 12)
		basic_atk_effect.flip_h = true
		body_collider.position = Vector2(-6, 16)
		sprite.flip_h = false
		basic_atk_collider.position = Vector2(42, 16)
		body_collider.rotation_degrees = 11
		body_collider.position.x = -7

func chase_player():
	if player:
		navigation_agent.target_position = player.global_position
		
		if navigation_agent.is_navigation_finished():
			if sprite.animation == "running":
				sprite.play("idle")
		else:
			target_position = navigation_agent.get_next_path_position()
			
			var new_velocity = global_position.direction_to(target_position) * 200
			
			if navigation_agent.avoidance_enabled:
				navigation_agent.set_velocity(new_velocity)
			else:
				_on_navigation_agent_2d_velocity_computed(new_velocity)
			
			sprite.play("running")
			move_and_slide()
		var player_position = (player.position - position).normalized()
		flip(player_position)

func sprint_to_player():
	if player != null:
		var player_position = player.position
		target_position = (player_position - position).normalized()
		flip(target_position)
		
		sprite.play("running")
		move_and_collide(target_position * 5)

func choose_atk():
	var rng = randi_range(0,100)
	if rng >= 0 and rng < 10:
		choosed_atk = Possible_Attacks.IDLE
	elif rng >= 10 and rng < 85:
		choosed_atk = Possible_Attacks.BASIC_ATK
	else:
		choosed_atk = Possible_Attacks.SPRINT


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
	if is_in_atk_range and !grabbed:
		var dmg = get_parent().get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc)
		show_hitmarker("-" + str(dmg))
		health -= dmg
		set_health_bar()
		if sprinting and dmg >= 25:
			sprinting = false
		if stun_sec > 0:
			moving = false
			stun_timer.wait_time = stun_sec
			stun_timer.start()
			sprite.play("damaged")

'DIGEST DEL SENGALE DEL PLAYER "grab"
{
	PARAMETRI
	boolean is_been_grabbed: controlla se il segnale è di entrata o di uscita dalla grab
	booelan is_flipped: indica se il player è flippato o meno
}
se il segnale è di grab, il nodo non è già grabbato e il nodo è in range
	faccio ricevere un danno al nodo
	tolgo la possibilità di muoversi del nodo
	setto il grabbed a true
	lo sprite diventa invisibile
	disattivo le collisioni
se il segnale è di uscita dalla grab e il nodo è grabbato
	il nodo potrà di nuovo muoversi
	setto il grabbed a false
	se il nodo è flipped
		spinge il nodo a sinistra di 450
	altrimenti
		spinge il nodo a destra di 450
	lo sprite diventa visibile
	faccio partire un timer per risettare le collisioni, se le riabilito insieme avviene un bug'

func _on_player_grab(is_been_grabbed, is_flipped):
	if is_been_grabbed and !grabbed and is_in_atk_range:
		if player.char_name == "Nathan":
			emit_signal("got_grabbed", true)
		_on_inhale_time_timeout()
		choosed_atk = Possible_Attacks.IDLE
		$Update_Atk.stop()
		moving = false
		sprinting = false
		grabbed = true
		sprite.visible = false
		body_collider.disabled = true
		healthbar.visible = false
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
		healthbar.visible = true
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

'DIGEST DEL SEGNALE PROPRIO "set_health_bar", AGGIORNA LA BARRA DELLA SALUTE
	il valore della barra diventa uguale a quello della vita attuale
	se il valore della vita è minore o uguale a 0
		cancello il nodo dalla scena'

func set_health_bar():
	healthbar.value = health
	if health <= 0:
		queue_free()

'DIGEST DEL TIMER "GrabTime", IMPOSTA UN DELAY DOPO LA GRAB
	setto le collisioni a true'

func _on_timer_timeout():
	body_collider.disabled = false

# -------- SIGNAL DIGEST -------- #

'DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO'

func _on_inhale_time_timeout():
	moving = true
	sprinting = false
	choosed_atk = Possible_Attacks.IDLE
	sprint_area.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.play("idle")

func _on_area_of_detection_body_entered(body):
	if body == player:
		player_entered = true

func _on_area_of_detection_body_exited(body):
	if body == player:
		player_entered = false

func _on_basic_atk_area_body_entered(body):
	if body == player:
		player_in_atk_range = true

func _on_basic_atk_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_sprint_area_body_entered(body):
	if body == player:
		player_in_atk_range = true
		emit_signal("take_dmg", current_str, 15, 1, current_pbc, current_efc)
		$Inhale_time.start(0.5)
		$Update_Atk.start(0.5)

func _on_sprint_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_effect_animation_finished():
	if stun_timer.is_stopped() and basic_atk_effect.animation == "effect" and not grabbed and player_in_atk_range:
		emit_signal("take_dmg",current_str, 5, 1, current_pbc, current_efc)
		$Basic_atk_Cooldown.start()
	basic_atk_effect.play("idle")
	sprite.play("idle")

func basic_atk():
	if player_entered and stun_timer.is_stopped() and not grabbed and player_in_atk_range and not sprinting:
		basic_atk_effect.play("effect")
		sprite.play("attack")
	$Basic_atk_Cooldown.start()

func sprint():
	if player_entered and stun_timer.is_stopped() and not grabbed and not sprinting:
		sprite.play("charging_sprint")
		moving = false
		$Charge_Time.start()

func _on_charge_time_timeout():
	if stun_timer.is_stopped():
		sprinting = true
		sprint_area.process_mode = Node.PROCESS_MODE_INHERIT
		$Inhale_time.start(6)

func _on_update_atk_timeout():
	if not sprinting:
		choose_atk()
	$Update_Atk.start()

func _on_navigation_agent_2d_velocity_computed(safe_velocity):
	velocity = safe_velocity

func _on_change_stats(stat, amount, time_duration):
	if (is_in_atk_range and !grabbed) or time_duration == 0:
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
