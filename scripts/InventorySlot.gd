extends Control

signal item_selected(data: Resource)

# --- CAMBIO: Asegúrate de que en tu escena el nodo CountLabel sea un TextureRect ---
@onready var button: TextureButton = $TextureButton
@onready var count_label: TextureRect = $CountLabel 
@onready var uses_label: Label = $UsesLabel
@onready var tooltip: PanelContainer = $Tooltip

# --- NUEVO: Arrastra aquí tus imágenes de los círculos ---
@export_group("Tier Textures")
@export var tier_bronze_texture: Texture2D
@export var tier_silver_texture: Texture2D
@export var tier_gold_texture: Texture2D

var item_data: Resource = null
var current_count: int = 0
var sell_percentage: int = 50

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)
	
	# Nos aseguramos de que el TextureRect no bloquee el clic del ratón
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

## Actualiza la textura según la cantidad (Tier)
func update_count(count: int) -> void:
	current_count = count
	
	if button:
		button.item_count = current_count

	# --- LÓGICA DE TEXTURAS ---
	if item_data is PieceData and count_label:
		count_label.visible = true # Siempre visible, incluso con 1 copia
		
		match count:
			1:
				count_label.texture = tier_bronze_texture
			2:
				count_label.texture = tier_silver_texture
			3:
				count_label.texture = tier_gold_texture
			_:
				# Si es mayor que 3, mantenemos Oro
				if count > 3:
					count_label.texture = tier_gold_texture
				else:
					count_label.visible = false
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
	if item_data:
		tooltip.show_tooltip(item_data, sell_percentage)

func _on_button_mouse_exited() -> void:
	tooltip.hide_tooltip()
