extends CharacterBody2D

var var_velocity = 2
var is_in_atk_range = false
var moving = true
var grabbed = false

signal take_dmg(dmg, sec_stun)

var player_position
var target_position
var player
var cooldown_states = {"basic":false}

var player_entered = false
var player_in_atk_range = false

@onready var sprite = $Sprite2D

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

'METODO CHE VIENE PROCESSATO PER FRAME
	controlla se il player è entrato in area e si può muovere
		allora si muove
	controlla se è grabbato
		allora fa partire il metodo grab()'

func _physics_process(delta):
	if player_entered and moving:
		move()
	if grabbed:
		is_grabbed()

'METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
	salvo la posizione attuale del player
	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
	se il nodo è distante dal player di almeno 16 unità
		muovo il nodo verso il player con la velocità di 3'

func move():
	player_position = player.position
	target_position = (player_position - position).normalized()
	
	if target_position.x < 0:
		$Basic_atk_Area/Effect.position = Vector2(-35.802, -8.642)
		$Basic_atk_Area/Effect.flip_h = false
		sprite.flip_h = true
		$Basic_atk_Area/Skill_collider.position = Vector2(-40.123, -6.237)
	elif target_position.x > 0:
		$Basic_atk_Area/Effect.position = Vector2(35.802, -8.642)
		$Basic_atk_Area/Effect.flip_h = true
		sprite.flip_h = false
		$Basic_atk_Area/Skill_collider.position = Vector2(40.123, -6.237)
	
	if position.distance_to(player_position) > 50:
		sprite.play("running")
		move_and_collide(target_position * 2.5)

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
		#print("take dmg: "+str(dmg))
		moving = false
		$Stun.wait_time = sec
		$Stun.start()
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
		grabbed = true
		sprite.visible = false
		$CollisionShape2D.disabled = true
	if !is_been_grabbed and grabbed:
		moving = true
		grabbed = false
		if is_flipped:
			position.x += -450
		else:
			position.x += 450
		sprite.visible = true
		$GrabTime.start()

'METODO CHE TELETRASPORTA IL NODO NELLA POSIZIONE DEL PLAYER DURANTE LA GRAB
	setto la posizione uguale a quella del player'

func is_grabbed():
	position = player.position

'DIGEST DEL TIMER "Stun"
	setto il movimento a true'

func _on_stun_timeout():
	moving = true
	sprite.play("idle")

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
	$CollisionShape2D.disabled = false

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

func _on_basic_atk_area_body_entered(body):
	if body == player:
		player_in_atk_range = true
		if $Basic_atk_Cooldown.is_stopped():
			$Basic_atk_Area/Effect.play("effect")
			sprite.play("attack")

func _on_basic_atk_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_effect_animation_finished():
	if $Stun.is_stopped() and $Basic_atk_Area/Effect.animation == "effect" and not grabbed and player_in_atk_range:
		emit_signal("take_dmg", 5, 1)
		$Basic_atk_Cooldown.start()
	$Basic_atk_Area/Effect.play("idle")
	sprite.play("idle")

func _on_basic_atk_cooldown_timeout():
	#print("finito")
	if player_entered and $Stun.is_stopped() and not grabbed and player_in_atk_range:
		$Basic_atk_Area/Effect.play("effect")
		sprite.play("attack")
	$Basic_atk_Cooldown.start()
