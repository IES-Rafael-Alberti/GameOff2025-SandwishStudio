extends AnimatedSprite2D
class_name npc

signal died(n: npc)

enum Team { ALLY, ENEMY }
@export var team: Team = Team.ALLY
const NpcRes = preload("res://scripts/npc_res.gd")

# Speed Atack adaptable
const ATTACK_SPEED_SOFT_CAP := 2.0   # a partir de aquí escala más lento
const ATTACK_SPEED_HARD_CAP := 4.0   # nunca pasa de 4 ataques/segundo
const ATTACK_SPEED_OVER_FACTOR := 0.3  # 30% de lo que pase del soft cap

# Log
const DAMAGE_TEXT_SCENE := preload("res://scenes/damage_text.tscn")

@export var npc_res: npcRes
@export var show_healthbar: bool = true
@export var hide_when_full: bool = false

@export var abilities: Array[Ability] = []

var max_health: float = 1.0
var health: float = 1.0
# Gold pool that unit can drop
var gold_pool: int = 0
var display_name: String = ""
@onready var name_label: Label = $NameLabel
@onready var health_bar: ProgressBar = $healthBar

# Variables para almacenar las bonificaciones de GlobalStats
var bonus_health: float = 0.0
var bonus_damage: float = 0.0
var bonus_speed: float = 0.0
var bonus_crit_chance: float = 0.0
var bonus_crit_damage: float = 0.0

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

func set_display_name(text: String) -> void:
	display_name = text
	_update_name_label()

func _update_name_label() -> void:
	if not is_instance_valid(name_label):
		return
	name_label.text = display_name
	name_label.visible = display_name != ""

func _update_healthbar() -> void:
	if not is_instance_valid(health_bar): return
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = show_healthbar and (not hide_when_full or health < max_health)

func _show_damage_text(amount: float) -> void:
	# Instanciamos el Label
	var dmg_label: Label = DAMAGE_TEXT_SCENE.instantiate()
	
	# Redondeamos el daño para mostrarlo bonito
	dmg_label.text = str(int(round(amount)))
	
	# Lo añadimos a la escena raíz para que no herede escalados raros
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(dmg_label)
	
	# Posición inicial = posición del NPC, un poco por encima
	dmg_label.global_position = global_position + Vector2(0, -20)
	
	# Color rojo por si no lo pusiste en el inspector
	dmg_label.modulate = Color(1, 0, 0, 1)

	# Animación: subir y desvanecerse
	var tween := root.create_tween()
	# Sube hacia arriba
	tween.tween_property(dmg_label, "position", dmg_label.position + Vector2(0, -30), 0.4) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	# Luego baja la alpha a 0
	tween.tween_property(dmg_label, "modulate:a", 0.0, 0.3) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)
	
	# Cuando acabe la animación, lo destruimos
	tween.finished.connect(func ():
		if is_instance_valid(dmg_label):
			dmg_label.queue_free()
	)

func can_damage(other: npc) -> bool:
	return team != other.team

func heal(amount: float) -> void:
	if amount <= 0.0: return
	health = min(max_health, health + amount)
	_update_healthbar()

func apply_passive_bonuses(p_health: float, p_damage: float, p_speed: float, p_crit_c: float, p_crit_d: float):
	bonus_health = p_health
	bonus_damage = p_damage
	bonus_speed = p_speed
	bonus_crit_chance = p_crit_c
	bonus_crit_damage = p_crit_d
	
	max_health += bonus_health
	health = max_health 
	
	_update_healthbar()

# CONTROLER BATTLE
func get_damage(target: npc) -> float:

	var val := npc_res.damage + bonus_damage
	
	for ab in abilities:
		if ab: val = ab.modify_damage(val, self, target)
	return max(0.0, val)

func get_attack_speed() -> float:
	#Base plus bonus
	var val := npc_res.atack_speed + bonus_speed
	
	# Skill Modifiers
	for ab in abilities:
		if ab: val = ab.modify_attack_speed(val, self)

	# Diminishing returns a partir del soft cap
	if val > ATTACK_SPEED_SOFT_CAP:
		var over := val - ATTACK_SPEED_SOFT_CAP
		val = ATTACK_SPEED_SOFT_CAP + over * ATTACK_SPEED_OVER_FACTOR
	
	val = clamp(val, 0.1, ATTACK_SPEED_HARD_CAP)
	return val

func get_crit_chance(target: npc) -> int:

	var val := npc_res.critical_chance + bonus_crit_chance
	
	for ab in abilities:
		if ab: val = ab.modify_crit_chance(val, self, target)
	return max (0, val)

func get_crit_mult(target: npc) -> float:

	var val := npc_res.critical_damage + bonus_crit_damage
	
	for ab in abilities:
		if ab: val = ab.modify_crit_damage(val, self, target)
	return max (1.0, val)

# DAMAGE AND EVENTS
func take_damage(amount: float, from: npc = null) -> void:
	if amount <= 0.0: return
	health = max(0.0, health - amount)
	_show_damage_text(amount)
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
