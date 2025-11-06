extends Control

## Señal que emitiremos cuando se haga clic en el botón
signal item_selected(data: Resource)

@onready var button: TextureButton = $TextureButton
@onready var count_label: Label = $CountLabel
@onready var uses_label: Label = $UsesLabel


var item_data: Resource = null
var current_count: int = 0

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	clear_slot()

func set_item(data: Resource) -> void:
	item_data = data
	current_count = 1
	
	button.texture_normal = data.icon
	button.disabled = false
	button.set_meta("data", data) 

	button.item_data = data 
	
	update_count(current_count)
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

## Limpia el slot para que parezca vacío
func clear_slot() -> void:
	item_data = null
	current_count = 0
	button.texture_normal = null 
	button.disabled = true
	button.set_meta("data", null)
	count_label.hide()
	uses_label.hide()

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
