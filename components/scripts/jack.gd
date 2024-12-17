extends CharacterBody2D

var char_name = "Jack"

@export var default_vit : int = 220
var current_vit = default_vit
@export var default_str : int = 120
var current_str = default_str
@export var default_tem : int = 140
var current_tem = default_tem
@export var default_des : int = 165
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
signal set_health_bar(current_vit)
signal get_healed(amount)
signal change_stats(stat, amount, time_duration, ally_sender)
signal inflict_knockback(amount, time, sender)

signal launched_flashbang()

@export var ACCELERATION : float = 10000.0
@export var FRICTION : float = 7000.0

@onready var axis = Vector2.ZERO

var atk_state = Atk_States.IDLE

var move_state = Moving_States.IDLE

var can_move = true

var atk_anim_finished = true

var Guns = {
	"pistol" : {"force" : 2000, "precision" : 0.1, "delay" : 0.4, "gun_str" : 30, "knockback" : false, "stun_time" : 0, "bullet_count" : 6, "prefix" : "p_"}
}

var gun_prefix
var gun_force
var gun_precision
var gun_str
var gun_knockback_flag
var gun_stun_time
var max_bullet_count
var gun_bullet_count

@export var bullet_scene : PackedScene

@onready var sprite = $Sprite2D

@onready var bullets_spawnpoint = $Bullets_spawnpoint

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
	gun_handler("pistol")

func _physics_process(delta):
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
	var frame = sprite.frame
	var frame_progress = sprite.frame_progress
	if running and sprite.animation != "p_running_reload":
		sprite.play("p_running_reload")
		sprite.frame = frame
		sprite.frame_progress = frame_progress
	elif not running and sprite.animation != "p_reload":
		sprite.play("p_reload")
		sprite.frame = frame
		sprite.frame_progress = frame_progress

'METODO CHE GESTISCE TUTTE LE ABILITA\' DEL PLAYER
	ad ogni if si controlla l\'azione possibile, per l\'attacco di base si trovano
	dei controlli aggiuntivi in base alla combo:
	si controlla come prima cosa se l\'input è stato premuto, se l\'animazione è diversa da idle o running (ovvero o è fermo
	o si sta spostando) oppure il numero di combo che sta facendo ed infine se non è in cooldown'

func atk_handler():
	if Input.is_action_pressed("base_atk") and (sprite.animation == gun_prefix+"idle" or sprite.animation == gun_prefix+"running") and gun_bullet_count <= 0:
		if gun_prefix == "p_":
			sprite.play("p_reload")
			axis = Vector2.ZERO
		else:
			gun_handler("pistol")
		
	elif Input.is_action_pressed("base_atk") and (sprite.animation == gun_prefix+"idle" or sprite.animation == gun_prefix+"running") and atk_anim_finished and gun_bullet_count > 0:
		can_move = false
		atk_anim_finished = false
		atk_state = Atk_States.BASE_ATK
		sprite.play(gun_prefix+"shooting")
		reset_axis()
	
	elif Input.is_action_pressed("base_atk") and (sprite.animation == gun_prefix+"shooting" or sprite.animation == gun_prefix+"continue_shooting") and atk_anim_finished and shooting_delay_timer.is_stopped() and gun_bullet_count > 0:
		atk_state = Atk_States.BASE_ATK
		atk_anim_finished = false
		reaction_timer.stop()
		sprite.play(gun_prefix+"continue_shooting")
	
	#elif Input.is_action_just_pressed("skill1") and (sprite.animation == "idle" or sprite.animation == gun_prefix+"running") and skill1_cooldown.is_stopped():
		#skill1_cooldown.start()
		#can_move = false
		#atk_state = Atk_States.SK1
		#skill1_collider.disabled = false
		#sprite.play("skill1")
		#skill1_effect.play("effect")
		#axis = Vector2.ZERO
	#
	elif Input.is_action_just_pressed("evade") and (sprite.animation == gun_prefix+"idle" or sprite.animation == gun_prefix+"running") and eva_cooldown.is_stopped():
		eva_cooldown.start()
		can_move = false
		atk_state = Atk_States.EVA
		sprite.play(gun_prefix+"flashbang")
		reset_axis()
	
	#elif Input.is_action_just_pressed("skill2") and (sprite.animation == "idle" or sprite.animation == gun_prefix+"running") and skill2_cooldown.is_stopped():
		#skill2_cooldown.start()
		#can_move = false
		#atk_state = Atk_States.SK2
		#sprite.play("skill2")
		#skill2_effect.play("effect")
		#axis = Vector2.ZERO
