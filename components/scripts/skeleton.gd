extends CharacterBody2D

@export var default_vit : int = 70
var current_vit = default_vit
@export var default_str : int = 110
var current_str = default_str
@export var default_tem : int = 100
var current_tem = default_tem
@export var default_des : int = 150
var current_des = default_des
@export var default_pbc : int = 30
var current_pbc = default_pbc
@export var default_efc : float = 1.5
var current_efc = default_efc

@export var damage_node : PackedScene
@export var knockback_timer_node : PackedScene

var var_velocity = 2
var is_in_atk_range = false
var moving = true
var grabbed = false
var grab_position
var knockbacked = false
var knockback_force = 0
var knockback_sender

var parring = false
var dying = false
var soul_out = false

@export var slice_force = 5
@export var slice_stun_time = 0.5
@onready var slice_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

signal take_dmg(str, atk_str, sec_stun, pbc, efc, type)
signal got_grabbed(is_grabbed)
signal shake_camera(shake, strenght)

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

@onready var parry_time = $Parry_time

@onready var soul_delay_timer = $Soul_delay_time

@onready var navigation_agent = $NavigationAgent2D

@onready var healthbar = $HealthBar

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

@onready var status_sprite = $Status_alert_sprite

@onready var update_atk_timer = $Update_Atk

@onready var slash_cooldown = $Basic_atk_Cooldown
@onready var patty_cooldown = $Parry_Cooldown

var player_entered = true
var player_in_atk_range = false

'METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
	setta la vita attuale a quella massima
	imposta il valore massimo della barra della salute al massimo
	setta la barra della salute'

func _ready():
	healthbar.max_value = current_vit
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
	elif knockbacked:
		apply_knockback(knockback_sender)
	elif grabbed:
		is_grabbed()
	elif player_entered and moving:
		chase_player()
		if choosed_atk == Possible_Attacks.BASIC_ATK and slash_cooldown.is_stopped():
			basic_atk()
		elif choosed_atk == Possible_Attacks.PARRY and patty_cooldown.is_stopped():
			parry()
	elif not player_entered and moving:
		if player:
			if not navigation_agent.is_navigation_finished():
				sprite.play("running")
				target_position = navigation_agent.target_position
				velocity = global_position.direction_to(target_position) * current_des
				move_and_slide()
			else:
				sprite.play("idle")
	elif not player_entered and not moving and not parring:
		sprite.play("idle")

'METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
	salvo la posizione attuale del player
	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
	se il nodo è distante dal player di almeno 12 unità
		muovo il nodo verso il player con la velocità di 3'

func flip(distance_to_player):
	if distance_to_player.x < 0:
		basic_atk_effect.position = Vector2(-57, 12)
		basic_atk_effect.flip_h = false
		sprite.flip_h = true
		basic_atk_collider.position = Vector2(-48, 16)
		body_collider.position.x = 2
		body_collider.rotation_degrees = -16
		if grabbed:
			sprite.rotation_degrees = -90;
	elif distance_to_player.x > 0:
		basic_atk_effect.position = Vector2(57, 12)
		basic_atk_effect.flip_h = true
		sprite.flip_h = false
		basic_atk_collider.position = Vector2(48, 16)
		body_collider.position.x = -1
		body_collider.rotation_degrees = 16
		if grabbed:
			sprite.rotation_degrees = 90;

func chase_player():
	if player:
		navigation_agent.target_position = player.global_position
		
		if navigation_agent.is_navigation_finished():
			if sprite.animation == "running":
				sprite.play("idle")
		else:
			target_position = navigation_agent.get_next_path_position()
			
			var new_velocity = global_position.direction_to(target_position) * current_des
			
			if navigation_agent.avoidance_enabled:
				navigation_agent.set_velocity(new_velocity)
			else:
				_on_navigation_agent_2d_velocity_computed(new_velocity)
			
			sprite.play("running")
			move_and_slide()
		player_position = (player.position - position).normalized()
		flip(player_position)

func choose_atk():
	var rng = randi_range(0,100)
	if rng >= 0 and rng < 10:
		choosed_atk = Possible_Attacks.IDLE
	elif rng >= 10 and rng < 55:
		choosed_atk = Possible_Attacks.BASIC_ATK
	elif rng >= 55:
		choosed_atk = Possible_Attacks.PARRY

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

func _on_player_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc, type):
	if is_in_atk_range and !grabbed and not parring:
		var dmg_info = get_parent().get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc, type)
		var dmg = dmg_info[0]
		show_hitmarker("-" + str(dmg), dmg_info[1])
		current_vit -= dmg
		if dmg > 0:
			emit_signal("shake_camera", true, dmg_info[2])
		if stun_sec > 0 and not (dying or soul_out):
			moving = false
			stun_timer.wait_time = stun_sec
			stun_timer.start()
			sprite.play("damaged")
		set_health_bar()
	
	elif is_in_atk_range and !grabbed and parring:
		parry_time.start(0.8)

# DIGEST DEL SENGALE DEL PLAYER "grab" #

