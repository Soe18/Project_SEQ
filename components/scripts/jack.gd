extends CharacterBody2D

var char_name = "Jack"

@export var default_vit : int = 140
var current_vit = default_vit
@export var default_str : int = 120
var current_str = default_str
@export var default_tem : int = 80
var current_tem = default_tem
@export var default_des : int = 150
var current_des = default_des
@export var default_pbc : int = 30
var current_pbc = default_pbc
@export var default_efc : float = 1.5
var current_efc = default_efc

@export var damage_node : PackedScene
@export var knockback_controller_node : PackedScene
@export var change_stats_timer_node : PackedScene
@export var bullet_scene : PackedScene

enum Atk_States {IDLE, BASE_ATK, SK1, SK2, EVA, ULT}

signal is_in_atk_range(is_in, body)
signal take_dmg(str, atk_str, sec_stun, pbc, efc)
signal set_idle()
signal set_health_bar(current_vit)
signal get_healed(amount)
signal change_stats(stat, amount, time_duration, ally_sender)
signal inflict_knockback(amount, time, sender)
signal shake_camera(shake, strenght)

signal launched_flashbang()

@export var ACCELERATION : float = 10000.0
@export var FRICTION : float = 7000.0

@onready var axis = Vector2.ZERO

var atk_state = Atk_States.IDLE

var can_move = true
var grabbed = false
var grab_marker
var grab_sender

var knockbacked = false
var knockback_target_point
var knockback_force

var atk_anim_finished = true

var Guns = {
	"pistol" : {"force" : 2000, "precision" : 0.1, "delay" : 0.4, "gun_str" : 20, "knockback" : false, "stun_time" : 0, "bullet_count" : 8, "prefix" : "p_" , "shake_strenght" : 2},
	"assault" : {"force" : 2000, "precision" : 0.15, "delay" : 0.05, "gun_str" : 30, "knockback" : false, "stun_time" : 0, "bullet_count" : 30, "prefix" : "as_" , "shake_strenght" : 3},
	"shotgun" : {"force" : 1700, "precision" : 0.3, "delay" : 0.9, "gun_str" : 45, "knockback" : true, "stun_time" : 1.5, "bullet_count" : 2, "prefix" : "sh_" , "shake_strenght" : 20}
}

var gun_prefix
var gun_force
var gun_precision
var gun_str
var gun_knockback_flag
var gun_stun_time
var max_bullet_count
var gun_bullet_count
var gun_shake_strenght
@onready var flashbang_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

var changing_gun = false

var SKILL2_WAIT_TIME = 35
var SKILL1_WAIT_TIME = 26
var ULTI_WAIT_TIME = 90
var ULTI_DURATION = 20

var SHOTGUN_ROUNDS_COUNT = 6

@onready var sprite = $Sprite2D
@onready var camera

@onready var bullets_spawnpoint = $Bullets_spawnpoint
@onready var control_node = $Control

@onready var skill1_cooldown = $Skill1_cooldown
@onready var skill2_cooldown = $Skill2_cooldown
@onready var eva_cooldown = $Eva_cooldown
@onready var ulti_cooldown = $Ulti_cooldown

@onready var body_collider = $Body_collider

@onready var remaining_bullets_label = $Control/HBoxContainer/Label

@onready var flashbang_area = $Flashbang_area
@onready var flashbang_collider = $Flashbang_area/Collider

@onready var stun_timer = $Stun
@onready var shooting_delay_timer = $Shooting_delay_time
@onready var reaction_timer = $Reaction_time
@onready var ulti_duration_timer = $Ulti_duration

@onready var status_sprite = $Status_alert_sprite
@onready var hit_flash_player = $Hit_flash_player

@onready var animation_player = $Control/AnimationPlayer

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

'METODO CHE VIENE CHIAMATO AD OGNI FRAME
	se il player si può muovere
		esegue il metodo per muoversi
	esegue il metodo che gestisce gli attacchi
	se sta eseguendo un\'evasione
		esegue il metodo di evasione
	se ha attivato la skill1
		esegue il metodo di movimento della skill1'

@warning_ignore("unused_parameter")
@warning_ignore("unused_signal")

func _ready():
	emit_signal("set_health_bar", default_vit)
	skill2_cooldown.wait_time = SKILL2_WAIT_TIME
	skill1_cooldown.wait_time = SKILL1_WAIT_TIME
	ulti_cooldown.wait_time = ULTI_WAIT_TIME
	ulti_duration_timer.wait_time = ULTI_DURATION
	gun_handler("pistol")
	set_bullet_count_label()

