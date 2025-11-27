extends Panel

@export var max_glow_alpha := 0.7
@export var max_scale := 1.0
@export var min_scale := 0.6
@export var attraction_radius := 120.0
@export var highlight_speed := 10.0

# --- TEXTURAS DE TIER ---
@export_group("Tier Textures")
@export var tier_bronze_texture: Texture2D
@export var tier_silver_texture: Texture2D
@export var tier_gold_texture: Texture2D

# --- SHADER ---
const OUTLINE_SHADER = preload("res://shaders/outline_highlight.gdshader")
var highlight_material: ShaderMaterial

var glow_sprite: Sprite2D
var particles: CPUParticles2D
var piece_over: Node = null
var occupied := false
var current_piece_data: Resource = null 
var current_piece_count: int = 0

# Referencias a la jerarquía
@onready var ruleta: Node = get_parent().get_parent().get_parent().get_parent()
@onready var item_icon: TextureRect = $ItemIcon
@onready var piece_texture_rect: TextureRect = $ItemIcon/PieceTextureRect
@onready var count_label: TextureRect = $ItemIcon/CountLabel
@onready var tier_label: TextureRect = $ItemIcon/TierLabel

func _ready():
	# 1. Configuración Visual del Highlight
	if not has_node("Highlight"):
		var h = Node2D.new()
		h.name = "Highlight"
		add_child(h)
		h.z_index = 10
		glow_sprite = Sprite2D.new()
		glow_sprite.centered = true
		glow_sprite.modulate = Color(1,1,0,0)
		glow_sprite.scale = Vector2(min_scale,min_scale)
		h.add_child(glow_sprite)
		particles = CPUParticles2D.new()
		particles.amount = 6
		particles.one_shot = false
		particles.emitting = false
		h.add_child(particles)
	else:
		glow_sprite = get_node("Highlight/Glow")
		particles = get_node("Highlight/Particles")

	# 2. Configuración de la imagen
	if not item_icon:
		push_error("RouletteSlot: ¡No se encontró el nodo 'ItemIcon'!")
	else:
		item_icon.visible = false # Ocultamos al inicio
	
	if not piece_texture_rect:
		push_error("RouletteSlot: ¡No se encontró el nodo hijo 'PieceTextureRect'!")
	else:
		piece_texture_rect.visible = false 
		piece_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
	self.gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# 3. Configurar Shader
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = OUTLINE_SHADER
	highlight_material.set_shader_parameter("width", 5.0)
	highlight_material.set_shader_parameter("color", Color.WHITE)
	
	if GlobalSignals:
		GlobalSignals.piece_count_changed.connect(_on_piece_count_changed)

	clear_slot()

func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	if not occupied:
		return
		
	if ruleta and ruleta.has_method("is_moving"):
		if ruleta.is_moving() or not ruleta.is_interactive:
			return

	GlobalSignals.piece_returned_from_roulette.emit(current_piece_data)
	clear_slot()
	GlobalSignals.synergy_update_requested.emit()
	
func _on_mouse_entered() -> void:
	if occupied and item_icon:
		item_icon.material = highlight_material

func _on_mouse_exited() -> void:
	if item_icon:
		item_icon.material = null

# --- DRAG & DROP --
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Verificaciones de estado de la ruleta (no cambiar)
	if ruleta and ruleta.has_method("is_moving"):
		if ruleta.is_moving() or not ruleta.is_interactive:
			return false
	if data is Dictionary and "data" in data:
		if data.data is PieceData:
			return data.data.uses > 0
			
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if occupied and current_piece_data:
		GlobalSignals.piece_returned_from_roulette.emit(current_piece_data)
	occupied = true
	current_piece_data = data.data
	
	if "count" in data:
		current_piece_count = data.count
	else:
		current_piece_count = 1 
	
	if current_piece_data and "icon" in current_piece_data:
		if current_piece_data.icon:
			piece_texture_rect.texture = current_piece_data.icon
			piece_texture_rect.visible = true 
			if item_icon:
				item_icon.visible = true 
				
				# --- CAMBIO IMPORTANTE: Usar call_deferred ---
				call_deferred("_play_appearance_effect")
				# ---------------------------------------------

	GlobalSignals.piece_placed_on_roulette.emit(current_piece_data)
	GlobalSignals.synergy_update_requested.emit()
	_refresh_visuals()

# --- ACTUALIZACIÓN DE DATOS ---

func _on_piece_count_changed(piece_data: Resource, _new_count: int) -> void:
	if not occupied or not current_piece_data:
		return
		
	if piece_data is PieceData and current_piece_data is PieceData:
		# Comprobamos si es la misma pieza (usando piece_origin como identificador único)
		if piece_data.piece_origin == current_piece_data.piece_origin:
			# --- CAMBIO: Actualizar la cantidad localmente ---
			current_piece_count = _new_count
			_refresh_visuals()
func _refresh_visuals():
	if not current_piece_data: return
	
	# Salvaguarda: Aseguramos que el ItemIcon sea visible si hay datos
	if item_icon and not item_icon.visible:
		item_icon.visible = true
		
	# --- CAMBIO: Usar la variable local current_piece_count ---
	# Ya no llamamos a _get_total_copies aquí
	_update_tier_and_members(current_piece_count)
	# ----------------------------------------------------------
