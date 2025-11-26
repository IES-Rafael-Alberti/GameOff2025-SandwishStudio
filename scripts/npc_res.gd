extends Resource

class_name npcRes

enum UnitType { GLADIATOR, PIECE }

@export var frames: SpriteFrames
@export var max_health: float
@export var health: float
@export var damage: float
@export var atack_speed: float
@export var critical_chance: int
@export var critical_damage: float
@export var description: String
@export var raza: String
@export var rareza: String
@export var gold: int

@export var Unit_type: UnitType = UnitType.PIECE
@export var health_bar_offset: Vector2 = Vector2(0, -40)

#Sound
@export_group("Sonidos")
@export var sfx_spawn: AudioStream
@export var sfx_attack: AudioStream
@export var sfx_death: AudioStream