func _physics_process(delta):
	if knockbacked:
		apply_knockback(delta)
	if grabbed:
		is_grabbed()
	if can_move:
		move(delta)
	if stun_timer.is_stopped():
		atk_handler()

'METODO CHE GESTISCE IL MOVIMENTO DEL PLAYER
	pulisce il vettore della velocità
	# Last Win #
	quando si gira il player a destra o sinistra si deve girare anche le aree, 
	altrimenti ci sarebbe il personaggio flippato ma l\'area rimane dall\'altra
	parte'

func move(delta):
	axis = get_input_axis()
	if axis == Vector2.ZERO:
		apply_friction(FRICTION * delta)
	else:
		if not "reload" in sprite.animation:
			sprite.play(gun_prefix+"running")
		else:
			switch_between_reload_animation(true)
		
		apply_movement(axis * ACCELERATION * delta)
		if axis.x < 0:
			flip_sprite(true)
		elif axis.x > 0:
			flip_sprite(false)
		
	move_and_slide()

func get_input_axis():
	axis.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	axis.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return axis

func apply_friction(amount):
	if velocity.length() > amount:
		velocity -= velocity.normalized() * amount
	else:
		velocity = Vector2.ZERO
		if not "reload" in sprite.animation:
			sprite.play(gun_prefix+"idle")
		else:
			switch_between_reload_animation(false)

func apply_movement(accel):
	velocity += accel
	velocity = velocity.limit_length(current_des * 2.5)

func reset_axis():
	velocity = Vector2.ZERO
	axis = Vector2.ZERO

func switch_between_reload_animation(running):
	var frame = sprite.get_frame()
	var frame_progress = sprite.get_frame_progress()
	if running and sprite.animation != "p_running_reload":
		sprite.play("p_running_reload")
		sprite.set_frame_and_progress(frame, frame_progress)
	elif not running and sprite.animation != "p_reload":
		sprite.play("p_reload")
		sprite.set_frame_and_progress(frame, frame_progress)

'METODO CHE GESTISCE TUTTE LE ABILITA\' DEL PLAYER
	ad ogni if si controlla l\'azione possibile, per l\'attacco di base si trovano
	dei controlli aggiuntivi in base alla combo:
	si controlla come prima cosa se l\'input è stato premuto, se l\'animazione è diversa da idle o running (ovvero o è fermo
	o si sta spostando) oppure il numero di combo che sta facendo ed infine se non è in cooldown'

