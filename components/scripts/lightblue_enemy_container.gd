extends Node2D

var markers = []
var active_markers = []
var possible_enemies = ["res://scenes/enemies/zombie.tscn","res://scenes/enemies/skeleton.tscn","res://scenes/enemies/giant.tscn"]
var boss_scene = "res://scenes/enemies/lich.tscn"

signal round_changed()
signal heal_between_rounds(amount)
signal boss_defeted()
signal connect_boss_with_GUI(boss)

var fighting
var boss_is_defeted = false
var boss_spawned = false
var portal_spawned = false

@onready var time_between_rounds = $Round_cooldown
@onready var boss_spawner = $Boss_Spawner

func _ready():
	for i in get_children():
		if "Spawnpoint" in i.name:
			markers.append(i)

'METODO CHE VIENE EVOCATO AD OGNI FRAME, CONTROLLA SE I NEMICI SONO ANCORA PRESENTI IN GAME'
func _process(_delta):
	fighting = false
	var boss_present = false
	for i in get_children():
		if "Enemy" in i.name:
			fighting = true
		if "Enemy" in i.name and is_boss_round():
			boss_present = true
	
	if boss_spawned and not boss_present:
		boss_is_defeted = true
	
	if not boss_is_defeted:
		if not fighting and time_between_rounds.is_stopped():
			time_between_rounds.start()
	else:
		if not portal_spawned:
			emit_signal("boss_defeted")
			portal_spawned = true

func _on_round_cooldown_timeout():
	emit_signal("round_changed")
	emit_signal("heal_between_rounds", 50)
	fighting = true
	if is_boss_round() and not boss_is_defeted:
		spawn_boss()
		boss_spawned = true
	else:
		activate_markers()

func activate_markers():
	active_markers.clear()
	
	var round_count = get_parent().round_gui.round_count
	
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
	#enemy_count = markers.size()
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
		#add_child(load(possible_enemies[0]).instantiate(),true)
		get_child(get_child_count()-1).position = i.position

func spawn_boss():
	add_child(load(boss_scene).instantiate(),true)
	var active_boss = get_child(get_child_count()-1)
	active_boss.position = boss_spawner.position
	emit_signal("connect_boss_with_GUI", active_boss)

func is_boss_round():
	var round_count = get_parent().round_gui.round_count
	if round_count > 0 and round_count % 10 == 0:
		return true
	else:
		return false
