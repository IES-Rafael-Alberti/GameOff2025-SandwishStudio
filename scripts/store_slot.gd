extends Control
class_name StoreSlot

signal slot_pressed(slot_instance)
signal slot_hovered(data)
signal slot_exited()

# --- REFERENCIAS ---
@onready var texture_button: TextureButton = $TextureButton
@onready var item_icon: TextureRect = $TextureButton/ItemIcon 
@onready var count_label: TextureRect = $TextureButton/CountLabel
@onready var price_label: RichTextLabel = $TextureButton/PriceLabel 

# --- NUEVO: Icono de moneda para inyectar en el texto ---
@export var coin_icon: Texture2D 

# --- ETIQUETAS DE ESTADO ---
@onready var too_expensive_label: Control = $TooExpensiveLabel
@onready var out_of_stock_label: Control = $OutOfStockLabel
@onready var maxed_label: Control = $MaxedLabel 

var item_data: Resource
var current_price: int = 0
var highlight_mat: ShaderMaterial

# Variables de estado
var is_purchased: bool = false 
var is_maxed: bool = false
var can_afford_status: bool = true 

# --- COLORES ---
var color_normal: Color = Color.WHITE
var color_dark: Color = Color(0.3, 0.3, 0.3, 1.0) 

func _ready() -> void:
	if texture_button:
		texture_button.pressed.connect(func(): slot_pressed.emit(self))
		texture_button.mouse_entered.connect(_on_mouse_entered)
		texture_button.mouse_exited.connect(_on_mouse_exited)
	
	_setup_texture_rect(item_icon)
	_setup_texture_rect(count_label)
	
	_setup_label(too_expensive_label)
	_setup_label(out_of_stock_label)
	_setup_label(maxed_label)
	
	if price_label:
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_label.bbcode_enabled = true
		price_label.fit_content = true
		price_label.scroll_active = false

func _setup_texture_rect(node: TextureRect):
	if node:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _setup_label(node: Control):
	if node:
		node.visible = false
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.z_index = 10 

func set_item(data: Resource, price: int, shader: ShaderMaterial, can_afford: bool, count: int) -> void:
	# Resetear estados
	is_purchased = false
	is_maxed = false
	
	if texture_button: 
		texture_button.disabled = false
		texture_button.modulate = color_normal
	
	if out_of_stock_label: out_of_stock_label.visible = false
	if too_expensive_label: too_expensive_label.visible = false
	if maxed_label: maxed_label.visible = false
	
	item_data = data
	current_price = price
	highlight_mat = shader
	
	# --- CAMBIO: Precio + Imagen ondulando juntos ---
	if price_label:
		var icon_bbcode = ""
		if coin_icon:
			# Inyectamos la imagen con un tamaño fijo (ej. 20x20)
			icon_bbcode = "[img=20x20]%s[/img]" % coin_icon.resource_path
		
		# Formato: [OLA] PRECIO  IMAGEN [/OLA]
		# Al estar todo dentro de [wave], se mueven sincronizados
		price_label.text = "[center][wave amp=25 freq=5]%d %s[/wave][/center]" % [current_price, icon_bbcode]
	
	var icon_texture: Texture2D = null
	if "icon" in data and data.icon:
		icon_texture = data.icon
	elif "texture" in data:
		icon_texture = data.texture
	if item_icon: item_icon.texture = icon_texture
	
	update_count_visuals(data, count)
	update_affordability(can_afford)

func update_count_visuals(data: Resource, count: int) -> void:
	if not count_label: return
	if not (data is PieceData):
		count_label.visible = false
		return

	count_label.visible = true
	var tier_key = "BRONCE"
	if count == 2: tier_key = "PLATA"
	elif count >= 3: tier_key = "ORO"
	
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

func update_affordability(can_afford: bool) -> void:
	can_afford_status = can_afford
	
	if not texture_button or is_purchased or is_maxed: return
	
	if can_afford:
		texture_button.modulate = color_normal
		if too_expensive_label: too_expensive_label.visible = false
	else:
		texture_button.modulate = color_dark
		if too_expensive_label: too_expensive_label.visible = true

func set_maxed_state(state: bool) -> void:
	if is_purchased: return
	
	is_maxed = state
	
	if is_maxed:
		if texture_button:
			texture_button.disabled = false
			texture_button.modulate = color_dark
		
		if maxed_label: maxed_label.visible = true
		if too_expensive_label: too_expensive_label.visible = false
		if out_of_stock_label: out_of_stock_label.visible = false
	else:
		if texture_button:
			texture_button.disabled = false
			texture_button.modulate = color_normal
			
		if maxed_label: maxed_label.visible = false

func disable_interaction() -> void:
	if texture_button:
		is_purchased = true
		
		texture_button.modulate = color_dark
		texture_button.material = null 
		texture_button.disabled = false
		
		if out_of_stock_label: out_of_stock_label.visible = true
		if too_expensive_label: too_expensive_label.visible = false
		if maxed_label: maxed_label.visible = false

func _on_mouse_entered() -> void:
	slot_hovered.emit(item_data)

	if is_purchased or is_maxed or not can_afford_status: 
		return

	if texture_button:
		texture_button.material = highlight_mat

func _on_mouse_exited() -> void:
	if texture_button:
		texture_button.material = null
	slot_exited.emit()
func update_price(new_price: int) -> void:
	current_price = new_price
	
	if price_label:
		var icon_bbcode = ""
		if coin_icon:
			icon_bbcode = "[img=20x20]%s[/img]" % coin_icon.resource_path
		
		# Actualizamos el texto manteniendo el efecto wave
		price_label.text = "[center][wave amp=25 freq=5]%d %s[/wave][/center]" % [current_price, icon_bbcode]
