extends Resource
class_name PieceRes

# Nombres únicos para evitar choque con otros enums/vars
enum PieceRace { NORDICA, JAPONESA, EUROPEA }
enum PieceTier { COMUN, INUSUAL, RARO, EPICO }

@export var id: String = ""
@export var display_name: String = ""
@export var race: PieceRace = PieceRace.NORDICA
@export var tier: PieceTier = PieceTier.COMUN
@export var role: String = ""

@export_range(1, 20, 1) var members_per_piece: int = 6

@export var frames: SpriteFrames
@export var max_health: float = 100.0
@export var health: float = 100.0
@export var damage: float = 10.0
@export var attack_speed: float = 1.0
@export var critical_chance: int = 5
@export var critical_damage: float = 1.5
@export var gold_per_enemy: int = 0
