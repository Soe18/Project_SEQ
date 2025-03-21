extends CharacterBody2D

@export var default_vit : int = 180
var current_vit = default_vit
@export var default_str : int = 180
var current_str = default_str
@export var default_tem : int = 148
var current_tem = default_tem
@export var default_des : int = 125
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

var attacking = false

@export var punch_force = 25
@export var punch_stun_time = 2.0
@onready var punch_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

@export var earthquake_force = 2.5
@onready var earthquake_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

signal take_dmg(str, atk_str, sec_stun, pbc, efc, type)
signal got_grabbed(is_grabbed)
signal shake_camera(shake, strenght)

var player_position
var target_position
var player

enum Possible_Attacks {IDLE, PUNCH, EARTHQUAKE}
var choosed_atk

@onready var sprite = $Sprite2D

@onready var punch_collider = $Punch_Area/Skill_collider
@onready var punch_effect = $Punch_Area/Effect

@onready var earthquake_collider = $Earthquake_Area/Skill_collider
@onready var earthquake_effect = $Earthquake_Area/Effect

@onready var stun_timer = $Stun

@onready var body_collider = $Body_collider

@onready var navigation_agent = $NavigationAgent2D

@onready var healthbar = $HealthBar

@onready var hitmarker_spawnpoint = $Hitmarker_spawn
@onready var hit_flash_player = $Hit_flash_player

@onready var punch_cooldown = $Punch_Cooldown
@onready var earthquake_cooldown = $Earthquake_Cooldown

@onready var status_sprite = $Status_alert_sprite

@onready var update_atk_timer = $Update_Atk

var PUNCH_COLLIDER_POSITION_X
var PUNCH_EFFECT_POSITION_X
var BODY_COLLIDER_POSITION_X
var BODY_COLLIDER_ROTATION

var player_entered = true
var player_in_atk_range = false

#METODO CHE PARTE QUANDO VIENE ISTANZIATO IL NODO
	#setta la vita attuale a quella massima
	#imposta il valore massimo della barra della salute al massimo
	#setta la barra della salute

func _ready():
	healthbar.max_value = default_vit
	set_health_bar()
	sprite.play("idle")
	update_atk_timer.wait_time = randf_range(3, 5.8)
	PUNCH_COLLIDER_POSITION_X = punch_collider.position.x
	PUNCH_EFFECT_POSITION_X = punch_effect.position.x
	BODY_COLLIDER_POSITION_X = body_collider.position.x
	BODY_COLLIDER_ROTATION = body_collider.rotation_degrees

#METODO CHE VIENE PROCESSATO PER FRAME
	#controlla se il player è entrato in area e si può muovere
		#allora si muove
	#altrimenti se il player NON è entrato in area e si può muovere
		#allora comincia a vagare
	#controlla se è grabbato
		#allora fa partire il metodo grab()

func _physics_process(_delta):
	if knockbacked:
		apply_knockback(knockback_sender)
	elif grabbed:
		is_grabbed()
	elif player_entered and moving and not attacking:
		chase_player()
		if choosed_atk == Possible_Attacks.PUNCH and punch_cooldown.is_stopped():
			punch()
		if choosed_atk == Possible_Attacks.EARTHQUAKE and earthquake_cooldown.is_stopped() and stun_timer.is_stopped():
			earthquake()
	elif not player_entered and moving:
		if player:
			if not navigation_agent.is_navigation_finished():
				sprite.play("running")
				target_position = navigation_agent.target_position
				velocity = global_position.direction_to(target_position) * current_des
				move_and_slide()
			else:
				sprite.play("idle")
	elif not player_entered and not moving and not attacking:
		sprite.play("idle")
		punch_effect.play("idle")
		earthquake_effect.play("idle")

'METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
	salvo la posizione attuale del player
	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
	se il nodo è distante dal player di almeno 12 unità
		muovo il nodo verso il player con la velocità di 3'

func flip(distance_to_player):
	if distance_to_player.x < 0:
		punch_collider.position.x = -PUNCH_COLLIDER_POSITION_X
		punch_effect.position.x = -PUNCH_EFFECT_POSITION_X
		punch_effect.flip_h = true
		sprite.flip_h = true
		body_collider.rotation_degrees = -BODY_COLLIDER_ROTATION
		body_collider.position.x = -6.835
		if grabbed:
			sprite.rotation_degrees = -90;
	elif distance_to_player.x > 0:
		punch_collider.position.x = PUNCH_COLLIDER_POSITION_X
		punch_effect.position.x = PUNCH_EFFECT_POSITION_X
		punch_effect.flip_h = false
		sprite.flip_h = false
		body_collider.rotation_degrees = BODY_COLLIDER_ROTATION
		body_collider.position.x = 11.151
		if grabbed:
			sprite.rotation_degrees = 90;

