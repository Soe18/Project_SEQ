extends CharacterBody2D

var char_name = "Stencil"

enum Moving_States {IDLE, RUNNING}
enum Move_Keys {UP, DOWN, LEFT, RIGHT}

enum Atk_States {IDLE, BASE_ATK, SK1, SK2, EVA, ULT}

signal is_in_atk_range(is_in, body)
signal take_dmg(atk_state, dmg, sec_stun)
signal set_idle()
signal send_sk2(flag)

var cooldown_state = {"sk1":false, "sk2":false, "eva":false, "ult":false}

const SPEED = 300.0
const OK_MULTIPLYER = 350.0
const ACCELERATION_INCREASE = 10.0
const MAX_ACCELERATION = 10000.0

var atk_state = Atk_States.IDLE
var acceleration_value = 0.0
var move_state = Moving_States.IDLE
var move_horizontal = null
var move_vertical = null
var can_move = true
var is_evading = false

@onready var sprite = $Sprite2D

func _physics_process(delta):
	if can_move:
		move()
	if is_evading:
		evade()
	base_atk()

func move():
	" Movimento
	Per la gestione del movimento, ho deciso di gestirlo in un modo ben specifico:
	Prima di tutto userò i vari Input.is_action_pressed cambiando soltanto la
	velocity di uno degli elementi interessati, garantendo il movimento in diagonale.
	Importante! Accorgersi se il movimento è in diagonale per rallentare il
	giocatore, per non renderlo troppo veloce e quindi OP.
	Inoltre, applicare la metodologia di input: Last Win.
	Ciò si intende che premendo prima UP, e poi DOWN, MANTENENDO PREMUTO UP,
	avrò l'input di DOWN, essendo l'ultimo che è stato premuto "
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
		sprite.play("Running")
		sprite.set_flip_h(true)
		$Basic_atk_Area.position.x = -70
		$Skill_1_area.rotation_degrees = 180
		$Ult_area.rotation_degrees = 180
	elif move_horizontal == Move_Keys.RIGHT:
		velocity.x = +OK_MULTIPLYER
		sprite.set_flip_h(false)
		$Basic_atk_Area.position.x = 40
		$Skill_1_area.rotation = 0
		$Ult_area.rotation = 0
		sprite.play("Running")
	
	if move_vertical != null and move_horizontal != null:
		# Teoricamente equivalente a fare il vettore serialized
		velocity.x = velocity.x/sqrt(2)
		velocity.y = velocity.y/sqrt(2)
	
	# Finalmente, muoviamo il player
	move_and_slide()

#func acceleration_manager():

func base_atk():
	if Input.is_action_just_pressed("base_atk") and (sprite.animation=="idle" or sprite.animation == "Running"):
		atk_state = Atk_States.BASE_ATK
		sprite.play("base attack")
		move_horizontal = null
		move_vertical = null
	
	elif Input.is_action_just_pressed("skill1") and (sprite.animation=="idle" or sprite.animation == "Running") and !cooldown_state["sk1"]:
		can_move = false
		atk_state = Atk_States.SK1
		$Skill_1_area.process_mode = Node.PROCESS_MODE_INHERIT
		sprite.play("skill1")
		move_horizontal = null
		move_vertical = null
	
	elif Input.is_action_just_pressed("evade") and (sprite.animation=="idle" or sprite.animation == "Running") and !cooldown_state["eva"]:
		if atk_state != Atk_States.EVA:
			$Eva_cooldown.start()
			cooldown_state["eva"] = true
			can_move = false
			atk_state = Atk_States.EVA
			$Eva_time.start()
			sprite.play("Eva")
			is_evading = true
	
	elif Input.is_action_just_pressed("skill2") and (sprite.animation=="idle" or sprite.animation == "Running") and !cooldown_state["sk2"]:
		can_move = false
		atk_state = Atk_States.SK2
		sprite.play("skill2")
		move_horizontal = null
		move_vertical = null
		emit_signal("send_sk2", sprite.flip_h)
	
	elif Input.is_action_just_pressed("ult") and (sprite.animation=="idle" or sprite.animation == "Running") and !cooldown_state["ult"]:
		can_move = false
		atk_state = Atk_States.ULT
		$Ult_area.process_mode = Node.PROCESS_MODE_INHERIT
		sprite.play("charging_ult")
		move_horizontal = null
		move_vertical = null
		$Ult_area/Charge_time.start()
	
	elif sprite.animation!="idle" or sprite.animation!="Running":
		pass

