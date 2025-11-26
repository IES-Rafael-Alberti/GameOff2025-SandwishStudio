extends Node2D
class_name RuletaScene

signal roulette_spin_started

# --- CONFIGURACIÓN DE FÍSICA GENERAL ---
@export_group("Physics")
@export var friction: float = 0.985
@export var min_impulse_force: float = 60.0 
@export var min_impulse_random_range: Vector2 = Vector2(1.0, 5) 
@export var bounce_angle: float = 12.0
@export var bounce_time: float = 0.08

# --- CONFIGURACIÓN DE LA PALANCA ---
@export_group("Lever Mechanics")
@export var lever_max_angle: float = 75.0
@export var drag_sensitivity: float = 0.6
@export var activation_threshold: float = 0.75
@export var ratchet_step_angle: float = 10.0 

# --- CONFIGURACIÓN DE IMPACTO ROMANO REALISTA (HDR) ---
@export_group("Roman Impact Juice")
@export var tension_color: Color = Color(1.5, 0.5, 0.5)
# Usamos un valor muy alto para el HDR (Efecto de brillo intenso)
@export var sun_reflection_color: Color = Color(4.0, 3.5, 3.0, 1.0) 

# Define cómo se "aplasta" la pieza al ser golpeada.
@export var impact_squash_scale: Vector2 = Vector2(1.15, 0.9) 

# Color final para el ganador (Oro fundido HDR)
@export var winner_highlight_color: Color = Color(2.5, 2.0, 0.5, 1.0)

@export var shake_intensity_lever: float = 3.0
@export var screen_shake_force: float = 6.0
@export var zoom_strength: float = 0.05

@export_subgroup("Particle References")
@export var lever_release_particles: GPUParticles2D
@export var win_particles: GPUParticles2D

# --- REFERENCIAS VISUALES ROMANAS ---
@export_group("Roman FX")
@export var spin_dust_particles: CPUParticles2D 
@export var needle_sparks_particles: CPUParticles2D 

@export_subgroup("Audio & Camera")
@export var game_camera: Camera2D
@export var lever_ratchet_audio: AudioStreamPlayer 

# --- REFERENCIAS INTERNAS ---
@onready var slots_container: Node2D = $SpriteRuleta/SlotsContainer
@onready var lever_sprite: Sprite2D = $Lever
@onready var lever_area: Area2D = $Lever/AreaLever
@onready var manecilla_area: Area2D = $Manecilla
@onready var manecilla_sprite: Sprite2D = $Manecilla/SpriteManecilla
@onready var ticker_audio: AudioStreamPlayer = $Manecilla/AudioStreamPlayer

# REFERENCIAS A LOS ICONOS DE SINERGIA
@onready var icon_japonesa = $Japonesa
@onready var icon_nordica = $Nordica
@onready var icon_europea = $Europea

# --- MEMORIA DE POSICIONES ---
@onready var lever_origin_pos: Vector2 = $Lever.position
@onready var roulette_origin_pos: Vector2 = $SpriteRuleta.position
var camera_origin_zoom: Vector2 = Vector2.ONE
var lever_origin_rotation: float = 0.0 

# --- ESTADOS ---
enum State { IDLE, SPINNING }
var state: State = State.IDLE
var is_interactive: bool = true

# Variables lógica
var is_dragging_lever: bool = false
var drag_start_mouse_y: float = 0.0
var current_lever_rotation: float = 0.0
var inertia: float = 0.0
var _selected_area: Area2D = null
var bouncing: bool = false

# Variables FX
var shake_trauma: float = 0.0
var target_zoom: Vector2 = Vector2.ONE
var last_ratchet_angle: float = 0.0

# --- INICIO ---
func _ready() -> void:
	if has_node("/root/GlobalStats"):
		GlobalStats.roulette_scene_ref = self
	
	lever_origin_pos = lever_sprite.position
	roulette_origin_pos = $SpriteRuleta.position
	lever_origin_rotation = lever_sprite.rotation_degrees 
	
	if game_camera:
		camera_origin_zoom = game_camera.zoom
		target_zoom = camera_origin_zoom
	
	if GlobalSignals:
		GlobalSignals.piece_type_deleted.connect(_on_piece_type_deleted)
	
	if lever_area:
		lever_area.input_pickable = true
		lever_area.input_event.connect(_on_lever_input_event)
		
	if manecilla_area:
		manecilla_area.area_entered.connect(_on_manecilla_area_entered)
	
	update_ui_synergies()

