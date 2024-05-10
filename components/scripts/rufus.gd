extends CharacterBody2D

var char_name = "Rufus"

enum Moving_States {IDLE, RUNNING}
enum Move_Keys {UP, DOWN, LEFT, RIGHT}

enum Atk_States {IDLE, BASE_ATK, SK1, SK2, EVA, ULT}

signal is_in_atk_range(is_in, body)
signal take_dmg(atk_state, dmg, sec_stun)
signal set_idle()

var cooldown_state = {"sk1":false, "sk2":false, "eva":false, "ult":false}

const OK_MULTIPLYER = 350.0
const ACCELERATION_INCREASE = 10.0
const MAX_ACCELERATION = 10000.0
const MAX_HEALTH = 100

var health = 100

var initial_y_position = 0

var atk_state = Atk_States.IDLE

var acceleration_value = 0.0
var move_state = Moving_States.IDLE
var move_horizontal = null
var move_vertical = null
var can_move = true

var is_evading = false

var atk_anim_finished = true

var is_moving_ult = false
var ult_moving_mod

@onready var sprite = $Sprite2D

@onready var bs_atk_area = $Basic_atk_Area
@onready var bs_atk_collider = $Basic_atk_Area/Atk_collider

@onready var skill1_area = $Skill_1_area
@onready var skill1_collider = $Skill_1_area/Skill_collider
@onready var skill1_effect = $Skill_1_area/Effect

@onready var eva_collider = $Eva_area/Eva_collider

@onready var skill2_area = $Skill2_area
@onready var skill2_collider = $Skill2_area/Skill_collider
@onready var skill2_effect = $Skill2_area/Effect

@onready var ult_area = $Ult_area
@onready var ult_collider = $Ult_area/Ult_collider
@onready var ult_effect = $Ult_area/Effect

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
	health = MAX_HEALTH
	$HealthBar.max_value = MAX_HEALTH
	set_health_bar()

func _physics_process(_delta):
	if can_move:
		move()
	if $Stun.is_stopped():
		base_atk()
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

func move():
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
		
	if move_horizontal == Move_Keys.LEFT:
		velocity.x = -OK_MULTIPLYER
		sprite.flip_h = true
		bs_atk_collider.position.x = -89.75
		skill1_area.rotation_degrees = 180
		skill1_effect.flip_h = true
		skill1_effect.rotation_degrees = 180
		sprite.play("Running")
	elif move_horizontal == Move_Keys.RIGHT:
		velocity.x = +OK_MULTIPLYER
		sprite.flip_h = false
		bs_atk_collider.position.x = 4.25
		skill1_area.rotation_degrees = 0
		skill1_effect.flip_h = false
		skill1_effect.rotation_degrees = 0
		sprite.play("Running")
	
	if move_vertical != null and move_horizontal != null:
		# Teoricamente equivalente a fare il vettore serialized
		velocity.x = velocity.x/sqrt(2)
		velocity.y = velocity.y/sqrt(2)
	
	# Finalmente, muoviamo il player
	move_and_slide()

'METODO CHE GESTISCE TUTTE LE ABILITA\' DEL PLAYER
	ad ogni if si controlla l\'azione possibile, per l\'attacco di base si trovano
	dei controlli aggiuntivi in base alla combo:
	si controlla come prima cosa se l\'input è stato premuto, se l\'animazione è diversa da idle o running (ovvero o è fermo
	o si sta spostando) oppure il numero di combo che sta facendo ed infine se non è in cooldown'

func base_atk():
	if Input.is_action_just_pressed("base_atk") and (sprite.animation == "idle" or sprite.animation == "Running") and atk_anim_finished:
		can_move = false
		bs_atk_area.process_mode = Node.PROCESS_MODE_INHERIT
		bs_atk_collider.disabled = false
		atk_anim_finished = false
		atk_state = Atk_States.BASE_ATK
		sprite.play("base atk1")
		move_horizontal = null
		move_vertical = null
	
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
		can_move = false
		atk_state = Atk_States.SK1
		skill1_area.process_mode = Node.PROCESS_MODE_INHERIT
		skill1_collider.disabled = false
		sprite.play("skill1")
		skill1_effect.play("effect")
		move_horizontal = null
		move_vertical = null
	
	elif Input.is_action_just_pressed("evade") and (sprite.animation == "idle" or sprite.animation == "Running") and !cooldown_state["eva"]:
		$Eva_cooldown.start()
		cooldown_state["eva"] = true
		can_move = false
		atk_state = Atk_States.EVA
		$Eva_time.start()
		sprite.play("Eva")
		eva_collider.disabled = false
		is_evading = true
	
	elif Input.is_action_just_pressed("skill2") and (sprite.animation == "idle" or sprite.animation == "Running") and !cooldown_state["sk2"]:
		can_move = false
		atk_state = Atk_States.SK2
		sprite.play("skill2")
		skill2_effect.play("effect")
		skill2_area.process_mode = Node.PROCESS_MODE_INHERIT
		skill2_collider.disabled = false
		move_horizontal = null
		move_vertical = null

	elif Input.is_action_just_pressed("ult") and (sprite.animation == "idle" or sprite.animation == "Running") and !cooldown_state["ult"]:
		can_move = false
		atk_state = Atk_States.ULT
		sprite.play("charging_ult")
		move_horizontal = null
		move_vertical = null
		ult_moving_mod = -9

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
		emit_signal("take_dmg", atk_state, 2, 2.1)

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

