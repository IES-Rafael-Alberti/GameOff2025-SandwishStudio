extends Control

signal item_selected(data: Resource)

# --- REFERENCIAS ---
@onready var button: TextureButton = $TextureButton
@onready var item_icon: TextureRect = $TextureButton/ItemIcon 
@onready var count_label: TextureRect = $TextureButton/CountLabel # Muestra "members"
@onready var tier_label: TextureRect = $TextureButton/TierLabel # Icono de rareza
@onready var uses_label: Label = $UsesLabel
@onready var tooltip: PanelContainer = $Tooltip

# --- CONFIGURACIÓN VISUAL ---
var frame_texture: Texture2D = null

# --- TIER ICONS (Exportados desde el editor) ---
@export_group("Tier Icons")
@export var icon_bronze: Texture2D
@export var icon_silver: Texture2D
@export var icon_gold: Texture2D

# --- SHADER ---
const OUTLINE_SHADER = preload("res://shaders/outline_highlight.gdshader")
var highlight_material: ShaderMaterial

var item_data: Resource = null
var current_count: int = 0
var sell_percentage: int = 50

func _ready() -> void:
	frame_texture = button.texture_normal
	
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = OUTLINE_SHADER
	highlight_material.set_shader_parameter("width", 3.0)
	highlight_material.set_shader_parameter("color", Color.WHITE)
	
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
	
	# Restaurar marco
	if frame_texture: button.texture_normal = frame_texture
	
	# Imagen pieza
	if item_icon:
		item_icon.texture = data.icon
		item_icon.show()
	else:
		button.texture_normal = data.icon 
	
	button.disabled = false
	button.set_meta("data", data) 
	button.item_data = data 
	button.item_count = current_count 
	
	# Actualizar todo (Tier y Numeritos)
	update_count(current_count)
	# Nota: _update_uses se sigue llamando desde Inventory.gd, así que mantenemos el nombre
	# para no romper el otro script, aunque ahora actualiza "members".
	_update_uses(data) 
	
	show()

func update_count(count: int) -> void:
	current_count = count
	if button: button.item_count = current_count
	
	# 1. ACTUALIZAR ICONO DE TIER (Bronce/Plata/Oro)
	if tier_label:
		if count > 0 and item_data is PieceData:
			tier_label.visible = true
			match count:
				1: tier_label.texture = icon_bronze
				2: tier_label.texture = icon_silver
				_: tier_label.texture = icon_gold # 3 o más
		else:
			tier_label.visible = false
			
	# 2. IMPORTANTE: Si cambia la cantidad (sube de nivel), 
	# también puede cambiar el número de "members", así que refrescamos la visual.
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
	button.material = null

func is_empty() -> bool:
	return item_data == null

# --- AQUÍ ESTÁ LA CORRECCIÓN ---
# Se mantiene el nombre _update_uses por compatibilidad con Inventory.gd,
# pero ahora carga los "members" desde el stats del PieceRes.
func _update_uses(data: Resource) -> void:
	if data is PieceData:
		# (Opcional) Label de debug para usos reales
		if uses_label:
			uses_label.text = "%d" % data.uses
			uses_label.show()
		
		# CÓDIGO CORREGIDO: Cargar imagen basada en "members" del Tier actual
		if count_label:
			count_label.visible = true
			
			# 1. Determinar el Tier actual
			var tier_key = "BRONCE"
			if current_count == 2:
				tier_key = "PLATA"
			elif current_count >= 3:
				tier_key = "ORO"
			
			# 2. Obtener el valor de 'members' del diccionario stats
			var members_num = 1 # Valor por defecto
			
			if data.piece_origin and "stats" in data.piece_origin:
				var stats = data.piece_origin.stats
				if stats.has(tier_key) and stats[tier_key].has("members"):
					members_num = stats[tier_key]["members"]
			
			# 3. Cargar la imagen correspondiente
			var visual_num = clampi(members_num, 1, 14)
			var path = "res://assets/numeros/%d.png" % visual_num
			
			if ResourceLoader.exists(path):
				count_label.texture = load(path)
			else:
				count_label.visible = false

		# Efecto visual si está agotado (usos = 0)
		var target_node = item_icon if item_icon else button
		if data.uses <= 0:
			target_node.self_modulate = Color(0.5, 0.5, 0.5) 
		else:
			target_node.self_modulate = Color.WHITE 
			
	else:
		if uses_label: uses_label.hide()
		if count_label: count_label.hide()
		if tier_label: tier_label.hide()
		if item_icon: item_icon.self_modulate = Color.WHITE
		button.self_modulate = Color.WHITE

func _on_button_pressed() -> void:
	if item_data:
		item_selected.emit(item_data)
		tooltip.hide_tooltip()

func _on_button_mouse_entered() -> void:
	if not button.disabled:
		button.material = highlight_material
	if item_data:
		tooltip.show_tooltip(item_data, sell_percentage, current_count)

func _on_button_mouse_exited() -> void:
	button.material = null
	tooltip.hide_tooltip()
