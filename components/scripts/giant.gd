extends CharacterBody2D

@export var vit : int = 500
var current_vit = vit
@export var str : int = 200
var current_str = str
@export var tem : int = 148
var current_tem = tem
@export var des : int = 145
var current_des = des
@export var pbc : int = 30
var current_pbc = pbc
@export var efc : float = 1.5
var current_efc = efc

var is_in_atk_range = false
var moving = true
var grabbed = false

signal take_dmg(str, atk_str, sec_stun)

var player_position
var target_position
var player

var attacking = false

enum Atk_Selected {IDLE, PUNCH, EARTHQUAKE, GIGAGRAB}
var choosed_atk

@onready var sprite = $Sprite2D

@onready var punch_area = $Punch_Area
@onready var punch_collider = $Punch_Area/Skill_collider
@onready var punch_effect = $Punch_Area/Effect

@onready var earthquake_area = $Earthquake_Area
@onready var earthquake_collider = $Earthquake_Area/Skill_collider
@onready var earthquake_effect = $Earthquake_Area/Effect

@onready var stun_timer = $Stun

@onready var head_collider = $Head_collider
@onready var body_collider = $Body_collider
@onready var legs_collider = $Legs_collider

@onready var update_direction_timer = $UpdateDirection

var player_entered = false
var player_in_atk_range = false

var health

'METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
	setta la vita attuale a quella massima
	imposta il valore massimo della barra della salute al massimo
	setta la barra della salute'

func _ready():
	health = vit
	$HealthBar.max_value = vit
	set_health_bar()
	_on_update_direction_timeout()
	update_direction_timer.start()
	sprite.play("idle")

'METODO CHE VIENE PROCESSATO PER FRAME
	controlla se il player è entrato in area e si può muovere
		allora si muove
	altrimenti se il player NON è entrato in area e si può muovere
		allora comincia a vagare
	controlla se è grabbato
		allora fa partire il metodo grab()'

func _physics_process(delta):
	if player_entered and moving:
		chase_player()
		if choosed_atk == Atk_Selected.PUNCH and $Punch_Cooldown.is_stopped():
			punch()
		if choosed_atk == Atk_Selected.EARTHQUAKE and $Earthquake_Cooldown.is_stopped() and stun_timer.is_stopped():
			earthquake()
	elif not player_entered and moving:
		wander()
	elif not player_entered and not moving and not attacking:
		sprite.play("idle")
		punch_effect.play("idle")
		earthquake_effect.play("idle")
	elif grabbed:
		is_grabbed()

'METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
	salvo la posizione attuale del player
	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
	se il nodo è distante dal player di almeno 12 unità
		muovo il nodo verso il player con la velocità di 3'

func flip():
	if target_position.x < 0:
		punch_collider.position = Vector2(-50, 13)
		punch_effect.position = Vector2(-59,-5)
		punch_effect.flip_h = true
		sprite.flip_h = true
	elif target_position.x > 0:
		punch_collider.position = Vector2(50, 13)
		punch_effect.position = Vector2(59,-5)
		punch_effect.flip_h = false
		sprite.flip_h = false

func chase_player():
	player_position = player.position
	target_position = (player_position - position).normalized()
	flip()
	if position.distance_to(player_position) > 200:
		sprite.play("running")
		move_and_collide(target_position * 1.5)
	elif position.distance_to(player_position) <= 200 and sprite.animation == "running":
		sprite.play("idle")

func choose_atk():
	var rng = randi_range(0,100)
	if rng >= 0 and rng < 15:
		choosed_atk = Atk_Selected.IDLE
	elif rng >= 15 and rng <= 72:
		choosed_atk = Atk_Selected.PUNCH
	elif rng >= 72:
		choosed_atk = Atk_Selected.EARTHQUAKE

'METODO CHE FA VAGARE IL NODO, MA GESTISCE SOLO LO SPOSTAMENTO E NON LA DIREZIONE'

func wander():
	sprite.play("running")
	flip()
	move_and_collide(target_position * 1)

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

