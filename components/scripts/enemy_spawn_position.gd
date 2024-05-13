extends Node2D

var markers = []
var active_markers = []
var possible_enemies = ["res://scenes/characters/zombie.tscn","res://scenes/characters/skeleton.tscn"]
@onready var time_between_rounds = $Round_cooldown

var fighting
# Called when the node enters the scene tree for the first time.
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
	activate_markers()
	fighting = true


func activate_markers():
	active_markers.clear()
	for i in randi_range(1,markers.size()-1):
		var out = false
		while not out:
			var marker = markers.pick_random()
			if not marker in active_markers:
				active_markers.append(marker)
				out = true
	
	for i in active_markers:
		add_child(load(possible_enemies.pick_random()).instantiate(),true)
		get_child(get_child_count()-1).position = i.position


