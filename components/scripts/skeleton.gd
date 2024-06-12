extends CharacterBody2D

@export var vit : int = 200
var current_vit = vit
@export var str : int = 110
var current_str = str
@export var tem : int = 100
var current_tem = tem
@export var des : int = 145
var current_des = des
@export var pbc : int = 30
var current_pbc = pbc
@export var efc : float = 1.5
var current_efc = efc

var var_velocity = 2
var is_in_atk_range = false
var moving = true
var grabbed = false
var parring = false
var dying = false
var soul_out = false

signal take_dmg(str, atk_str, sec_stun, pbc, efc)
signal got_grabbed(is_grabbed)

var player_position
var target_position
var player

enum Possible_Attacks {IDLE, BASIC_ATK, PARRY}
var choosed_atk

@onready var sprite = $Sprite2D
@onready var basic_atk_effect = $Basic_atk_Area/Effect
@onready var basic_atk_collider = $Basic_atk_Area/Skill_collider
@onready var stun_timer = $Stun
@onready var body_collider = $Body_collider

@onready var navigation_agent = $NavigationAgent2D

@onready var healthbar = $HealthBar

var player_entered = true
var player_in_atk_range = false

'METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
	setta la vita attuale a quella massima
	imposta il valore massimo della barra della salute al massimo
	setta la barra della salute'

func _ready():
	$HealthBar.max_value = current_vit
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
	if dying or soul_out:
		pass
	elif parring:
		pass
	elif player_entered and moving:
		chase_player()
		if choosed_atk == Possible_Attacks.BASIC_ATK and $Basic_atk_Cooldown.is_stopped():
			basic_atk()
		elif choosed_atk == Possible_Attacks.PARRY and $Parry_Cooldown.is_stopped():
			parry()
	elif not player_entered and moving:
		if player:
			if not navigation_agent.is_navigation_finished():
				sprite.play("running")
				target_position = navigation_agent.target_position
				velocity = global_position.direction_to(target_position) * 150
				move_and_slide()
			else:
				sprite.play("idle")
	elif not player_entered and not moving and not parring:
		sprite.play("idle")
	if grabbed:
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
		sprite.flip_h = true
		basic_atk_collider.position = Vector2(-42, 16)
		body_collider.position.x = 2
		body_collider.rotation_degrees = -16
	elif distance_to_player.x > 0:
		basic_atk_effect.position = Vector2(49, 12)
		basic_atk_effect.flip_h = true
		sprite.flip_h = false
		basic_atk_collider.position = Vector2(42, 16)
		body_collider.position.x = -1
		body_collider.rotation_degrees = 16

func chase_player():
	if player:
		navigation_agent.target_position = player.global_position
		
		if navigation_agent.is_navigation_finished():
			if sprite.animation == "running":
				sprite.play("idle")
		else:
			var current_agent_position = global_position
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

func choose_atk():
	var rng = randi_range(0,100)
	if rng >= 0 and rng < 10:
		choosed_atk = Possible_Attacks.IDLE
	elif rng >= 10 and rng < 65:
		choosed_atk = Possible_Attacks.BASIC_ATK
	elif rng >= 65:
		choosed_atk = Possible_Attacks.PARRY

'METODO CHE FA VAGARE IL NODO, MA GESTISCE SOLO LO SPOSTAMENTO E NON LA DIREZIONE'

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
		impedisco al nodo di muoversi mentre viene attaccato
		imposto il tempo di stun con il parametro passato
		faccio partire il timer dello stun'

func _on_player_take_dmg(str, atk_str, sec, pbc, efc):
	if dying and not soul_out:
		pass
	elif is_in_atk_range and !grabbed and not parring:
		current_vit -= get_parent().get_parent().calculate_dmg(str, atk_str, self.current_tem, pbc, efc)
		moving = false
		if current_vit > 0:
			stun_timer.wait_time = sec
			stun_timer.start()
			sprite.play("damaged")
		elif current_vit <= 0 and not dying:
			dying = true
			if not sprite.animation == "dying":
				sprite.play("dying")
			current_vit = 1
			body_collider.process_mode = Node.PROCESS_MODE_DISABLED
			$Soul_delay_time.start()
		set_health_bar()
	elif is_in_atk_range and !grabbed and parring:
		$Inhale_time.start(0.8)

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
		if not soul_out or dying:
			if player.char_name == "Nathan":
				emit_signal("got_grabbed", true)
			_on_inhale_time_timeout()
			choosed_atk = Possible_Attacks.IDLE
			$Update_Atk.stop()
			moving = false
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
	if not dying:
		choosed_atk = Possible_Attacks.IDLE
		_on_inhale_time_timeout()