#
	#elif Input.is_action_just_pressed("ult") and (sprite.animation == "idle" or sprite.animation == gun_prefix+"running") and ulti_cooldown.is_stopped():
		#ulti_cooldown.start()
		#can_move = false
		#atk_state = Atk_States.ULT
		#sprite.play("charging_ult")
		#ult_moving_mod = -9
		#axis = Vector2.ZERO

	elif sprite.animation != gun_prefix+"idle" or sprite.animation != gun_prefix+"running":
		pass




# ----------------- AREA2D INIZIO ----------------- #
'DIGEST DELLE AREE2D PER GESTIRE QUANDO UN NEMICO ENTRA O ESCE DALL\'AREA
	ogni metodo controlla sempre come prima cosa se il body è diverso da se stesso, altrimenti
	manderebbe dei segnali inutili'


# ----------------- AREA2D FINE ----------------- #




func flip_sprite(flip):
	if flip:
		sprite.flip_h = true
		bullets_spawnpoint.position.x = -40
	else:
		sprite.flip_h = false
		bullets_spawnpoint.position.x = 40

func _on_sprite_2d_animation_finished():
	if atk_state == Atk_States.BASE_ATK and "shooting" in sprite.animation:
		shooting_delay_timer.start()
	if "reload" in sprite.animation:
		gun_bullet_count = max_bullet_count
		set_bullet_count_label()
		emit_signal("set_idle")
	if "flashbang" in sprite.animation:
		flashbang_collider.set_deferred("disabled", true)
		emit_signal("set_idle")

func _on_sprite_2d_frame_changed():
	if (sprite.animation == "p_shooting" and sprite.frame == 3) or (sprite.animation == "p_continue_shooting" and sprite.frame == 1):
		gun_handler()
	if "flashbang" in sprite.animation and sprite.frame == 4:
		emit_signal("launched_flashbang")
		flashbang_collider.set_deferred("disabled", false)

func _on_effect_frame_changed():
	pass


func gun_handler(param = "shoot"):
	if param == "shoot":
		if gun_bullet_count > 0:
			shoot()
			gun_bullet_count -= 1
			set_bullet_count_label()
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
		set_bullet_count_label()
		
		if param == "shotgun":
			pass

func shoot():
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
	instantiated_bullet.bullet_force = gun_force
	instantiated_bullet.knockback_flag = gun_knockback_flag
	instantiated_bullet.gun_stun_time = gun_stun_time
	get_parent().connect_player_projectile(instantiated_bullet)
	instantiated_bullet.reparent(get_parent())

func set_bullet_count_label():
	remaining_bullets_label.text = "x" + str(gun_bullet_count)


#  -- set_idle mi permette di resettare il player allo stato di idle --  #
func _on_set_idle():
	axis = Vector2.ZERO
	
	atk_state = Atk_States.IDLE
	
	sprite.z_index = 0
	
	sprite.play(gun_prefix+"idle")
	
	self.set_collision_layer_value(1, true)
	self.set_collision_layer_value(2, false)
	
	self.set_collision_mask_value(1, true)
	self.set_collision_mask_value(2, false)
	
	can_move = true
	atk_anim_finished = true
	reaction_timer.stop()

'  -- quando finisce l\'effetto della skill allora disattivo l\'area e setto ad idle --  '
func _on_effect_animation_finished():
	pass

func _on_shooting_delay_time_timeout():
	atk_anim_finished = true
	reaction_timer.start()

func _on_reaction_time_timeout() -> void:
	emit_signal("set_idle")

func _on_flashbang_area_body_entered(body: Node2D) -> void:
	if body != self:
		emit_signal("is_in_atk_range", true, body)
		emit_signal("take_dmg", 0, 0, 3, 0, 0)
		emit_signal("inflict_knockback", 0.2, 600, self)


func _on_flashbang_area_body_exited(body: Node2D) -> void:
	emit_signal("is_in_atk_range", false, body)



' -- DIGEST SEGNALI NEMICI -- '
func _on_enemy_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc):
	var dmg_crit = get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc)
	var dmg = dmg_crit[0]
	show_hitmarker("-" + str(dmg), dmg_crit[1])
	current_vit -= dmg
	emit_signal("set_health_bar", current_vit)
	if stun_sec > 0:
		shooting_delay_timer.stop()
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
