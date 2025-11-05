extends Control

@onready var piece_inventory: GridContainer = $piece_inventory
@onready var passive_inventory: GridContainer = $passive_inventory
@export  var font_size := 20

@export var max_pieces: int = 6
@export var max_passives: int = 30

# Diccionarios para registrar lo comprado
var piece_counts: Dictionary = {}
var passive_counts: Dictionary = {}

func add_item(data):
	if not can_add_item(data):
		print("❌ No hay espacio en el inventario para", data)
		return false

	# --- PIEZAS ---
	if data is PieceData:
		var id = _get_piece_id(data)

		if piece_counts.has(id):
			piece_counts[id]["count"] += 1
			_update_piece_label(id)
			return true

		var button_container := VBoxContainer.new()
		button_container.alignment = BoxContainer.ALIGNMENT_CENTER
		button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var button := TextureButton.new()
		button.texture_normal = data.icon
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.set_meta("data", data)
		button.pressed.connect(_on_item_pressed.bind(button))

		# Fuente grande

		# Label de usos
		var uses_label := Label.new()
		uses_label.text = "Usos: %d" % data.uses
		uses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		uses_label.add_theme_font_size_override("font_size", font_size)

		# Label de cantidad
		var count_label := Label.new()
		count_label.text = "x1"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", font_size)

		button_container.add_child(button)
		button_container.add_child(uses_label)
		button_container.add_child(count_label)
		piece_inventory.add_child(button_container)

		piece_counts[id] = {
			"button_container": button_container,
			"button": button,
			"count_label": count_label,
			"uses_label": uses_label,
			"count": 1,
			"data": data
		}

	# --- PASIVOS ---
	elif data is PassiveData:
		var id = _get_piece_id(data)

		if passive_counts.has(id):
			passive_counts[id]["count"] += 1
			_update_passive_label(id)
			return true

		var button_container := VBoxContainer.new()
		button_container.alignment = BoxContainer.ALIGNMENT_CENTER
		button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var button := TextureButton.new()
		button.texture_normal = data.icon
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.set_meta("data", data)
		button.pressed.connect(_on_item_pressed.bind(button))

		# 💪 compensar el scale 0.5 (36px = se verá como 18px)
		var font_size := 36

		var count_label := Label.new()
		count_label.text = "x1"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", font_size)

		button_container.add_child(button)
		button_container.add_child(count_label)
		passive_inventory.add_child(button_container)

		passive_counts[id] = {
			"button_container": button_container,
			"button": button,
			"count_label": count_label,
			"count": 1,
			"data": data
		}
	return true


func can_add_item(data) -> bool:
	if data is PieceData:
		return piece_inventory.get_child_count() < max_pieces or piece_counts.has(_get_piece_id(data))
	elif data is PassiveData:
		return passive_inventory.get_child_count() < max_passives or passive_counts.has(_get_piece_id(data))
	return false


func _on_item_pressed(button: TextureButton) -> void:
	var data = button.get_meta("data")
	if data:
		print("Has seleccionado:", data.type)


func _update_piece_label(id: String) -> void:
	if not piece_counts.has(id):
		return
	var entry = piece_counts[id]
	entry["count_label"].text = "x%d" % entry["count"]


func _update_passive_label(id: String) -> void:
	if not passive_counts.has(id):
		return
	var entry = passive_counts[id]
	entry["count_label"].text = "x%d" % entry["count"]


func _get_piece_id(data: Resource) -> String:
	if typeof(data) == TYPE_OBJECT and data.resource_path != "":
		return data.resource_path
	return "%s_%d" % [data.get_class(), data.get_instance_id()]
