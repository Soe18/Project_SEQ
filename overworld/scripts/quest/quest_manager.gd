extends Node

var quests : Dictionary = {
	1 : preload("res://overworld/resources/a_to_b.tres"),
}

func _ready():
	print(quests[1].title)
	print(quests[1].description)
	#quests[1].display_quest()
	if quests[1].status == QuestStatus.of_type.available:
		print("Puoi fare la missione!")
	else:
		print("Missione bloccata")