func _on_player_grab(is_been_grabbed, is_flipped, grab_position_marker):
	if is_been_grabbed and !grabbed and is_in_atk_range and not dying and not soul_out:
		set_idle()
		sprite.play("damaged")
		update_atk_timer.stop()
		moving = false
		grabbed = true
		body_collider.set_deferred("disabled", true)
		grab_position = grab_position_marker
		
		if player.char_name == "Nathan":
			emit_signal("got_grabbed", true)
			healthbar.visible = false
		
	if !is_been_grabbed and grabbed:
		set_idle()
		grabbed = false
		body_collider.set_deferred("disabled", false)
		is_in_atk_range = true
		init_knockback(450, 0.5, player.global_position)
		is_in_atk_range = false
		healthbar.visible = true
		
		if player.char_name == "Nathan":
			emit_signal("got_grabbed", false)
			sprite.rotation_degrees = 0;
			healthbar.visible = true

# METODO CHE TELETRASPORTA IL NODO NELLA POSIZIONE DEL PLAYER DURANTE LA GRAB #

func is_grabbed():
	flip((player.position - position).normalized())
	position = grab_position.global_position

'DIGEST DEL TIMER "Stun"
	setto il movimento a true'

func _on_stun_timeout():
	if not dying:
		choosed_atk = Possible_Attacks.IDLE
		set_idle()

'DIGEST DEL SEGNALE PROPRIO "set_health_bar", AGGIORNA LA BARRA DELLA SALUTE
	il valore della barra diventa uguale a quello della vita attuale
	se il valore della vita è minore o uguale a 0
		cancello il nodo dalla scena'

func set_health_bar():
	if soul_out and current_vit <= 0:
		queue_free()
	elif current_vit <= 0 and not dying:
			set_idle()
			dying = true
			sprite.play("dying")
			current_vit = 1
			soul_delay_timer.start()
	elif current_vit > default_vit:
			current_vit = default_vit
	
	healthbar.value = current_vit

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


# -------- SIGNAL DIGEST -------- #

'DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO'

func set_idle():
	if not knockbacked and not grabbed and not (dying or soul_out):
		moving = true
		dying = false
		soul_out = false
		if parring:
			parring = false
			sprite.play("idle")
		basic_atk_effect.play("idle")
		body_collider.set_deferred("disabled", false)

func _on_basic_atk_area_body_entered(body):
	if body == player:
		player_in_atk_range = true

func _on_basic_atk_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_effect_animation_finished():
	if stun_timer.is_stopped() and basic_atk_effect.animation == "effect" and not grabbed and player_in_atk_range and not (soul_out or dying):
		emit_signal("take_dmg", current_str, slice_force, slice_stun_time, current_pbc, current_efc, slice_type)
	basic_atk_effect.play("idle")
	set_idle()
	
func basic_atk():
	if player_entered and stun_timer.is_stopped() and not grabbed and player_in_atk_range and not parring:
		moving = false
		basic_atk_effect.play("effect")
		sprite.play("attack")
	slash_cooldown.start()

func parry():
	if player_entered and stun_timer.is_stopped() and not grabbed and player_in_atk_range and not parring:
		parring = true
		sprite.play("parry")
		parry_time.start()
	patty_cooldown.start()

func _on_parry_time_timeout() -> void:
	set_idle()

func _on_update_atk_timeout():
	choose_atk()
	update_atk_timer.start()

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
		current_vit = default_vit
		set_health_bar()
		dying = false
		set_idle()


func _on_navigation_agent_2d_velocity_computed(safe_velocity):
	velocity = safe_velocity

func init_knockback(amount, time, sender):
	if is_in_atk_range and not grabbed and not parring:
		moving = false
		knockbacked = true
		knockback_force = amount
		knockback_sender = sender
		
		self.add_child(knockback_timer_node.instantiate(), true)
		var timer_node = get_child(get_child_count()-1)
		timer_node.wait_time = time
		timer_node.reset_knockback.connect(self._on_knockback_reset_timeout)
		timer_node.start()

func apply_knockback(sender):
	velocity = sender.direction_to(self.global_position) * knockback_force
	move_and_slide()

func _on_knockback_reset_timeout():
	knockbacked = false

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
			new_timer.reset_stats.connect(self._on_change_stats)
			new_timer.start()

func _on_status_alert_sprite_animation_finished():
	status_sprite.play("idle")

func show_hitmarker(dmg, crit):
	var hitmarker = damage_node.instantiate()
	hitmarker.position = hitmarker_spawnpoint.global_position
	
	var tween = get_tree().create_tween()
	tween.tween_property(hitmarker, 
						"position", 
						hitmarker_spawnpoint.global_position + (Vector2(randf_range(-1,1), -randf()) * 40), 
						0.75)
	
	hitmarker.get_child(0).text = dmg
	if crit:
		hitmarker.get_child(0).set("theme_override_colors/font_color", Color.GOLDENROD)
	get_tree().current_scene.add_child(hitmarker)
