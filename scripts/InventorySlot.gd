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
	button.disabled = false
	button.set_meta("data", data) 
	
	button.item_data = data 
	button.item_count = current_count # <-- ¡NUEVA LÍNEA! (Añadida)
	
	update_count(current_count) # update_count se encargará de actualizar el botón si es > 1
	_update_uses(data)
	
	show()

## Actualiza el contador de stack (apilamiento)
func update_count(count: int) -> void:
	current_count = count
	if current_count > 1:
		count_label.text = "x%d" % current_count
		count_label.show()
	else:
		count_label.hide()
		
	# ¡NUEVA LÍNEA!
# Actualizamos el botón para el drag-and-drop
	button.item_count = current_count

## Limpia el slot para que parezca vacío
func clear_slot() -> void:
	item_data = null
	current_count = 0
	button.texture_normal = null 
	button.disabled = true
	button.set_meta("data", null)
	
	button.item_data = null # <-- ¡NUEVA LÍNEA! (Añadida)
	button.item_count = 0  # <-- ¡NUEVA LÍNEA! (Añadida)
	
	count_label.hide()
	uses_label.hide()
	tooltip.hide_tooltip()
	
	# --- ¡NUEVA LÍNEA! ---
	# Reseteamos el color por si estaba gris
	button.modulate = Color.WHITE

func is_empty() -> bool:
	return item_data == null

# --- ¡FUNCIÓN MODIFICADA! ---
func _update_uses(data: Resource) -> void:
	if data is PieceData:
		uses_label.text = "%d" % data.uses
		uses_label.show()
		
		# --- ¡LÓGICA DE AGOTADO! ---
		# Si los usos llegan a 0, lo ponemos gris.
		# Si tiene > 0 usos, nos aseguramos de que sea blanco.
		if data.uses <= 0:
			button.modulate = Color(0.5, 0.5, 0.5) # Gris
		else:
			button.modulate = Color.WHITE # Blanco normal
			
	else:
		uses_label.hide()
		# --- ¡NUEVA LÍNEA! ---
		# Nos aseguramos de que otros items no PieceData no se queden grises
		button.modulate = Color.WHITE


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
