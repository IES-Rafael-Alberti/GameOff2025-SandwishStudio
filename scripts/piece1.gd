extends Node2D
class_name Piece

# --- configuración editable ---
@export var base_scale := Vector2(0.6, 0.6)
@export var grab_scale := Vector2(0.85, 0.85)
@export var snap_duration := 0.15
@export var bounce_scale := 1.2
@export var bounce_time := 0.12
@export var attraction_radius := 120.0  # para búsqueda de slot cercano al soltar (px)

@export var sound_snap: AudioStreamPlayer2D
@export var sound_return: AudioStreamPlayer2D
@export var particles_snap: CPUParticles2D

# Opcionales (se buscan automáticamente si no los asignas)
@export var drag_layer: NodePath
@export var inventory_node: NodePath

# --- estado interno ---
var dragging = false
var offset = Vector2.ZERO
var original_parent: Node = null
var original_index := 0
var original_position := Vector2.ZERO
static var piece_being_dragged = null

@onready var area: Area2D = $Area2D if has_node("Area2D") else null
@onready var sprite: Node = $Sprite2D if has_node("Sprite2D") else null

var overlapped_slots: Array = []
var blocked := false

# runtime caches (nodes)
var _drag_layer_node: Node = null
var _inventory_node: Node = null
var _roulette_node: Node = null

func _enter_tree():
	# agrégate al grupo "piece" para que la ruleta pueda encontrarte sin importar estructura
	if not is_in_group("piece"):
		add_to_group("piece")

func _ready():
	scale = base_scale
	# encontrar/crear drag_layer e inventory_node si no se asignaron via Inspector
	_resolve_common_nodes()

	# conectar el area si existe
	if area:
		area.input_pickable = true
		area.connect("input_event", Callable(self, "_on_input_event"))
		# los signals area_entered/exit pueden ser útiles, pero no confíes sólo en ellos:
		area.connect("area_entered", Callable(self, "_on_area_entered"))
		area.connect("area_exited", Callable(self, "_on_area_exited"))

	# intentar localizar ruleta (por nombre "Roulette" o por grupo "roulette")
	_roulette_node = get_tree().get_current_scene().get_node_or_null("Roulette")
	if not _roulette_node:
		var r_nodes = get_tree().get_nodes_in_group("roulette")
		if r_nodes.size() > 0:
			_roulette_node = r_nodes[0]
	# no dependemos de que la ruleta conecte a cada pieza; la ruleta nos pedirá bloquear directamente por grupo
	# pero también conectamos si existe para compatibilidad
	if _roulette_node and _roulette_node.has_method("connect"):
		# solo conexiones locales por compatibilidad (si ruleta emite start_spin/end_spin)
		if _roulette_node.has_signal("start_spin"):
			_roulette_node.connect("start_spin", Callable(self, "_on_ruleta_spin_start"))
		if _roulette_node.has_signal("end_spin"):
			_roulette_node.connect("end_spin", Callable(self, "_on_ruleta_spin_end"))

	# guardar posición original
	original_position = global_position

func _resolve_common_nodes():
	# drag_layer
	if typeof(drag_layer) == TYPE_NIL or drag_layer == NodePath(""):
		# buscar nodo llamado "DragLayer" en escena actual
		var dd = get_tree().get_current_scene().get_node_or_null("DragLayer")
		if dd:
			_drag_layer_node = dd
		else:
			# crear uno bajo root de scene
			var root = get_tree().get_current_scene()
			_drag_layer_node = Node2D.new()
			_drag_layer_node.name = "DragLayer"
			root.add_child(_drag_layer_node)
	else:
		_drag_layer_node = get_node_or_null(drag_layer)
		if not _drag_layer_node:
			# intentar get_tree path
			_drag_layer_node = get_tree().get_current_scene().get_node_or_null(drag_layer)

	# inventory_node
	if typeof(inventory_node) == TYPE_NIL or inventory_node == NodePath(""):
		var inv = get_tree().get_current_scene().get_node_or_null("PiecesContainer")
		if inv:
			_inventory_node = inv
		else:
			# fallback: buscar nodo en grupo "inventory"
			var nodes = get_tree().get_nodes_in_group("inventory")
			if nodes.size() > 0:
				_inventory_node = nodes[0]
			else:
				_inventory_node = get_tree().get_current_scene()
	else:
		_inventory_node = get_node_or_null(inventory_node)
		if not _inventory_node:
			_inventory_node = get_tree().get_current_scene().get_node_or_null(inventory_node)

func _on_ruleta_spin_start():
	blocked = true

func _on_ruleta_spin_end():
	blocked = false

func _on_input_event(_viewport, event, _shape_idx):
	if blocked: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not dragging and piece_being_dragged == null:
			# evitar iniciar drag si la ruleta está en movimiento (pregunta a ruleta)
			if _roulette_node and _roulette_node.has_method("is_moving") and _roulette_node.is_moving():
				return
			_start_drag()
		elif not event.pressed and dragging:
			_stop_drag()

