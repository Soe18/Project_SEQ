extends Node2D

var markers = []
var active_markers = []
var possible_enemies = ["res://scenes/characters/zombie.tscn","res://scenes/characters/skeleton.tscn", "res://scenes/characters/giant.tscn"]
@onready var time_between_rounds = $Round_cooldown

signal round_changed()
signal heal_between_rounds(amount)

var fighting

func _ready():
	for i in get_children():
		if "Spawnpoint" in i.name:
			markers.append(i)

'METODO CHE VIENE EVOCATO AD OGNI FRAME, CONTROLLA SE I NEMICI SONO ANCORA PRESENTI IN GAME'
func _process(delta):
	fighting = false
	for i in get_children():
		if "Enemy" in i.name:
			fighting = true
	
	if not fighting and time_between_rounds.is_stopped():
		time_between_rounds.start()

func _on_round_cooldown_timeout():
	emit_signal("heal_between_rounds", 50)
	activate_markers()
	fighting = true
	emit_signal("round_changed")

func activate_markers():
	active_markers.clear()
	
	var round_count = get_parent().round_gui.round_count+1
	
	var min_count = ceil(round_count/2)
	
	if min_count < 1:
		min_count = 1
	elif min_count > markers.size():
		min_count = markers.size()
	
	if min_count == 1 and round_count > 2:
		min_count = 2
	
	var max_count = round_count
	if max_count < 1:
		max_count = 1
	elif max_count > markers.size():
		max_count = markers.size()
	
	var enemy_count = randi_range(min_count, max_count)
	print("round_count = " + str(round_count))
	print("min_count = " + str(min_count))
	print("max_count = " + str(max_count))
	print("enemy_count = " + str(enemy_count))
	
	for i in enemy_count:
		var out = false
		while not out:
			var marker = markers.pick_random()
			if not marker in active_markers:
				active_markers.append(marker)
				out = true
	
	for i in active_markers:
		var out = false
		var enemy_scene
		while not out:
			enemy_scene = possible_enemies.pick_random()
			if round_count < 4:
				if enemy_scene == possible_enemies[2]:
					out = false
				else:
					out = true
			else:
				out = true
		
		add_child(load(enemy_scene).instantiate(),true)
		#add_child(load(possible_enemies[2]).instantiate(),true)
		get_child(get_child_count()-1).position = i.position


