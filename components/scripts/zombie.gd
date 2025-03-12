extends CharacterBody2D

@export var default_vit : int = 50
var current_vit = default_vit
@export var default_str : int = 125
var current_str = default_str
@export var default_tem : int = 121
var current_tem = default_tem
@export var default_des : int = 150
var current_des = default_des
@export var default_pbc : int = 30
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

signal take_dmg(str, atk_str, sec_stun, pbc, efc, type)
signal got_grabbed(is_grabbed)
signal shake_camera(shake, strenght)

var BODY_COLLIDER_POSITION_X
var BODY_COLLIDER_ROTATION
var BITE_EFFECT_X
var BITE_COLLIDER_POSITION_X

var target_position
var player

enum Possible_Attacks {IDLE, BITE, SPRINT}
var choosed_atk

var sprinting = false

@export var bite_force = 5
@export var bite_stun_time = 0.5
@onready var bite_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

@export var sprint_force = 10
@export var sprint_stun_time = 0.3
@export var sprint_multiplyer = 5
@export var sprint_duration = 6.0
@onready var sprint_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

@onready var navigation_agent = $NavigationAgent2D

@onready var sprite = $Sprite2D

@onready var bite_effect = $Bite_Area/Effect
@onready var bite_collider = $Bite_Area/Collider
@onready var stun_timer = $Stun

@onready var body_collider = $Body_collider

@onready var sprint_collider = $Sprint_Area/Collider

@onready var sprint_charge_time = $Charge_Time
@onready var sprint_time = $Sprint_time

@onready var healthbar = $Control/HealthBar

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

@onready var area_of_detection = $Area_of_detection

@onready var status_sprite = $Status_alert_sprite
@onready var hit_flash_player = $Hit_flash_player

@onready var update_atk_timer = $Update_Atk

@onready var bite_cooldown = $Bite_Cooldown
@onready var sprint_cooldown = $Sprint_Cooldown

var player_entered = true
var player_in_atk_range = false

'METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
	setta la vita attuale a quella massima
	imposta il valore massimo della barra della salute al massimo
	setta la barra della salute'

func _ready():
	healthbar.max_value = default_vit
	set_health_bar()
	BODY_COLLIDER_POSITION_X = body_collider.position.x
	BODY_COLLIDER_ROTATION = body_collider.rotation_degrees
	BITE_EFFECT_X = bite_effect.position.x
	BITE_COLLIDER_POSITION_X = bite_effect.position.x
	sprite.play("idle")

'METODO CHE VIENE PROCESSATO PER FRAME
	controlla se il player è entrato in area e si può muovere
		allora si muove
	altrimenti se il player NON è entrato in area e si può muovere
		allora comincia a vagare
	controlla se è grabbato
		allora fa partire il metodo grab()'

func _physics_process(_delta):
	if knockbacked:
		apply_knockback(knockback_sender)
	elif grabbed:
		is_grabbed()
	elif sprinting:
		sprint_to_player()
	elif player_entered and moving:
		chase_player()
		if choosed_atk == Possible_Attacks.BITE and bite_cooldown.is_stopped():
			bite()
		if choosed_atk == Possible_Attacks.SPRINT and sprint_cooldown.is_stopped() and not sprinting and $Stun.is_stopped():
			sprint()
	elif not player_entered and moving:
		if player:
			if not navigation_agent.is_navigation_finished():
				sprite.play("running")
				target_position = navigation_agent.target_position
				velocity = global_position.direction_to(target_position) * current_des
				move_and_slide()
			else:
				sprite.play("idle")
	elif not player_entered and not moving:
		sprite.play("idle")

'METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
	salvo la posizione attuale del player
	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
	se il nodo è distante dal player di almeno 12 unità
		muovo il nodo verso il player con la velocità di 3'

func flip(distance_to_player):
	if distance_to_player.x < 0:
		body_collider.position.x = BODY_COLLIDER_POSITION_X
		body_collider.rotation_degrees = -BODY_COLLIDER_ROTATION
		sprite.flip_h = true
		bite_effect.position.x = -BITE_EFFECT_X
		bite_effect.flip_h = false
		bite_collider.position.x = -BITE_COLLIDER_POSITION_X
		
	elif distance_to_player.x > 0:
		body_collider.position.x = -BODY_COLLIDER_POSITION_X
		body_collider.rotation_degrees = BODY_COLLIDER_ROTATION
		sprite.flip_h = false
		bite_effect.position.x = BITE_EFFECT_X
		bite_effect.flip_h = true
		bite_collider.position.x = BITE_COLLIDER_POSITION_X

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

func sprint_to_player():
	if player != null:
		var player_position = player.position
		target_position = (player_position - position).normalized()
		flip(target_position)
		
		sprite.play("running")
		move_and_collide(target_position * sprint_multiplyer)

func choose_atk():
	var rng = randi_range(0,100)
	if rng >= 0 and rng < 10:
		choosed_atk = Possible_Attacks.IDLE
	elif rng >= 10 and rng < 85:
		choosed_atk = Possible_Attacks.BITE
	else:
		choosed_atk = Possible_Attacks.SPRINT


# -------- SIGNAL DIGEST -------- #

#DIGEST DEL SEGNALE DEL PLAYER "is_in_atk_range"
#{
	#PARAMETRI
	#boolean is_in: identifica se il nodo è entrato oppure è uscito
	#Node body: identifica il nodo che è entrato o uscito
