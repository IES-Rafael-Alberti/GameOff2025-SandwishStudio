extends Control

signal item_selected(data: Resource)

@onready var button: TextureButton = $TextureButton
@onready var count_label: TextureRect = $CountLabel 
@onready var uses_label: Label = $UsesLabel
@onready var tooltip: PanelContainer = $Tooltip

@export_group("Tier Textures")
@export var tier_bronze_texture: Texture2D
@export var tier_silver_texture: Texture2D
@export var tier_gold_texture: Texture2D

# --- SHADER ---
const OUTLINE_SHADER = preload("res://shaders/outline_highlight.gdshader")
var highlight_material: ShaderMaterial

var item_data: Resource = null
var current_count: int = 0
var sell_percentage: int = 50

func _ready() -> void:
	# Configurar material de hover
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = OUTLINE_SHADER
	highlight_material.set_shader_parameter("width", 3.0)
	highlight_material.set_shader_parameter("color", Color.WHITE)
	
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)
	
	if count_label:
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		count_label.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	clear_slot()

func set_item(data: Resource) -> void:
	item_data = data
	current_count = 1
	
	button.texture_normal = data.icon
	button.disabled = false
	button.set_meta("data", data) 
	
	button.item_data = data 
	button.item_count = current_count 
	
	update_count(current_count)
	_update_uses(data)
	
	show()

func update_count(count: int) -> void:
	current_count = count
	
	if button:
		button.item_count = current_count

	if item_data is PieceData and count_label:
		count_label.visible = true
		
		match count:
			1:
				if tier_bronze_texture: count_label.texture = tier_bronze_texture
			2:
				if tier_silver_texture: count_label.texture = tier_silver_texture
			3:
				if tier_gold_texture: count_label.texture = tier_gold_texture
			_:
				if count > 3 and tier_gold_texture:
					count_label.texture = tier_gold_texture
				else:
					pass
	else:
		count_label.visible = false

func clear_slot() -> void:
	item_data = null
	current_count = 0
	button.texture_normal = null 
	button.disabled = true
	button.set_meta("data", null)
	
	button.item_data = null 
	button.item_count = 0
	
	count_label.hide()
	uses_label.hide()
	tooltip.hide_tooltip()
	
	button.modulate = Color.WHITE
	button.material = null # Limpiar shader

func is_empty() -> bool:
	return item_data == null

func _update_uses(data: Resource) -> void:
	if data is PieceData:
		uses_label.text = "%d" % data.uses
		uses_label.show()
		
		if data.uses <= 0:
			button.self_modulate = Color(0.5, 0.5, 0.5) 
		else:
			button.self_modulate = Color.WHITE 
			
	else:
		uses_label.hide()
		button.self_modulate = Color.WHITE 

func _on_button_pressed() -> void:
	if item_data:
		item_selected.emit(item_data)
		tooltip.hide_tooltip()

func _on_button_mouse_entered() -> void:
	# --- APLICAR SHADER ---
	if not button.disabled:
		button.material = highlight_material
		
	if item_data:
		# --- LÓGICA NUEVA: DETECTAR MODO PASIVAS ---
		# Si es un dato pasivo, asumimos que estamos en un slot de pasivas.
		# Buscamos el inventario (padre del GridContainer del Slot) para pasar la referencia.
		if item_data is PassiveData:
			# Intentamos encontrar el nodo "inventory" subiendo en la jerarquía
			# Slot -> GridContainer -> Inventory
			var potential_inventory = get_parent().get_parent()
			
			# Verificamos si es realmente el inventario (tiene el diccionario passive_counts)
			if potential_inventory and "passive_counts" in potential_inventory:
				# Activamos modo resumen (flag true) y pasamos el inventario
				tooltip.show_tooltip(item_data, sell_percentage, current_count, true, potential_inventory)
			else:
				# Fallback normal si no encuentra el inventario
				tooltip.show_tooltip(item_data, sell_percentage, current_count)
		else:
			# Modo normal para piezas
			tooltip.show_tooltip(item_data, sell_percentage, current_count)

func _on_button_mouse_exited() -> void:
	# --- QUITAR SHADER ---
	button.material = null
	tooltip.hide_tooltip()
