extends CharacterBody2D

var char_name = "Rufus"

@export var default_vit : int = 200
var current_vit = default_vit
@export var default_str : int = 150
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

enum Moving_States {IDLE, RUNNING}
enum Move_Keys {UP, DOWN, LEFT, RIGHT}

enum Atk_States {IDLE, BASE_ATK, SK1, SK2, EVA, ULT}

signal is_in_atk_range(is_in, body)
signal take_dmg(str, atk_str, sec_stun, pbc, efc)
signal set_idle()
signal set_health_bar(current_vit)
signal get_healed(amount)
signal change_stats(stat, amount, time_duration, ally_sender)
signal inflict_knockback(amount, time, sender)


@export var ACCELERATION : float = 10000.0
@export var FRICTION : float = 7000.0

@onready var axis = Vector2.ZERO

var initial_y_position = 0

var atk_state = Atk_States.IDLE

var move_state = Moving_States.IDLE

var can_move = true

var is_evading = false

var atk_anim_finished = true

var is_moving_ult = false
var ult_moving_mod


@onready var sprite = $Sprite2D

@onready var bs_atk_collider = $Basic_atk_Area/Atk_collider

@onready var skill1_collider = $Skill_1_area/Skill_collider
@onready var skill1_effect = $Skill_1_area/Effect

@onready var eva_collider = $Eva_area/Eva_collider

@onready var skill2_collider = $Skill2_area/Skill_collider
@onready var skill2_effect = $Skill2_area/Effect

@onready var ult_collider = $Ult_area/Ult_collider
@onready var ult_effect = $Ult_area/Effect

@onready var skill1_cooldown = $Skill1_cooldown
@onready var skill2_cooldown = $Skill2_cooldown
@onready var eva_cooldown = $Eva_cooldown
@onready var ulti_cooldown = $Ulti_cooldown

@onready var body_collider = $Body_collider

@onready var stun_timer = $Stun

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
	emit_signal("set_health_bar", default_vit)

func _physics_process(delta):
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
		axis = Vector2.ZERO
	
	elif Input.is_action_just_pressed("base_atk") and sprite.animation == "base atk1" and atk_anim_finished:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		$Combo_time.stop()
		sprite.play("base atk2")
	
	elif Input.is_action_just_pressed("base_atk") and sprite.animation == "base atk2" and atk_anim_finished:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		$Combo_time.stop()
		sprite.play("base atk3")
	
	elif Input.is_action_just_pressed("base_atk") and sprite.animation == "base atk3" and atk_anim_finished:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		$Combo_time.stop()
		sprite.play("base atk4")
	
	elif Input.is_action_just_pressed("base_atk") and sprite.animation == "base atk4" and atk_anim_finished:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		$Combo_time.stop()
		sprite.play("base atk5")
	
	elif Input.is_action_just_pressed("skill1") and (sprite.animation == "idle" or sprite.animation == "Running") and skill1_cooldown.is_stopped():
		skill1_cooldown.start()
		can_move = false
		atk_state = Atk_States.SK1
		skill1_collider.disabled = false
		sprite.play("skill1")
		skill1_effect.play("effect")
		axis = Vector2.ZERO
	
	elif Input.is_action_just_pressed("evade") and (sprite.animation == "idle" or sprite.animation == "Running") and eva_cooldown.is_stopped():
		eva_cooldown.start()
		can_move = false
		atk_state = Atk_States.EVA
		$Eva_time.start()
		sprite.play("Eva")
		eva_collider.disabled = false
		is_evading = true
	
	elif Input.is_action_just_pressed("skill2") and (sprite.animation == "idle" or sprite.animation == "Running") and skill2_cooldown.is_stopped():
		skill2_cooldown.start()
		can_move = false
		atk_state = Atk_States.SK2
		sprite.play("skill2")
		skill2_effect.play("effect")
		axis = Vector2.ZERO

	elif Input.is_action_just_pressed("ult") and (sprite.animation == "idle" or sprite.animation == "Running") and ulti_cooldown.is_stopped():
		ulti_cooldown.start()
		can_move = false
		atk_state = Atk_States.ULT
		sprite.play("charging_ult")
		ult_moving_mod = -9
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
		emit_signal("take_dmg", current_str, 10, 2.1, current_pbc, current_efc)

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
		emit_signal("take_dmg", current_str, 17, 1.4, current_pbc, current_efc)
		emit_signal("change_stats", "tem", -25, 3, false)
		emit_signal("inflict_knockback", 600, 0.2, self.global_position)
		#emit_signal("inflict_knockback", 10, 10, self.global_position)

