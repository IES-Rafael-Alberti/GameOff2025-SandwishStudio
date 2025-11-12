extends AnimatedSprite2D
class_name npc

signal died(n: npc)

enum Team { ALLY, ENEMY }
@export var team: Team = Team.ALLY
const NpcRes = preload("res://scripts/npc_res.gd")

@export var npc_res: npcRes
@export var show_healthbar: bool = true
@export var hide_when_full: bool = false

@export var abilities: Array[Ability] = []

var max_health: float = 1.0
var health: float = 1.0
# Gold pool that unit can drop
var gold_pool: int = 0

@onready var health_bar: ProgressBar = $healthBar

func _ready() -> void:
	# Carge stats form the resource
	if npc_res:
		max_health = max(1.0, npc_res.max_health)
		health = clamp(npc_res.health, 0.0, max_health)
		gold_pool = int(npc_res.gold)
	else:
		max_health = 1.0
		health = 1.0
		gold_pool = 0
		
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
	
	# Hook: spawn
	for ab in abilities:
		if ab: ab.on_spwan(self)

func _update_healthbar() -> void:
	if not is_instance_valid(health_bar): return
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = show_healthbar and (not hide_when_full or health < max_health)

func can_damage(other: npc) -> bool:
	return team != other.team

func heal(amount: float) -> void:
	if amount <= 0.0: return
	health = min(max_health, health + amount)
	_update_healthbar()

# CONTROLER BATTLE
func get_damage(target: npc) -> float:
	var val := npc_res.damage
	for ab in abilities:
		if ab: val = ab.modify_damage(val, self, target)
	return max(0.0, val)

func get_attack_speed() -> float:
	var val := npc_res.atack_speed
	for ab in abilities: 
		if ab: val = ab.modify_attack_speed(val, self)
	return max (0.01, val)

func get_crit_chance(target: npc) -> int:
	var val := npc_res.critical_chance
	for ab in abilities: 
		if ab: val = ab.modify_crit_chance(val, self, target)
	return max (0, val)

func get_crit_mult(target: npc) -> float:
	var val := npc_res.critical_damage
	for ab in abilities: 
		if ab: val = ab.modify_crit_damage(val, self, target)
	return max (1.0, val)

# DAMAGE AND EVENTS
func take_damage(amount: float, from: npc = null) -> void:
	if amount <= 0.0: return
	health = max(0.0, health - amount)
	for ab in abilities:
		if ab: ab.on_take_damage(self, amount, from)
	_update_healthbar()
	if health <= 0.0:
		_die(from)

func _die(killer: npc = null) -> void:
	for ab in abilities:
		if ab: ab.on_die(self, killer)
	emit_signal("died", self)
	queue_free()

# Notificadores 
func notify_before_attack(target: npc) -> void:
	for ab in abilities:
		if ab: ab.on_before_attack(self, target)

func notify_after_attack(target: npc, dealt_damage: float, was_crit: bool) -> void:
	for ab in abilities:
		if ab: ab.on_after_attack(self, target, dealt_damage, was_crit)

func notify_kill(victim: npc) -> void:
	for ab in abilities:
		if ab: ab.on_kill(self, victim)