# --- INPUT Y PALANCA ---
func _on_lever_input_event(_viewport, event, _shape_idx):
	if not is_interactive or state != State.IDLE: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_dragging()

func _input(event):
	if is_dragging_lever and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			release_lever()
			
	if is_dragging_lever and event is InputEventMouseMotion:
		update_lever_drag()

func start_dragging():
	is_dragging_lever = true
	drag_start_mouse_y = get_global_mouse_position().y
	last_ratchet_angle = 0.0 
	
	var t = create_tween()
	t.tween_property(lever_sprite, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK)

func is_moving():
	return state != State.IDLE

func update_lever_drag():
	var current_mouse_y = get_global_mouse_position().y
	var diff = current_mouse_y - drag_start_mouse_y
	if diff < 0: diff = 0
	
	var target_angle_offset = diff * drag_sensitivity
	current_lever_rotation = clamp(target_angle_offset, 0.0, lever_max_angle)
	
	lever_sprite.rotation_degrees = lever_origin_rotation + current_lever_rotation
	
	if lever_ratchet_audio and abs(current_lever_rotation - last_ratchet_angle) > ratchet_step_angle:
		last_ratchet_angle = current_lever_rotation
		lever_ratchet_audio.pitch_scale = randf_range(0.9, 1.1)
		lever_ratchet_audio.play()
	
	var progress = current_lever_rotation / lever_max_angle
	lever_sprite.modulate = Color.WHITE.lerp(tension_color, progress)
	
	var stretch = 1.0 + (progress * 0.15)
	var squash = 1.0 - (progress * 0.05)
	lever_sprite.scale = Vector2(squash, stretch)
	
	if progress > 0.9:
		var shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity_lever * (progress - 0.9) * 10
		lever_sprite.position = lever_origin_pos + shake_offset
	else:
		lever_sprite.position = lever_origin_pos

