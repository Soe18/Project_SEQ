class_name Powerup extends Resource

@export_group("Power-up info")
@export var p_name : String = "Power-up name"
@export var description : String = "Power-up description"

@export var type : PowerupStats.type = PowerupStats.type.offensive
@export var max_rarity : PowerupStats.rar = PowerupStats.rar.common

@export var base : float = 0
@export var step : float = 0

@export var boost : float = 0

@export var custom_handler : PackedScene = null
