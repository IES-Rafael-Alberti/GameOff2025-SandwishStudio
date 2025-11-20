extends AnimatedSprite2D
class_name npc

signal died(n: npc)

enum Team { ALLY, ENEMY }
@export var team: Team = Team.ALLY
const NpcRes = preload("res://scripts/npc_res.gd")

# Speed Atack adaptable
const ATTACK_SPEED_SOFT_CAP := 2.0   
const ATTACK_SPEED_HARD_CAP := 4.0   
const ATTACK_SPEED_OVER_FACTOR := 0.3

# Log
const DAMAGE_TEXT_SCENE := preload("res://scenes/damage_text.tscn")

# Shader de daño (shock)
@onready var shock_material: ShaderMaterial = material
var shock_timer: float = 0.0
var is_shocked: bool = false

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

# --- VARIABLES DE SINERGIA (NUEVO) ---
var synergy_jap_tier: int = 0
var synergy_nor_tier: int = 0
var synergy_eur_tier: int = 0

# Flags de estado
var has_attacked: bool = false # Para Japonés
var nordica_heal_used: bool = false # Para Nórdico

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
	if shock_material:
		shock_material.set_shader_parameter("shock_time", 999.0)
	else:
		push_warning("NPC sin frames en inspector")

	_update_healthbar()
	
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

func _show_damage_text(amount: float, was_crit: bool = false) -> void:
	# Instanciamos el Label
	var dmg_label: Label = DAMAGE_TEXT_SCENE.instantiate()
	var dmg_int := int(round(amount))
	dmg_label.text = str(dmg_int)

	var base_font_size := 34.0
	var size_factor: float = clamp(0.7 + float(dmg_int) / 60.0, 0.7, 2.5)
	var size := int(base_font_size * size_factor)

	# Si es crítico, un pelín más grande (efecto “negrita” ligero)
	if was_crit:
		size = int(size * 1.1)

	dmg_label.add_theme_font_size_override("font_size", size)

	# --- Color según el daño (de rojo a morado intenso) ---
	var min_color := Color(1.0, 0.0, 0.0, 1.0)   # rojo para poco daño
	var max_color := Color(0.276, 0.005, 0.396, 1.0)   # morado intenso para mucho daño

	# Daño a partir del cual se considera “máximo morado” (ajusta a tu gusto)
	var color_damage_cap := 120.0
	var t : float = clamp(float(dmg_int) / color_damage_cap, 0.0, 1.0)

	var final_color := min_color.lerp(max_color, t)

	# Si es crítico, lo aclaramos un poco para que destaque, pero
	# el tono base sigue viniendo del daño (no del crítico en sí).
	if was_crit:
		final_color = final_color.lightened(0.15)

	dmg_label.modulate = final_color

	# Si quieres remarcar aún más el crítico (“negrita” visual):
	if was_crit:
		dmg_label.add_theme_constant_override("outline_size", 2)
		dmg_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	var root := get_tree().current_scene
	if root == null: return
	root.add_child(dmg_label)

	# --------------------
	#  POSICIÓN DENTRO DE UN "CONO"
	# --------------------
	var max_height := 140.0   # cuanto más grande, más alto pueden aparecer
	var min_height := 50.0

	var h := randf_range(min_height, max_height)

	var max_width_at_top := 160.0
	var half_width := (h / max_height) * (max_width_at_top * 0.5)

	var offset_x := randf_range(-half_width, half_width)
	var offset_y := -h

	var start_pos := global_position + Vector2(offset_x, offset_y)
	dmg_label.global_position = start_pos

	# --------------------
	#  ANIMACIÓN SERPENTEANTE
	# --------------------
	var total_travel := randf_range(40.0, 90.0)
	var amplitude := randf_range(10.0, 15.0)
	var waves := randf_range(1.5, 3.0)
	var move_time := 0.7
	var fade_time := 0.3

	var tween := root.create_tween()

	tween.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(dmg_label):
				return
			var y := -t * total_travel
			var x := sin(t * TAU * waves) * amplitude
			dmg_label.global_position = start_pos + Vector2(x, y)
	, 0.0, 1.0, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		dmg_label, "modulate:a", 0.0, fade_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(move_time - fade_time)

	tween.finished.connect(func() -> void:
		if is_instance_valid(dmg_label): dmg_label.queue_free()
	)

func can_damage(other: npc) -> bool:
	return team != other.team

func heal(amount: float) -> void:
	if amount <= 0.0: return
	health = min(max_health, health + amount)
	_update_healthbar()

# --- CONFIGURACIÓN DE SINERGIAS ---
func apply_synergies(data: Dictionary):
	synergy_jap_tier = data.get("jap", 0)
	synergy_nor_tier = data.get("nor", 0)
	synergy_eur_tier = data.get("eur", 0)
	
	_apply_european_buff()

