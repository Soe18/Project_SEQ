extends CharacterBody2D

@export var default_vit : int = 225
var current_vit = default_vit
@export var default_str : int = 175
var current_str = default_str
@export var default_tem : int = 100
var current_tem = default_tem
@export var default_des : int = 175
var current_des = default_des
@export var default_pbc : int = 40
var current_pbc = default_pbc
@export var default_efc : float = 1.5
var current_efc = default_efc

@export var damage_node : PackedScene
@export var knockback_timer_node : PackedScene

var is_in_atk_range = false
var moving = true
var grabbed = false
var grab_position
var knockbacked = false
var knockback_force = 0
var knockback_sender

var agility_percentage = 20
var agility_activated = false
var agility_multiplyer = 50

@export var claw_force = 3.2
@export var claw_stun_time = 0.2
@export var howl_amount = 50
@export var howl_duration = 15
@export var howl_changed_stat = "str"

var second_time_claw = true

signal take_dmg(str, atk_str, sec_stun, pbc, efc)
signal got_grabbed(is_grabbed)
signal change_stats(stat, amount, time_duration, ally_sender)

var target_position
var player

enum Possible_Attacks {IDLE, CLAWS, HOWL, AGILITY}
var choosed_atk

@onready var navigation_agent = $NavigationAgent2D

@onready var sprite = $Sprite2D

@onready var stun_timer = $Stun

@onready var body_collider = $Body_collider

@onready var claws_area = $Claws_area
@onready var claws_collider = $Claws_area/Collider

@onready var howl_effect_sprite = $Howl_effect

@onready var healthbar = $Control/HealthBar

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

@onready var area_of_detection = $Area_of_detection

@onready var status_sprite = $Status_alert_sprite

@onready var update_atk_timer = $Update_Atk

@onready var claws_cooldown = $Claws_cooldown
@onready var howl_cooldown = $Howl_cooldown
@onready var agility_cooldown = $Agility_cooldown

@onready var howl_charge_time = $Howl_charge_time
@onready var agility_duration = $Agility_duration

var player_entered = true
var player_in_atk_range = false

#METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
#	setta la vita attuale a quella massima
#	imposta il valore massimo della barra della salute al massimo
#	setta la barra della salute

func _ready():
	healthbar.max_value = default_vit
	set_health_bar()
	sprite.play("idle")

#METODO CHE VIENE PROCESSATO PER FRAME
#	controlla se il player è entrato in area e si può muovere
#		allora si muove
#	altrimenti se il player NON è entrato in area e si può muovere
#		allora comincia a vagare
#	controlla se è grabbato
#		allora fa partire il metodo grab()

func _physics_process(_delta):
	if knockbacked:
		apply_knockback(knockback_sender)
	elif grabbed:
		is_grabbed()
	elif player_entered and moving:
		chase_player()
		if choosed_atk == Possible_Attacks.CLAWS and claws_cooldown.is_stopped():
			claws()
		if choosed_atk == Possible_Attacks.HOWL and howl_cooldown.is_stopped():
			howl()
	elif not player_entered and moving and sprite.animation != "howl":
		if player:
			if not navigation_agent.is_navigation_finished():
				sprite.play("running")
				target_position = navigation_agent.target_position
				velocity = global_position.direction_to(target_position) * 150
				move_and_slide()
			else:
				sprite.play("idle")
	elif not player_entered and not moving and sprite.animation != "howl":
		sprite.play("idle")

#METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
#	salvo la posizione attuale del player
#	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
#	se il nodo è distante dal player di almeno 12 unità
#		muovo il nodo verso il player con la velocità di 3
func flip(distance_to_player):
	if distance_to_player.x < 0:
		body_collider.position = Vector2(19, 16)
		body_collider.rotation_degrees = -11
		body_collider.position.x = 7
		claws_collider.position.x = -33
		sprite.flip_h = true
		if grabbed:
			sprite.rotation_degrees = -90;
	elif distance_to_player.x > 0:
		body_collider.position = Vector2(-6, 16)
		body_collider.rotation_degrees = 11
		body_collider.position.x = -7
		claws_collider.position.x = 33
		sprite.flip_h = false
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
		var player_position = (player.position - position).normalized()
		flip(player_position)

func choose_atk():
	var rng = randi_range(0,100)
	if rng < 75:
		choosed_atk = Possible_Attacks.CLAWS
	elif rng >= 75:
		choosed_atk = Possible_Attacks.HOWL
	
	#choosed_atk = Possible_Attacks.HOWL

func claws():
	if player_entered and stun_timer.is_stopped() and not grabbed and player_in_atk_range:
		sprite.play("claws")
		if agility_activated:
			second_time_claw = false
	claws_cooldown.start()

func howl():
	if stun_timer.is_stopped() and not grabbed:
		moving = false
		sprite.play("howl")
		howl_charge_time.start()
	howl_cooldown.start()

func agility():
	agility_activated = true
	sprite.speed_scale = 1.5
	howl_effect_sprite.speed_scale = 1.5
	current_des += agility_multiplyer
	status_sprite.play("buff")
	init_knockback(100, 0.8, player.global_position)
	sprite.play("agility")
	agility_cooldown.start()
	agility_duration.start()

