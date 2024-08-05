extends CharacterBody2D

var char_name = "Nathan"

@export var default_vit : int = 270
var current_vit = default_vit
@export var default_str : int = 138
var current_str = default_str
@export var default_tem : int = 162
var current_tem = default_tem
@export var default_des : int = 145
var current_des = default_des
@export var default_pbc : int = 30
var current_pbc = default_pbc
@export var default_efc : float = 1.5
var current_efc = default_efc

enum Moving_States {IDLE, RUNNING}
enum Move_Keys {UP, DOWN, LEFT, RIGHT}

enum Atk_States {IDLE, BASE_ATK, SK1, SK2, EVA, ULT}

signal is_in_atk_range(is_in, body)
signal take_dmg(atk_state, dmg, sec_stun, pbc, efc)
signal set_idle()
signal grab(has_grabbed, is_flipped)
signal set_health_bar(current_vit)
signal shake_camera(is_shacking)
signal get_healed(amount)

var cooldown_state = {"sk1":false, "sk2":false, "eva":false, "ult":false}

const OK_MULTIPLYER = 390.0
var current_multiplyer = OK_MULTIPLYER
const ACCELERATION = 10000.0
const FRICTION = 7000.0

@onready var axis = Vector2.ZERO

var atk_state = Atk_States.IDLE

var acceleration_value = 0.0
var move_state = Moving_States.IDLE

var can_move = true

var is_evading = false

var sk1_activated = false

var atk_anim_finished = true

@onready var sprite = $Sprite2D

@onready var player_collider = $Player_collider

@onready var bs_atk_collider = $Basic_atk_Area/Atk_collider

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

@onready var stun_timer = $Stun

@onready var status_sprite = $Status_alert_sprite

'METODO CHE VIENE CHIAMATO AD OGNI FRAME
	se il player si può muovere
		esegue il metodo per muoversi
	esegue il metodo che gestisce gli attacchi
	se sta eseguendo un\'evasione
		esegue il metodo di evasione
	se ha attivato la skill1
		esegue il metodo di movimento della skill1'

@warning_ignore("unused_parameter") # c'è sta cosa altrimenti mi da fastidio "l'errore"

func _ready():
	emit_signal("set_health_bar", current_vit)

func _physics_process(delta):
	if can_move:
		move(delta)
	elif sk1_activated:
		skill1_moving(sprite.flip_h)
	elif is_evading:
		evade()
	base_atk()

'METODO CHE GESTISCE IL MOVIMENTO DEL PLAYER
	pulisce il vettore della velocità
	# Last Win #
	quando si gira il player a destra o sinistra si deve girare anche le aree, 
	altrimenti ci sarebbe il personaggio flippato ma l\'area rimane dall\'altra
	parte'

'func move():
	# Reset velocity
	velocity = Vector2(0, 0)
	#acceleration_manager()
	
	" Implemento Last Win "
	# Controllo se vecchi input sono stati rilasciati
	if Input.is_action_just_released("move_up"):
		sprite.play("idle")
		# Se è stato rilasciato, metto altro input, se esiste ancora
		if Input.is_action_pressed("move_down"):
			move_vertical = Move_Keys.DOWN
		# Se non esiste più, nessun tasto premuto, fermare personaggio
		else:
			move_vertical = null
	if Input.is_action_just_released("move_down"):
		sprite.play("idle")
		if Input.is_action_pressed("move_up"):
			move_vertical = Move_Keys.UP
		else:
			move_vertical = null
	if Input.is_action_just_released("move_left"):
		sprite.play("idle")
		if Input.is_action_pressed("move_right"):
			move_horizontal = Move_Keys.RIGHT
		else:
			move_horizontal = null
	if Input.is_action_just_released("move_right"):
		sprite.play("idle")
		if Input.is_action_pressed("move_left"):
			move_horizontal = Move_Keys.LEFT
		else:
			move_horizontal = null
	
	# Controllo se vengono inseriti nuovi input
	if Input.is_action_just_pressed("move_up"):
		move_vertical = Move_Keys.UP
	if Input.is_action_just_pressed("move_down"):
		move_vertical = Move_Keys.DOWN
	if Input.is_action_just_pressed("move_left"):
		move_horizontal = Move_Keys.LEFT
	if Input.is_action_just_pressed("move_right"):
		move_horizontal = Move_Keys.RIGHT
	
	" Muovo giocatore "
	if move_vertical == Move_Keys.UP:
		velocity.y = -OK_MULTIPLYER
		sprite.play("Running")
		
	elif move_vertical == Move_Keys.DOWN:
		velocity.y = +OK_MULTIPLYER
		sprite.play("Running")
		
	if move_horizontal == Move_Keys.LEFT: # valori da flippare il player
		velocity.x = -OK_MULTIPLYER
		flip_sprite(true)
		sprite.play("Running")
	elif move_horizontal == Move_Keys.RIGHT:
		velocity.x = +OK_MULTIPLYER
		flip_sprite(false)
		sprite.play("Running")
	
	if move_vertical != null and move_horizontal != null:
		# Teoricamente equivalente a fare il vettore serialized
		velocity.x = velocity.x/sqrt(2)
		velocity.y = velocity.y/sqrt(2)
	
	# Finalmente, muoviamo il player
	move_and_slide()'

