extends Resource
class_name PieceRes

enum PieceRace { NORDICA, JAPONESA, EUROPEA }
enum PiecePowerTier { BRONCE, PLATA, ORO }
enum PieceRarity { COMUN, RARO, EPICO, LEGENDARIO }

# --- IDENTIDAD ---
@export var id: String = ""
@export var display_name: String = ""
@export var race: PieceRace = PieceRace.EUROPEA
@export var rarity: PieceRarity = PieceRarity.COMUN

# --- VISUALES Y ECONOMÍA ---
@export var frames: SpriteFrames

# --- ESTADÍSTICAS POR TIER ---
## Diccionario que contiene los valores absolutos para cada tier.
## Claves: "BRONCE", "PLATA", "ORO".
## Valores: Dictionary con { "hp", "dmg", "aps", "members", "crit_chance", "crit_mult" }
@export var stats: Dictionary = {
	"BRONCE": {
		"members": 6,
		"hp": 100.0,
		"dmg": 10.0,
		"aps": 1.0,
		"crit_chance": 5,
		"crit_mult": 1.5
	},
	"PLATA": {
		"members": 8,
		"hp": 150.0,
		"dmg": 15.0,
		"aps": 1.1,
		"crit_chance": 10,
		"crit_mult": 1.6
	},
	"ORO": {
		"members": 10,
		"hp": 250.0,
		"dmg": 25.0,
		"aps": 1.2,
		"crit_chance": 15,
		"crit_mult": 2.0
	}
}

# --- LÓGICA ---

## Devuelve el diccionario de stats correspondiente al tier solicitado.
## Si no encuentra el tier, devuelve un diccionario con valores por defecto (seguro contra fallos).
func get_stats_for_tier(tier: PiecePowerTier) -> Dictionary:
	var tier_key = PiecePowerTier.keys()[tier] # Convierte 0 -> "BRONCE"
	
	if stats.has(tier_key):
		return stats[tier_key]
	
	# Valores de seguridad si la configuración está vacía
	printerr("PieceRes: No se encontraron stats para el tier ", tier_key, " en ", id)
	return {
		"members": 1,
		"hp": 100.0,
		"dmg": 10.0,
		"aps": 1.0,
		"crit_chance": 0,
		"crit_mult": 1.0
	}