# -------- SIGNAL DIGEST -------- #

#DIGEST DEL SEGNALE DEL PLAYER "is_in_atk_range"
#{
#	PARAMETRI
#	boolean is_in: identifica se il nodo è entrato oppure è uscito
#	Node body: identifica il nodo che è entrato o uscito
#}
#	se il segnale che manda al nodo è di entrata nell'area e il nodo è questo
#		allora il nodo è dentro l'area del player
#	altrimenti
#		non è in range
func _on_player_is_in_atk_range(is_in, body):
	if is_in and body == self and not is_in_atk_range:
		is_in_atk_range = true
	else:
		is_in_atk_range = false
	
#DIGEST DEL SEGNALE DEL PLAYER "take_dmg"
#{
#	PARAMETRI
#	int atk_state: DEPRECATO
#	int dmg: quantità del danno inflitto
#	float sec: tempo dello stun
#}
#	se il nodo è in range e non è grabbato
#		allora sottraggo alla vita il danno
#		setto la barra della vita con il nuovo valore
#		# print di debug #
#		impedisco al nodo di muoversi mentre viene attaccato
#		imposto il tempo di stun con il parametro passato
#		faccio partire il timer dello stun
func _on_player_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc):
	if is_in_atk_range and not grabbed and not knockbacked:
		var dmg = get_parent().get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc)
		
		var rng = randi_range(0, 100)
		if agility_cooldown.is_stopped() and rng <= agility_percentage:
			agility()
		
		if not agility_activated: 
			show_hitmarker("-" + str(dmg))
			current_vit -= dmg
			set_health_bar()
			if stun_sec > 0:
				moving = false
				howl_charge_time.stop()
				stun_timer.wait_time = stun_sec
				stun_timer.start()
				sprite.play("damaged")
		else:
			show_hitmarker("Schivato")
			sprite.play("agility")
			howl_charge_time.stop()

# DIGEST DEL SENGALE DEL PLAYER "grab" #

func _on_player_grab(is_been_grabbed, is_flipped, grab_position_marker):
	if not agility_activated:
		if is_been_grabbed and !grabbed and is_in_atk_range:
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
	else:
		show_hitmarker("Schivato")
		sprite.play("agility")
		howl_charge_time.stop()

# METODO CHE TELETRASPORTA IL NODO NELLA POSIZIONE DEL PLAYER DURANTE LA GRAB #

func is_grabbed():
	flip((player.position - position).normalized())
	position = grab_position.global_position

#DIGEST DEL TIMER "Stun"
#	setto il movimento a true
func _on_stun_timeout():
	choosed_atk = Possible_Attacks.IDLE
	set_idle()

#DIGEST DEL SEGNALE PROPRIO "set_health_bar", AGGIORNA LA BARRA DELLA SALUTE
#	il valore della barra diventa uguale a quello della vita attuale
#	se il valore della vita è minore o uguale a 0
#		cancello il nodo dalla scena
func set_health_bar():
	healthbar.value = current_vit
	if current_vit <= 0:
		queue_free()
	elif current_vit > default_vit:
		current_vit = default_vit

# -------- SIGNAL DIGEST -------- #

# DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO
func set_idle():
	if not knockbacked and not grabbed:
		moving = true
		choosed_atk = Possible_Attacks.IDLE
		sprite.play("idle")
		howl_effect_sprite.play("idle")
		howl_charge_time.stop()

func _on_sprite_2d_animation_finished() -> void:
	if sprite.animation == "claws" and not second_time_claw:
		sprite.play("claws")
		second_time_claw = true
	else:
		set_idle()

func _on_sprite_2d_frame_changed() -> void:
	if sprite.animation == "claws" and (sprite.frame == 1 or sprite.frame == 4):
		emit_signal("take_dmg", current_str, claw_force, claw_stun_time, current_pbc, current_efc)

func _on_area_of_detection_body_entered(body):
	if body == player:
		player_entered = true

func _on_area_of_detection_body_exited(body):
	if body == player:
		player_entered = false

func _on_claws_area_body_entered(body: Node2D) -> void:
	if body == player:
		player_in_atk_range = true

func _on_claws_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_atk_range = false

func _on_howl_charge_time_timeout() -> void:
	sprite.frame = 1
	howl_effect_sprite.play("effect")
	emit_signal("change_stats", howl_changed_stat, howl_amount, howl_duration, true)

func _on_howl_effect_animation_finished() -> void:
	set_idle()

func _on_agility_duration_timeout() -> void:
	agility_activated = false
	sprite.speed_scale = 1
	howl_effect_sprite.speed_scale = 1
	current_des -= agility_multiplyer

# //////////// AREA COMUNE TRA NODI //////////// #

func _on_update_atk_timeout():
	choose_atk()
	$Update_Atk.start()

func _on_navigation_agent_2d_velocity_computed(safe_velocity):
	velocity = safe_velocity

func init_knockback(amount, time, sender):
	if (is_in_atk_range and not grabbed and not agility_activated) or sender == self.global_position:
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
	set_idle()

func _on_change_stats(stat, amount, time_duration, ally_sender):
	if (is_in_atk_range and !grabbed) or time_duration == 0 or ally_sender:
		if (ally_sender and agility_activated) or not agility_activated:
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