func atk_handler():
	if Input.is_action_pressed("base_atk") and (sprite.animation == gun_prefix+"idle" or sprite.animation == gun_prefix+"running") and gun_bullet_count <= 0:
		if gun_prefix == "p_":
			sprite.play("p_reload")
			reset_axis()
		else:
			animation_player.play("shake_ammo")
	
	elif Input.is_action_pressed("base_atk") and not "change" in sprite.animation and (sprite.animation == gun_prefix+"idle" or sprite.animation == gun_prefix+"running") and atk_anim_finished and not changing_gun and gun_bullet_count > 0:
		can_move = false
		atk_anim_finished = false
		atk_state = Atk_States.BASE_ATK
		sprite.play(gun_prefix+"shooting")
		reset_axis()
	
	elif Input.is_action_pressed("base_atk") and (sprite.animation == gun_prefix+"shooting" or sprite.animation == gun_prefix+"continue_shooting") and atk_anim_finished and not changing_gun  and shooting_delay_timer.is_stopped() and gun_bullet_count > 0:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		reaction_timer.stop()
		sprite.play(gun_prefix+"continue_shooting")
	
	#elif Input.is_action_just_pressed("evade") and ("idle" in sprite.animation or "running" in sprite.animation) and eva_cooldown.is_stopped():
	elif Input.is_action_just_pressed("evade") and not ("damaged" in sprite.animation or "flashbang" in sprite.animation) and eva_cooldown.is_stopped():
		eva_cooldown.start()
		can_move = false
		shooting_delay_timer.stop()
		reaction_timer.stop()
		atk_state = Atk_States.EVA
		sprite.play(gun_prefix+"flashbang")
		reset_axis()
	
	#elif Input.is_action_just_pressed("skill1") and ("idle" in sprite.animation or "running" in sprite.animation) and gun_prefix != "as_" and skill1_cooldown.is_stopped():
	elif Input.is_action_just_pressed("skill1") and not ("damaged" in sprite.animation or "flashbang" in sprite.animation) and gun_prefix != "as_" and skill1_cooldown.is_stopped():
		can_move = false
		atk_state = Atk_States.SK2
		put_down_gun(gun_prefix)
		gun_handler("assault")
		reset_axis()
	
	#elif Input.is_action_just_pressed("skill1") and (sprite.animation == "as_idle" or sprite.animation == "as_running"):
	elif Input.is_action_just_pressed("skill1") and not ("damaged" in sprite.animation or "flashbang" in sprite.animation) and gun_prefix == "as_":
		put_down_gun("as_")
		gun_handler("pistol")
	
	#elif Input.is_action_just_pressed("skill2") and ("idle" in sprite.animation or "running" in sprite.animation) and gun_prefix != "sh_" and skill2_cooldown.is_stopped():
	elif Input.is_action_just_pressed("skill2") and not ("damaged" in sprite.animation or "flashbang" in sprite.animation) and gun_prefix != "sh_" and skill2_cooldown.is_stopped():
		can_move = false
		atk_state = Atk_States.SK2
		put_down_gun(gun_prefix)
		gun_handler("shotgun")
		reset_axis()
	
	#elif Input.is_action_just_pressed("skill2") and (sprite.animation == "sh_idle" or sprite.animation == "sh_running"):
	elif Input.is_action_just_pressed("skill2") and not ("damaged" in sprite.animation or "flashbang" in sprite.animation) and gun_prefix == "sh_":
		put_down_gun("sh_")
		gun_handler("pistol")

	#elif Input.is_action_just_pressed("ult") and (sprite.animation == gun_prefix+"idle" or sprite.animation == gun_prefix+"running") and ulti_cooldown.is_stopped():
	elif Input.is_action_just_pressed("ult") and not ("damaged" in sprite.animation or "flashbang" in sprite.animation) and ulti_cooldown.is_stopped():
		ulti_cooldown.start()
		ulti_duration_timer.start(ULTI_DURATION)
		skill1_cooldown.start(0.1)
		skill2_cooldown.start(0.1)
		atk_state = Atk_States.ULT
		_on_change_stats("pbc", 100, ULTI_DURATION, false)
		_on_change_stats("str", 100, ULTI_DURATION, false)

	elif sprite.animation != gun_prefix+"idle" or sprite.animation != gun_prefix+"running":
		pass




# ----------------- AREA2D INIZIO ----------------- #
'DIGEST DELLE AREE2D PER GESTIRE QUANDO UN NEMICO ENTRA O ESCE DALL\'AREA
	ogni metodo controlla sempre come prima cosa se il body è diverso da se stesso, altrimenti
	manderebbe dei segnali inutili'

func _on_flashbang_area_body_entered(body: Node2D) -> void:
	if body != self:
		emit_signal("is_in_atk_range", true, body)
		emit_signal("take_dmg", 0, 0, 4, 0, 0, flashbang_type)
		emit_signal("inflict_knockback", 300, 5, self.global_position)

func _on_flashbang_area_body_exited(body: Node2D) -> void:
	emit_signal("is_in_atk_range", false, body)


# ----------------- AREA2D FINE ----------------- #




func flip_sprite(flip):
	if flip:
		sprite.flip_h = true
		bullets_spawnpoint.position.x = -17
	else:
		sprite.flip_h = false
		bullets_spawnpoint.position.x = 17

func _on_sprite_2d_animation_finished():
	if "reload" in sprite.animation:
		gun_bullet_count = max_bullet_count
		set_bullet_count_label()
		emit_signal("set_idle")
	
	if "flashbang" in sprite.animation:
		flashbang_collider.set_deferred("disabled", true)
		emit_signal("set_idle")
	
	if "change" in sprite.animation and changing_gun:
		can_move = false
		changing_gun = false
		if ulti_duration_timer.is_stopped():
			sprite.play(gun_prefix+"change")
		else:
			sprite.play(gun_prefix+"change", 3.0)
	
	elif "change" in sprite.animation:
		emit_signal("set_idle")
	
	if "shooting" in sprite.animation:
		shooting_delay_timer.start()
		if gun_bullet_count <= 0 and gun_prefix != "p_":
			put_down_gun(gun_prefix)
			gun_handler("pistol")
	

