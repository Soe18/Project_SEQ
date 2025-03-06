extends CharacterBody2D

var char_name = "Rufus"

@export var default_vit : int = 200
var current_vit = default_vit
@export var default_str : int = 195
var current_str = default_str
@export var default_tem : int = 121
var current_tem = default_tem
@export var default_des : int = 145
var current_des = default_des
@export var default_pbc : int = 25
var current_pbc = default_pbc
@export var default_efc : float = 1.5
var current_efc = default_efc

@export var damage_node : PackedScene
@export var knockback_timer_node : PackedScene

enum Moving_States {IDLE, RUNNING}
enum Move_Keys {UP, DOWN, LEFT, RIGHT}

enum Atk_States {IDLE, BASE_ATK, SK1, SK2, EVA, ULT}

signal is_in_atk_range(is_in, body)
signal take_dmg(str, atk_str, sec_stun, pbc, efc, type)
signal set_idle()
signal set_health_bar(current_vit)
signal get_healed(amount)
signal change_stats(stat, amount, time_duration, ally_sender)
signal inflict_knockback(amount, time, sender)
signal shake_camera(shake, strenght)

@export var ACCELERATION : float = 10000.0
@export var FRICTION : float = 7000.0

@onready var axis = Vector2.ZERO

var initial_y_position = 0
const MAX_Y_POSITION = 270

var BASIC_ATK_COLLIDER_POSITION_X
var SKILL1_COLLIDER_POSITION_X

var atk_state = Atk_States.IDLE

var move_state = Moving_States.IDLE

var can_move = true
var grabbed = false
var grab_marker
var grab_sender

var knockbacked = false
var knockback_force
var knockback_sender

var is_evading = false

var atk_anim_finished = true

var is_moving_ult = false
var ult_moving_mod

@export var basic_atk_force = 10
@export var basic_stun_time = 0.4
@onready var basic_atk_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

@export var evade_amount = 1000
@export var evade_force = 10
@export var evade_stun_time = 2.1
@onready var evade_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

@export var skill1_force = 20
@export var skill1_stun_time = 0.6
@onready var skill1_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

@export var skill2_force = 23
@export var skill2_stun_time = 1.4
@export var skill2_changed_stat = "tem"
@export var skill2_stat_amount = -25
@export var skill2_duration = 10
@export var skill2_knockback_force = 600
@export var skill2_knockback_duration = 0.2
@onready var skill2_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

@export var ult_force = 80
@export var ult_stun_time = 6
@export var ult_knockback_force = 900
@export var ult_knockback_duration = 0.3
@onready var ult_type = get_tree().get_first_node_in_group("gm").Attack_Types.PHYSICAL

@onready var sprite = $Sprite2D

@onready var bs_atk_collider = $Basic_atk_Area/Atk_collider

@onready var skill1_collider = $Skill_1_area/Skill_collider
@onready var skill1_effect = $Skill_1_area/Effect

@onready var eva_collider = $Eva_area/Eva_collider
@onready var eva_duration_timer = $Eva_area/Eva_time

@onready var skill2_collider = $Skill2_area/Skill_collider
@onready var skill2_effect = $Skill2_area/Effect

@onready var ult_collider = $Ult_area/Ult_collider
@onready var ult_effect = $Ult_area/Effect
@onready var ult_stop_timer = $Ult_area/Ult_time

@onready var skill1_cooldown = $Skill1_cooldown
@onready var skill2_cooldown = $Skill2_cooldown
@onready var eva_cooldown = $Eva_cooldown
@onready var ulti_cooldown = $Ulti_cooldown

@onready var body_collider = $Body_collider

@onready var stun_timer = $Stun
@onready var combo_time = $Combo_time

@onready var status_sprite = $Status_alert_sprite

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
func _ready():
	BASIC_ATK_COLLIDER_POSITION_X = bs_atk_collider.position.x
	SKILL1_COLLIDER_POSITION_X = skill1_collider.position.x
	emit_signal("set_health_bar", default_vit)

func _physics_process(delta):
	if knockbacked:
		apply_knockback(knockback_sender)
	if grabbed:
		is_grabbed()
	if can_move:
		move(delta)
	if stun_timer.is_stopped():
		atk_handler()
	if is_evading:
		evade()
	if is_moving_ult:
		ult_moving()

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
		sprite.play("Running")
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
		sprite.play("idle")

