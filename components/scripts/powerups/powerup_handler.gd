extends Node

var player : Node

var active_powerups : Array
var possible_powerups : Array

var pickable_scene = preload("res://scenes/powerup/powerup_pickable.tscn")

signal spawn_pickable(node)

func _ready() -> void:
	var path = "res://components/resources/powerups/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				possible_powerups.append(load(path + file_name))
			file_name = dir.get_next()

func _on_instantiate_pickable():
	add_child(pickable_scene.instantiate())
	var pickable = get_child(-1)
	pickable.handler = self
	pickable.player = player
	pickable.canvas_layer = get_parent().canvas_layer
	for i in range(3):
		var pulled_powerup = possible_powerups.pick_random()
		var pulled_rar = PowerupStats.rar.find_key(randi_range(0, 4))
		
		if active_powerups.has(pulled_powerup):
			var prev_rar = active_powerups[active_powerups.find(pulled_powerup)].max_rarity
			
			if not prev_rar == PowerupStats.rar.legendary:
				pulled_rar = randi_range(prev_rar+1, PowerupStats.rar.legendary)
			else:
				pulled_rar = PowerupStats.rar.legendary
			
			pulled_rar = PowerupStats.rar.find_key(pulled_rar)
		
		pickable.pulled_powerups.append(pulled_powerup)
		pickable.pulled_rarities.append(PowerupStats.rar.get(pulled_rar))
	emit_signal("spawn_pickable", pickable)

func new_powerup(resource : Resource, pulled_rarity : PowerupStats.rar) -> void:
	if not active_powerups.has(resource):
		resource.max_rarity = pulled_rarity
		active_powerups.append(resource)
		activate_powerup(resource)
		
		if resource.custom_handler:
			add_child(load(resource.custom_handler).instantiate())
	else:
		activate_powerup(resource, true)
		resource.max_rarity = pulled_rarity
		activate_powerup(resource)

func activate_powerup(powerup : Resource, delete : bool = false) -> void:
	if powerup.p_name == "Robert":
		if not delete:
			powerup.boost = increase_stat_by_percentage(player.default_vit, rarity_power(powerup))
		else:
			powerup.boost *= -1
		player.default_vit += powerup.boost
		player.current_vit += powerup.boost
		player.emit_signal("set_health_bar", player.current_vit)
		
		powerup.boost = abs(powerup.boost)
	
	elif powerup.p_name == "Vivian":
		powerup.boost = increase_stat_by_percentage(player.default_vit, rarity_power(powerup))

func increase_stat_by_percentage(base : int, perc : int) -> int:
	return perc * base / 100

func rarity_power(resource : Resource) -> float:
	return resource.base + (resource.step * resource.max_rarity)

func apply_powerup_boost(powerup_name : String, param : Array = [null]) -> Variant:
	for i in active_powerups:
		if powerup_name == i.p_name:
			if i.p_name == "Vivian":
				player._on_get_healed(i.boost)
				return null
			if i.p_name == "Alvin":
				param.all(
					func(element): 
					element = increase_stat_by_percentage(element, rarity_power(i))
					return i.boost
					)
				return param
			
	return null
