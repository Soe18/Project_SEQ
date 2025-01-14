extends CharacterBody2D

var char_name = "Nathan"

@export var default_vit : int = 270
var current_vit = default_vit
@export var default_str : int = 138
var current_str = default_str
@export var default_tem : int = 162
var current_tem = default_tem
@export var default_des : int = 180
var current_des = default_des
@export var default_pbc : int = 30
var current_pbc = default_pbc
@export var default_efc : float = 1.5
var current_efc = default_efc

@export var damage_node : PackedScene

enum Moving_States {IDLE, RUNNING}
enum Move_Keys {UP, DOWN, LEFT, RIGHT}

enum Atk_States {IDLE, BASE_ATK, SK1, SK2, EVA, ULT}

signal is_in_atk_range(is_in, body)
signal take_dmg(str, atk_str, sec_stun, pbc, efc)
signal set_idle()
signal grab(has_grabbed, is_flipped, grab_position_marker)
signal set_health_bar(current_vit)
signal shake_camera(is_shacking)
signal get_healed(amount)

@export var OK_MULTIPLYER : float = 390.0
var current_multiplyer = OK_MULTIPLYER
@export var ACCELERATION : float = 10000.0
@export var FRICTION : float = 7000.0

@onready var axis = Vector2.ZERO

var atk_state = Atk_States.IDLE

var can_move = true

var is_evading = false

var sk1_activated = false
var bite_heal_force = 12

var atk_anim_finished = true

@onready var sprite = $Sprite2D

@onready var player_collider = $Player_collider

@onready var bs_atk_collider = $Basic_atk_Area/Atk_collider
@onready var combo_time = $Combo_time

@onready var skill1_collider = $Skill_1_area/Skill_collider
@onready var skill1_duration_time = $Skill_1_area/Sk1_time
@onready var skill1_cooldown = $Skill1_cooldown

@onready var eva_collider = $Eva_area/Eva_collider
@onready var eva_cooldown = $Eva_cooldown

@onready var skill2_collider = $Skill2_area/Skill_collider
@onready var skill2_cooldown = $Skill2_cooldown

@onready var ult_collider = $Ult_area/Ult_collider
@onready var ult_effect = $Ult_area/Effect
@onready var ulti_cooldown = $Ult_cooldown

@onready var roar_time = $Ult_area/Roar_time

@onready var stun_timer = $Stun

@onready var status_sprite = $Status_alert_sprite

@onready var hitmarker_spawnpoint = $Hitmarker_spawn

@onready var grab_position_marker = $Grab_position


@warning_ignore("unused_parameter") # c'è sta cosa altrimenti mi da fastidio "l'errore"

func _ready():
	emit_signal("set_health_bar", current_vit)

'METODO CHE VIENE CHIAMATO AD OGNI FRAME
	se il player si può muovere
		esegue il metodo per muoversi
	esegue il metodo che gestisce gli attacchi
	se sta eseguendo un\'evasione
		esegue il metodo di evasione
	se ha attivato la skill1
		esegue il metodo di movimento della skill1'

func _physics_process(delta):
	if can_move:
		move(delta)
	elif sk1_activated:
		skill1_moving(sprite.flip_h)
	elif is_evading:
		evade()
	if stun_timer.is_stopped():
		atk_handler()

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

'METODO CHE GESTISCE TUTTE LE ABILITA\' DEL PLAYER
	ad ogni if si controlla l\'azione possibile, per l\'attacco di base si trovano
	dei controlli aggiuntivi in base alla combo:
	si controlla come prima cosa se l\'input è stato premuto, se l\'animazione è diversa da idle o running (ovvero o è fermo
	o si sta spostando) oppure il numero di combo che sta facendo ed infine se non è in cooldown'

func atk_handler():
	if Input.is_action_just_pressed("base_atk") and (sprite.animation == "idle" or sprite.animation == "Running") and atk_anim_finished:
		can_move = false
		bs_atk_collider.set_deferred("disabled", false)
		atk_anim_finished = false
		atk_state = Atk_States.BASE_ATK
		sprite.play("base atk1")
		axis = Vector2.ZERO
	
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
		sk1_activated = true
		atk_state = Atk_States.SK1
		skill1_collider.set_deferred("disabled", false)
		sprite.play("skill1")
		skill1_duration_time.start(4)
		axis = Vector2.ZERO
	
	elif Input.is_action_just_pressed("evade") and (sprite.animation == "idle" or sprite.animation == "Running") and eva_cooldown.is_stopped():
		eva_cooldown.start()
		can_move = false
		velocity = Vector2(0, 0)
		atk_state = Atk_States.EVA
		$Eva_time.start()
		sprite.play("Eva")
		is_evading = true
	
	elif Input.is_action_just_pressed("skill2") and (sprite.animation == "idle" or sprite.animation == "Running") and skill2_cooldown.is_stopped():
		skill2_cooldown.start()
		can_move = false
		atk_state = Atk_States.SK2
		sprite.play("skill2")
		skill2_collider.set_deferred("disabled", false)
		$Grab_time.start()
		axis = Vector2.ZERO

	elif Input.is_action_just_pressed("ult") and (sprite.animation == "idle" or sprite.animation == "Running") and ulti_cooldown.is_stopped():
		ulti_cooldown.start()
		can_move = false
		atk_state = Atk_States.ULT
		sprite.play("charging_ult")
		axis = Vector2.ZERO

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
		emit_signal("take_dmg", current_str, 12, 2.1, current_pbc, current_efc)

func _on_eva_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

'questo metodo gestisce la durata della skill in modo che quando si colpisce qualcosa essa si blocca'

func _on_skill_1_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)
		emit_signal("take_dmg", current_str, 30, 2, current_pbc, current_efc)
		skill1_duration_time.start(0.5)