func apply_movement(accel):
	velocity += accel
	velocity = velocity.limit_length(current_des * 2.5)

func reset_axis():
	velocity = Vector2.ZERO
	axis = Vector2.ZERO

'METODO CHE GESTISCE TUTTE LE ABILITA\' DEL PLAYER
	ad ogni if si controlla l\'azione possibile, per l\'attacco di base si trovano
	dei controlli aggiuntivi in base alla combo:
	si controlla come prima cosa se l\'input è stato premuto, se l\'animazione è diversa da idle o running (ovvero o è fermo
	o si sta spostando) oppure il numero di combo che sta facendo ed infine se non è in cooldown'

func atk_handler():
	if Input.is_action_just_pressed("base_atk") and (sprite.animation == "idle" or sprite.animation == "Running") and atk_anim_finished:
		can_move = false
		bs_atk_collider.disabled = false
		atk_anim_finished = false
		atk_state = Atk_States.BASE_ATK
		sprite.play("base atk1")
		reset_axis()
	
	elif Input.is_action_just_pressed("base_atk") and sprite.animation == "base atk1" and atk_anim_finished:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		combo_time.stop()
		sprite.play("base atk2")
	
	elif Input.is_action_just_pressed("base_atk") and sprite.animation == "base atk2" and atk_anim_finished:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		combo_time.stop()
		sprite.play("base atk3")
	
	elif Input.is_action_just_pressed("base_atk") and sprite.animation == "base atk3" and atk_anim_finished:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		combo_time.stop()
		sprite.play("base atk4")
	
	elif Input.is_action_just_pressed("base_atk") and sprite.animation == "base atk4" and atk_anim_finished:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		combo_time.stop()
		sprite.play("base atk5")
	
	elif Input.is_action_just_pressed("skill1") and (sprite.animation == "idle" or sprite.animation == "Running") and skill1_cooldown.is_stopped():
		skill1_cooldown.start()
		can_move = false
		atk_state = Atk_States.SK1
		skill1_collider.disabled = false
		sprite.play("skill1")
		skill1_effect.play("effect")
		reset_axis()
	
	elif Input.is_action_just_pressed("evade") and (sprite.animation == "idle" or sprite.animation == "Running") and eva_cooldown.is_stopped():
		eva_cooldown.start()
		can_move = false
		atk_state = Atk_States.EVA
		eva_duration_timer.start()
		sprite.play("Eva")
		eva_collider.disabled = false
		is_evading = true
	
	elif Input.is_action_just_pressed("skill2") and (sprite.animation == "idle" or sprite.animation == "Running") and skill2_cooldown.is_stopped():
		skill2_cooldown.start()
		can_move = false
		atk_state = Atk_States.SK2
		sprite.play("skill2")
		skill2_effect.play("effect")
		reset_axis()

	elif Input.is_action_just_pressed("ult") and (sprite.animation == "idle" or sprite.animation == "Running") and ulti_cooldown.is_stopped():
		ulti_cooldown.start()
		can_move = false
		atk_state = Atk_States.ULT
		sprite.play("charging_ult")
		ult_moving_mod = -9
		reset_axis()

	elif sprite.animation != "idle" or sprite.animation != "Running":
		pass




# ----------------- AREA2D INIZIO ----------------- #
'DIGEST DELLE AREE2D PER GESTIRE QUANDO UN NEMICO ENTRA O ESCE DALL\'AREA
	ogni metodo controlla sempre come prima cosa se il body è diverso da se stesso, altrimenti
	manderebbe dei segnali inutili'

func _on_basic_atk_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)

func _on_basic_atk_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

func _on_eva_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)
		emit_signal("take_dmg", current_str, evade_force, evade_stun_time, current_pbc, current_efc, evade_type)

func _on_eva_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

func _on_skill_1_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)

func _on_skill_1_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