'DIGEST DEL SEGNALE PROPRIO "set_health_bar", AGGIORNA LA BARRA DELLA SALUTE
	il valore della barra diventa uguale a quello della vita attuale
	se il valore della vita è minore o uguale a 0
		cancello il nodo dalla scena'

func set_health_bar():
	if soul_out:
		queue_free()
	else:
		$HealthBar.value = current_vit

'DIGEST DEL TIMER "GrabTime", IMPOSTA UN DELAY DOPO LA GRAB
	setto le collisioni a true'

func _on_timer_timeout():
	body_collider.disabled = false

'DIGEST DELL\'AREA2D "area_of_detection", DETERMINA QUANDO IL PLAYER ENTRA NELLA ZONA
{
	PARAMETRI
	Node body: identifica il nodo che è entrato
}
	se il body è il player
		allora setto che il player è entrato'

func _on_area_of_detection_body_entered(body):
	if body == player:
		player_entered = true

'DIGEST DELL\'AREA2D "area_of_detection", DETERMINA QUANDO IL PLAYER ESCE DALLA ZONA
{
	PARAMETRI
	Node body: identifica il nodo che è entrato
}
	se il body è il player
		allora setto che il player è uscito'

func _on_area_of_detection_body_exited(body):
	if body == player:
		player_entered = false

'DIGEST CHE AGGIORNA LA DIREZIONE QUANDO IL NODO VAGA
	ferma il movimento
	fa partire il tempo di fermo
	aspetta il segnale
	crea un vettore con direzione casuale
	aggiorna il target con il vettore appena creato
	crea una variabile randomica che determina quanto durerà lo spostamento
	aggiorna il wait_time del timer'

func _on_update_direction_timeout():
	moving = false
	sprite.play("idle")
	$Inhale_time.start()
	await _on_inhale_time_timeout
	var updated_vector = Vector2(randf_range(-1,1), randf_range(-1,1))
	target_position = Vector2(updated_vector.x/sqrt(2),updated_vector.y/sqrt(2))
	var new_update_time = randf_range(3,6)
# -------- SIGNAL DIGEST -------- #

'DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO'

func _on_inhale_time_timeout():
	moving = true
	dying = false
	soul_out = false
	if parring:
		parring = false
		sprite.play("idle")

func _on_basic_atk_area_body_entered(body):
	if body == player:
		player_in_atk_range = true

func _on_basic_atk_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_effect_animation_finished():
	if stun_timer.is_stopped() and basic_atk_effect.animation == "effect" and not grabbed and player_in_atk_range:
		emit_signal("take_dmg", current_str, 5, 1, current_pbc, current_efc)
	basic_atk_effect.play("idle")
	sprite.play("idle")
	
func basic_atk():
	if player_entered and stun_timer.is_stopped() and not grabbed and player_in_atk_range and not parring:
		basic_atk_effect.play("effect")
		sprite.play("attack")
	$Basic_atk_Cooldown.start()

func parry():
	if player_entered and stun_timer.is_stopped() and not grabbed and player_in_atk_range and not parring:
		parring = true
		sprite.play("parry")
		$Inhale_time.start(3)
	$Parry_Cooldown.start()

func _on_update_atk_timeout():
	choose_atk()
	$Update_Atk.start()

func _on_soul_delay_time_timeout():
	sprite.play("soul_spawning")

func _on_soul_respawn_time_timeout():
	dying = true
	soul_out = false
	sprite.speed_scale = 0.5
	sprite.play_backwards("dying")

func _on_sprite_2d_animation_finished():
	if sprite.animation == "soul_spawning":
		dying = false
		soul_out = true
		sprite.play("soul_idle")
		$Soul_respawn_time.start()
	
	if sprite.animation == "dying" and sprite.speed_scale == 0.5 and dying:
		sprite.speed_scale = 1
		current_vit = vit
		set_health_bar()
		_on_inhale_time_timeout()


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
			add_child(load("res://scenes/time_of_change.tscn").instantiate(),true)
			var new_timer = get_child(get_child_count()-1)
			new_timer.stat = stat
			new_timer.amount = -amount
			new_timer.wait_time = time_duration
			new_timer.start()