func chase_player():
	if player:
		navigation_agent.target_position = player.global_position
		
		if navigation_agent.is_navigation_finished():
			if sprite.animation == "running":
				sprite.play("idle")
		else:
			var current_agent_position = global_position
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
		if (dmg >= 25 or dmg <= 0) and stun_sec > 0:
			punch_effect.play("idle")
			sprite.position = Vector2.ZERO
			attacking = false
			moving = false
			stun_timer.start(stun_sec)
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
	choosed_atk = Possible_Attacks.IDLE
	set_idle()

'DIGEST DEL SEGNALE PROPRIO "set_health_bar", AGGIORNA LA BARRA DELLA SALUTE
	il valore della barra diventa uguale a quello della vita attuale
	se il valore della vita è minore o uguale a 0
		cancello il nodo dalla scena'

func set_health_bar():
	healthbar.value = current_vit
	if current_vit <= 0:
		if player.char_name == "Nathan" and grabbed:
			emit_signal("got_grabbed", false)
		queue_free()
	elif current_vit > default_vit:
		current_vit = default_vit

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
		player_in_atk_range = true

func _on_punch_area_body_exited(body):
	if body == player:
		player_in_atk_range = false

func _on_earthquake_area_body_entered(body):
	if body == player:
		player_in_atk_range = true

func _on_earthquake_area_body_exited(body):
	if body == player:
		player_in_atk_range = false
		player.current_des = player.default_des
# -------- SIGNAL DIGEST -------- #

func _on_sprite_2d_animation_finished():
	if sprite.animation == "punch":
		set_idle()

func _on_sprite_2d_frame_changed():
	if (sprite.animation == "earthquake" and sprite.frame == 1) or (sprite.animation == "earthquake" and sprite.frame == 3) or (sprite.animation == "earthquake" and sprite.frame == 7):
		if earthquake_effect.is_playing():
			earthquake_effect.stop()
			earthquake_effect.play("effect")
		else:
			earthquake_effect.play("effect")
	if sprite.animation == "punch" and sprite.frame == 8 and stun_timer.is_stopped() and not grabbed and player_in_atk_range:
		emit_signal("take_dmg", current_str, punch_force, punch_stun_time, current_pbc, current_efc, punch_type)

# FUNZIONE PER L'ATTACCO PUGNO
func punch():
	if stun_timer.is_stopped() and not grabbed:
		punch_cooldown.start()
		attacking = true
		if sprite.flip_h:
			sprite.position = Vector2(-58,0)
		else:
			sprite.position = Vector2(58,0)
		moving = false
		sprite.play("punch")
		punch_effect.play("effect")
		punch_collider.set_deferred("disabled", false)

func _on_effect_animation_finished():
	if punch_effect.animation == "effect":
		punch_effect.play("idle")
	if earthquake_effect.animation == "effect":
		set_idle()

func _on_effect_frame_changed():
	if earthquake_effect.animation == "effect" and earthquake_effect.frame%2==0 and stun_timer.is_stopped() and not grabbed and player_in_atk_range:
		emit_signal("take_dmg", current_str, earthquake_force, 0, 0, 0, earthquake_type)
		if player.current_des == player.default_des:
			player.current_des /= 2.5
			player.status_sprite.play("debuff")

# FUNZIONE PER L'ATTACCO TERREMOTO'
func earthquake():
	if player_entered and stun_timer.is_stopped() and not grabbed:
		earthquake_cooldown.start()
		attacking = true
		moving = false
		sprite.play("earthquake")
		earthquake_collider.set_deferred("disabled", false)

# DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO
func set_idle():
	if not knockbacked and not grabbed:
		sprite.position = Vector2.ZERO
		moving = true
		attacking = false
		punch_collider.set_deferred("disabled", true)
		earthquake_collider.set_deferred("disabled", true)
		sprite.play("idle")
		punch_effect.play("idle")
		earthquake_effect.play("idle")

func _on_update_atk_timeout():
	choose_atk()
	update_atk_timer.wait_time = randf_range(3, 5.8)
	update_atk_timer.start()

func _on_navigation_agent_2d_velocity_computed(safe_velocity):
	velocity = safe_velocity

func init_knockback(amount, time, sender):
	if is_in_atk_range and not grabbed:
		set_idle()
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