func _on_skill_2_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)
		emit_signal("take_dmg", current_str, skill2_force, skill2_stun_time, current_pbc, current_efc, skill2_type)
		emit_signal("change_stats", skill2_changed_stat, skill2_stat_amount, skill2_duration, false)
		emit_signal("inflict_knockback", skill2_knockback_force, skill2_knockback_duration, self.global_position)
		#emit_signal("inflict_knockback", 10, 10, self.global_position)

func _on_skill_2_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

func _on_ult_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)
		emit_signal("take_dmg", current_str, ult_force, ult_stun_time, current_pbc, current_efc, ult_type)
		emit_signal("inflict_knockback", ult_knockback_force, ult_knockback_duration, self.global_position)

func _on_ult_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

# ----------------- AREA2D FINE ----------------- #




func flip_sprite(flip):
	if flip:
		sprite.flip_h = true
		bs_atk_collider.position.x = -BASIC_ATK_COLLIDER_POSITION_X
		skill1_collider.position.x = -SKILL1_COLLIDER_POSITION_X
		skill1_effect.flip_h = true
	else:
		sprite.flip_h = false
		bs_atk_collider.position.x = BASIC_ATK_COLLIDER_POSITION_X
		skill1_collider.position.x = SKILL1_COLLIDER_POSITION_X
		skill1_effect.flip_h = false

func _on_sprite_2d_animation_finished():
	if atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk1":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, basic_atk_force, basic_stun_time, current_pbc, current_efc, basic_atk_type)
		atk_anim_finished = true
		combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk2":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, basic_atk_force, basic_stun_time, current_pbc, current_efc, basic_atk_type)
		atk_anim_finished = true
		combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk3":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, basic_atk_force, basic_stun_time, current_pbc, current_efc, basic_atk_type)
		atk_anim_finished = true
		combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk4":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, basic_atk_force+1, basic_stun_time+0.1, current_pbc, current_efc, basic_atk_type)
		atk_anim_finished = true
		combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk5":
		emit_signal("set_idle")

	elif atk_state == Atk_States.ULT and sprite.animation == "charging_ult":
		sprite.play("ult_animation")

	elif atk_state == Atk_States.ULT and sprite.animation == "ult_animation":
		sprite.pause()
		ult_collider.disabled = false
		ult_effect.play("effect")

func _on_sprite_2d_frame_changed():
	if sprite.frame == 4 and sprite.animation == "base atk5":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, basic_atk_force+2, basic_stun_time+0.1, current_pbc, current_efc, basic_atk_type)
	
	if sprite.frame == 7 and sprite.animation == "ult_animation":
		sprite.pause()
		is_moving_ult = true
		initial_y_position = sprite.position.y

func _on_effect_frame_changed():
	if skill1_effect.frame % 2 == 0 and atk_state == Atk_States.SK1:
		emit_signal("take_dmg", current_str, skill1_force, skill1_stun_time, current_pbc, current_efc, skill1_type)
	
	elif skill2_effect.frame == 2 and atk_state == Atk_States.SK2:
		skill2_collider.set_deferred("disabled", false)
	
	elif skill2_effect.frame == 3 and atk_state == Atk_States.SK2:
		skill2_collider.set_deferred("disabled", true)
	
	if ult_effect.frame == 5:
		ult_collider.set_deferred("disabled", true)

# METODO CHE FA MUOVERE LO SPRITE IN ALTO DURANTE L'ANIMAZIONE DELLA ULTI #
func ult_moving():
	body_collider.set_deferred("disabled", true)
	sprite.z_index = 1
	sprite.position.y += ult_moving_mod
	if sprite.flip_h:
		sprite.position.x += -0.10
	else:
		sprite.position.x += 0.10
	if sprite.position.y == initial_y_position-MAX_Y_POSITION:
		sprite.frame += 1.5
		ult_moving_mod = 9
	if sprite.position.y == initial_y_position:
		is_moving_ult = false
		sprite.play()

