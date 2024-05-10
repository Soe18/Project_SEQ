extends Node2D

var markers = []
var active_markers = []
var possible_enemies = ["res://scenes/characters/zombie.tscn","res://scenes/characters/skeleton.tscn"]

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in get_children():
		markers.append(i)
	
	for i in range(randi_range(1,markers.size())):
		var out = false
		while not out:
			var marker = markers.pick_random()
			if not marker in active_markers:
				active_markers.append(marker)
				out = true
	
	for i in active_markers:
		var enemy_chooser = randi_range(0,possible_enemies.size()-1)
		var enemy_scene = load(possible_enemies[enemy_chooser])
		add_child(enemy_scene.instantiate(),true)
		get_child(get_child_count()-1).position = i.position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