func move(delta):
	axis = get_input_axis()
	if axis == Vector2.ZERO:
		apply_friction(FRICTION * delta)
	else:
		sprite.play("Running")
		apply_movement(axis * ACCELERATION * delta)
		if axis.x < 0:
			flip_sprite(true)
		else:
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
	velocity = velocity.limit_length(current_multiplyer)

'METODO CHE GESTISCE TUTTE LE ABILITA\' DEL PLAYER
	ad ogni if si controlla l\'azione possibile, per l\'attacco di base si trovano
	dei controlli aggiuntivi in base alla combo:
	si controlla come prima cosa se l\'input è stato premuto, se l\'animazione è diversa da idle o running (ovvero o è fermo
	o si sta spostando) oppure il numero di combo che sta facendo ed infine se non è in cooldown'

func base_atk():
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
	
	elif Input.is_action_just_pressed("skill1") and (sprite.animation == "idle" or sprite.animation == "Running") and !cooldown_state["sk1"]:
		skill1_cooldown.start()
		can_move = false
		sk1_activated = true
		atk_state = Atk_States.SK1
		skill1_collider.set_deferred("disabled", false)
		sprite.play("skill1")
		skill1_duration_time.wait_time = 1.696
		skill1_duration_time.start()
		axis = Vector2.ZERO
	
	elif Input.is_action_just_pressed("evade") and (sprite.animation == "idle" or sprite.animation == "Running") and !cooldown_state["eva"]:
		eva_cooldown.start()
		cooldown_state["eva"] = true
		can_move = false
		velocity = Vector2(0, 0)
		atk_state = Atk_States.EVA
		$Eva_time.start()
		sprite.play("Eva")
		is_evading = true
	
	elif Input.is_action_just_pressed("skill2") and (sprite.animation == "idle" or sprite.animation == "Running") and !cooldown_state["sk2"]:
		skill2_cooldown.start()
		can_move = false
		atk_state = Atk_States.SK2
		sprite.play("skill2")
		skill2_collider.set_deferred("disabled", false)
		$Grab_time.start()
		axis = Vector2.ZERO

	elif Input.is_action_just_pressed("ult") and (sprite.animation == "idle" or sprite.animation == "Running") and !cooldown_state["ult"]:
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
		skill1_duration_time.wait_time = 0.4
		skill1_duration_time.start()
		emit_signal("is_in_atk_range", false, body)

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
		bs_atk_collider.position.x = -121
		skill2_collider.position.x = -90
	else:
		sprite.flip_h = false
		bs_atk_collider.position.x = 43.5
		skill2_collider.position.x = 90

