extends Node
class_name PieceAdapter
const NpcRes = preload("res://scripts/npc_res.gd")


# NUEVO: Función auxiliar para determinar el Tier (PiecePowerTier) basado en el número de copias.
static func _get_piece_tier(num_copies: int) -> int:
	# 1 copia = BRONCE, 2 = PLATA, 3+ = ORO
	var tier: int = PieceRes.PiecePowerTier.BRONCE # 0
	if num_copies >= 3:
		tier = PieceRes.PiecePowerTier.ORO # 2
	elif num_copies >= 2:
		tier = PieceRes.PiecePowerTier.PLATA # 1
	# Si num_copies < 1, usa BRONCE (valor por defecto)
	return tier

# MODIFICADO: Ahora requiere el número de copias para determinar el Tier y obtener las stats absolutas.
static func to_effective_stats(piece: PieceRes, num_copies: int) -> Dictionary:
	var tier: int = _get_piece_tier(num_copies)
	
	# Usamos el nuevo método get_stats_for_tier que devuelve el diccionario de stats del Tier.
	var stats: Dictionary = piece.get_stats_for_tier(tier)
	
	# Estructuramos el diccionario de salida, asegurando tipos correctos y valores por defecto.
	var effective_stats: Dictionary = {
		"members": int(stats.get("members", 1)),
		"hp": float(stats.get("hp", 100.0)),
		"dmg": float(stats.get("dmg", 10.0)),
		"aps": float(stats.get("aps", 1.0)),
		"crit_chance": int(stats.get("crit_chance", 5)),
		"crit_mult": float(stats.get("crit_mult", 1.5)),
	}
	
	# Incluimos el tier para que to_npc_res pueda actualizar el campo "rareza"
	effective_stats["_piece_tier"] = tier 
	
	return effective_stats

# MODIFICADO: Ahora requiere el número de copias y el oro por enemigo.
static func to_npc_res(piece: PieceRes, num_copies: int, gold_per_enemy: int) -> Dictionary:
	var eff: Dictionary = to_effective_stats(piece, num_copies)

	var r := NpcRes.new()
	r.frames = piece.frames
	r.max_health = float(eff["hp"])
	r.health = float(eff["hp"])
	r.damage = float(eff["dmg"])
	r.atack_speed = float(eff["aps"])
	r.critical_chance = int(eff["crit_chance"])
	r.critical_damage = float(eff["crit_mult"])
	r.description = piece.display_name
	r.raza = ["Nordic","Japanese","European"][piece.race]
	r.health_bar_offset = piece.health_bar_offset
	
	# Usar el tier calculado
	var tier: int = int(eff["_piece_tier"])
	var tier_name = ["Bronce","Plata","Oro"][tier]
	r.rareza = tier_name
	
	# Usamos el nuevo parámetro para el oro
	r.gold = gold_per_enemy 

	# NUEVO: Feedback visual por consola
	print("--- Pieza Spawneada ---")
	print("Nombre: ", piece.display_name)
	print("Copias poseídas: ", num_copies)
	print("Tier efectivo (Rareza): ", tier_name)
	print("Miembros: ", int(eff["members"]))
	print("-----------------------")

	return {"res": r, "members": int(eff["members"])}
