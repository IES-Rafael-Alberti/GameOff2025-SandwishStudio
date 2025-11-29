extends Control
class_name PassiveStoreSlot

# --- SEÑALES ---
# Usamos 'slot_pressed' para ser consistentes con las Piezas
signal slot_pressed(slot_ref)
signal slot_hovered(data)
signal slot_exited()

# --- REFERENCIAS UI ---
@onready var texture_button: TextureButton = $ItemIcon
@onready var price_label: RichTextLabel = $ItemIcon/PriceLabel

# --- ETIQUETAS DE ESTADO ---
@onready var too_expensive_label: Control = $TooExpensiveLabel
@onready var out_of_stock_label: Control = $OutOfStockLabel

# --- CONFIGURACIÓN VISUAL ---
@export var coin_icon: Texture2D 

# --- VARIABLES DE ESTADO ---
var current_passive: PassiveData
var current_price: int = 0
var highlight_mat: ShaderMaterial

var is_purchased: bool = false 
var can_afford_status: bool = true 

# --- COLORES ---
var color_normal: Color = Color.WHITE
var color_available: Color = Color(0.1, 1.0, 0.1) # verde
var color_unaffordable: Color = Color(1.0, 0.1, 0.1) # rojo
var color_neutral: Color = Color(1.0, 1.0, 1.0) # blanco
var color_unavailable_bg: Color = Color(0.6, 0.0, 0.0, 1.0) # Para cuando está comprado/bloqueado

func _ready() -> void:
	if not texture_button:
		printerr("ERROR: No se encuentra el nodo 'ItemIcon' (TextureButton) en ", name)
		return
		
	# Conectamos las señales básicas
	texture_button.pressed.connect(_on_button_pressed)
	texture_button.mouse_entered.connect(_on_mouse_entered)
	texture_button.mouse_exited.connect(_on_mouse_exited)
	
	if too_expensive_label: too_expensive_label.hide()
	if out_of_stock_label: out_of_stock_label.hide()
	
	if price_label:
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_label.bbcode_enabled = true
		price_label.fit_content = true
		price_label.scroll_active = false

func set_passive(data: PassiveData, price: int, shader: ShaderMaterial, can_afford: bool) -> void:
	is_purchased = false
	current_passive = data
	current_price = price
	highlight_mat = shader
	
	if texture_button: 
		texture_button.disabled = false
		texture_button.modulate = color_normal
		texture_button.mouse_filter = Control.MOUSE_FILTER_STOP
		
		if data.icon:
			texture_button.texture_normal = data.icon
			texture_button.ignore_texture_size = true
			texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	if out_of_stock_label: out_of_stock_label.hide()
	if too_expensive_label: too_expensive_label.hide()
	if price_label: price_label.show()
	
	update_price_visuals()
	update_affordability(can_afford)

func update_price_visuals() -> void:
	if not price_label: return
	var icon_bbcode = ""
	if coin_icon:
		icon_bbcode = "[img=20x20]%s[/img]" % coin_icon.resource_path
	price_label.text = "[center][wave amp=25 freq=5]%d %s[/wave][/center]" % [current_price, icon_bbcode]

func update_affordability(can_afford: bool) -> void:
	can_afford_status = can_afford
	
	if is_purchased or not texture_button: return
	
	if can_afford:
		texture_button.modulate = color_normal
		if too_expensive_label: too_expensive_label.hide()
	else:
		# APLICAMOS ROJO (color_unaffordable) A LA PIEZA TAMBIÉN
		texture_button.modulate = color_unaffordable
		if too_expensive_label: too_expensive_label.show()

	# Llamamos a la actualización de color del texto
	update_price_color()
# --- VISUALES AL COMPRAR ---
func disable_interaction() -> void:
	is_purchased = true
	if texture_button:
		texture_button.modulate = color_unavailable_bg 
		texture_button.material = null 
		
		
	if out_of_stock_label: out_of_stock_label.show()
	if too_expensive_label: too_expensive_label.hide()
	
	
	update_price_color()
func _on_button_pressed() -> void:
	slot_pressed.emit(self)

func _on_mouse_entered() -> void:
	if is_purchased: return
	slot_hovered.emit(current_passive)
	
	if can_afford_status and highlight_mat and texture_button:
		texture_button.material = highlight_mat
		
	var t = create_tween()
	t.tween_property(texture_button, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited() -> void:
	slot_exited.emit()
	if texture_button:
		texture_button.material = null
		var t = create_tween()
		t.tween_property(texture_button, "scale", Vector2(1.0, 1.0), 0.1)
func update_price_color() -> void:
	if not price_label:
		return

	if is_purchased:
		price_label.modulate = color_neutral
		return
	
	if not can_afford_status:
		price_label.modulate = color_unaffordable
		return
	
	# Disponible y comprable
	price_label.modulate = color_available
