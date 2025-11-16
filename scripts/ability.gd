extends Resource
class_name Ability

# Modificadores de stats (puedes devolver el mismo valor si no cambian)
func modify_damage(base: float, user: Node, target: Node) -> float:
	return base

func modify_attack_speed(base_aps: float, user: Node) -> float:
	return base_aps

func modify_crit_chance(base_cc: float, user: Node, target: Node) -> float:
	return base_cc

func modify_crit_mult(base_cm: float, user: Node, target: Node) -> float:
	return base_cm

# Hooks de eventos
func on_spawn(user: Node) -> void: pass
func on_before_attack(user: Node, target: Node) -> void: pass
func on_after_attack(user: Node, target: Node, dealt_damage: float, was_crit: bool) -> void: pass
func on_take_damage(user: Node, amount: float, from: Node) -> void: pass
func on_kill(user: Node, victim: Node) -> void: pass
func on_die(user: Node, killer: Node) -> void: pass
