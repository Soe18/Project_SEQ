extends CharacterBody2D

@export var default_vit : int = 60
var current_vit = default_vit
@export var default_str : int = 60
var current_str = default_str
@export var default_tem : int = 80
var current_tem = default_tem
@export var default_des : int = 200
var current_des = default_des
@export var default_pbc : int = 45
var current_pbc = default_pbc
@export var default_efc : float = 1.5
var current_efc = default_efc

@export var knockback_controller_node : PackedScene

var scene_manager : Node2D

var is_in_atk_range = false
var moving = true
var grabbed = false
var grab_position

var knockbacked = false
var knockback_target_point
var knockback_force

signal got_grabbed(is_grabbed)
signal change_stats(stat, amount, time_duration, ally_sender)
signal shake_camera(shake, strenght)

var target_position
var player

enum Possible_Attacks {IDLE, MAGIC_DART, ENCHANTMENT, HEAL}
var choosed_atk

@onready var navigation_agent = $NavigationAgent2D

@onready var sprite = $Sprite2D

@onready var stun_timer = $Stun

@onready var body_collider = $Body_collider

@onready var healthbar = $Control/HealthBar

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

@onready var status_sprite = $Status_alert_sprite

@onready var projectile_spawnpoint = $Projectile_spawnpoint

@onready var update_atk_timer = $Update_Atk

@onready var heal_charge_time = $Heal_charge_time
@onready var flee_delay = $Flee_delay
@onready var flee_timeout_timer = $Flee_timeout

@onready var magic_dart_cooldown = $Magic_dart_cooldown
@onready var enchantment_cooldown = $Enchantment_cooldown
@onready var heal_cooldown = $Heal_cooldown
@onready var flee_cooldown = $Flee_cooldown

@onready var hit_flash_player = $Hit_flash_player

@export var magic_dart_projectile_node : PackedScene
@export var enchantment_projectile_node : PackedScene

@export var heal_amount = 50

var flee_locations = []

var player_in_atk_range = false

var flee_activated = false

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
func _physics_process(delta):
	if knockbacked:
		apply_knockback(delta)
	elif grabbed:
		is_grabbed()
	elif is_instance_valid(player) and moving:
		chase_player()
		if choosed_atk == Possible_Attacks.MAGIC_DART and magic_dart_cooldown.is_stopped() and not flee_activated:
			sprite.play("launch_dart")
			moving = false
			flee_timeout_timer.start()
			magic_dart_cooldown.start()
		if choosed_atk == Possible_Attacks.ENCHANTMENT and enchantment_cooldown.is_stopped() and not flee_activated:
			sprite.play("launch_dart", 0.40)
			moving = false
			flee_timeout_timer.start()
			enchantment_cooldown.start()
		if choosed_atk == Possible_Attacks.HEAL and heal_cooldown.is_stopped() and not flee_activated:
			sprite.play("charging_heal")
			heal_charge_time.start()
			moving = false
			flee_timeout_timer.start()
			heal_cooldown.start()
	elif not is_instance_valid(player) and not moving:
		set_idle()
	elif not is_instance_valid(player) and moving:
		sprite.play("idle")

#METODO CHE PERMETTE AL NODO DI SPOSTARSI VERSO IL PLAYER
#	salvo la posizione attuale del player
#	creo il vettore che punta al player, facendo la posizione del player - la posizione attuale e infine normalizzo il vettore
#	se il nodo è distante dal player di almeno 12 unità
#		muovo il nodo verso il player con la velocità di 3
func flip(distance_to_player):
	if distance_to_player.x < 0:
		sprite.flip_h = true
		body_collider.position.x = -3
		if grabbed:
			sprite.rotation_degrees = -90;
	elif distance_to_player.x > 0:
		sprite.flip_h = false
		body_collider.position.x = 3
		if grabbed:
			sprite.rotation_degrees = 90;
	

func chase_player():
	if is_instance_valid(player) or flee_activated:
		if not flee_activated:
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
		
		if not flee_activated:
			var player_position = (player.position - position).normalized()
			flip(player_position)
		else:
			flip((navigation_agent.target_position - position).normalized())

func choose_atk():
	var rng = randi_range(0,100)
	if rng < 40:
		choosed_atk = Possible_Attacks.MAGIC_DART
	elif rng >= 40 and rng < 80:
		choosed_atk = Possible_Attacks.ENCHANTMENT
	else:
		choosed_atk = Possible_Attacks.HEAL
	
	#choosed_atk = Possible_Attacks.HEAL

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
func _on_player_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc, type, sender):
	if is_in_atk_range and not grabbed and not knockbacked:
		var dmg_info = scene_manager.calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc, type, self)
		var dmg = dmg_info[0]
		scene_manager.show_hitmarker("-" + str(dmg), dmg_info[1], hitmarker_spawnpoint)
		current_vit -= dmg
		set_health_bar()
		if dmg > 0:
			scene_manager.emit_hit_particles(sender, self)
			hit_flash_player.stop()
			hit_flash_player.play("hit_flash")
			emit_signal("shake_camera", true, dmg_info[2])
		if stun_sec > 0 and not flee_activated:
			if flee_cooldown.is_stopped():
				heal_charge_time.stop()
				moving = false
				flee_delay.start()
				flee_timeout_timer.start()
				sprite.play("damaged")
				self.set_collision_layer_value(2, false)
			else:
				moving = false
				heal_charge_time.stop()
				stun_timer.wait_time = stun_sec
				stun_timer.start()
				sprite.play("damaged")

