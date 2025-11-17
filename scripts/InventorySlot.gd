extends Control

## Señal que emitiremos cuando se haga clic en el botón
signal item_selected(data: Resource)

@onready var button: TextureButton = $TextureButton
@onready var count_label: Label = $CountLabel
@onready var uses_label: Label = $UsesLabel
@onready var tooltip: PanelContainer = $Tooltip


var item_data: Resource = null
var current_count: int = 0

# --- NUEVA VARIABLE ---
# 'inventory.gd' nos dirá qué valor poner aquí
var sell_percentage: int = 50


func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	
	# --- NUEVAS LÍNEAS ---
	# Conectamos las señales del ratón del botón a nuestras nuevas funciones
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)
	
	clear_slot()

func set_item(data: Resource) -> void:
	item_data = data
	current_count = 1
	
	button.texture_normal = data.icon
	button.modulate = Color(1, 1, 1, 1)
	button.set_meta("data", data) 
	
	button.item_data = data 
	
	update_count(current_count)
	_update_uses(data)
	
	show()

func update_count(count: int) -> void:
	current_count = count
	button.item_count = current_count

	if current_count > 0:
		button.disabled = false
		button.modulate = Color(1, 1, 1, 1)
		button.item_data = item_data
		
		if current_count > 1:
			count_label.text = "x%d" % current_count
			count_label.show()
		else:
			count_label.hide()
	else:
		button.disabled = false          
		button.modulate = Color(1, 1, 1, 0.5)
		button.item_data = null             
		count_label.hide()
		
func _get_drag_data(at_position: Vector2) -> Variant:
	if item_data == null:
		return null
	if current_count > 0:
		var drag_data_packet = {
			"data": item_data,
			"count": 1 # Se arrastra una sola unidad
		}
		var preview = TextureRect.new()
		preview.texture = button.texture_normal
		set_drag_preview(preview)
		return drag_data_packet
	elif current_count == 0:
		var delete_action_packet = {
			"type": "DELETE_STACK", 
			"data": item_data,
			"source_slot": self 
		}
		var preview = TextureRect.new()
		preview.texture = button.texture_normal
		preview.modulate = Color(1, 1, 1, 0.5)
		set_drag_preview(preview)
		
		return delete_action_packet
		
	return null

## Limpia el slot para que parezca vacío
func clear_slot() -> void:
	item_data = null
	current_count = 0
	button.texture_normal = null 
	button.disabled = true
	button.set_meta("data", null)
	
	button.item_data = null
	button.modulate = Color(1, 1, 1, 1)
	button.item_count = 0
	
	count_label.hide()
	uses_label.hide()
	tooltip.hide_tooltip()
	tooltip.hide_tooltip()

func is_empty() -> bool:
	return item_data == null

func _update_uses(data: Resource) -> void:
	if data is PieceData:
		uses_label.text = "%d" % data.uses
		uses_label.show()
	else:
		uses_label.hide()

func _on_button_pressed() -> void:
	if item_data:
		item_selected.emit(item_data)
		
		# --- NUEVA LÍNEA ---
		# Al vender el ítem, ocultamos el tooltip
		tooltip.hide_tooltip()


# --- FUNCIONES TOTALMENTE NUEVAS PARA EL TOOLTIP ---

## Se llama cuando el ratón entra en el TextureButton
func _on_button_mouse_entered() -> void:
	if item_data:
		# ¡Llamamos al Autoload 'Tooltip' que creamos!
		tooltip.show_tooltip(item_data, sell_percentage)

## Se llama cuando el ratón sale del TextureButton
func _on_button_mouse_exited() -> void:
	# ¡Llamamos al Autoload 'Tooltip' que creamos!
	tooltip.hide_tooltip()
