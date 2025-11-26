extends Control

signal item_selected(data: Resource)

# --- REFERENCIAS ---
@onready var button: TextureButton = $TextureButton
@onready var item_icon: TextureRect = $TextureButton/ItemIcon 
@onready var count_label: TextureRect = $TextureButton/CountLabel
@onready var tier_label: TextureRect = $TextureButton/TierLabel
@onready var uses_label: Label = $UsesLabel
@onready var tooltip: PanelContainer = $Tooltip

# --- CONFIGURACIÓN VISUAL ---
var frame_texture: Texture2D = null

# --- TIER ICONS ---
@export_group("Tier Icons")
@export var icon_bronze: Texture2D
@export var icon_silver: Texture2D
@export var icon_gold: Texture2D

# --- SHADER ---
const OUTLINE_SHADER = preload("res://shaders/outline_highlight.gdshader")
var highlight_material: ShaderMaterial

const FILL_SHADER = preload("res://shaders/oscurecer.gdshader")
var fill_material: ShaderMaterial # Este material se compartirá entre Botón e Icono

var item_data: Resource = null
var current_count: int = 0
var sell_percentage: int = 50

func _ready() -> void:
	frame_texture = button.texture_normal
	
	# 1. Inicializar Material de Outline (Solo para el botón al hacer hover)
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = OUTLINE_SHADER
	highlight_material.set_shader_parameter("width", 3.0)
	highlight_material.set_shader_parameter("color", Color.WHITE)
	
	# 2. Inicializar Material de Fill (Para botón e icono normalmente)
	fill_material = ShaderMaterial.new()
	fill_material.shader = FILL_SHADER
	fill_material.set_shader_parameter("roll_amount", 0.0) # Empezar limpio
	
	# --- CLAVE 1: Asignación inicial independiente ---
	# Asignamos el MISMO material a los dos.
	button.material = fill_material
	if item_icon:
		item_icon.material = fill_material
		item_icon.use_parent_material = false # IMPORTANTE: No heredar para que el outline no afecte al icono
	
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)
	
	_setup_texture_rect(count_label)
	_setup_texture_rect(item_icon)
	_setup_texture_rect(tier_label)
	
	clear_slot()

func _setup_texture_rect(node: TextureRect):
	if node:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func set_item(data: Resource) -> void:
	item_data = data
	current_count = 1
	
	if frame_texture: button.texture_normal = frame_texture
	
	if item_icon:
		item_icon.texture = data.icon
		item_icon.show()
		# Reasegurar el material por si acaso
		item_icon.material = fill_material
	else:
		button.texture_normal = data.icon 
	
	button.disabled = false
	button.set_meta("data", data) 
	button.item_data = data 
	button.item_count = current_count 
	
	# Asegurar que el botón tenga el material de relleno (no el outline)
	button.material = fill_material
	
	update_count(current_count)
	_update_uses(data) 
	
	show()

func update_count(count: int) -> void:
	current_count = count
	if button: button.item_count = current_count
	
	if tier_label:
		if count > 0 and item_data is PieceData:
			tier_label.visible = true
			match count:
				1: tier_label.texture = icon_bronze
				2: tier_label.texture = icon_silver
				_: tier_label.texture = icon_gold
		else:
			tier_label.visible = false
			
	if item_data:
		_update_uses(item_data)

func clear_slot() -> void:
	item_data = null
	current_count = 0
	button.texture_normal = null 
	
	if item_icon:
		item_icon.texture = null
		item_icon.hide()
	if tier_label:
		tier_label.texture = null
		tier_label.hide()
	
	button.disabled = true
	button.set_meta("data", null)
	button.item_data = null 
	button.item_count = 0
	
	if count_label: count_label.hide()
	if uses_label: uses_label.hide()
	tooltip.hide_tooltip()
	
	button.modulate = Color.WHITE
	
	# Limpiar visualmente el shader compartido
	fill_material.set_shader_parameter("roll_amount", 0.0)
	button.material = fill_material

func is_empty() -> bool:
	return item_data == null