func _on_sprite_2d_animation_finished() -> void:
	if sprite.animation != "damaged":
		set_idle()

func _on_sprite_2d_frame_changed() -> void:
	if sprite.animation == "launch_dart" and sprite.frame == 1 and choosed_atk == Possible_Attacks.MAGIC_DART:
		launch_magic_dart()
	elif sprite.animation == "launch_dart" and sprite.frame == 1 and choosed_atk == Possible_Attacks.ENCHANTMENT:
		launch_enchantment()

func launch_magic_dart():
	self.add_child(magic_dart_projectile_node.instantiate(),true)
	var magic_dart_projectile = get_child(get_child_count()-1,true)
	magic_dart_projectile.position = projectile_spawnpoint.position
	magic_dart_projectile.player = player
	magic_dart_projectile.player_position = player.global_position
	magic_dart_projectile.fae_str = current_str
	magic_dart_projectile.fae_pbc = current_pbc
	magic_dart_projectile.fae_efc = current_efc
	magic_dart_projectile.take_dmg.connect(player._on_enemy_take_dmg)
	magic_dart_projectile.look_at(player.global_position)
	magic_dart_projectile.reparent(get_parent())
	set_idle()

func launch_enchantment():
	self.add_child(enchantment_projectile_node.instantiate(),true)
	var enchantment_projectile = get_child(get_child_count()-1,true)
	enchantment_projectile.position = projectile_spawnpoint.position
	enchantment_projectile.player = player
	enchantment_projectile.player_position = player.global_position
	enchantment_projectile.fae_str = current_str
	enchantment_projectile.fae_pbc = current_pbc
	enchantment_projectile.fae_efc = current_efc
	enchantment_projectile.take_dmg.connect(player._on_enemy_take_dmg)
	enchantment_projectile.reparent(get_parent())
	set_idle()

func _on_flee_delay_timeout() -> void:
	moving = true
	flee_activated = true
	
	var most_distant = flee_locations[0]
	for i in flee_locations:
		if (i.position - position).length() > (most_distant.position - position).length():
			most_distant = i
		
	navigation_agent.target_position = most_distant.global_position
	navigation_agent.target_desired_distance = 50
	current_des += 300
	flee_cooldown.start()

func _on_navigation_agent_2d_target_reached(timeout = false) -> void:
	if is_instance_valid(player):
		if navigation_agent.target_position != player.global_position or timeout:
			flee_activated = false
			flee_timeout_timer.stop()
			self.set_collision_layer_value(2, true)
			navigation_agent.target_desired_distance = 250
			current_des -= 300
			set_idle()

func _on_flee_timeout_timeout() -> void:
	set_idle()

func _on_heal_charge_time_timeout() -> void:
	sprite.play("heal")
	heal()

func heal():
	var allies = []
	for i in get_parent().get_children(true):
		if "Enemy" in i.name:
			allies.append(i)
	
	if allies.size() > 0:
		var target = allies[0]
		
		for i in allies:
			if (i.current_vit*100)/i.default_vit < (target.current_vit*100)/target.default_vit:
				target = i
		
		target.current_vit += heal_amount
		target.set_health_bar()
		target.status_sprite.play("recover")

# //////////// AREA COMUNE TRA NODI //////////// #

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

#DIGEST DEL TIMER "Stun"
#	setto il movimento a true
func _on_stun_timeout():
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

func _on_timer_timeout():
	body_collider.disabled = false

func _on_update_atk_timeout():
	choose_atk()
	update_atk_timer.start(randf_range(2, 4.5))

func _on_navigation_agent_2d_velocity_computed(safe_velocity):
	velocity = safe_velocity

func init_knockback(amount, force, sender):
	if is_in_atk_range and not grabbed:
		velocity = Vector2(0, 0)
		moving = false
		knockbacked = true
		
		knockback_target_point = self.global_position + (sender.direction_to(self.global_position) * amount)
		knockback_force = force
		
		self.add_child(knockback_controller_node.instantiate(), true)
		var knockback_controller = get_child(-1)
		knockback_controller.reparent(get_parent())
		knockback_controller.target_point = knockback_target_point
		knockback_controller.vel_multiplyer = force
		knockback_controller.caller = self
		knockback_controller.target_reached.connect(self._on_knockback_reset)

func apply_knockback(delta):
	velocity = Vector2(0, 0)
	self.global_position = self.global_position.lerp(knockback_target_point, knockback_force * delta)
	move_and_slide()

func _on_knockback_reset():
	knockbacked = false
	if not stun_timer.is_stopped():
		set_idle()

# DIGEST CHE PERMETTE DI FAR RIPARTIRE IL MOVIMENTO
func set_idle():
	if not knockbacked:
		moving = true
		choosed_atk = Possible_Attacks.IDLE
		sprite.play("idle")
		heal_charge_time.stop()
		flee_timeout_timer.stop()
		update_atk_timer.start()

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