# LÓGICA EUROPEA: Aumenta Vida Máxima
func _apply_european_buff():
	if synergy_eur_tier == 0: return
	
	var mult = 1.0
	if synergy_eur_tier == 1: mult = 1.25 # +25%
	elif synergy_eur_tier == 2: mult = 1.50 # +50%
	
	max_health = max_health * mult
	health = max_health # Rellena la vida con el nuevo máximo
	_update_healthbar()
	
# --- APLICAR GLOBAL STATS ---
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
	
	# LÓGICA JAPONESA: Bonus primer ataque
	if synergy_jap_tier > 0 and not has_attacked:
		var mult = 1.0
		if synergy_jap_tier == 1: mult = 1.5 # +50%
		elif synergy_jap_tier == 2: mult = 2.0 # +100%
		val *= mult
		# Nota: has_attacked se pone true en 'notify_after_attack'
	
	for ab in abilities:
		if ab: val = ab.modify_damage(val, self, target)
	return max(0.0, val)

func get_attack_speed() -> float:
	var val := npc_res.atack_speed + bonus_speed
	for ab in abilities:
		if ab: val = ab.modify_attack_speed(val, self)

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
func take_damage(amount: float, from: npc = null, was_crit: bool = false) -> void:
	if amount <= 0.0: return
	health = max(0.0, health - amount)
	if shock_material:
		shock_timer = 0.0
		is_shocked = true
		shock_material.set_shader_parameter("shock_time", shock_timer)

	_show_damage_text(amount, was_crit)

	
	# LÓGICA NÓRDICA: Curación al 25% HP
	if synergy_nor_tier > 0 and not nordica_heal_used:
		if health > 0 and (health / max_health) <= 0.25:
			nordica_heal_used = true
			var target_pct = 0.50 # Tier 1: 50%
			if synergy_nor_tier == 2: target_pct = 0.75 # Tier 2: 75%
			
			var heal_amt = (max_health * target_pct) - health
			if heal_amt > 0:
				health += heal_amt
				_show_heal_text(heal_amt)
				# Opcional: Mostrar texto de cura
				print("%s se curó por sinergia Nórdica" % name)
	
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
	# Sinergia Japonesa: Marcar que ya atacó
	if not has_attacked:
		has_attacked = true
		
	for ab in abilities:
		if ab: ab.on_after_attack(self, target, dealt_damage, was_crit)

func notify_kill(victim: npc) -> void:
	for ab in abilities:
		if ab: ab.on_kill(self, victim)

func _process(delta: float) -> void:
	if is_shocked and shock_material:
		# Avanzamos el tiempo del efecto
		shock_timer += delta * 8.0  # sube/baja este 8.0 para cambiar velocidad
		shock_material.set_shader_parameter("shock_time", shock_timer)

		# Cuando pasa un rato, damos por terminado el efecto
		if shock_timer > 0.3:
			is_shocked = false
			shock_material.set_shader_parameter("shock_time", 999.0)
func _show_heal_text(amount: float) -> void:
	# Instanciamos la misma escena que el daño
	var heal_label: Label = DAMAGE_TEXT_SCENE.instantiate()
	var heal_int := int(round(amount))
	
	# Ponemos un "+" para indicar que es positivo
	heal_label.text = "+" + str(heal_int)

	# Configuración de tamaño (similar al daño)
	var base_font_size := 34.0
	var size_factor: float = clamp(0.7 + float(heal_int) / 60.0, 0.7, 2.5)
	var size := int(base_font_size * size_factor)

	heal_label.add_theme_font_size_override("font_size", size)

	# --- COLOR VERDE BRILLANTE ---
	heal_label.modulate = Color(0.396, 1.0, 0.376, 1.0) 

	var root := get_tree().current_scene
	if root == null: return
	root.add_child(heal_label)

	# --- POSICIONAMIENTO Y ANIMACIÓN (Idéntico al daño) ---
	var max_height := 140.0
	var min_height := 50.0
	var h := randf_range(min_height, max_height)
	var max_width_at_top := 160.0
	var half_width := (h / max_height) * (max_width_at_top * 0.5)

	var offset_x := randf_range(-half_width, half_width)
	var offset_y := -h
	var start_pos := global_position + Vector2(offset_x, offset_y)
	
	heal_label.global_position = start_pos

	var total_travel := randf_range(40.0, 90.0)
	var amplitude := randf_range(10.0, 15.0)
	var waves := randf_range(1.5, 3.0)
	var move_time := 0.7
	var fade_time := 0.3

	var tween := root.create_tween()

	tween.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(heal_label): return
			var y := -t * total_travel
			var x := sin(t * TAU * waves) * amplitude
			heal_label.global_position = start_pos + Vector2(x, y)
	, 0.0, 1.0, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		heal_label, "modulate:a", 0.0, fade_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(move_time - fade_time)

	tween.finished.connect(func() -> void:
		if is_instance_valid(heal_label): heal_label.queue_free()
	)
