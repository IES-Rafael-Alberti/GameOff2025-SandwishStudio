extends Resource
class_name npcRes

enum UnitType { GLADIATOR, PIECE }

@export var frames: SpriteFrames
@export var description: String
@export var raza: String
@export var rareza: String
@export var gold: int

@export var Unit_type: UnitType = UnitType.PIECE
@export var health_bar_offset: Vector2 = Vector2(0, -40)

@export var day_stats: Dictionary = {
	1: {
		"hp": 55.0,
		"dmg": 7.0,
		"aps": 1.1,
		"crit_chance": 6,
		"crit_mult": 1.5,
	},
	2: {
		"hp": 70.0,
		"dmg": 9.0,
		"aps": 1.1,
		"crit_chance": 7,
		"crit_mult": 1.6,
	},
	3: {
		"hp": 90.0,
		"dmg": 11.0,
		"aps": 1.2,
		"crit_chance": 8,
		"crit_mult": 1.7,
	},
}

func get_stats_for_day(day: int) -> Dictionary:
	if not day_stats.has(day):
		day = 1
	return day_stats[day]
