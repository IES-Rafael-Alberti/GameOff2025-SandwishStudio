extends Resource
class_name npcRes

enum UnitType { GLADIATOR, PIECE }

@export var frames: SpriteFrames

@export_group("Stats por día")
@export var day_stats: Dictionary = {
	1: { "hp": 200.0, "dmg": 25.0, "aps": 2.0, "crit_chance": 5,  "crit_mult": 1.25, "members": 1 },
	2: { "hp": 250.0, "dmg": 30.0, "aps": 2.2, "crit_chance": 10,  "crit_mult": 1.5, "members": 1 },
	3: { "hp": 300.0, "dmg": 35.0, "aps": 2.4, "crit_chance": 15, "crit_mult": 1.8, "members": 1 },
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
@export var sfx_attack_variations: Array[AudioStream] = []

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
