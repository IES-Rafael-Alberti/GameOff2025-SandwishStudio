# GlobalStats.gd
extends Node

# Señal para notificar si algo necesita actualizarse en vivo
signal stats_updated

# Almacenamos las bonificaciones TOTALES de todas las pasivas
var total_health: float = 0.0
var total_damage: float = 0.0
var total_speed: float = 0.0
var total_crit_chance: float = 0.0
var total_crit_damage: float = 0.0

# Función para que el inventario (inventory.gd) actualice los datos
func update_stats(stats: Dictionary) -> void:
	total_health = stats.get("health", 0.0)
	total_damage = stats.get("damage", 0.0)
	total_speed = stats.get("speed", 0.0)
	total_crit_chance = stats.get("crit_chance", 0.0)
	total_crit_damage = stats.get("crit_damage", 0.0)

	# print("GlobalStats actualizado: ", stats) # Descomenta para depurar
	stats_updated.emit()

# --- Funciones 'Getter' ---
# Las usaremos en combat_scene.gd para obtener los valores

func get_health_bonus() -> float:
	return total_health

func get_damage_bonus() -> float:
	return total_damage

func get_speed_bonus() -> float:
	return total_speed

func get_crit_chance_bonus() -> float:
	return total_crit_chance

func get_crit_damage_bonus() -> float:
	return total_crit_damage