func _input(event):
	if blocked: return
	if dragging and event is InputEventMouseMotion:
		global_position = event.global_position - offset

func _start_drag():
	if blocked: return
	if not _drag_layer_node: _resolve_common_nodes()
	if not _drag_layer_node: return
	dragging = true
	piece_being_dragged = self
	original_position = global_position
	offset = get_global_mouse_position() - global_position
	original_parent = get_parent()
	original_index = get_index()
	var gpos = global_position
	if original_parent:
		original_parent.remove_child(self)
	_drag_layer_node.add_child(self)
	global_position = gpos
	create_tween().tween_property(self, "scale", grab_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _stop_drag():
	if not dragging: return
	dragging = false
	piece_being_dragged = null
	var slot = _get_best_slot()
	if slot:
		_place_in_slot(slot)
	else:
		_return_to_inventory(self)
	_clear_slot_highlights()
	overlapped_slots.clear()

# --- búsqueda robusta del mejor slot ---
func _get_best_slot():
	# 1) si hay overlapped slots (entradas de Area2D), priorizarlas
	if overlapped_slots.size() > 0:
		var closest = null
		var min_d = INF
		for s in overlapped_slots:
			if not is_instance_valid(s): continue
			var d = global_position.distance_to(s.global_position)
			if d < min_d:
				min_d = d
				closest = s
		# si está razonablemente cerca (o siempre lo devolvemos)
		if closest: return closest
	# 2) fallback: buscar el slot más cercano en el grupo "slot" dentro de attraction_radius
	var best = null
	var best_d = INF
	for s in get_tree().get_nodes_in_group("slot"):
		if not is_instance_valid(s): continue
		var d = global_position.distance_to(s.global_position)
		if d < best_d and d <= attraction_radius:
			best_d = d
			best = s
	return best

func _place_in_slot(slot: Area2D):
	if not slot: return
	# detectar pieza existente (iterando hijos)
	var existing: Piece = null
	for c in slot.get_children():
		if c is Piece and c != self:
			existing = c
			break
	# si hay una existente, devolverla a inventario (la dejamos "suelta")
	if existing:
		_return_to_inventory(existing)

	# mover esta pieza al slot
	if is_instance_valid(_drag_layer_node) and get_parent() == _drag_layer_node:
		_drag_layer_node.remove_child(self)
	slot.add_child(self)
	# marcar ocupado mediante meta para no requerir propiedades en el slot
	slot.set_meta("occupied", true)

	var t = create_tween()
	t.tween_property(self, "global_position", slot.global_position, snap_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", base_scale * bounce_scale, bounce_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", base_scale, bounce_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.play()

	if sound_snap: sound_snap.play()
	if particles_snap:
		particles_snap.global_position = global_position
		particles_snap.emitting = true

func _return_to_inventory(piece: Piece):
	if not piece: return
	# liberar slot si estaba en uno
	var prev = piece.get_parent()
	if prev and prev.is_in_group("slot"):
		prev.set_meta("occupied", false)
	# mover a drag_layer->inventory o directamente al inventory
	if is_instance_valid(_drag_layer_node) and piece.get_parent() == _drag_layer_node:
		_drag_layer_node.remove_child(piece)
	if not _inventory_node:
		_resolve_common_nodes()
	# si hay inventory_node, añadir allí; si no, attach al root de la escena
	var dest = _inventory_node if _inventory_node else get_tree().get_current_scene()
	dest.add_child(piece)
	# animar vuelta
	var t = piece.create_tween()
	t.tween_property(piece, "global_position", dest.to_global(Vector2.ZERO), snap_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(piece, "scale", base_scale, snap_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.play()
	if sound_return: sound_return.play()

# Area enter/exit (útil si slot son Area2D)
func _on_area_entered(a: Area2D):
	if not a: return
	# consideramos solo slots (grupo "slot")
	if a.is_in_group("slot") and not overlapped_slots.has(a):
		overlapped_slots.append(a)
		_highlight_slot(a, true)

func _on_area_exited(a: Area2D):
	if not a: return
	if a.is_in_group("slot"):
		overlapped_slots.erase(a)
		_highlight_slot(a, false)

func _highlight_slot(slot: Node, enable: bool):
	if not is_instance_valid(slot): return
	if not slot.has_node("Highlight"):
		var h = ColorRect.new()
		h.name = "Highlight"
		h.color = Color(1,1,0.4,0.4)
		h.size = Vector2(80,80)
		slot.add_child(h)
	slot.get_node("Highlight").visible = enable

func _clear_slot_highlights():
	for s in overlapped_slots:
		_highlight_slot(s, false)