func _on_sprite_2d_animation_finished():
	if atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk1":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 9, 0.5, current_pbc, current_efc)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk2":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 10, 0.5, current_pbc, current_efc)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk3":
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 10, 0.5, current_pbc, current_efc)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk4":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 11, 0.5, current_pbc, current_efc)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk5":
		bs_atk_collider.set_deferred("disabled", true)
		bs_atk_collider.set_deferred("disabled", false)
		emit_signal("take_dmg", current_str, 12, 0.5, current_pbc, current_efc)
		emit_signal("set_idle")
	
	elif atk_state == Atk_States.EVA:
		eva_collider.set_deferred("disabled", false)
		emit_signal("set_idle")

	elif atk_state == Atk_States.SK1:
		emit_signal("set_idle")

	elif atk_state == Atk_States.SK2:
		emit_signal("grab", true, sprite.flip_h)
		cooldown_state["sk2"] = true
		emit_signal("set_idle")

	elif atk_state == Atk_States.ULT and sprite.animation == "charging_ult":
		sprite.pause()
		emit_signal("shake_camera", true)
		$Ult_area/Ult_time.start()
		ult_collider.set_deferred("disabled", false)
		ult_effect.play("effect")

func _on_sprite_2d_frame_changed():
	if sprite.animation == "Eva" and sprite.frame == 3:
		sprite.pause()

'  -- set_idle mi permette di resettare il player allo stato di idle --  '
func _on_set_idle():
	axis = Vector2.ZERO
	
	atk_state = Atk_States.IDLE
	
	sprite.play("idle")
	ult_effect.play("idle")
	
	skill1_duration_time.stop()
	
	bs_atk_collider.set_deferred("disabled", true)
	eva_collider.set_deferred("disabled", true)
	skill1_collider.set_deferred("disabled", true)
	skill2_collider.set_deferred("disabled", true)
	ult_collider.set_deferred("disabled", true)
	$Player_collider.set_deferred("disabled", false)
	
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
	cooldown_state["ult"] = true
	$Ult_area/Ult_time.stop()
	emit_signal("set_idle")

func _on_combo_time_timeout():
	emit_signal("set_idle")

func _on_eva_time_timeout():
	sprite.play()
	eva_collider.set_deferred("disabled", false)

func _on_grab_time_timeout():
	emit_signal("grab", false, sprite.flip_h)

func _on_sk_1_time_timeout():
	emit_signal("set_idle")
	cooldown_state["sk1"] = true
	emit_signal("set_idle")

# --------------------- TIMER FINE --------------------- #




'METODO DELL\'EVASIONE DEL PLAYER'
func evade():
	self.set_collision_layer_value(1, false)
	self.set_collision_layer_value(2, true)
	
	self.set_collision_mask_value(1, false)
	self.set_collision_mask_value(2, true)
	if axis.x == 0 and axis.y < 0:
		velocity.y += -15
	elif axis.x == 0 and axis.y > 0:
		velocity.y += 15
	if axis.x < 0 and axis.y == 0:
		velocity.x += -15
	elif axis.x > 0 and axis.y == 0:
		velocity.x += 15
	if axis.x > 0 and axis.y < 0:
		velocity.x += 15
		velocity.y += -15
	elif axis.x > 0 and axis.y > 0:
		velocity.x += 15
		velocity.y += 15
	elif axis.x < 0 and axis.y > 0:
		velocity.x += -15
		velocity.y += 15
	elif axis.x < 0 and axis.y < 0:
		velocity.x += -15
		velocity.y += -15
	move_and_slide()

'METODO CHE SPOSTA IL PLAYER DURANTE LA SKILL1'
func skill1_moving(is_flipped):
	if is_flipped:
		velocity.x += -20
	else:
		velocity.x += 20
	move_and_slide()

'  -- GESTIONE COOLDOWN --  '
func _on_skill_1_cooldown_timeout():
	cooldown_state["sk1"] = false

func _on_skill_2_cooldown_timeout():
	cooldown_state["sk2"] = false

func _on_eva_cooldown_timeout():
	cooldown_state["eva"] = false

func _on_ult_cooldown_timeout():
	cooldown_state["ult"] = false

' - DIGEST DEL SEGNALE take_dmg DEI NEMICI - '

func _on_enemy_take_dmg(atk_str, skill_str, stun_sec, atk_pbc, atk_efc):
	current_vit -= get_parent().calculate_dmg(atk_str, skill_str, self.current_tem, atk_pbc, atk_efc)
	emit_signal("set_health_bar", current_vit)
	#print("take dmg: "+str(dmg))
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

func _on_change_stats(stat, amount, time_duration):
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
			new_timer.start()

func _on_status_alert_sprite_animation_finished():
	status_sprite.play("idle")
