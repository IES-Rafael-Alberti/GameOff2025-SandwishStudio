extends AnimatedSprite2D
class_name npc

signal died(n: npc)

enum Team { ALLY, ENEMY }
@export var team: Team = Team.ALLY
const NpcRes = preload("res://scripts/npc_res.gd")
var is_hovered: bool = false 
# Speed Atack adaptable
const ATTACK_SPEED_SOFT_CAP := 2.0   
const ATTACK_SPEED_HARD_CAP := 4.0   
const ATTACK_SPEED_OVER_FACTOR := 0.3

# Log
const DAMAGE_TEXT_SCENE := preload("res://scenes/damage_text.tscn")

# Sounds
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer

# Shader de daño (shock)
@onready var shock_material: ShaderMaterial = material
var shock_timer: float = 0.0
var is_shocked: bool = false
var attack_notified: bool = false

@export var npc_res: npcRes
@export var show_healthbar: bool = true
@export var hide_when_full: bool = false

@export var abilities: Array[Ability] = []

var max_health: float = 1.0
var health: float = 1.0
# Gold pool that unit can drop
var gold_pool: int = 0
@onready var health_bar: ProgressBar = $healthBar

# Variables para almacenar las bonificaciones de GlobalStats
var bonus_health: float = 0.0
var bonus_damage: float = 0.0
var bonus_speed: float = 0.0
var bonus_crit_chance: float = 0.0
var bonus_crit_damage: float = 0.0

# --- VARIABLES DE SINERGIA ---
var synergy_jap_tier: int = 0
var synergy_nor_tier: int = 0
var synergy_eur_tier: int = 0

# Flags de estado
var attack_count: int = 0        # Contador de ataques
var is_last_attack_special: bool = false # Para efectos visuales
var nordica_heal_used: bool = false
var jap_special_ready: bool = false
# MULTIPLICADOR ALMACENADO (Solo HP)
var synergy_hp_mult: float = 1.0

# ESTILO ORIGINAL (Para restaurar el verde)
var default_bar_style: StyleBox = null

func _ready() -> void:
	# --- SFX de spawn (solo GLADIADOR) ---
	if npc_res and npc_res.sfx_spawn and team == Team.ENEMY:
		play_sfx(npc_res.sfx_spawn, "spawn_enemy")
	

	if has_node("MouseArea"):
		var area = get_node("MouseArea")
		area.mouse_entered.connect(_on_mouse_entered)
		area.mouse_exited.connect(_on_mouse_exited)
	else:
		# Fallback por si olvidaste crearlo, avisa en consola
		push_warning("NPC: No se encontró 'MouseArea' para el tooltip.")
	# CARGAR STATS BASE
	if npc_res:
		var base_hp = max(1.0, npc_res.max_health)
		max_health = (base_hp + bonus_health) * synergy_hp_mult
		
		health = clamp(npc_res.health, 0.0, max_health)
		if abs(npc_res.health - npc_res.max_health) < 0.1:
			health = max_health
			
		gold_pool = int(npc_res.gold)
	else:
		max_health = 1.0
		health = 1.0
		gold_pool = 0

	if material:
		material = material.duplicate()
		shock_material = material
	else:
		shock_material = null

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

	# Configuración visual de la barra (Posición y Z-Index de Rama A)
	_setup_healthbar_z()
	_apply_healthbar_offset_from_res()

	# 2. GUARDAR ESTILO ORIGINAL (VERDE) Y APLICAR VISUALES (Rama B)
	if is_instance_valid(health_bar):
		# Guardamos el estilo verde de la escena antes de tocar nada
		default_bar_style = health_bar.get_theme_stylebox("fill")
		
	_update_healthbar()
	_apply_bar_visuals() 

	for ab in abilities:
		if ab: ab.on_spwan(self)

func _update_healthbar() -> void:
	if not is_instance_valid(health_bar): return
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = show_healthbar and (not hide_when_full or health < max_health)

func _apply_bar_visuals():
	if not is_instance_valid(health_bar): return
	
	# Reseteamos tintes
	health_bar.modulate = Color.WHITE
	health_bar.self_modulate = Color.WHITE
	
	# Sin sinergia barra de vida verde
	if synergy_eur_tier == 0:
		# Si tenemos guardado el estilo original (verde), lo restauramos
		if default_bar_style:
			health_bar.add_theme_stylebox_override("fill", default_bar_style)
		return

	# Con sinergia barra de vida azul o morado

	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(2) 

	if synergy_eur_tier == 1:
		sb.bg_color = Color(0.0, 0.8, 1.0) # Azul Cian
	elif synergy_eur_tier == 2:
		sb.bg_color = Color(0.6, 0.2, 1.0) # Morado
	
	health_bar.add_theme_stylebox_override("fill", sb)

