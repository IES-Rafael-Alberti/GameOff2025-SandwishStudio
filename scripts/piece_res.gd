extends Resource
class_name PieceRes

enum PieceRace { NORDICA, JAPONESA, EUROPEA }
enum PiecePowerTier { BRONCE, PLATA, ORO }
enum PieceRarity { COMUN, RARO, EPICO, LEGENDARIO }

@export var id: String = ""
@export var display_name: String = ""
@export var race: PieceRace = PieceRace.EUROPEA
@export var power_tier: PiecePowerTier = PiecePowerTier.BRONCE
@export var rarity: PieceRarity = PieceRarity.COMUN
@export var role: String = ""

# Stats base (referencia, p.ej. pensados para BRONCE)
@export var base_max_health := 100.0
@export var base_damage := 10.0
@export var base_attack_speed := 1.0
@export var critical_chance := 5
@export var critical_damage := 1.5
@export var frames: SpriteFrames
@export var gold_per_enemy := 0
@export var members_per_piece := 6  # valor por defecto si el perfil no lo sobreescribe

# NUEVO: perfil opcional de escalado por pieza
@export var scaling_profile: PieceScalingProfile