func _on_player_take_dmg(str, atk_str, sec):
	if is_in_atk_range and !grabbed:
		var dmg = get_parent().get_parent().calculate_dmg(str, atk_str, self.tem)
		health -= dmg
		set_health_bar()
		if dmg >= 25:
			punch_effect.play("idle")
			sprite.position = Vector2(0,0)
			attacking = false
			moving = false
			stun_timer.start(sec)
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
		_on_player_take_dmg(current_str, 13, 0.1)
		moving = false
		grabbed = true
		sprite.visible = false
		head_collider.disabled = true
		body_collider.disabled = true
		legs_collider.disabled = true
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
	head_collider.disabled = false
	body_collider.disabled = false
	legs_collider.disabled = false

'DIGEST DELL\'AREA2D "area_of_detection", DETERMINA QUANDO IL PLAYER ENTRA NELLA ZONA
{
	PARAMETRI
	Node body: identifica il nodo che è entrato
}
	se il body è il player
		allora setto che il player è entrato'

func _on_area_of_detection_body_entered(body):
	if body == player:
		update_direction_timer.stop()
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
		update_direction_timer.start()
		player_entered = false

func _on_punch_area_body_entered(body):
	if body == player:
		print("pugno entrato")
		player_in_atk_range = true

func _on_punch_area_body_exited(body):
	if body == player:
		print("pugno uscito")
		player_in_atk_range = false

func _on_earthquake_area_body_entered(body):
	if body == player:
		player_in_atk_range = true

func _on_earthquake_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

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
	update_direction_timer.wait_time = new_update_time
# -------- SIGNAL DIGEST -------- #

func _on_sprite_2d_animation_finished():
	if sprite.animation == "punch":
		_on_inhale_time_timeout()

func _on_sprite_2d_frame_changed():
	if (sprite.animation == "earthquake" and sprite.frame == 1) or (sprite.animation == "earthquake" and sprite.frame == 3) or (sprite.animation == "earthquake" and sprite.frame == 7):
		if earthquake_effect.is_playing():
			earthquake_effect.stop()
			earthquake_effect.play("effect")
		else:
			earthquake_effect.play("effect")

'FUNZIONE PER L\'ATTACCO PUGNO'

func punch():
	if stun_timer.is_stopped() and not grabbed:
		$Punch_Cooldown.start()
		attacking = true
		if sprite.flip_h:
			sprite.position = Vector2(-40,0)
		else:
			sprite.position = Vector2(40,0)
		moving = false
		sprite.play("punch")
		punch_effect.play("effect")
		punch_area.process_mode = Node.PROCESS_MODE_INHERIT

func _on_effect_animation_finished():
	if punch_effect.animation == "effect" and stun_timer.is_stopped() and not grabbed and player_in_atk_range:
		emit_signal("take_dmg", str, 25, 2.4)
		_on_inhale_time_timeout()
	if earthquake_effect.animation == "effect":
		_on_inhale_time_timeout()

func _on_effect_frame_changed():
	if earthquake_effect.animation == "effect" and earthquake_effect.frame%2==0 and stun_timer.is_stopped() and not grabbed and player_in_atk_range:
		emit_signal("take_dmg", str, 2, 0.5)

'FUNZIONE PER L\'ATTACCO TERREMOTO'

func earthquake():
	if player_entered and stun_timer.is_stopped() and not grabbed:
		$Earthquake_Cooldown.start()
		attacking = true
		moving = false
		sprite.play("earthquake")
		earthquake_area.process_mode = Node.PROCESS_MODE_INHERIT

'DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO'

func _on_inhale_time_timeout():
	sprite.position = Vector2(0,0)
	moving = true
	attacking = false
	punch_area.process_mode = Node.PROCESS_MODE_DISABLED
	earthquake_area.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.play("idle")
	punch_effect.play("idle")
	earthquake_effect.play("idle")

func _on_update_atk_timeout():
	choose_atk()
	$Update_Atk.start()
