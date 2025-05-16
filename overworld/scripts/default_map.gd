extends Node2D

var selected_character
var player
var player_in_area_to_change_char = false

@onready var canvas_layer = $CanvasLayer
@onready var dungeon_entrance = $Dungeon
@onready var player_spawnpoint = $Marker2D

@onready var ost_player = $Ost_player

@onready var leone_first_dialogue_bubble = $Change_char/MarginContainer
@onready var leone_second_dialogue_bubble = $Change_char/MarginContainer2
@onready var bubble_showing_time = $Change_char/Timer

func _ready():
	Menu.game_status = Menu.GAME_STATUSES.unopenable

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept") and player_in_area_to_change_char:
		if QuestManager.quests["the_bigger_they_are"].status == QuestStatus.of_type.hidden:
			QuestManager.quests["the_bigger_they_are"].display_quest()
			QuestManager.quests["the_bigger_they_are"].start_quest()
			leone_first_dialogue_bubble.visible = true
			bubble_showing_time.start()
		elif QuestManager.quests["the_bigger_they_are"].status == QuestStatus.of_type.reached_goal:
			QuestManager.quests["the_bigger_they_are"].complete_quest()
			leone_second_dialogue_bubble.visible = true
			bubble_showing_time.start()
		else:
			player.sprite.play("idle") # se il player si sta spostando mi pare giusto fermarlo
			change_player_menu()

func _on_gui_select_character(char: String) -> void:
	if selected_character == char: # se il player ha cliccato sullo stesso personaggio istanziato
		player.moving = true
		player.collider.set_deferred("disabled", false)
	else: # se il player ha selezionato un personaggio
		selected_character = char
		var player_scene
		if char == "jack":
			player_scene = load("res://overworld/scenes/players/jack_wander.tscn")
		elif char == "rufus":
			player_scene = load("res://overworld/scenes/players/rufus_wander.tscn")
		
		add_child(player_scene.instantiate(),true)
		var instantiated_node = get_child(get_child_count()-1)
		
		if not player: # se non esiste player vuol dire che devo istanziarlo nel punto di base
			player = instantiated_node
			player.global_position = player_spawnpoint.position
		else: # se esiste vuol dire che devo cambiarlo
			var temp_player : Node = player
			player = instantiated_node
			# metto il player nuovo sulla stessa posizione di quello vecchio
			player.global_position = temp_player.global_position 
			temp_player.queue_free() # libero il vecchio player
		
		player.name = "Player"
		# collego il segnale per entrare nel dungeon con il nuovo nodo
		dungeon_entrance.body_entered.connect(player._on_dungeon_body_entered)
	
	canvas_layer.hide() # nascondo il menu
	Menu.game_status = Menu.GAME_STATUSES.overworld

func change_player_menu():
	canvas_layer.show() # mostro il menu
	Menu.game_status = Menu.GAME_STATUSES.unopenable # blocco il menu altrimenti perdo il focus sul menu di selezione
	player.moving = false # rendo paraplegico il player
	player.collider.set_deferred("disabled", true) # rendo immateriale il player
	canvas_layer.get_child(0).jack_button.grab_focus() # il pulsante di jack prende focus
	

# DIGEST DEI SEGNALI BODY ENTERED/EXITED PER CAMBIARE PERSONAGGIO

func _on_change_char_body_entered(body: Node2D) -> void:
	if body == player:
		player_in_area_to_change_char = true

func _on_change_char_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_area_to_change_char = false

func _on_timer_timeout() -> void:
	leone_first_dialogue_bubble.visible = false
	leone_second_dialogue_bubble.visible = false