func _on_skill_1_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

func _on_skill_2_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)

func _on_skill_2_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

func _on_ult_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)
		emit_signal("take_dmg", current_str, 85, 6, current_pbc, current_efc)

func _on_ult_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

# ----------------- AREA2D FINE ----------------- #




func flip_sprite(flip):
	if flip:
		sprite.flip_h = true
		bs_atk_collider.position.x = -73
		skill2_collider.position.x = -71
		grab_position_marker.position.x = -61
	else:
		sprite.flip_h = false
		bs_atk_collider.position.x = 73
		skill2_collider.position.x = 71
		grab_position_marker.position.x = 61

func _on_sprite_2d_animation_finished():
	if atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk1":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 9, 0.5, current_pbc, current_efc)
		atk_anim_finished = true
		combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk2":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 10, 0.5, current_pbc, current_efc)
		atk_anim_finished = true
		combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk3":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 10, 0.5, current_pbc, current_efc)
		atk_anim_finished = true
		combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk4":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 11, 0.5, current_pbc, current_efc)
		atk_anim_finished = true
		combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk5":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 12, 0.5, current_pbc, current_efc)
		emit_signal("set_idle")
	
	elif atk_state == Atk_States.EVA:
		eva_collider.set_deferred("disabled", false)
		sprite.z_index = 0
		emit_signal("set_idle")

	elif atk_state == Atk_States.SK1:
		emit_signal("set_idle")

	elif atk_state == Atk_States.SK2:
		emit_signal("grab", true, sprite.flip_h, grab_position_marker)
		emit_signal("set_idle")

	elif atk_state == Atk_States.ULT and sprite.animation == "charging_ult":
		sprite.pause()
		emit_signal("shake_camera", true)
		roar_time.start()
		ult_collider.set_deferred("disabled", false)
		ult_effect.play("effect")
		sprite.z_index = 1

func _on_sprite_2d_frame_changed():
	if sprite.animation == "Eva" and sprite.frame == 3:
		sprite.pause()

'  -- set_idle mi permette di resettare il player allo stato di idle --  '
func _on_set_idle():
	axis = Vector2.ZERO
	
	atk_state = Atk_States.IDLE
	
	sprite.play("idle")
	ult_effect.play("idle")
	
	sprite.z_index = 0
	
	skill1_duration_time.stop()
	
	bs_atk_collider.set_deferred("disabled", true)
	eva_collider.set_deferred("disabled", true)
	skill1_collider.set_deferred("disabled", true)
	skill2_collider.set_deferred("disabled", true)
	ult_collider.set_deferred("disabled", true)
	player_collider.set_deferred("disabled", false)
	
	self.set_collision_layer_value(1, true)
	self.set_collision_layer_value(2, false)
	
	self.set_collision_mask_value(1, true)
	self.set_collision_mask_value(2, false)
	
	can_move = true
	atk_anim_finished = true
	is_evading = false
	sk1_activated = false




# --------------------- TIMER INIZIO --------------------- #

func _on_ult_time_timeout():
	emit_signal("shake_camera", false)
	roar_time.stop()
	emit_signal("set_idle")

func _on_combo_time_timeout():
	emit_signal("set_idle")

func _on_eva_time_timeout():
	sprite.play()
	eva_collider.set_deferred("disabled", false)

func _on_grab_time_timeout():
	emit_signal("grab", false, sprite.flip_h, null)

func _on_sk_1_time_timeout():
	emit_signal("set_idle")

# --------------------- TIMER FINE --------------------- #




'METODO DELL\'EVASIONE DEL PLAYER'
func evade():
	var multiplyer = 15
	self.set_collision_layer_value(1, false)
	self.set_collision_layer_value(2, true)
	
	self.set_collision_mask_value(1, false)
	self.set_collision_mask_value(2, true)
	
	if axis.x == 0 and axis.y < 0:
		velocity.y += -multiplyer
	elif axis.x == 0 and axis.y > 0:
		velocity.y += multiplyer
	elif axis.x < 0 and axis.y == 0:
		velocity.x += -multiplyer
	elif axis.x > 0 and axis.y == 0:
		velocity.x += multiplyer
	elif axis.x > 0 and axis.y < 0:
		velocity.x += multiplyer
		velocity.y += -multiplyer
	elif axis.x > 0 and axis.y > 0:
		velocity.x += multiplyer
		velocity.y += multiplyer
	elif axis.x < 0 and axis.y > 0:
		velocity.x += -multiplyer
		velocity.y += multiplyer
	elif axis.x < 0 and axis.y < 0:
		velocity.x += -multiplyer
		velocity.y += -multiplyer
	elif sprite.flip_h:
		velocity.x += -multiplyer
	else:
		velocity.x += multiplyer
	
	move_and_slide()

'METODO CHE SPOSTA IL PLAYER DURANTE LA SKILL1'
func skill1_moving(is_flipped):
	if is_flipped:
		velocity.x += -15
	else:
		velocity.x += 15
	move_and_slide()

' - DIGEST DEL SEGNALE take_dmg DEI NEMICI - '

func _on_enemy_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc):
	var dmg = get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc)
	current_vit -= dmg
	emit_signal("set_health_bar", current_vit)
	show_hitmarker("-" + str(dmg), false)
	if stun_sec > 0:
		emit_signal("set_idle")
		sprite.play("damaged")
		can_move = false
		stun_timer.wait_time = stun_sec
		stun_timer.start()

func _on_stun_timeout():
	emit_signal("set_idle")

func _on_get_healed(amount):
	current_vit += amount
	if current_vit > default_vit:
		current_vit = default_vit
	emit_signal("set_health_bar", current_vit)
	status_sprite.play("recover")

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
