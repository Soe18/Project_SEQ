extends Node

var quests : Dictionary = {
	
}

func _ready():
	var dir = DirAccess.open("res://overworld/resources/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var count = 0
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				quests[file_name.replace(".tres", "")] = load("res://overworld/resources/" + file_name)
			file_name = dir.get_next()