func _on_sprite_2d_frame_changed():
	if (sprite.animation == "p_shooting" and sprite.frame == 3) or (sprite.animation == "p_continue_shooting" and sprite.frame == 1):
		gun_handler()
	if (sprite.animation == "as_shooting" and sprite.frame == 4) or (sprite.animation == "as_continue_shooting" and sprite.frame == 1):
		gun_handler()
	if (sprite.animation == "sh_shooting" and sprite.frame == 4) or (sprite.animation == "sh_continue_shooting" and sprite.frame == 2):
		gun_handler()
	if "flashbang" in sprite.animation and sprite.frame == 4:
		emit_signal("launched_flashbang")
		emit_signal("shake_camera", true, 20)
		flashbang_collider.set_deferred("disabled", false)

func _on_effect_frame_changed():
	pass

func put_down_gun(prefix):
	can_move = false
	changing_gun = true
	reaction_timer.stop()
	shooting_delay_timer.stop()
	var new_wait_time
	if prefix != "p_":
		if prefix == "as_":
			new_wait_time = SKILL1_WAIT_TIME - SKILL1_WAIT_TIME * calculate_cooldown_based_on_bullets() / 100
			if new_wait_time <= 0 or not ulti_duration_timer.is_stopped():
				new_wait_time = 0.1
			skill1_cooldown.start(new_wait_time)
		elif prefix == "sh_":
			new_wait_time = SKILL2_WAIT_TIME - SKILL2_WAIT_TIME * calculate_cooldown_based_on_bullets() / 100
			if new_wait_time <= 0 or not ulti_duration_timer.is_stopped():
				new_wait_time = 0.1
			skill2_cooldown.start(new_wait_time)
	
	if ulti_duration_timer.is_stopped():
		sprite.play_backwards(prefix+"change")
	else:
		sprite.play(prefix+"change", -3.0, true)
	atk_anim_finished = false
	reset_axis()

func calculate_cooldown_based_on_bullets():
	return gun_bullet_count*100/max_bullet_count

func gun_handler(param = "shoot"):
	if param == "shoot":
		if gun_bullet_count > 0:
			if gun_prefix != "sh_":
				shoot()
			else:
				for i in SHOTGUN_ROUNDS_COUNT:
					shoot(true)
			gun_bullet_count -= 1
			set_bullet_count_label()
		#else:
			#if gun_prefix != "p_":
				#put_down_gun(gun_prefix)
				#gun_handler("pistol")
	else:
		gun_prefix = Guns[param]["prefix"]
		gun_force = Guns[param]["force"]
		gun_precision = Guns[param]["precision"]
		shooting_delay_timer.wait_time = Guns[param]["delay"]
		gun_str = Guns[param]["gun_str"]
		gun_knockback_flag = Guns[param]["knockback"]
		gun_stun_time = Guns[param]["stun_time"]
		max_bullet_count = Guns[param]["bullet_count"]
		gun_bullet_count = max_bullet_count
		gun_shake_strenght = Guns[param]["shake_strenght"]
		set_bullet_count_label()

func shoot(shotgun = false):
	add_child(bullet_scene.instantiate(),true)
	var instantiated_bullet = get_child(get_child_count()-1)
	instantiated_bullet.player = self
	if sprite.flip_h:
		instantiated_bullet.direction = Vector2(-1,0)
	else:
		instantiated_bullet.direction = Vector2(1,0)
	instantiated_bullet.direction.y = randf_range(-gun_precision, gun_precision)
	instantiated_bullet.global_position = bullets_spawnpoint.global_position
	instantiated_bullet.bullet_str = gun_str
	if shotgun:
		instantiated_bullet.bullet_force = randf_range(gun_force/3,gun_force)
	else:
		instantiated_bullet.bullet_force = gun_force
	emit_signal("shake_camera", true, gun_shake_strenght)
	instantiated_bullet.knockback_flag = gun_knockback_flag
	instantiated_bullet.gun_stun_time = gun_stun_time
	get_parent().connect_player_projectile(instantiated_bullet)
	instantiated_bullet.reparent(get_parent())

func set_bullet_count_label():
	remaining_bullets_label.text = "x" + str(gun_bullet_count)

