extends Resource
class_name npcRes

enum UnitType { GLADIATOR, PIECE }

@export var frames: SpriteFrames

# Stats base (sirven para PIEZAS y aliados)
@export var max_health: float = 1.0
@export var health: float = 1.0
@export var damage: float = 1.0
@export var atack_speed: float = 1.0
@export var critical_chance: int = 0
@export var critical_damage: float = 1.0

@export var description: String
@export var raza: String
@export var rareza: String
@export var gold: int = 0

@export var Unit_type: UnitType = UnitType.PIECE
@export var health_bar_offset: Vector2 = Vector2(0, -40)

# --- SOUND ---
@export_group("Sonidos")
@export var sfx_spawn: AudioStream
@export var sfx_attack: AudioStream
@export var sfx_death: AudioStream

# ------- STATS POR DÍA (solo gladiadores) -------
@export var day_stats := {
	1: { "hp": 55.0, "dmg": 7.0, "aps": 1.1, "crit_chance": 6, "crit_mult": 1.5 },
	2: { "hp": 70.0, "dmg": 9.0, "aps": 1.1, "crit_chance": 7, "crit_mult": 1.6 },
	3: { "hp": 90.0, "dmg": 11.0, "aps": 1.2, "crit_chance": 8, "crit_mult": 1.7 },
}

func get_stats_for_day(day: int) -> Dictionary:
	if not day_stats.has(day):
		return day_stats[1]
	return day_stats[day]