func _get_total_copies(data: Resource) -> int:
	var inventory_node = get_tree().root.find_child("Inventory", true, false)
	if inventory_node and inventory_node.has_method("get_item_count"):
		return inventory_node.get_item_count(data)
	return 1

# --- LÓGICA VISUAL (Tier + Members) ---

func _update_tier_and_members(count: int) -> void:
	if not current_piece_data: return
	# A. ACTUALIZAR TIER (Marco de rareza) - Lógica reforzada
	if tier_label:
		tier_label.visible = true
		if count == 1:
			tier_label.texture = tier_bronze_texture
		elif count == 2:
			tier_label.texture = tier_silver_texture
		elif count >= 3:
			tier_label.texture = tier_gold_texture
		else:
			# Si count es 0 o negativo (error), ocultamos
			tier_label.visible = false
	
	# B. ACTUALIZAR MEMBERS (Número de unidades)
	if count_label and current_piece_data is PieceData:
		count_label.visible = true
		
		var tier_key = "BRONCE"
		if count == 2: tier_key = "PLATA"
		elif count >= 3: tier_key = "ORO"
		
		var members_num = 1
		if current_piece_data.piece_origin and "stats" in current_piece_data.piece_origin:
			var stats = current_piece_data.piece_origin.stats
			if stats.has(tier_key) and stats[tier_key].has("members"):
				members_num = stats[tier_key]["members"]
		
		var visual_num = clampi(members_num, 1, 14)
		var path = "res://assets/numeros/%d.png" % visual_num
		
		if ResourceLoader.exists(path):
			count_label.texture = load(path)
		else:
			count_label.visible = false

func clear_slot():
	occupied = false
	current_piece_data = null
	current_piece_count = 0
	
	# Ocultamos todo el contenedor
	if item_icon:
		item_icon.visible = false
		item_icon.material = null
	
	if piece_texture_rect:
		piece_texture_rect.visible = false
		piece_texture_rect.texture = null
		
	if tier_label: tier_label.visible = false
	if count_label: count_label.visible = false
	
func _process(delta):
	if piece_over:
		var dist = piece_over.global_position.distance_to(global_position)
		var factor = clamp(1.0 - float(dist) / float(attraction_radius), 0.0, 1.0)
		glow_sprite.modulate.a = lerp(float(glow_sprite.modulate.a), max_glow_alpha * factor, delta * highlight_speed)
		var target_scale = lerp(float(min_scale), float(max_scale), factor)
		glow_sprite.scale = glow_sprite.scale.lerp(Vector2(target_scale, target_scale), delta * highlight_speed)
		particles.emitting = factor > 0.3
	else:
		glow_sprite.modulate.a = lerp(float(glow_sprite.modulate.a), 0.0, delta * highlight_speed)
		glow_sprite.scale = glow_sprite.scale.lerp(Vector2(min_scale, min_scale), delta * highlight_speed)
		particles.emitting = false
		
func _play_appearance_effect() -> void:
	if not item_icon: return
	
	# 1. Guardar la escala actual (para volver a ella luego)
	var current_scale = item_icon.scale
	if current_scale.length_squared() < 0.01:
		current_scale = Vector2.ONE

	# 2. CORRECCIÓN DE PIVOTE Y POSICIÓN (La solución al desplazamiento)
	# Solo recalculamos si el pivote no está ya en el centro
	var target_pivot = item_icon.size / 2.0
	if item_icon.pivot_offset != target_pivot:
		# Calculamos dónde está el centro visualmente AHORA MISMO
		# Asumimos que el pivote anterior era (0,0), que es el defecto
		var visual_center_global = item_icon.global_position + (item_icon.size / 2.0 * current_scale)
		
		# Cambiamos el pivote al centro
		item_icon.pivot_offset = target_pivot
		
		# Recalculamos la posición global para que el centro visual siga donde estaba
		# Fórmula: NuevaPos = CentroVisualAnterior - (NuevoPivote * EscalaActual)
		# Nota: Al rotar/escalar desde el centro, la posición visual del centro coincide con Pos + Pivote
		# Pero como el scale afecta desde el pivote, aquí simplificamos alineando el punto de anclaje.
		
		# Ajuste fino: Movemos la posición local hacia atrás para compensar el cambio de pivote
		# Desplazamiento = (NuevoPivote - ViejoPivote) * (1 - Escala) ? No, es más simple:
		# Simplemente reposicionamos usando el centro global calculado.
		item_icon.global_position = visual_center_global - (target_pivot * current_scale)
		
		# Nota: Si esto sigue fallando ligeramente por temas de jerarquía, la opción B es forzar la posición:
		# item_icon.position = (size - item_icon.size * current_scale) / 2.0 # (Solo si el padre es del mismo tamaño)

	# 3. Animación (Squish)
	var t = create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_ELASTIC)
	t.set_ease(Tween.EASE_OUT)
	
	# Aplastamiento relativo a su escala actual
	item_icon.scale = current_scale * Vector2(1.4, 0.6)
	
	# Recuperación: Vuelve a su escala original
	t.tween_property(item_icon, "scale", current_scale, 0.5)
	
	# Flash
	item_icon.modulate = Color(2.5, 2.5, 2.0)
	t.tween_property(item_icon, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)