func _update_uses(data: Resource) -> void:
	if data is PieceData:
		if uses_label: uses_label.visible = false 
		
		# --- CÁLCULO DE VIDA GASTADA ---
		var current = float(data.uses)
		var maximum: float
		
		# Corrección para que items nuevos NO empiecen oscuros:
		if data.has_meta("max_uses"):
			maximum = float(data.get_meta("max_uses"))
		else:
			# Si es la primera vez que lo vemos, asumimos que está NUEVO (lleno)
			maximum = current 
			if maximum <= 0: maximum = 1.0
			data.set_meta("max_uses", maximum)
		
		# Evitar que el máximo sea menor que el actual por error antiguo
		if maximum < current: maximum = current

		var ratio_life = clamp(current / maximum, 0.0, 1.0)
		var ratio_spent = 1.0 - ratio_life 
		
		# --- DEBUG IMPORTANTE ---
		# Si ves 0.0 aquí, es que está perfecto (nuevo). Si ves > 0.0, se oscurece.
		# print("Slot %s -> Spent: %f" % [data.resource_name, ratio_spent])
		
		# Actualizamos el material COMPARTIDO. 
		# Al hacer esto, se actualiza visualmente el icono Y el botón (si no tiene outline puesto).
		fill_material.set_shader_parameter("roll_amount", ratio_spent)
		
		# Transparencia extra si está muerto
		var target_alpha = 0.6 if current <= 0 else 1.0
		if item_icon: item_icon.modulate.a = target_alpha
		button.self_modulate.a = target_alpha

		# --- LÓGICA MEMBERS/TIER ---
		if count_label:
			count_label.visible = true
			var tier_key = "BRONCE"
			if current_count == 2: tier_key = "PLATA"
			elif current_count >= 3: tier_key = "ORO"
			
			var members_num = 1
			if data.piece_origin and "stats" in data.piece_origin:
				var stats = data.piece_origin.stats
				if stats.has(tier_key) and stats[tier_key].has("members"):
					members_num = stats[tier_key]["members"]
			
			var visual_num = clampi(members_num, 1, 14)
			var path = "res://assets/numeros/%d.png" % visual_num
			if ResourceLoader.exists(path):
				count_label.texture = load(path)
			else:
				count_label.visible = false
	else:
		_reset_visuals()

func _reset_visuals():
	if uses_label: uses_label.hide()
	if count_label: count_label.hide()
	if tier_label: tier_label.hide()
	if item_icon: item_icon.self_modulate = Color.WHITE
	button.self_modulate = Color.WHITE
	fill_material.set_shader_parameter("roll_amount", 0.0)

func _on_button_pressed() -> void:
	if item_data:
		item_selected.emit(item_data)
		tooltip.hide_tooltip()

func _on_button_mouse_entered() -> void:
	if not button.disabled:
		# Cambiamos solo el material del padre para el efecto visual (Outline)
		button.material = highlight_material
	
	if item_data:
		# --- MODIFICACIÓN: LÓGICA DIFERENCIADA PARA PASIVAS ---
		
		if item_data is PassiveData:
			# Si es una pasiva, queremos ver el RESUMEN GLOBAL, no solo este item.
			# Buscamos el GameManager para acceder a los datos del inventario.
			var gm = get_tree().get_first_node_in_group("game_manager")
			if gm and gm.inventory:
				# Le pasamos el diccionario 'passive_counts' que tiene TODAS las pasivas acumuladas
				tooltip.show_passive_list_tooltip(gm.inventory.passive_counts)
			else:
				# Si algo falla, mostramos el individual como respaldo
				tooltip.show_tooltip(item_data, sell_percentage, current_count)
				
		else:
			# Si es una PIEZA normal (tropa), mostramos su tooltip individual estándar
			tooltip.show_tooltip(item_data, sell_percentage, current_count)

func _on_button_mouse_exited() -> void:
	# --- CLAVE 3: Restaurar el material del PADRE ---
	button.material = fill_material
	tooltip.hide_tooltip()
