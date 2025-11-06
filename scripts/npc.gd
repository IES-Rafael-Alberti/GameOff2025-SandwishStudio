extends AnimatedSprite2D
class_name npc

enum Team { ALLY, ENEMY }
@export var team: Team = Team.ALLY
const NpcRes = preload("res://scripts/npc_res.gd")

@export var npc_res: npcRes
@export var show_healthbar: bool = true
@export var hide_when_full: bool = false

var max_health: float = 1.0
var health: float = 1.0
# (for debugg) var _did_test_hit := false

@onready var health_bar: ProgressBar = $healthBar

func _ready() -> void:
	# (for debugg) print("[npc] _ready")

	# Carge stats form the resource
	if npc_res:
		max_health = max(1.0, npc_res.max_health)
		health = clamp(npc_res.health, 0.0, max_health)
	else:
		max_health = 1.0
		health = 1.0

	# Frames + animation
	if npc_res and npc_res.frames:
		sprite_frames = npc_res.frames
		if sprite_frames.has_animation("idle"):
			animation = "idle"
			play()
	else:
		push_error("Debbug posible problema en el inspector")

	# Update the healthbar
	_update_healthbar()
	# (for debugg) call_deferred("_debug_test_hit")

# (for debugg) func _debug_test_hit() -> void:
	# (for debugg) if _did_test_hit: return
	# (for debugg) _did_test_hit = true
	# (for debugg) print("[npc] test: take_damage(5)")
	# (for debugg) take_damage(5)

func _update_healthbar() -> void:
	if not is_instance_valid(health_bar): return
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = show_healthbar and (not hide_when_full or health < max_health)
	# (for debugg) print("[npc] _update_healthbar -> ", health, "/", max_health)

func take_damage(amount: float) -> void:
	if amount <= 0.0: return
	# (for debugg) print("[npc] take_damage(", amount, ") antes=", health)
	health = max(0.0, health - amount)
	_update_healthbar()
	# (for debugg) print("[npc] take_damage -> después=", health)
	if health <= 0.0:
		_die()

func can_damage(other: npc) -> bool:
	return team != other.team

func heal(amount: float) -> void:
	if amount <= 0.0: return
	# (for debugg) print("[npc] heal(", amount, ") antes=", health)
	health = min(max_health, health + amount)
	_update_healthbar()
	# (for debugg) print("[npc] heal -> después=", health)

func _die() -> void:
	# (for debugg) print("[npc] _die()")
	queue_free()