# VISUAL: Textos de daño
func _show_damage_text(amount: float, was_crit: bool = false, is_epic: bool = false) -> void:
	var dmg_label: Label = DAMAGE_TEXT_SCENE.instantiate()
	var dmg_int := int(round(amount))
	dmg_label.text = str(dmg_int)

	var base_font_size := 34.0
	var size_factor: float = clamp(0.7 + float(dmg_int) / 60.0, 0.7, 2.5)
	
	if is_epic:
		size_factor *= 1.5 
		dmg_label.text += "!" 
	
	var size := int(base_font_size * size_factor)
	if was_crit:
		size = int(size * 1.1)

	dmg_label.add_theme_font_size_override("font_size", size)

	var final_color: Color
	if is_epic:
		final_color = Color(1.0, 0.84, 0.0, 1.0) # Dorado
		dmg_label.add_theme_constant_override("outline_size", 4)
		dmg_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	else:
		var min_color := Color(1.0, 0.0, 0.0, 1.0) 
		var max_color := Color(0.276, 0.005, 0.396, 1.0)
		# Daño a partir del cual se considera “máximo morado”
		var color_damage_cap := 120.0
		var t : float = clamp(float(dmg_int) / color_damage_cap, 0.0, 1.0)
		final_color = min_color.lerp(max_color, t)

		if was_crit:
			final_color = final_color.lightened(0.15)
			dmg_label.add_theme_constant_override("outline_size", 2)
			dmg_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	dmg_label.add_theme_color_override("font_color", final_color)
	dmg_label.modulate = Color.WHITE

	var root := get_tree().current_scene
	if root == null: return
	root.add_child(dmg_label)
	
	_animate_label(dmg_label)