func release_lever():
	is_dragging_lever = false
	
	var percentage_pulled = current_lever_rotation / lever_max_angle
	
	if percentage_pulled >= activation_threshold:
		trigger_spin()
		shake_trauma = 0.6
		
		if lever_release_particles:
			lever_release_particles.restart()
			lever_release_particles.emitting = true
		
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(lever_sprite, "rotation_degrees", lever_origin_rotation - 25.0, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.chain().tween_property(lever_sprite, "rotation_degrees", lever_origin_rotation, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.chain().tween_callback(func(): lever_sprite.position = lever_origin_pos)
		t.parallel().tween_property(lever_sprite, "modulate", Color.WHITE, 0.3)
		t.parallel().tween_property(lever_sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)
		
	else:
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(lever_sprite, "rotation_degrees", lever_origin_rotation, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_property(lever_sprite, "modulate", Color.WHITE, 0.2)
		t.tween_property(lever_sprite, "scale", Vector2.ONE, 0.3)
		t.chain().tween_callback(func(): lever_sprite.position = lever_origin_pos)
		GlobalSignals.emit_signal("roulette_state_changed", true)

# --- LÓGICA CENTRAL ---
func trigger_spin():
	_reset()
	state = State.SPINNING
	_selected_area = null
	var pull_factor = current_lever_rotation / lever_max_angle
	var base_force = min_impulse_force * pull_factor
	var random_multiplier = randf_range(min_impulse_random_range.x, min_impulse_random_range.y)
	inertia = base_force * random_multiplier
	roulette_spin_started.emit()

func _process(delta: float) -> void:
	if state == State.SPINNING:
		_spin(delta)
		_process_zoom(delta)
		
	if shake_trauma > 0:
		shake_trauma = max(shake_trauma - delta * 2.0, 0)
		if state == State.IDLE:
			shake_trauma = 0
			$SpriteRuleta.position = roulette_origin_pos
			if game_camera: game_camera.zoom = camera_origin_zoom
		else:
			_apply_screen_shake()

func _spin(_delta: float):
	$SpriteRuleta.rotation_degrees += inertia
	
	# --- MEJORA: Bamboleo del Eje (Wobble) ---
	# Simula que la rueda es pesada y el eje no está perfectamente centrado.
	var wobble_offset = Vector2(
		sin(deg_to_rad($SpriteRuleta.rotation_degrees)), 
		cos(deg_to_rad($SpriteRuleta.rotation_degrees))
	) * 2.0 
	
	# Aplicamos el bamboleo si no hay terremoto mayor (screen shake) ocurriendo
	if shake_trauma <= 0:
		$SpriteRuleta.position = roulette_origin_pos + wobble_offset

	# Lógica de Polvo al girar rápido
	if spin_dust_particles:
		if inertia > 4.0:
			spin_dust_particles.emitting = true
			var dust_intensity = remap(clamp(inertia, 0, 50), 0, 50, 0.2, 0.8)
			if "amount_ratio" in spin_dust_particles:
				spin_dust_particles.amount_ratio = dust_intensity
		else:
			spin_dust_particles.emitting = false

	inertia *= friction

	if abs(inertia) < 0.05:
		inertia = 0
		if spin_dust_particles: spin_dust_particles.emitting = false
		$SpriteRuleta.modulate = Color.WHITE 
		_reward()
		_reset()

func _process_zoom(delta: float):
	if not game_camera: return
	if inertia < 15.0 and inertia > 0.1:
		var target = camera_origin_zoom * (1.0 + zoom_strength)
		game_camera.zoom = game_camera.zoom.lerp(target, delta * 3.0)
	else:
		game_camera.zoom = game_camera.zoom.lerp(camera_origin_zoom, delta * 4.0)

func _apply_screen_shake():
	var amount = shake_trauma * shake_trauma
	var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * screen_shake_force * amount
	# Sumamos el offset a la posición original (ignorando el wobble durante el shake fuerte)
	$SpriteRuleta.position = roulette_origin_pos + offset

# --- MANECILLA Y FÍSICA MEJORADA ---
func _on_manecilla_area_entered(area: Area2D) -> void:
	if state != State.SPINNING: return
	_selected_area = area
	_bounce_manecilla()
	_impact_slot(area) 
	
	# --- MEJORA FÍSICA: Fricción por Impacto ---
	# Cada golpe con un slot frena un poco la rueda ("resistencia mecánica")
	var resistance = 0.5 
	if inertia > 0:
		inertia = max(inertia - resistance, 0)
	
	# --- MEJORA: Micro-Shake Rítmico ---
	# Pequeño golpe de cámara con cada "click", solo si la velocidad es moderada
	if inertia < 25.0:
		shake_trauma = min(shake_trauma + 0.05, 0.3)

func _bounce_manecilla():
	if bouncing: return
	bouncing = true
	
	var spr = $Manecilla/SpriteManecilla
	var orig_pos = spr.position
	var orig_rot = spr.rotation_degrees
	
	# --- MEJORA: Rebote Limitado (Saturación) ---
	# Evitamos que la manecilla gire locamente a altas velocidades
	var max_bounce_angle = 45.0
	var target_angle = -bounce_angle * (inertia / 10.0)
	target_angle = clamp(target_angle, -max_bounce_angle, -5.0) # Siempre un mínimo rebote
	
	spr.rotation_degrees = target_angle
	# Desplazamiento vertical limitado
	spr.position.y = clamp(orig_pos.y - (abs(target_angle) * 0.1), orig_pos.y - 5.0, orig_pos.y)
	
	# --- MEJORA: Chispas Físicas Direccionales ---
	if needle_sparks_particles:
		# Las chispas salen en la dirección del giro (derecha)
		needle_sparks_particles.direction = Vector2(1.0, -0.5)
		needle_sparks_particles.spread = 25.0
		
		var speed_factor = clamp(inertia, 0, 50)
		# Velocidad y cantidad dependen de la inercia actual
		needle_sparks_particles.initial_velocity_min = 50.0 + (speed_factor * 8.0)
		needle_sparks_particles.initial_velocity_max = 100.0 + (speed_factor * 12.0)
		
		# Ajuste de cantidad (simulado si son CPUParticles one_shot)
		if speed_factor > 5.0:
			needle_sparks_particles.restart()
			needle_sparks_particles.emitting = true
	
	# Audio del "Clack"
	if ticker_audio:
		var pitch = remap(clamp(inertia, 0, 50), 0, 50, 0.8, 1.2)
		ticker_audio.pitch_scale = pitch
		ticker_audio.play()
	
	var t = create_tween()
	t.set_parallel(true)
	# Vuelta elástica rápida
	t.tween_property(spr, "rotation_degrees", orig_rot, bounce_time * 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(spr, "position", orig_pos, bounce_time * 1.5)
	t.chain().tween_callback(func(): bouncing = false)

# --- IMPACTO VISUAL (HDR & FLASH) ---
func _impact_slot(area: Area2D) -> void:
	if not "slot_index" in area: return
	var slot_index: int = area.slot_index
	
	var count = slots_container.get_child_count()
	var safe_index = wrapi(slot_index, 0, count)
	var slot_root = slots_container.get_child(safe_index)
	
	if slot_root and slot_root.has_node("slot"):
		var actual_slot = slot_root.get_node("slot")
		if actual_slot is CanvasItem:
			if slot_root.has_method("kill_highlight_tween"):
				slot_root.kill_highlight_tween()
			
			actual_slot.material = null
			
			var t = create_tween()
			t.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			
			# --- MEJORA: Flash HDR "Explosivo" ---
			# Usamos el color sun_reflection_color (muy brillante) para quemar la imagen
			t.tween_property(actual_slot, "scale", impact_squash_scale, 0.04)
			t.parallel().tween_property(actual_slot, "modulate", sun_reflection_color, 0.04)
			
			# Fase de enfriamiento (Cool down)
			t.chain().tween_property(actual_slot, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)
			t.parallel().tween_property(actual_slot, "modulate", Color.WHITE, 0.2) # Vuelve a normalidad rápido

func _reward(): 
	get_current_synergies() 
	
	if win_particles:
		win_particles.restart()
		win_particles.emitting = true

	if not _selected_area or not "slot_index" in _selected_area:
		GlobalSignals.emit_signal("combat_requested", null)
		return
	
	var index: int = _selected_area.slot_index
	if index >= slots_container.get_child_count():
		GlobalSignals.emit_signal("combat_requested", null)
		return

	var winning_slot_root = slots_container.get_child(index)

	if winning_slot_root and winning_slot_root.has_node("slot"):
		var actual_slot = winning_slot_root.get_node("slot")
		if actual_slot is CanvasItem:
			
			# --- MEJORA: Palpito de Victoria (Oro Fundido) ---
			if winning_slot_root.has_method("kill_highlight_tween"):
				winning_slot_root.kill_highlight_tween()

			var t = create_tween()
			t.set_loops(3) # Tres latidos brillantes
			t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			
			# Sube a oro HDR y baja a blanco
			t.tween_property(actual_slot, "modulate", winner_highlight_color, 0.15)
			t.tween_property(actual_slot, "modulate", Color.WHITE, 0.15)
			
			t.finished.connect(func(): 
				actual_slot.modulate = Color(1.2, 1.1, 1.0) # Brillo residual
			)

		if actual_slot and "current_piece_data" in actual_slot:
			var piece = actual_slot.current_piece_data
			if piece and piece.get("piece_origin"):
				print("¡Pieza obtenida: %s!" % piece.resource_name)
				GlobalSignals.emit_signal("combat_requested", piece.piece_origin)
				return
	
	GlobalSignals.emit_signal("combat_requested", null)

func _reset():
	_selected_area = null
	inertia = 0.0
	bouncing = false
	state = State.IDLE
	shake_trauma = 0.0
	$SpriteRuleta.position = roulette_origin_pos
	
	lever_sprite.position = lever_origin_pos
	lever_sprite.rotation_degrees = lever_origin_rotation 
	lever_sprite.material = null 
	
	for slot_root in slots_container.get_children():
		if slot_root.has_node("slot"):
			var actual_slot = slot_root.get_node("slot")
			if actual_slot is CanvasItem:
				if slot_root.has_method("kill_highlight_tween"):
					slot_root.kill_highlight_tween()
				actual_slot.modulate = Color.WHITE
				actual_slot.scale = Vector2.ONE 
				actual_slot.material = null 
	
	if win_particles:
		win_particles.emitting = false
	
	if game_camera:
		var t = create_tween()
		t.tween_property(game_camera, "zoom", camera_origin_zoom, 0.5).set_trans(Tween.TRANS_CUBIC)

	GlobalSignals.emit_signal("roulette_state_changed", false)
	update_ui_synergies()

func reset_rotation_to_zero():
	if state == State.IDLE:
		$SpriteRuleta.rotation_degrees = 0.0
		$SpriteRuleta.position = roulette_origin_pos

func set_interactive(interactive: bool):
	is_interactive = interactive
	if lever_sprite:
		lever_sprite.modulate = Color.WHITE if interactive else Color(0.5, 0.5, 0.5)

func _on_piece_type_deleted(piece_data: PieceData):
	if not piece_data:
		return
		
	print("... Ruleta ha recibido orden de borrado para: %s" % piece_data.resource_name)
	
	for slot_root in slots_container.get_children():
		if not slot_root.has_node("slot"):
			continue
			
		var slot = slot_root.get_node("slot")
		
		if slot and "current_piece_data" in slot:
			if slot.current_piece_data == piece_data:
				if slot.has_method("clear_slot"):
					print("... ... Limpiando slot %s" % slot.name)
					slot.clear_slot()
					update_ui_synergies()
				else:
					push_warning("Ruleta: El slot %s no tiene método clear_slot()" % slot.name)

# --- SISTEMA DE SINERGIAS CENTRALIZADO ---
func _calculate_counts() -> Dictionary:
	var unique_ids_jap = {}
	var unique_ids_nor = {}
	var unique_ids_eur = {}
	
	if not slots_container: 
		return {"jap_count":0, "nor_count":0, "eur_count":0}

	for slot_root in slots_container.get_children():
		if not slot_root.has_node("slot"): continue
		var actual_slot = slot_root.get_node("slot")
		
		if "current_piece_data" in actual_slot and actual_slot.current_piece_data:
			var data = actual_slot.current_piece_data
			if "piece_origin" in data and data.piece_origin is PieceRes:
				var res = data.piece_origin
				var id = res.id
				match res.race:
					PieceRes.PieceRace.JAPONESA: unique_ids_jap[id] = true
					PieceRes.PieceRace.NORDICA: unique_ids_nor[id] = true
					PieceRes.PieceRace.EUROPEA: unique_ids_eur[id] = true

	return {
		"jap_count": unique_ids_jap.size(),
		"nor_count": unique_ids_nor.size(),
		"eur_count": unique_ids_eur.size()
	}

func update_ui_synergies():
	var counts = _calculate_counts()
	
	if icon_japonesa and icon_japonesa.has_method("update_synergy_count"):
		icon_japonesa.update_synergy_count(counts["jap_count"])
		
	if icon_nordica and icon_nordica.has_method("update_synergy_count"):
		icon_nordica.update_synergy_count(counts["nor_count"])
		
	if icon_europea and icon_europea.has_method("update_synergy_count"):
		icon_europea.update_synergy_count(counts["eur_count"])

func get_current_synergies() -> Dictionary:
	var counts = _calculate_counts()
	update_ui_synergies()
	
	var result = {"jap": 0, "nor": 0, "eur": 0}
	
	if counts["jap_count"] >= 4: result["jap"] = 2
	elif counts["jap_count"] >= 2: result["jap"] = 1
		
	if counts["nor_count"] >= 4: result["nor"] = 2
	elif counts["nor_count"] >= 2: result["nor"] = 1
		
	if counts["eur_count"] >= 4: result["eur"] = 2
	elif counts["eur_count"] >= 2: result["eur"] = 1
	
	return result
