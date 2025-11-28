extends Resource
class_name npcRes

enum UnitType { GLADIATOR, PIECE }

@export var frames: SpriteFrames

@export_group("Stats por día")
@export var day_stats: Dictionary = {
	1: { "hp": 55.0, "dmg": 7.0, "aps": 1.1, "crit_chance": 6,  "crit_mult": 1.5, "members": 5 },
	2: { "hp": 65.0, "dmg": 8.0, "aps": 1.2, "crit_chance": 8,  "crit_mult": 1.6, "members": 5 },
	3: { "hp": 80.0, "dmg": 9.0, "aps": 1.3, "crit_chance": 10, "crit_mult": 1.7, "members": 5 },
}
@export_group("Stats legacy (compatibilidad)")
@export var max_health: float = 55.0
@export var health: float = 55.0
@export var damage: float = 7.0
@export var atack_speed: float = 1.1
@export var critical_chance: int = 6
@export var critical_damage: float = 1.5

@export var description: String = ""
@export var raza: String = ""
@export var rareza: String = ""
@export var gold: int = 0

@export var Unit_type: UnitType = UnitType.PIECE
@export var health_bar_offset: Vector2 = Vector2(0, -40)

@export_group("Sonidos")
@export var sfx_spawn: AudioStream       # cuando aparece
@export var sfx_attack: AudioStream      # cuando ataca
@export var sfx_death: AudioStream       # cuando muere

func get_stats_for_day(day: int) -> Dictionary:
	# Fallback: si no hay tabla de stats por día, usamos los campos "legacy"
	if day_stats.is_empty():
		return {
			"hp": max_health,
			"dmg": damage,
			"aps": atack_speed,
			"crit_chance": critical_chance,
			"crit_mult": critical_damage,
			"members": 1,
		}

	if day_stats.has(day):
		return day_stats[day]

	if day < 1 and day_stats.has(1):
		return day_stats[1]

	var keys := day_stats.keys()
	if keys.is_empty():
		return {}

	var max_day: int = int(keys[0])
	for k in keys:
		if int(k) > max_day:
			max_day = int(k)

	return day_stats.get(max_day, {})
