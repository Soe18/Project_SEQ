extends CanvasLayer

enum GAME_STATUSES{
	dungeon,
	overworld,
	unopenable
}

@onready var first_menu = %FirstMenu
@onready var quest_menu = %QuestMenu
@onready var continue_button = %ContinueButton
@onready var re_open_menu_delay = %ReOpenMenuDelay
@onready var all_quest_filter = %AllQuestFilter
@onready var quest_container = %QuestContainer
@onready var pause_ost = %Pause_ost_player

var is_delay_finished : bool = true
var game_status : GAME_STATUSES = GAME_STATUSES.unopenable

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _input(event):
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and first_menu.visible:
		resume_game()
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and quest_menu.visible:
		quest_menu.visible = false
		first_menu.visible = true
		continue_button.grab_focus()

func pause_game():
	if is_delay_finished:
		pause_ost.play()
		is_delay_finished = false
		get_tree().paused = true
		visible = true
		continue_button.grab_focus()

func resume_game():
	pause_ost.stop()
	visible = false
	get_tree().paused = false
	re_open_menu_delay.start()

func _on_continue_button_pressed():
	resume_game()

func _on_quit_button_pressed():
	get_tree().quit()

func _on_quest_button_pressed():
	quest_container.dump_quest_data()
	first_menu.visible = false
	quest_menu.visible = true
	all_quest_filter.grab_focus()

func _on_re_open_menu_delay_timeout():
	is_delay_finished = true

func _on_escape_button_pressed():
	resume_game()
	get_tree().get_first_node_in_group("gm").load_map()
