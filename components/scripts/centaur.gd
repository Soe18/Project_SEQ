extends CharacterBody2D

@export var default_vit : int = 200
var current_vit = default_vit
@export var default_str : int = 175
var current_str = default_str
@export var default_tem : int = 120
var current_tem = default_tem
@export var default_des : int = 300
var current_des = default_des
@export var default_pbc : int = 20
var current_pbc = default_pbc
@export var default_efc : float = 1.3
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
signal grab_player(has_grabbed, grab_position_marker, sender)
signal change_stats(stat, amount, time_duration, ally_sender)
signal inflict_knockback(amount, time, sender)
signal shake_camera(shake, strenght)

var target_position
var player

enum Possible_Attacks {IDLE, HALBERD, SPRINT, TEMPERANCE}
var choosed_atk

var sprinting = false

var target_location
var origin
var first_direction
var first_enter = true

@export var halberd_force = 10
@export var halberd_stun_time = 2
@onready var halberd_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL
@export var sprint_duration = 5
@export var sprint_force = 17
@export var sprint_multiplyer = 800
@export var sprint_knockback_force = 2000
@export var sprint_knockback_time = 1
@onready var sprint_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL
@export var temperance_changed_stat = "tem"
@export var temperance_amount = 60
@export var temperance_duration = 20

@onready var navigation_agent = $NavigationAgent2D

@onready var sprite = $Sprite2D

@onready var stun_timer = $Stun
@onready var safe_timer = $Safe_timer

@onready var body_collider = $Body_collider
@onready var upper_body_collider = $Body_collider_upper

@onready var halberd_area = $Halberd_area
@onready var halberd_collider = $Halberd_area/Collider

@onready var sprint_area = $Sprint_area
@onready var sprint_collider = $Sprint_area/Collider
@onready var sprint_duration_timer = $Sprint_area/Sprint_duration
@onready var sprint_reset_collider = $Reset_sprint_area/Collision

@onready var healthbar = $Control/HealthBar

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

@onready var area_of_detection = $Area_of_detection

@onready var status_sprite = $Status_alert_sprite

@onready var update_atk_timer = $Update_Atk

@onready var grab_position_marker = $Grab_position
@onready var animation_player = $AnimationPlayer
@onready var hit_flash_player = $Hit_flash_player

@onready var halberd_cooldown = $Halberd_cooldown
@onready var sprint_cooldown = $Sprint_cooldown
@onready var temperance_cooldown = $Temperance_cooldown

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
	set_idle()

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
	elif sprinting:
		sprint_to_target()
		if sprint_duration_timer.time_left == sprint_duration/2:
			sprint_reset_collider.set_deferred("disabled", false)
	elif player_entered and moving:
		chase_player()
		if choosed_atk == Possible_Attacks.HALBERD and halberd_cooldown.is_stopped():
			halberd()
		if choosed_atk == Possible_Attacks.SPRINT and sprint_cooldown.is_stopped():
			sprint()
		if choosed_atk == Possible_Attacks.TEMPERANCE and temperance_cooldown.is_stopped():
			temperance()
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
	elif grabbed:
		is_grabbed()

'METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
	salvo la posizione attuale del player
	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
	se il nodo è distante dal player di almeno 12 unità
		muovo il nodo verso il player con la velocità di 3'

func flip(distance_to_player):
	if distance_to_player.x < 0:
		sprite.flip_h = true
		upper_body_collider.position.x = -38
		halberd_collider.position.x = -83
		sprint_collider.position.x = -134
	elif distance_to_player.x > 0:
		sprite.flip_h = false
		upper_body_collider.position.x = 38
		halberd_collider.position.x = 83
		sprint_collider.position.x = 134

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

func sprint_to_target():
	if is_instance_valid(player):
		var direction = global_position.direction_to(target_location)
		
		if first_enter:
			first_direction = direction
			first_enter = false
		
		if global_position.distance_to(origin) >= target_location.distance_to(origin):
			direction = first_direction
			
		velocity = direction * sprint_multiplyer
		move_and_slide()

func choose_atk():
	var rng = randi_range(0,100)
	if rng >= 0 and rng < 40:
		choosed_atk = Possible_Attacks.HALBERD
	elif rng >= 40 and rng < 80:
		choosed_atk = Possible_Attacks.SPRINT
	else:
		choosed_atk = Possible_Attacks.TEMPERANCE
	
	#choosed_atk = Possible_Attacks.SPRINT

'DIGEST DEL SEGNALE DEL PLAYER \"is_in_atk_range\"
{
	PARAMETRI
	boolean is_in: identifica se il nodo è entrato oppure è uscito
	Node body: identifica il nodo che è entrato o uscito
}
	se il segnale che manda al nodo è di entrata nell\'area e il nodo è questo
		allora il nodo è dentro l\'area del player
	altrimenti
		non è in range'

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
		elif stun_sec > 0:
			moving = false
			stun_timer.wait_time = stun_sec
			stun_timer.start()
			safe_timer.start()
			sprite.play("damaged")

