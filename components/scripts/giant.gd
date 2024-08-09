extends CharacterBody2D

@export var default_vit : int = 400
var current_vit = default_vit
@export var default_str : int = 200
var current_str = default_str
@export var default_tem : int = 148
var current_tem = default_tem
@export var default_des : int = 145
var current_des = default_des
@export var default_pbc : int = 30
var current_pbc = default_pbc
@export var default_efc : float = 1.5
var current_efc = default_efc

@export var damage_node : PackedScene

var is_in_atk_range = false
var moving = true
var grabbed = false

signal take_dmg(str, atk_str, sec_stun, pbc, efc)
signal got_grabbed(is_grabbed)

var player_position
var target_position
var player

var attacking = false

enum Possible_Attacks {IDLE, PUNCH, EARTHQUAKE, GIGAGRAB}
var choosed_atk

@onready var sprite = $Sprite2D

@onready var punch_area = $Punch_Area
@onready var punch_collider = $Punch_Area/Skill_collider
@onready var punch_effect = $Punch_Area/Effect

@onready var earthquake_area = $Earthquake_Area
@onready var earthquake_collider = $Earthquake_Area/Skill_collider
@onready var earthquake_effect = $Earthquake_Area/Effect

@onready var stun_timer = $Stun

@onready var body_collider = $Body_collider

@onready var navigation_agent = $NavigationAgent2D

@onready var healthbar = $HealthBar

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

@onready var status_sprite = $Status_alert_sprite

var player_entered = true
var player_in_atk_range = false

'METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
	setta la vita attuale a quella massima
	imposta il valore massimo della barra della salute al massimo
	setta la barra della salute'

func _ready():
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
	if player_entered and moving and not attacking:
		chase_player()
		if choosed_atk == Possible_Attacks.PUNCH and $Punch_Cooldown.is_stopped():
			punch()
		if choosed_atk == Possible_Attacks.EARTHQUAKE and $Earthquake_Cooldown.is_stopped() and stun_timer.is_stopped():
			earthquake()
	elif not player_entered and moving:
		if player:
			if not navigation_agent.is_navigation_finished():
				sprite.play("running")
				target_position = navigation_agent.target_position
				velocity = global_position.direction_to(target_position) * 150
				move_and_slide()
			else:
				sprite.play("idle")
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

func flip(distance_to_player):
	if distance_to_player.x < 0:
		punch_collider.position = Vector2(-62.95, 13)
		punch_effect.position = Vector2(-59,-5)
		punch_effect.flip_h = true
		sprite.flip_h = true
		body_collider.rotation_degrees = -16.5
		body_collider.position.x = -6.835
	elif distance_to_player.x > 0:
		punch_collider.position = Vector2(62.95, 13)
		punch_effect.position = Vector2(59,-5)
		punch_effect.flip_h = false
		sprite.flip_h = false
		body_collider.rotation_degrees = 16.5
		body_collider.position.x = 11.151

func chase_player():
	if player:
		navigation_agent.target_position = player.global_position
		
		if navigation_agent.is_navigation_finished():
			if sprite.animation == "running":
				sprite.play("idle")
		else:
			var current_agent_position = global_position
			target_position = navigation_agent.get_next_path_position()
			
			var new_velocity = global_position.direction_to(target_position) * 125
			
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
	if rng >= 0 and rng < 20:
		choosed_atk = Possible_Attacks.IDLE
	elif rng >= 20 and rng <= 80:
		choosed_atk = Possible_Attacks.PUNCH
	elif rng >= 80:
		choosed_atk = Possible_Attacks.EARTHQUAKE
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
		current_vit -= dmg
		set_health_bar()
		if dmg >= 25 and stun_sec > 0:
			punch_effect.play("idle")
			sprite.position = Vector2(0,0)
			attacking = false
			moving = false
			stun_timer.start(stun_sec)
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
		_on_inhale_time_timeout()
		if player.char_name == "Nathan":
				emit_signal("got_grabbed", true)
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
		sprite.visible = true
		healthbar.visible = true
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
	healthbar.value = current_vit
	if current_vit <= 0:
		queue_free()

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
		player.current_multiplyer = player.OK_MULTIPLYER
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
		emit_signal("take_dmg", current_str, 25, 2.4, current_pbc, current_efc)
		_on_inhale_time_timeout()
	if earthquake_effect.animation == "effect":
		_on_inhale_time_timeout()

func _on_effect_frame_changed():
	if earthquake_effect.animation == "effect" and earthquake_effect.frame%2==0 and stun_timer.is_stopped() and not grabbed and player_in_atk_range:
		emit_signal("take_dmg", current_str, 3.5, 0, 0, 0)
		if player.current_multiplyer == player.OK_MULTIPLYER:
			player.current_multiplyer -= 200
			player.status_sprite.play("debuff")

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
