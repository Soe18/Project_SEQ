extends CharacterBody2D

var var_velocity = 2
var is_in_atk_range = false
var moving = true
var grabbed = false

signal take_dmg(dmg, sec_stun)

var player_position
var target_position
var player

enum Atk_Selected {IDLE, BASIC_ATK, SPRINT}
var choosed_atk
var sprinting = false

@onready var sprite = $Sprite2D
@onready var basic_atk_effect = $Basic_atk_Area/Effect
@onready var basic_atk_collider = $Basic_atk_Area/Skill_collider
@onready var stun_timer = $Stun
@onready var sprite_collider = $Collider

@onready var sprint_area = $Sprint_Area
@onready var sprint_collider = $Sprint_Area/Skill_collider

var player_entered = false
var player_in_atk_range = false

'const SPEED = 300.0
const JUMP_VELOCITY = -400.0'

const MAX_HEALTH = 300

var health

'METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
	setta la vita attuale a quella massima
	imposta il valore massimo della barra della salute al massimo
	setta la barra della salute'

func _ready():
	health = MAX_HEALTH
	$HealthBar.max_value = MAX_HEALTH
	set_health_bar()
	_on_update_direction_timeout()
	$UpdateDirection.start()
	sprite.play("idle")

'METODO CHE VIENE PROCESSATO PER FRAME
	controlla se il player è entrato in area e si può muovere
		allora si muove
	altrimenti se il player NON è entrato in area e si può muovere
		allora comincia a vagare
	controlla se è grabbato
		allora fa partire il metodo grab()'

func _physics_process(delta):
	if sprinting:
		sprint_to_player()
	elif player_entered and moving:
		chase_player()
		if choosed_atk == Atk_Selected.BASIC_ATK and $Basic_atk_Cooldown.is_stopped():
			basic_atk()
		if choosed_atk == Atk_Selected.SPRINT and $Sprint_Cooldown.is_stopped() and not sprinting and $Stun.is_stopped():
			sprint()
	elif not player_entered and moving:
		wander()
	elif not player_entered and not moving:
		sprite.play("idle")
	elif grabbed:
		is_grabbed()

'METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
	salvo la posizione attuale del player
	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
	se il nodo è distante dal player di almeno 12 unità
		muovo il nodo verso il player con la velocità di 3'

func flip():
	if target_position.x < 0:
		basic_atk_effect.position = Vector2(-49, 12)
		basic_atk_effect.flip_h = false
		sprite.flip_h = true
		basic_atk_collider.position = Vector2(-73.5, 5.5)
	elif target_position.x > 0:
		basic_atk_effect.position = Vector2(49, 12)
		basic_atk_effect.flip_h = true
		sprite.flip_h = false
		basic_atk_collider.position = Vector2(73.5, 5.5)

func chase_player():
	player_position = player.position
	target_position = (player_position - position).normalized()
	flip()
	if position.distance_to(player_position) > 100:
		sprite.play("running")
		move_and_collide(target_position * 3)
	elif position.distance_to(player_position) <= 100 and sprite.animation == "running":
		sprite.play("idle")

func sprint_to_player():
	player_position = player.position
	target_position = (player_position - position).normalized()
	flip()
	sprite.play("running")
	move_and_collide(target_position * 5)

func choose_atk():
	var rng = randi_range(0,100)
	if rng >= 0 and rng < 10:
		choosed_atk = Atk_Selected.IDLE
	elif rng >= 10 and rng < 75:
		choosed_atk = Atk_Selected.BASIC_ATK
	elif rng >= 75:
		choosed_atk = Atk_Selected.SPRINT

'METODO CHE FA VAGARE IL NODO, MA GESTISCE SOLO LO SPOSTAMENTO E NON LA DIREZIONE'

func wander():
	sprite.play("running")
	flip()
	move_and_collide(target_position * 2)

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

func _on_player_take_dmg(atk_state, dmg, sec):
	if is_in_atk_range and !grabbed:
		health -= dmg
		set_health_bar()
		moving = false
		sprinting = false
		$Charge_Time.stop()
		stun_timer.wait_time = sec
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
		_on_player_take_dmg(1, 13, 0.1)
		moving = false
		sprinting = false
		grabbed = true
		sprite.visible = false
		sprite_collider.disabled = true
	if !is_been_grabbed and grabbed:
		moving = true
		grabbed = false
		if is_flipped:
			position.x += -450
		else:
			position.x += 450
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
	_on_inhale_time_timeout()

'DIGEST DEL SEGNALE PROPRIO "set_health_bar", AGGIORNA LA BARRA DELLA SALUTE
	il valore della barra diventa uguale a quello della vita attuale
	se il valore della vita è minore o uguale a 0
		cancello il nodo dalla scena'

func set_health_bar():
	$HealthBar.value = health
	if health <= 0:
		queue_free()

'DIGEST DEL TIMER "GrabTime", IMPOSTA UN DELAY DOPO LA GRAB
	setto le collisioni a true'

func _on_timer_timeout():
	sprite_collider.disabled = false

'DIGEST DELL\'AREA2D "area_of_detection", DETERMINA QUANDO IL PLAYER ENTRA NELLA ZONA
{
	PARAMETRI
	Node body: identifica il nodo che è entrato
}
	se il body è il player
		allora setto che il player è entrato'

func _on_area_of_detection_body_entered(body):
	if body == player:
		$UpdateDirection.stop()
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
		$UpdateDirection.start()
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
	$UpdateDirection.wait_time = new_update_time
# -------- SIGNAL DIGEST -------- #

'DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO'

func _on_inhale_time_timeout():
	moving = true
	sprinting = false
	sprint_area.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.play("idle")

func _on_basic_atk_area_body_entered(body):
	if body == player:
		player_in_atk_range = true

func _on_basic_atk_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_sprint_area_body_entered(body):
	if body == player:
		player_in_atk_range = true
		emit_signal("take_dmg", 15, 2)
		$Inhale_time.start(0.5)

func _on_sprint_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_effect_animation_finished():
	if stun_timer.is_stopped() and basic_atk_effect.animation == "effect" and not grabbed and player_in_atk_range:
		emit_signal("take_dmg", 5, 1)
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
		sprint_area.process_mode = Node.PROCESS_MODE_ALWAYS
		$Inhale_time.start(6)

func _on_update_atk_timeout():
	if not sprinting:
		choose_atk()
	$Update_Atk.start()