func _on_skill_2_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

func _on_ult_area_body_entered(body):
	if body != self:
		emit_signal("is_in_atk_range", true, body)
		emit_signal("take_dmg", atk_state, 200, 6)

func _on_ult_area_body_exited(body):
	if body != self:
		emit_signal("is_in_atk_range", false, body)

# ----------------- AREA2D FINE ----------------- #




func _on_sprite_2d_animation_finished():
	if atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk1":
		emit_signal("take_dmg", atk_state, 9, 0.4)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk2":
		emit_signal("take_dmg", atk_state, 10, 0.4)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk3":
		emit_signal("take_dmg", atk_state, 10, 0.4)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk4":
		emit_signal("take_dmg", atk_state, 11, 0.5)
		atk_anim_finished = true
		$Combo_time.start()

	elif atk_state == Atk_States.BASE_ATK and sprite.animation == "base atk5":
		emit_signal("set_idle")

	elif atk_state == Atk_States.ULT and sprite.animation == "charging_ult":
		sprite.play("ult_animation")

	elif atk_state == Atk_States.ULT and sprite.animation == "ult_animation":
		sprite.pause()
		ult_area.process_mode = Node.PROCESS_MODE_INHERIT
		ult_collider.disabled = false
		ult_effect.play("effect")

func _on_sprite_2d_frame_changed():
	if sprite.frame == 4 and sprite.animation == "base atk5":
		emit_signal("take_dmg", atk_state, 12, 0.5)
	
	if sprite.frame == 7 and sprite.animation == "ult_animation":
		sprite.pause()
		is_moving_ult = true
		initial_y_position = sprite.position.y

func _on_effect_frame_changed():
	if skill1_effect.frame%2 == 0 and atk_state == Atk_States.SK1:
		emit_signal("take_dmg", atk_state, 30, 0.6)
	
	elif skill2_effect.frame == 2 and atk_state == Atk_States.SK2:
		emit_signal("take_dmg", atk_state, 16, 1.4)

func ult_moving():
	$Player_collider.disabled = true
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

'  -- set_idle mi permette di resettare il player allo stato di idle --  '
func _on_set_idle():
	move_horizontal = null
	move_vertical = null
	atk_state = Atk_States.IDLE
	sprite.play("idle")
	bs_atk_area.process_mode = Node.PROCESS_MODE_DISABLED
	bs_atk_collider.disabled = true
	eva_collider.disabled = true
	skill1_effect.play("idle")
	skill1_area.process_mode = Node.PROCESS_MODE_DISABLED
	skill1_collider.disabled = true
	skill2_effect.play("idle")
	skill2_area.process_mode = Node.PROCESS_MODE_DISABLED
	skill2_collider.disabled = true
	ult_effect.play("idle")
	ult_area.process_mode = Node.PROCESS_MODE_DISABLED
	ult_collider.disabled = true
	$Player_collider.disabled = false
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
		$Skill1_cooldown.start()
		cooldown_state["sk1"] = true
		emit_signal("set_idle")

	elif atk_state == Atk_States.SK2:
		$Skill2_cooldown.start()
		cooldown_state["sk2"] = true
		emit_signal("set_idle")

	elif atk_state == Atk_States.ULT:
		$Ult_cooldown.start()
		cooldown_state["ult"] = true
		$Ult_area/Ult_time.start()

func _on_eva_time_timeout():
	emit_signal("set_idle")

func _on_comb_time_timeout():
	emit_signal("set_idle")

'METODO CHE GESTISCE L\'EVASIONE IN BASE ALLA DIREZIONE PREMUTA'
func evade():
	$Player_collider.disabled = true
	if move_vertical == Move_Keys.UP:
		velocity.y += -50
	elif move_vertical == Move_Keys.DOWN:
		velocity.y += 50
	if move_horizontal == Move_Keys.LEFT:
		velocity.x += -50
	elif move_horizontal == Move_Keys.RIGHT:
		velocity.x += 50
	elif (move_vertical == null and move_horizontal == null) and sprite.flip_h == false:
		velocity.x += 50
	elif (move_vertical == null and move_horizontal == null) and sprite.flip_h == true:
		velocity.x += -50
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

' -- DIGEST SEGNALI NEMICI -- '
func _on_enemy_take_dmg(dmg, sec):
	health -= dmg
	set_health_bar()
	#print("take dmg: "+str(dmg))
	emit_signal("set_idle")
	sprite.play("damaged")
	can_move = false
	$Stun.wait_time = sec
	$Stun.start()

func set_health_bar():
	$HealthBar.value = health
	if health <= 0:
		queue_free()

func _on_stun_timeout():
	emit_signal("set_idle")
