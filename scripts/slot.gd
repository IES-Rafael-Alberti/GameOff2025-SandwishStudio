extends Panel

@export var max_glow_alpha := 0.7
@export var max_scale := 1.0
@export var min_scale := 0.6
@export var attraction_radius := 120.0
@export var highlight_speed := 10.0

# --- NUEVO: Arrastra aquí tus imágenes ---
@export_group("Tier Textures")
@export var tier_bronze_texture: Texture2D
@export var tier_silver_texture: Texture2D
@export var tier_gold_texture: Texture2D

var glow_sprite: Sprite2D
var particles: CPUParticles2D
var piece_over: Node = null
var occupied := false
var current_piece_data: Resource = null 
var current_piece_count: int = 0
@onready var ruleta: Node = get_parent().get_parent().get_parent().get_parent()
@onready var piece_texture_rect: TextureRect = $PieceTextureRect

# El icono visual que crearemos por código
var tier_icon: TextureRect

func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	if not occupied:
		return
		
	if ruleta and ruleta.has_method("is_moving"):
		if ruleta.is_moving() or not ruleta.is_interactive:
			print("No se puede devolver la pieza: ¡La ruleta está girando o el juego está en combate!")
			return

	GlobalSignals.piece_returned_from_roulette.emit(current_piece_data)
	clear_slot()

func _on_return_attempt_finished(success: bool):
	if success:
		clear_slot()

func _ready():
	# Configuración visual (Highlight, partículas, etc.)
	if not has_node("Highlight"):
		var h = Node2D.new()
		h.name = "Highlight"
		add_child(h)
		h.z_index = 10
		glow_sprite = Sprite2D.new()
		glow_sprite.centered = true
		glow_sprite.modulate = Color(1,1,0,0)
		glow_sprite.scale = Vector2(min_scale,min_scale)
		h.add_child(glow_sprite)
		particles = CPUParticles2D.new()
		particles.amount = 6
		particles.one_shot = false
		particles.emitting = false
		h.add_child(particles)
	else:
		glow_sprite = get_node("Highlight/Glow")
		particles = get_node("Highlight/Particles")

	if not piece_texture_rect:
		push_error("RouletteSlot: ¡No se encontró el nodo hijo 'PieceTextureRect'!")
	else:
		piece_texture_rect.visible = false
		
	self.gui_input.connect(_on_gui_input)
	
	# Creación del icono de Tier (Bronce/Plata/Oro)
	tier_icon = TextureRect.new()
	tier_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tier_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tier_icon.custom_minimum_size = Vector2(20, 20)
	tier_icon.size = Vector2(20, 20)
	tier_icon.anchor_left = 1.0
	tier_icon.anchor_right = 1.0
	tier_icon.position = Vector2(-20, 0)
	tier_icon.visible = false
	add_child(tier_icon)
	
	# --- ¡NUEVO! Conectar señal para actualizarse en tiempo real ---
	GlobalSignals.piece_count_changed.connect(_on_piece_count_changed)
	
func _on_piece_count_changed(piece_data: Resource, new_count: int) -> void:
	# Si el slot está vacío o no tiene datos, ignorar
	if not occupied or not current_piece_data:
		return
		
	# Verificamos si la pieza que se actualizó es la misma que tenemos aquí.
	# Comparamos el 'piece_origin' (la unidad base) para asegurar que sean del mismo tipo.
	if piece_data is PieceData and current_piece_data is PieceData:
		if piece_data.piece_origin == current_piece_data.piece_origin:
			print("Slot Ruleta detectó compra de su pieza. Actualizando visual a: %d copias" % new_count)
			_update_tier_visual(new_count)

func _process(delta):
	if piece_over:
		var dist = piece_over.global_position.distance_to(global_position)
		var factor = clamp(1.0 - float(dist) / float(attraction_radius), 0.0, 1.0)
		glow_sprite.modulate.a = lerp(float(glow_sprite.modulate.a), max_glow_alpha * factor, delta * highlight_speed)
		var target_scale = lerp(float(min_scale), float(max_scale), factor)
		glow_sprite.scale = glow_sprite.scale.lerp(Vector2(target_scale, target_scale), delta * highlight_speed)
		particles.emitting = factor > 0.3
	else:
		glow_sprite.modulate.a = lerp(float(glow_sprite.modulate.a), 0.0, delta * highlight_speed)
		glow_sprite.scale = glow_sprite.scale.lerp(Vector2(min_scale, min_scale), delta * highlight_speed)
		particles.emitting = false
		
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if ruleta and ruleta.has_method("is_moving"):
		if ruleta.is_moving() or not ruleta.is_interactive:
			return false
	
	if occupied:
		return false
		
	if data is Dictionary and "data" in data and "count" in data:
		if data.data is PieceData:
			return data.data.uses > 0
		return false

	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	
	occupied = true
	current_piece_data = data.data
	current_piece_count = 1 
	
	if current_piece_data and "icon" in current_piece_data:
		if current_piece_data.icon:
			piece_texture_rect.texture = current_piece_data.icon
			piece_texture_rect.visible = true
	
	GlobalSignals.piece_placed_on_roulette.emit(current_piece_data)
	
	# --- Actualizar Tier Visual ---
	if current_piece_data is PieceData:
		var total_copies = _get_total_copies(current_piece_data)
		_update_tier_visual(total_copies)

func _get_total_copies(data: Resource) -> int:
	var manager = null
	if owner and owner.has_method("get_inventory_piece_count"):
		manager = owner
	elif get_tree().current_scene.has_method("get_inventory_piece_count"):
		manager = get_tree().current_scene
	
	if manager:
		return manager.get_inventory_piece_count(data)
	return 1

# --- LÓGICA VISUAL DEL TIER ---
func _update_tier_visual(count: int) -> void:
	if not tier_icon: return
	
	tier_icon.visible = true
	match count:
		1:
			tier_icon.texture = tier_bronze_texture
		2:
			tier_icon.texture = tier_silver_texture
		3: 
			tier_icon.texture = tier_gold_texture
		_:
			if count > 3:
				tier_icon.texture = tier_gold_texture
			else:
				tier_icon.visible = false

func clear_slot():
	occupied = false
	current_piece_data = null
	current_piece_count = 0
	if piece_texture_rect:
		piece_texture_rect.visible = false
		
	if tier_icon:
		tier_icon.visible = false
