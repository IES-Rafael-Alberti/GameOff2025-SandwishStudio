extends Node2D

var dragging: bool = false
var offset: Vector2 = Vector2.ZERO
var original_parent: Node
var original_index: int
var original_position: Vector2

@onready var area: Area2D = $Area2D
@onready var drag_layer: Node = $"../DragLayer"
var overlapped_slots: Array[Area2D] = []

@export var base_scale: Vector2 = Vector2(0.6, 0.6)
@export var grab_scale: Vector2 = Vector2(0.8, 0.8)
@export var roulette: Node = null   # ya no afecta al bloqueo

static var piece_being_dragged: Node = null

func _ready():
	area.input_pickable = true
	area.connect("input_event", _on_input_event)
	area.connect("area_entered", _on_area_entered)
	area.connect("area_exited", _on_area_exited)
	scale = base_scale

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not dragging and piece_being_dragged == null:
				_start_drag()
		else:
			if dragging:
				_stop_drag()

func _unhandled_input(event):
	if dragging and event is InputEventMouseButton and not event.pressed:
		_stop_drag()

func _input(event):
	if dragging and event is InputEventMouseMotion:
		global_position = global_position.lerp(event.global_position - offset, 0.5)

func _start_drag():
	dragging = true
	piece_being_dragged = self

	original_position = global_position
	offset = get_global_mouse_position() - global_position
	original_parent = get_parent()
	original_index = get_index()

	var gpos = global_position
	original_parent.remove_child(self)
	drag_layer.add_child(self)
	global_position = gpos

	create_tween().tween_property(self, "scale", grab_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _stop_drag():
	if not dragging:
		return

	dragging = false
	piece_being_dragged = null

	var slot = _get_best_slot()

	if slot != null and not slot.occupied:
		drag_layer.remove_child(self)
		slot.add_child(self)
		slot.occupied = true

		var t = create_tween()
		t.tween_property(self, "global_position", slot.global_position, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "scale", base_scale, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	else:
		drag_layer.remove_child(self)
		original_parent.add_child(self)
		original_parent.move_child(self, original_index)

		create_tween().tween_property(self, "global_position", original_position, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(self, "scale", base_scale, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	overlapped_slots.clear()

func _on_area_entered(area: Area2D):
	if area.is_in_group("slot") and not overlapped_slots.has(area):
		overlapped_slots.append(area)

func _on_area_exited(area: Area2D):
	if area.is_in_group("slot"):
		overlapped_slots.erase(area)

func _get_best_slot() -> Area2D:
	if overlapped_slots.is_empty():
		return null

	var closest_slot: Area2D
	var closest_dist = INF

	for slot in overlapped_slots:
		var dist = global_position.distance_to(slot.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_slot = slot

	return closest_slot