#  -- set_idle mi permette di resettare il player allo stato di idle --  #
func _on_set_idle():
	if not knockbacked:
		self.rotation_degrees = 0
		
		axis = Vector2.ZERO
		
		atk_state = Atk_States.IDLE
		
		sprite.z_index = 0
		sprite.flip_v = false
		
		sprite.play(gun_prefix+"idle")
		
		self.set_collision_layer_value(1, true)
		self.set_collision_layer_value(2, false)
		
		self.set_collision_mask_value(1, true)
		self.set_collision_mask_value(2, false)
		
		flashbang_collider.set_deferred("disabled", true)
		
		control_node.rotation_degrees = 0
		control_node.position.y = -53
		
		can_move = true
		atk_anim_finished = true
		changing_gun = false
		shooting_delay_timer.stop()
		reaction_timer.stop()

'  -- quando finisce l\'effetto della skill allora disattivo l\'area e setto ad idle --  '
func _on_effect_animation_finished():
	pass

func _on_shooting_delay_time_timeout():
	atk_anim_finished = true
	reaction_timer.start()

func _on_reaction_time_timeout() -> void:
	emit_signal("set_idle")

func _on_ulti_duration_timeout() -> void:
	pass # Replace with function body.



' -- DIGEST SEGNALI NEMICI -- '
func _on_enemy_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc, type):
	var dmg_info = get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc, type)
	var dmg = dmg_info[0]
	show_hitmarker("-" + str(dmg), dmg_info[1])
	current_vit -= dmg
	emit_signal("set_health_bar", current_vit)
	if dmg > 0:
		hit_flash_player.stop()
		hit_flash_player.play("hit_flash")
		emit_signal("shake_camera", true, dmg_info[2])
	if stun_sec > 0 and not "flashbang" in sprite.animation:
		shooting_delay_timer.stop()
		emit_signal("set_idle")
		sprite.play(gun_prefix+"damaged")
		can_move = false
		stun_timer.wait_time = stun_sec
		stun_timer.start()

func _on_enemy_grab(is_been_grabbed, grab_position_marker, sender):
	if is_been_grabbed and not grabbed:
		emit_signal("set_idle")
		sprite.play(gun_prefix+"damaged")
		
		can_move = false
		grabbed = true
		
		self.set_collision_layer_value(1, false)
		self.set_collision_layer_value(2, true)
		self.set_collision_mask_value(1, false)
		self.set_collision_mask_value(2, true)
		
		grab_marker = grab_position_marker
		grab_sender = sender
		
		if not sender.sprite.flip_h:
			flip_sprite(true)
		else: 
			flip_sprite(false)
		
		if sprite.flip_h:
			control_node.position.y = 53
			sprite.flip_v = true 
			sprite.flip_h = false
		else:
			sprite.flip_v = false
		
	elif not is_been_grabbed:
		emit_signal("set_idle")
		grabbed = false

#METODO CHE TELETRASPORTA IL NODO NELLA POSIZIONE DEL PLAYER DURANTE LA GRAB
#	setto la posizione uguale a quella del player
func is_grabbed():
	self.look_at(grab_sender.global_position)
	control_node.rotation_degrees = -self.rotation_degrees
	position = grab_marker.global_position

func _on_stun_timeout():
	emit_signal("set_idle")

func _on_get_healed(amount):
	current_vit += amount
	if current_vit > default_vit:
		current_vit = default_vit
	status_sprite.play("recover")
	emit_signal("set_health_bar", current_vit)

func init_knockback(amount, force, sender):
	if not grabbed:
		can_move = false
		knockbacked = true
		
		knockback_target_point = self.global_position + (sender.direction_to(self.global_position) * amount)
		knockback_force = force
		
		sprite.play(gun_prefix+"damaged")
		
		self.add_child(knockback_controller_node.instantiate(), true)
		var knockback_controller = get_child(-1)
		knockback_controller.reparent(get_parent())
		knockback_controller.target_point = knockback_target_point
		knockback_controller.vel_multiplyer = force
		knockback_controller.caller = self
		knockback_controller.target_reached.connect(self._on_knockback_reset)

func apply_knockback(delta):
	self.global_position = self.global_position.lerp(knockback_target_point, knockback_force * delta)
	move_and_slide()

func _on_knockback_reset():
	knockbacked = false
	reaction_timer.start()

func _on_change_stats(stat, amount, time_duration, _ally_sender):
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
			add_child(change_stats_timer_node.instantiate(),true)
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