func _on_basic_atk_area_body_entered(body):
	emit_signal("is_in_atk_range", true, body)

func _on_basic_atk_area_body_exited(body):
	emit_signal("is_in_atk_range", false, body)

func _on_skill_1_area_body_entered(body):
	emit_signal("is_in_atk_range", true, body)
	emit_signal("take_dmg", atk_state, 55, 1.2)

func _on_skill_1_area_body_exited(body):
	emit_signal("is_in_atk_range", false, body)

func _on_ult_area_body_entered(body):
	emit_signal("is_in_atk_range", true, body)
	emit_signal("take_dmg", atk_state, 200, 6)

func _on_ult_area_body_exited(body):
	emit_signal("is_in_atk_range", false, body)

func _on_sprite_2d_animation_finished():
	if atk_state == Atk_States.BASE_ATK:
		emit_signal("take_dmg", atk_state, 9, 0.2)
		emit_signal("set_idle")

	elif atk_state == Atk_States.SK1:
		sprite.pause()
		$Skill_1_area.process_mode = Node.PROCESS_MODE_INHERIT
		$Skill_1_area/Skill_collider.disabled = false
		$Skill_1_area/Effect.play("effect")

	elif atk_state == Atk_States.SK2:
		$Skill2_animation_time.start()
		get_parent().get_node("Skill2_child").process_mode = Node.PROCESS_MODE_INHERIT

	elif atk_state == Atk_States.ULT:
		sprite.pause()
		$Ult_area.process_mode = Node.PROCESS_MODE_INHERIT
		$Ult_area/Ult_collider.disabled = false
		$Ult_area/Effect.play("effect")

'  -- set_idle mi permette di resettare il player allo stato di idle --  '
func _on_set_idle():
	move_horizontal = null
	move_vertical = null
	atk_state = Atk_States.IDLE
	sprite.play("idle")
	$Skill_1_area/Effect.play("idle")
	$Ult_area/Effect.play("idle")
	$Player_collider.disabled = false
	can_move = true
	is_evading = false

'  -- quando finisce l\'effetto della skill 1 allora disattivo l\'area e setto ad idle --  '
func _on_effect_animation_finished():
	if atk_state == Atk_States.SK1:
		$Skill1_cooldown.start()
		cooldown_state["sk1"] = true
		$Skill_1_area.process_mode = Node.PROCESS_MODE_DISABLED
		$Skill_1_area/Skill_collider.disabled = true
		emit_signal("set_idle")
	elif atk_state == Atk_States.ULT:
		$Ult_cooldown.start()
		cooldown_state["ult"] = true
		$Ult_area.process_mode = Node.PROCESS_MODE_DISABLED
		$Ult_area/Ult_collider.disabled = true
		emit_signal("set_idle")

func _on_eva_time_timeout():
	emit_signal("set_idle")

func _on_skill_2_animation_time_timeout():
	$Skill2_cooldown.start()
	cooldown_state["sk2"] = true
	get_parent().get_node("Skill2_child").process_mode = Node.PROCESS_MODE_INHERIT
	emit_signal("set_idle")

func _on_charge_time_timeout():
	sprite.play("ult_animation")

func evade():
	$Player_collider.disabled = true
	if move_vertical == Move_Keys.UP:
		velocity.y += -35
	elif move_vertical == Move_Keys.DOWN:
		velocity.y += +35
	if move_horizontal == Move_Keys.LEFT:
		velocity.x += -35
	elif move_horizontal == Move_Keys.RIGHT:
		velocity.x += +35
	elif (move_vertical == null and move_horizontal == null) and sprite.flip_h == false:
		velocity.x += 35
	elif (move_vertical == null and move_horizontal == null) and sprite.flip_h == true:
		velocity.x += -35
	move_and_slide()

func _on_skill_2_child_entered_body(body):
	emit_signal("is_in_atk_range", true, body)
	emit_signal("take_dmg",atk_state, 68, 2)

func _on_skill_2_child_exited_body(body):
	emit_signal("is_in_atk_range", false, body)

'  -- GESTIONE COOLDOWN --  '
func _on_skill_1_cooldown_timeout():
	cooldown_state["sk1"] = false

func _on_skill_2_cooldown_timeout():
	cooldown_state["sk2"] = false

func _on_eva_cooldown_timeout():
	cooldown_state["eva"] = false

func _on_ult_cooldown_timeout():
	cooldown_state["ult"] = false
