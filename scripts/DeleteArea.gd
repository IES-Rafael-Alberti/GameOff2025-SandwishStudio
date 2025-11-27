extends Panel

# --- REFERENCIAS ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var sfx_player: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer")
@onready var particles: CPUParticles2D = get_node_or_null("CPUParticles2D")
@onready var sell_sprite: Sprite2D = get_node_or_null("SellSprite")

# --- CARGAMOS LA ESCENA ORIGINAL DEL SLOT ---
const SLOT_SCENE = preload("res://scenes/inventory_slot.tscn")

var normal_color = Color.WHITE
var hover_color = Color(1.2, 1.2, 1.1)
var roman_phrases = ["¡GLORIA!", "¡PECUNIA!", "¡AVE CAESAR!", "¡TRIBUTUM!", "¡AUREUS!", "¡DIVITIAE!"]
var _is_roulette_spinning: bool = false

func _ready() -> void:
	if sprite: sprite.modulate = normal_color
	if sell_sprite: 
		sell_sprite.visible = false
		sell_sprite.modulate.a = 0.0

	self.mouse_exited.connect(_on_mouse_exited)
	if GlobalSignals.has_signal("roulette_state_changed"):
		GlobalSignals.roulette_state_changed.connect(_on_roulette_state_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if sprite:
			var t = create_tween()
			t.tween_property(sprite, "modulate", normal_color, 0.2)
			t.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.2)

## ------------------------------------------------------------------
## Drag-and-Drop
## ------------------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var game_manager = get_tree().current_scene
	if game_manager and "current_state" in game_manager:
		if game_manager.current_state == 2 or game_manager.current_state == 3:
			return false
	if _is_roulette_spinning: return false

	if sprite:
		sprite.modulate = hover_color
		# Latido suave
		var scale_pulse = 1.0 + (sin(Time.get_ticks_msec() * 0.015) * 0.03)
		sprite.scale = Vector2(scale_pulse, scale_pulse)
		
	if data is Dictionary and "data" in data: return data.data is Resource 
	return data is Resource

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# Recuperar forma del pozo
	if sprite:
		var t = create_tween()
		t.tween_property(sprite, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_ELASTIC)
		t.parallel().tween_property(sprite, "modulate", normal_color, 0.1)

	var item_to_delete: Resource = null
	if data is Dictionary and "data" in data:
		item_to_delete = data.data
	elif data is Resource:
		item_to_delete = data
		
	if item_to_delete:
		# Ejecutar la caída centrada y realista
		_play_aligned_hole_drop(item_to_delete, at_position)
	else:
		push_warning("DeleteArea: Datos vacíos.")

func _on_mouse_exited() -> void:
	if sprite:
		var t = create_tween()
		t.tween_property(sprite, "modulate", normal_color, 0.2)
		t.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.2)

func _on_roulette_state_changed(is_spinning: bool):
	_is_roulette_spinning = is_spinning
	if is_spinning and sprite: sprite.modulate = normal_color

## ------------------------------------------------------------------
## ANIMACIÓN: ALINEACIÓN PERFECTA Y CAÍDA VERTICAL
## ------------------------------------------------------------------

