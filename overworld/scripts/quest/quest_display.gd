extends VBoxContainer

@onready var preloaded_quest_label = preload("res://overworld/scenes/quest_label.tscn")

func _ready():
	dump_quest_data()

func dump_quest_data():
	# I don't like this code, but can't do much :/
	for i in range(0, get_child_count()):
		get_child(i).queue_free()
	print_debug("dump started")
	var quest_title : String
	var quest_description : String
	var quest_status : int
	var quest_display_node : Node
	for quest_id in QuestManager.quests.keys():
		print_debug(QuestManager.quests[quest_id].title)
		quest_title = QuestManager.quests[quest_id].title
		quest_description = QuestManager.quests[quest_id].description
		quest_status = QuestManager.quests[quest_id].status
		quest_display_node = preloaded_quest_label.instantiate()
		add_child(quest_display_node)
		quest_display_node.set_labels(quest_id, quest_title, quest_description, quest_status)
		