#DIGEST DEL SENGALE DEL PLAYER "grab"
#{
#	PARAMETRI
#	boolean is_been_grabbed: controlla se il segnale è di entrata o di uscita dalla grab
#	booelan is_flipped: indica se il player è flippato o meno
#}
#se il segnale è di grab, il nodo non è già grabbato e il nodo è in range
#	faccio ricevere un danno al nodo
#	tolgo la possibilità di muoversi del nodo
#	setto il grabbed a true
#	lo sprite diventa invisibile
#	disattivo le collisioni
#se il segnale è di uscita dalla grab e il nodo è grabbato
#	il nodo potrà di nuovo muoversi
#	setto il grabbed a false
#	se il nodo è flipped
#		spinge il nodo a sinistra di 450
#	altrimenti
#		spinge il nodo a destra di 450
#	lo sprite diventa visibile
#	faccio partire un timer per risettare le collisioni, se le riabilito insieme avviene un bug
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

#METODO CHE TELETRASPORTA IL NODO NELLA POSIZIONE DEL PLAYER DURANTE LA GRAB
#	setto la posizione uguale a quella del player
func is_grabbed():
	flip((player.position - position).normalized())
	position = grab_position.global_position

#DIGEST DEL TIMER "Stun"
#	setto il movimento a true
func _on_stun_timeout():
	choosed_atk = Possible_Attacks.IDLE
	set_idle()

func _on_sprite_2d_animation_finished() -> void:
	if sprite.animation == "charging_sprint":
		sprinting = true
		moving = false
		target_location = player.global_position
		origin = global_position
		flip((target_location - global_position).normalized())
		upper_body_collider.set_deferred("disabled", true)
		sprint_collider.set_deferred("disabled", false)
		sprint_duration_timer.start(sprint_duration)
		sprite.play("sprint")
		update_atk_timer.stop()
	elif sprite.animation != "damaged":
		set_idle()

func _on_sprite_2d_frame_changed() -> void:
	if sprite.animation == "grab" and sprite.frame == 5:
		emit_signal("grab_player", false, null, null)
		emit_signal("take_dmg", current_str, sprint_force, 0, current_pbc, current_efc, sprint_type)
		emit_signal("inflict_knockback", 600, 0.3, self.global_position)
	if sprite.animation == "halberd" and (sprite.frame == 4 or sprite.frame == 8) and player_in_atk_range:
		emit_signal("take_dmg", current_str, halberd_force, halberd_stun_time, current_pbc, current_efc, halberd_type)
	if sprite.animation == "temperance" and sprite.frame == 2:
		_on_change_stats(temperance_changed_stat, temperance_amount, temperance_duration, true)

func halberd():
	if player_entered and stun_timer.is_stopped() and not grabbed and not sprinting and player_in_atk_range:
		moving = false
		safe_timer.start()
		sprite.play("halberd")
		update_atk_timer.stop()
	halberd_cooldown.start()

func sprint():
	if player_entered and stun_timer.is_stopped() and not grabbed and not sprinting:
		sprite.play("charging_sprint")
		moving = false
		safe_timer.start()
		first_enter = true
		update_atk_timer.stop()
	sprint_cooldown.start()

func temperance():
	if stun_timer.is_stopped() and not grabbed and not sprinting:
		sprite.play("temperance")
		moving = false
		safe_timer.start()
		update_atk_timer.stop()
	temperance_cooldown.start()

func _on_sprint_duration_timeout() -> void:
	set_idle()

func _on_area_of_detection_body_entered(body):
	if body == player:
		player_entered = true

func _on_area_of_detection_body_exited(body):
	if body == player:
		player_entered = false

func _on_halberd_area_body_entered(body: Node2D) -> void:
	if body == player:
		player_in_atk_range = true

func _on_halberd_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_atk_range = false

func _on_sprint_area_body_entered(body: Node2D) -> void:
	if body == player:
		sprint_collider.set_deferred("disabled", true)
		sprint_reset_collider.set_deferred("disabled", true)
		sprint_duration_timer.stop()
		sprinting = false
		if sprite.flip_h:
			animation_player.play("marker_movement_flip")
		else:
			animation_player.play("marker_movement")
		sprite.play("grab")
		emit_signal("grab_player", true, grab_position_marker, self)
	elif body is TileMapLayer:
		set_idle()

func _on_reset_sprint_area_body_entered(body: Node2D) -> void:
	if body is TileMapLayer or body == player:
		set_idle()

func _on_sprint_area_body_exited(body: Node2D) -> void:
	pass # Replace with function body.

#DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO
func set_idle():
	if not knockbacked:
		moving = true
		sprinting = false
		choosed_atk = Possible_Attacks.IDLE
		sprite.play("idle")
		upper_body_collider.set_deferred("disabled", false)
		halberd_collider.set_deferred("disabled", false)
		sprint_collider.set_deferred("disabled", true)
		sprint_reset_collider.set_deferred("disabled", true)
		sprint_duration_timer.stop()
		safe_timer.stop()
		update_atk_timer.start()

func _on_safe_timer_timeout() -> void:
	set_idle()

#DIGEST DEL SEGNALE PROPRIO "set_health_bar", AGGIORNA LA BARRA DELLA SALUTE
#	il valore della barra diventa uguale a quello della vita attuale
#	se il valore della vita è minore o uguale a 0
#		cancello il nodo dalla scena
func set_health_bar():
	healthbar.value = current_vit
	if current_vit <= 0:
		queue_free()

# //////////// AREA COMUNE TRA NODI //////////// #

func _on_update_atk_timeout():
	choose_atk()
	update_atk_timer.start()

func _on_navigation_agent_2d_velocity_computed(safe_velocity):
	velocity = safe_velocity

func init_knockback(amount, time, sender):
	if is_in_atk_range and not grabbed:
		moving = false
		safe_timer.start()
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