func _play_aligned_hole_drop(item: Resource, drop_pos: Vector2):
	# 1. Crear clon del slot
	var visual_slot = SLOT_SCENE.instantiate()
	visual_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_slot.set_script(null)
	add_child(visual_slot)
	
	# 2. Configurar imagen
	var texture_btn = visual_slot.get_node_or_null("TextureButton")
	if texture_btn:
		texture_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_btn.disabled = true
		var item_icon_node = texture_btn.get_node_or_null("ItemIcon")
		if item_icon_node:
			var tex = null
			if "sprite" in item and item.sprite: tex = item.sprite
			elif "texture" in item and item.texture: tex = item.texture
			elif "icon" in item and item.icon: tex = item.icon
			if tex: item_icon_node.texture = tex
		
		# Limpiar etiquetas
		for child in texture_btn.get_children():
			if child is Label or child.name.contains("Label"): child.visible = false
	if visual_slot.has_node("UsesLabel"): visual_slot.get_node("UsesLabel").visible = false

	# 3. Posición inicial (donde soltaste el mouse)
	visual_slot.size = Vector2(100, 100)
	visual_slot.pivot_offset = visual_slot.size / 2.0
	visual_slot.position = drop_pos - (visual_slot.size / 2.0)
	visual_slot.rotation_degrees = randf_range(-5, 5) # Leve imperfección inicial

	var center_pos = (size / 2.0) - (visual_slot.size / 2.0)
	var t = create_tween()
	
	# --- FASE 1: ALINEARSE (0.15s) ---
	# La pieza viaja AL CENTRO y se detiene sobre el agujero
	t.set_parallel(true)
	t.tween_property(visual_slot, "position", center_pos, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Se pone recta y crece un pelín (levita sobre el agujero)
	t.tween_property(visual_slot, "rotation_degrees", 0.0, 0.15)
	t.tween_property(visual_slot, "scale", Vector2(1.1, 1.1), 0.15)
	t.tween_property(visual_slot, "modulate", Color(1.2, 1.2, 1.2), 0.15) # Luz cenital

	# --- FASE 2: CAER POR EL AGUJERO (0.25s) ---
	# Una vez centrada, cae hacia abajo (Scale -> 0)
	t.chain().set_parallel(true)
	t.set_ease(Tween.EASE_IN) # Empieza a caer y acelera
	t.set_trans(Tween.TRANS_BACK) # TRANS_BACK hace un pequeño "impulso" antes de caer
	
	# Se encoge hacia su propio centro (efecto profundidad)
	t.tween_property(visual_slot, "scale", Vector2(0.0, 0.0), 0.25)
	# Se vuelve negra (sombra)
	t.tween_property(visual_slot, "modulate", Color(0.0, 0.0, 0.0), 0.25)
	
	# --- FASE 3: IMPACTO ---
	t.chain().tween_callback(func():
		visual_slot.queue_free()
		_trigger_reward_effects()
		GlobalSignals.item_deleted.emit(item)
	)

func _trigger_reward_effects():
	var center_pos = size / 2.0
	
	if sfx_player:
		sfx_player.pitch_scale = randf_range(1.1, 1.3)
		sfx_player.play()

	# El pozo rebota al "comer"
	if sprite:
		var t = create_tween()
		sprite.scale = Vector2(1.1, 1.1)
		t.tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE)
		sprite.modulate = Color(2.0, 2.0, 2.0)
		t.parallel().tween_property(sprite, "modulate", normal_color, 0.3)

	if particles:
		particles.restart()
		particles.emitting = true

	# --- DINERO SALE HACIA ARRIBA ---
	if sell_sprite:
		sell_sprite.visible = true
		sell_sprite.position = center_pos + Vector2(0, 40) # Sale de lo profundo
		sell_sprite.scale = Vector2.ZERO
		sell_sprite.modulate.a = 1.0
		sell_sprite.z_index = 100
		
		var t_coin = create_tween()
		t_coin.set_ease(Tween.EASE_OUT)
		t_coin.set_trans(Tween.TRANS_BACK)
		
		# Sube con fuerza
		t_coin.tween_property(sell_sprite, "scale", Vector2(1.3, 1.3), 0.3)
		t_coin.parallel().tween_property(sell_sprite, "position:y", center_pos.y - 120, 0.8)
		
		# Cae flotando
		var t_fall = create_tween()
		t_fall.tween_interval(0.6)
		t_fall.tween_property(sell_sprite, "position:y", center_pos.y - 90, 0.4).set_ease(Tween.EASE_IN)
		t_fall.parallel().tween_property(sell_sprite, "modulate:a", 0.0, 0.4)
		t_fall.tween_callback(func(): sell_sprite.visible = false)

	_spawn_roman_text(center_pos)

func _spawn_roman_text(pos: Vector2):
	var label = Label.new()
	label.text = roman_phrases.pick_random()
	
	if ResourceLoader.exists("res://assets/fonts/Romanica.ttf"):
		var font = load("res://assets/fonts/Romanica.ttf")
		label.add_theme_font_override("font", font)
	
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	
	add_child(label)
	label.position = pos - (label.get_minimum_size() / 2)
	label.position.y -= 50
	label.scale = Vector2.ZERO
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(label, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK)
	t.tween_property(label, "position:y", label.position.y - 90, 1.5).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.8)
	t.chain().tween_callback(label.queue_free)