func _on_skill_2_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

func _on_ult_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)
		emit_signal("take_dmg", current_str, 70, 6, current_pbc, current_efc)
		emit_signal("inflict_knockback", 900, 0.3, self.global_position)

func _on_ult_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

# ----------------- AREA2D FINE ----------------- #




func flip_sprite(flip):
	if flip:
		sprite.flip_h = true
		bs_atk_collider.position.x = -89.75
		skill1_collider.position.x = -36
		skill1_effect.flip_h = true
	else:
		sprite.flip_h = false
		bs_atk_collider.position.x = 4.25
		skill1_collider.position.x = 36
		skill1_effect.flip_h = false

func _on_sprite_2d_animation_finished():
	if atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk1":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 10, 0.4, current_pbc, current_efc)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk2":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 10, 0.4, current_pbc, current_efc)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk3":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 10, 0.4, current_pbc, current_efc)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk4":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 11, 0.5, current_pbc, current_efc)
		atk_anim_finished = true
		$Combo_time.start()

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
		emit_signal("take_dmg", current_str, 13, 0.5, current_pbc, current_efc)
	
	if sprite.frame == 7 and sprite.animation == "ult_animation":
		sprite.pause()
		is_moving_ult = true
		initial_y_position = sprite.position.y

func _on_effect_frame_changed():
	if skill1_effect.frame % 2 == 0 and atk_state == Atk_States.SK1:
		emit_signal("take_dmg", current_str, 20, 0.6, current_pbc, current_efc)
	
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
	if sprite.position.y == initial_y_position-270:
		sprite.frame += 1.5
		ult_moving_mod = 9
	if sprite.position.y == initial_y_position:
		is_moving_ult = false
		sprite.play()

#  -- set_idle mi permette di resettare il player allo stato di idle --  #
func _on_set_idle():
	axis = Vector2.ZERO
	
	atk_state = Atk_States.IDLE
	
	sprite.z_index = 0
	
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
	sprite.position = Vector2(0,0)

func _on_ult_time_timeout():
	emit_signal("set_idle")

'  -- quando finisce l\'effetto della skill allora disattivo l\'area e setto ad idle --  '
func _on_effect_animation_finished():
	if atk_state == Atk_States.SK1:
		emit_signal("set_idle")

	elif atk_state == Atk_States.SK2:
		emit_signal("set_idle")

	elif atk_state == Atk_States.ULT:
		$Ult_area/Ult_time.start()

func _on_eva_time_timeout():
	emit_signal("set_idle")

func _on_combo_time_timeout():
	emit_signal("set_idle")

'METODO CHE GESTISCE L\'EVASIONE IN BASE ALLA DIREZIONE PREMUTA'
func evade():
	self.set_collision_layer_value(1, false)
	self.set_collision_layer_value(2,true)
	self.set_collision_mask_value(1, false)
	self.set_collision_mask_value(2, true)
	if axis.x == 0 and axis.y < 0:
		velocity.y += -35
	elif axis.x == 0 and axis.y > 0:
		velocity.y += 35
	elif axis.x < 0 and axis.y == 0:
		velocity.x += -35
	elif axis.x > 0 and axis.y == 0:
		velocity.x += 35
	elif axis.x > 0 and axis.y < 0:
		velocity.x += 35
		velocity.y += -35
	elif axis.x > 0 and axis.y > 0:
		velocity.x += 35
		velocity.y += 35
	elif axis.x < 0 and axis.y > 0:
		velocity.x += -35
		velocity.y += 35
	elif axis.x < 0 and axis.y < 0:
		velocity.x += -35
		velocity.y += -35
	elif sprite.flip_h:
		velocity.x += -35
	else:
		velocity.x += 35
	move_and_slide()

' -- DIGEST SEGNALI NEMICI -- '
func _on_enemy_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc):
	var dmg_crit = get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc)
	var dmg = dmg_crit[0]
	show_hitmarker("-" + str(dmg), dmg_crit[1])
	current_vit -= dmg
	emit_signal("set_health_bar", current_vit)
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
	status_sprite.play("recover")
	emit_signal("set_health_bar", current_vit)

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
