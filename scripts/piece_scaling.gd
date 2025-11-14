extends Resource
class_name PieceScalingProfile

enum Mode { MULTIPLIER, ABSOLUTE }
@export var mode: Mode = Mode.MULTIPLIER

# TIPADO: haz que el export sea Dictionary tipado
@export var tiers: Dictionary = {
	"BRONCE": {"members": 6,  "hp": 1.0, "dmg": 1.0, "aps": 1.0, "crit_chance": 0, "crit_mult": 0.0},
	"PLATA":  {"members": 8,  "hp": 1.2, "dmg": 1.2, "aps": 1.0, "crit_chance": 1, "crit_mult": 0.05},
	"ORO":    {"members": 10, "hp": 1.4, "dmg": 1.4, "aps": 1.0, "crit_chance": 2, "crit_mult": 0.10},
}

# TIPADO en firma y variables internas
func compute_for_tier(tier_key: String, base: Dictionary) -> Dictionary:
	var t: Dictionary = tiers.get(tier_key, {}) as Dictionary

	var out: Dictionary = {
		"members": int(base.get("members", 1)),
		"hp": float(base.get("hp", 100.0)),
		"dmg": float(base.get("dmg", 10.0)),
		"aps": float(base.get("aps", 1.0)),
		"crit_chance": int(base.get("crit_chance", 5)),
		"crit_mult": float(base.get("crit_mult", 1.5)),
	}

	if mode == Mode.MULTIPLIER:
		out["members"] = int(round(float(t.get("members", out["members"]))))
		out["hp"] *= float(t.get("hp", 1.0))
		out["dmg"] *= float(t.get("dmg", 1.0))
		out["aps"] *= float(t.get("aps", 1.0))
		out["crit_chance"] += int(t.get("crit_chance", 0))
		out["crit_mult"] += float(t.get("crit_mult", 0.0))
	else:
		if "members" in t: out["members"] = int(t["members"])
		if "hp"       in t: out["hp"] = float(t["hp"])
		if "dmg"      in t: out["dmg"] = float(t["dmg"])
		if "aps"      in t: out["aps"] = float(t["aps"])
		if "crit_chance" in t: out["crit_chance"] = int(t["crit_chance"])
		if "crit_mult"   in t: out["crit_mult"] = float(t["crit_mult"])

	return out