#  -- set_idle mi permette di resettare il player allo stato di idle --  #
func _on_set_idle():
	reset_axis()
	
	atk_state = Atk_States.IDLE
	
	self.rotation_degrees = 0
	sprite.z_index = 0
	sprite.flip_v = false
	
	sprite.play("idle")
	skill1_effect.play("idle")
	skill2_effect.play("idle")
	ult_effect.play("idle")
	
	bs_atk_collider.set_deferred("disabled", true)
	skill1_collider.set_deferred("disabled", true)
	skill2_collider.set_deferred("disabled", true)
	eva_collider.set_deferred("disabled", true)
	ult_collider.set_deferred("disabled", true)
	
	body_collider.set_deferred("disabled", false)
	
	self.set_collision_layer_value(1, true)
	self.set_collision_layer_value(2, false)
	
	self.set_collision_mask_value(1, true)
	self.set_collision_mask_value(2, false)
	
	can_move = true
	is_evading = false
	is_moving_ult = false
	atk_anim_finished = true
	sprite.position = Vector2.ZERO

func _on_ult_time_timeout():
	emit_signal("set_idle")

'  -- quando finisce l\'effetto della skill allora disattivo l\'area e setto ad idle --  '
func _on_effect_animation_finished():
	if atk_state == Atk_States.SK1:
		emit_signal("set_idle")

	elif atk_state == Atk_States.SK2:
		emit_signal("set_idle")

	elif atk_state == Atk_States.ULT:
		ult_stop_timer.start()

func _on_eva_time_timeout():
	emit_signal("set_idle")

func _on_combo_time_timeout():
	emit_signal("set_idle")

'METODO CHE GESTISCE L\'EVASIONE IN BASE ALLA DIREZIONE PREMUTA'
func evade():
	velocity = Vector2.ZERO
	self.set_collision_layer_value(1, false)
	self.set_collision_layer_value(2,true)
	self.set_collision_mask_value(1, false)
	self.set_collision_mask_value(2, true)
	if axis.x == 0 and axis.y < 0:
		velocity.y += -evade_amount
	elif axis.x == 0 and axis.y > 0:
		velocity.y += evade_amount
	elif axis.x < 0 and axis.y == 0:
		velocity.x += -evade_amount
	elif axis.x > 0 and axis.y == 0:
		velocity.x += evade_amount
	elif axis.x > 0 and axis.y < 0:
		velocity.x += evade_amount
		velocity.y += -evade_amount
	elif axis.x > 0 and axis.y > 0:
		velocity.x += evade_amount
		velocity.y += evade_amount
	elif axis.x < 0 and axis.y > 0:
		velocity.x += -evade_amount
		velocity.y += evade_amount
	elif axis.x < 0 and axis.y < 0:
		velocity.x += -evade_amount
		velocity.y += -evade_amount
	elif sprite.flip_h:
		velocity.x += -evade_amount
	else:
		velocity.x += evade_amount
	move_and_slide()

' -- DIGEST SEGNALI NEMICI -- '
func _on_enemy_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc, type):
	var dmg_info = get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc, type)
	var dmg = dmg_info[0]
	show_hitmarker("-" + str(dmg), dmg_info[1])
	current_vit -= dmg
	emit_signal("set_health_bar", current_vit)
	if dmg_info[2] > 0:
		emit_signal("shake_camera", true, dmg_info[2])
	if stun_sec > 0:
		emit_signal("set_idle")
		sprite.play("damaged")
		can_move = false
		stun_timer.wait_time = stun_sec
		stun_timer.start()

func _on_enemy_grab(is_been_grabbed, grab_position_marker, sender):
	if is_been_grabbed and not grabbed:
		emit_signal("set_idle")
		sprite.play("damaged")
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
			sprite.flip_v = true 
			sprite.flip_h = false
		else:
			sprite.flip_v = false
		
	elif not is_been_grabbed:
		emit_signal("set_idle")
		grabbed = false

func is_grabbed():
	self.look_at(grab_sender.global_position)
	global_position = grab_marker.global_position

func _on_stun_timeout():
	emit_signal("set_idle")

func _on_get_healed(amount):
	current_vit += amount
	if current_vit > default_vit:
		current_vit = default_vit
	status_sprite.play("recover")
	emit_signal("set_health_bar", current_vit)

func init_knockback(amount, time, sender):
	if is_in_atk_range and not grabbed:
		can_move = false
		knockbacked = true
		knockback_force = amount
		knockback_sender = sender
		sprite.play("damaged")
		
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
	combo_time.start()

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
			add_child(load("res://scenes/time_of_change.tscn").instantiate(),true)
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