func _animate_label(lbl: Label) -> void:
	var max_height := 140.0
	var min_height := 50.0
	var h := randf_range(min_height, max_height)
	var max_width_at_top := 160.0
	var half_width := (h / max_height) * (max_width_at_top * 0.5)
	var offset_x := randf_range(-half_width, half_width)
	var offset_y := -h
	var start_pos := global_position + Vector2(offset_x, offset_y)
	lbl.global_position = start_pos

	var total_travel := randf_range(40.0, 90.0)
	var amplitude := randf_range(10.0, 15.0)
	var waves := randf_range(1.5, 3.0)
	var move_time := 0.7
	var fade_time := 0.3

	var tween := lbl.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(lbl): return
			var y := -t * total_travel
			var x := sin(t * TAU * waves) * amplitude
			lbl.global_position = start_pos + Vector2(x, y)
	, 0.0, 1.0, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		lbl, "modulate:a", 0.0, fade_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(move_time - fade_time)

	tween.finished.connect(func() -> void:
		if is_instance_valid(lbl): lbl.queue_free()
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
	
	synergy_hp_mult = 1.0
	if synergy_eur_tier == 1: 
		synergy_hp_mult = 1.25
	elif synergy_eur_tier == 2: 
		synergy_hp_mult = 1.50
	
	if is_node_ready():
		_recalculate_stats_live()

func _recalculate_stats_live():
	if not npc_res: return
	var base_hp = max(1.0, npc_res.max_health)
	max_health = (base_hp + bonus_health) * synergy_hp_mult
	health = max_health
	_update_healthbar()
	_apply_bar_visuals()

# --- APLICAR GLOBAL STATS ---
func apply_passive_bonuses(p_health: float, p_damage: float, p_speed: float, p_crit_c: float, p_crit_d: float):
	bonus_health = p_health
	bonus_damage = p_damage
	bonus_speed = p_speed
	bonus_crit_chance = p_crit_c
	bonus_crit_damage = p_crit_d
	
	if is_node_ready():
		_recalculate_stats_live()

# CONTROLER BATTLE
func get_damage(target: npc) -> float:
	var val := npc_res.damage + bonus_damage
	
	# LÓGICA JAPONESA 
	is_last_attack_special = false
	
	if synergy_jap_tier > 0 and jap_special_ready:
		var mult = 1.0
		if synergy_jap_tier == 1: mult = 1.5
		elif synergy_jap_tier == 2: mult = 2.0
		val *= mult
		
		is_last_attack_special = true
		jap_special_ready = false 
	
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
		var min_flash_gap := 0.08
		if (not is_shocked) or shock_timer > min_flash_gap:
			shock_timer = 0.0
			is_shocked = true
			shock_material.set_shader_parameter("shock_time", shock_timer)
	
	var is_epic_hit = false
	if from and "is_last_attack_special" in from and from.is_last_attack_special:
		is_epic_hit = true
	
	_show_damage_text(amount, was_crit, is_epic_hit)

	# LÓGICA NÓRDICA
	if synergy_nor_tier > 0 and not nordica_heal_used:
		if health > 0 and (health / max_health) <= 0.25:
			nordica_heal_used = true
			var target_pct = 0.50 
			if synergy_nor_tier == 2: target_pct = 0.75 
			
			var heal_amt = (max_health * target_pct) - health
			if heal_amt > 0:
				health += heal_amt
				_show_heal_text(heal_amt)
	
	for ab in abilities:
		if ab: ab.on_take_damage(self, amount, from)
	_update_healthbar()
	if health <= 0.0:
		_die(from)
	if is_hovered:
		_refresh_tooltip()

func _die(killer: npc = null) -> void:

	_on_mouse_exited()
	if npc_res and npc_res.sfx_death:
		var tag := "death_enemy" if team == Team.ENEMY else "death_ally"
		play_sfx(npc_res.sfx_death, tag)

	for ab in abilities:
		if ab:
			ab.on_die(self, killer)

	emit_signal("died", self)
	queue_free()

func notify_before_attack(target: npc) -> void:
	attack_notified = false
	for ab in abilities:
		if ab: ab.on_before_attack(self, target)
func notify_after_attack(target: npc, dealt_damage: float, was_crit: bool) -> void:
	attack_count += 1
	for ab in abilities:
		if ab: ab.on_after_attack(self, target, dealt_damage, was_crit)

func notify_kill(victim: npc) -> void:
	for ab in abilities:
		if ab: ab.on_kill(self, victim)

func _process(delta: float) -> void:
	if is_shocked and shock_material:
		shock_timer += delta * 8.0 
		shock_material.set_shader_parameter("shock_time", shock_timer)
		if shock_timer > 0.3:
			is_shocked = false
			shock_material.set_shader_parameter("shock_time", 999.0)

# VISUAL: Texto Curación Nórdica (Verde Puro)
func _show_heal_text(amount: float) -> void:
	var heal_label: Label = DAMAGE_TEXT_SCENE.instantiate()
	var heal_int := int(round(amount))
	
	heal_label.text = "+" + str(heal_int)

	var base_font_size := 34.0
	var size_factor: float = clamp(0.7 + float(heal_int) / 60.0, 0.7, 2.5)
	var size := int(base_font_size * size_factor)

	heal_label.add_theme_font_size_override("font_size", size)

	heal_label.add_theme_color_override("font_color", Color(0.396, 1.0, 0.376, 1.0))
	heal_label.modulate = Color.WHITE

	var root := get_tree().current_scene
	if root == null: return
	root.add_child(heal_label)
	
	# Reutilizamos la animación definida para el daño
	_animate_label(heal_label)

func _apply_healthbar_offset_from_res() -> void:
	if not is_instance_valid(health_bar):
		return
	if npc_res == null:
		return

	health_bar.position = npc_res.health_bar_offset

func _setup_healthbar_z() -> void:
	if not is_instance_valid(health_bar):
		return

	health_bar.z_as_relative = false
	health_bar.z_index = 100

func play_sfx(stream: AudioStream, debug_tag: String = "") -> void:
	if stream == null:
		print("ERROR: Intenté reproducir un sonido pero el Resource es NULL. Tag: ", debug_tag)
		return
	if audio_player == null:
		print("ERROR: No encuentro el nodo $AudioPlayer en el NPC. Tag: ", debug_tag)
		return

	audio_player.stream = stream
	audio_player.play()

	# DEBUG
	var npc_name := ""
	if npc_res and npc_res.resource_path != "":
		npc_name = npc_res.resource_path.get_file().get_basename()

	var tag_text := debug_tag if debug_tag != "" else "generic"
	var team_text := "ALLY" if team == Team.ALLY else "ENEMY"

	print("[SFX]", tag_text, "| NPC:", npc_name, "| Team:", team_text)

func charge_jap_synergy() -> void:
	if synergy_jap_tier > 0:
		jap_special_ready = true
		# Opcional: Aquí podrías añadir un efecto visual (brillo) para indicar que está cargado
func _on_mouse_entered() -> void:
	if team != Team.ENEMY: return
	
	is_hovered = true # Marcamos que estamos encima
	
	if health <= 0: return
	_refresh_tooltip()

func _on_mouse_exited() -> void:
	is_hovered = false # Marcamos que salimos
	var tooltip_node = get_tree().get_first_node_in_group("tooltip")
	if tooltip_node:
		tooltip_node.hide_tooltip()

# NUEVA FUNCIÓN HELPER
func _refresh_tooltip() -> void:
	var tooltip_node = get_tree().get_first_node_in_group("tooltip")
	if tooltip_node and tooltip_node.has_method("show_npc_tooltip"):
		tooltip_node.show_npc_tooltip(self)
