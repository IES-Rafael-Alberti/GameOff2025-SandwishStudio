extends Node
class_name PieceAdapter
const NpcRes = preload("res://scripts/npc_res.gd")

# TIPADO: dicionario de multiplicadores
static var GLOBAL_MULT: Dictionary = {
	PieceRes.PiecePowerTier.BRONCE: {"hp": 1.0,  "dmg": 1.0,  "aps": 1.0},
	PieceRes.PiecePowerTier.PLATA:  {"hp": 1.35, "dmg": 1.20, "aps": 1.10},
	PieceRes.PiecePowerTier.ORO:    {"hp": 1.75, "dmg": 1.45, "aps": 1.20},
}

static func _tier_key(t: int) -> String:
	return ["BRONCE","PLATA","ORO"][t]

static func to_effective_stats(piece: PieceRes) -> Dictionary:
	var base: Dictionary = {
		"members": int(piece.members_per_piece),
		"hp": float(piece.base_max_health),
		"dmg": float(piece.base_damage),
		"aps": float(piece.base_attack_speed),
		"crit_chance": int(piece.critical_chance),
		"crit_mult": float(piece.critical_damage),
	}
	var key: String = _tier_key(piece.power_tier)

	if piece.scaling_profile:
		return piece.scaling_profile.compute_for_tier(key, base)
	else:
		var m: Dictionary = GLOBAL_MULT.get(
			piece.power_tier,
			GLOBAL_MULT[PieceRes.PiecePowerTier.BRONCE]
		) as Dictionary

		base["hp"]  = float(base["hp"])  * float(m["hp"])
		base["dmg"] = float(base["dmg"]) * float(m["dmg"])
		base["aps"] = float(base["aps"]) * float(m["aps"])
		return base

static func to_npc_res(piece: PieceRes) -> Dictionary:
	var eff: Dictionary = to_effective_stats(piece)

	var r := NpcRes.new()
	r.frames = piece.frames
	r.max_health = float(eff["hp"])
	r.health = float(eff["hp"])
	r.damage = float(eff["dmg"])
	r.atack_speed = float(eff["aps"])
	r.critical_chance = int(eff["crit_chance"])
	r.critical_damage = float(eff["crit_mult"])
	r.description = piece.display_name
	r.raza = ["Nórdica","Japonesa","Europea"][piece.race]
	r.rareza = ["Bronce","Plata","Oro"][piece.power_tier]
	r.gold = int(piece.gold_per_enemy)

	return {"res": r, "members": int(eff["members"])}