#}
	#se il segnale che manda al nodo è di entrata nel\'area e il nodo è questo
		#allora il nodo è dentro l\'area del player
	#altrimenti
		#non è in range

func _on_player_is_in_atk_range(is_in, body):
	if is_in and body == self and not is_in_atk_range:
		is_in_atk_range = true
	else:
		is_in_atk_range = false
	
#DIGEST DEL SEGNALE DEL PLAYER "take_dmg"
#{
	#PARAMETRI
	#int atk_state: DEPRECATO
	#int dmg: quantità del danno inflitto
	#float sec: tempo dello stun
#}
	#se il nodo è in range e non è grabbato
		#allora sottraggo alla vita il danno
		#setto la barra della vita con il nuovo valore
		## print di debug #
		#impedisco al nodo di muoversi mentre viene attaccato
		#imposto il tempo di stun con il parametro passato
		#faccio partire il timer dello stun

func _on_player_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc, type):
	if is_in_atk_range and !grabbed:
		var dmg_info = get_parent().get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc, type)
		var dmg = dmg_info[0]
		show_hitmarker("-" + str(dmg), dmg_info[1])
		current_vit -= dmg
		set_health_bar()
		if dmg > 0:
			hit_flash_player.stop()
			hit_flash_player.play("hit_flash")
			emit_signal("shake_camera", true, dmg_info[2])
		if sprinting and dmg >= 25:
			sprinting = false
			sprint_collider.set_deferred("disabled", true)
			sprite.play("damaged")
		if stun_sec > 0:
			moving = false
			stun_timer.wait_time = stun_sec
			stun_timer.start()
			sprite.play("damaged")

# DIGEST DEL SENGALE DEL PLAYER "grab" #

func _on_player_grab(is_been_grabbed, is_flipped, grab_position_marker):
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
		
		if player.char_name == "Nathan":
			emit_signal("got_grabbed", false)
			sprite.rotation_degrees = 0;
			healthbar.visible = true

# METODO CHE TELETRASPORTA IL NODO NELLA POSIZIONE DEL PLAYER DURANTE LA GRAB #

func is_grabbed():
	flip((player.position - position).normalized())
	position = grab_position.global_position

#DIGEST DEL TIMER "Stun"
	#setto il movimento a true

func _on_stun_timeout():
	choosed_atk = Possible_Attacks.IDLE
	sprint_collider.set_deferred("disabled", true)
	set_idle()

'DIGEST DEL SEGNALE PROPRIO "set_health_bar", AGGIORNA LA BARRA DELLA SALUTE
	il valore della barra diventa uguale a quello della vita attuale
	se il valore della vita è minore o uguale a 0
		cancello il nodo dalla scena'

func set_health_bar():
	if current_vit <= 0:
		if player.char_name == "Nathan" and grabbed:
			emit_signal("got_grabbed", false)
		queue_free()
	elif current_vit > default_vit:
		current_vit = default_vit
	
	healthbar.value = current_vit

# -------- SIGNAL DIGEST -------- #

'DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO'

func set_idle():
	if not knockbacked and not grabbed:
		moving = true
		sprinting = false
		choosed_atk = Possible_Attacks.IDLE
		sprint_collider.set_deferred("disabled", true)
		sprint_charge_time.stop()
		sprite.play("idle")

func _on_area_of_detection_body_entered(body):
	if body == player:
		player_entered = true

func _on_area_of_detection_body_exited(body):
	if body == player:
		player_entered = false

func _on_bite_area_body_entered(body):
	if body == player:
		player_in_atk_range = true

func _on_bite_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_sprint_area_body_entered(body):
	if body == player:
		player_in_atk_range = true
		emit_signal("take_dmg", current_str, sprint_force, sprint_stun_time, current_pbc, current_efc, sprint_type)
		sprint_time.start(0.5)
		update_atk_timer.start(0.5)

func _on_sprint_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_effect_animation_finished():
	if stun_timer.is_stopped() and bite_effect.animation == "effect" and not grabbed and player_in_atk_range:
		emit_signal("take_dmg",current_str, bite_force, bite_stun_time, current_pbc, current_efc, bite_type)
		bite_cooldown.start()
	set_idle()

func bite():
	if player_entered and stun_timer.is_stopped() and not grabbed and player_in_atk_range and not sprinting:
		moving = false
		bite_effect.play("effect")
		sprite.play("attack")
	bite_cooldown.start()

func sprint():
	if player_entered and stun_timer.is_stopped() and not grabbed and not sprinting:
		sprite.play("charging_sprint")
		moving = false
		sprint_charge_time.start()
	sprint_cooldown.start()

func _on_sprint_time_timeout() -> void:
	set_idle()

func _on_charge_time_timeout():
	if stun_timer.is_stopped():
		sprinting = true
		sprint_collider.set_deferred("disabled", false)
		sprint_time.start(sprint_duration)

func _on_update_atk_timeout():
	if not sprinting:
		choose_atk()
	update_atk_timer.start()

func _on_navigation_agent_2d_velocity_computed(safe_velocity):
	velocity = safe_velocity

func init_knockback(amount, time, sender):
	if is_in_atk_range and not grabbed:
		moving = false
		sprinting = false
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
	if stun_timer.is_stopped():
		set_idle()

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
