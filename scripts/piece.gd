extends Node2D

@export var base_scale := Vector2(0.6,0.6)
@export var grab_scale := Vector2(0.85,0.85)
@export var drag_layer: Node
@export var inventory_node: Node
@export var highlight_color := Color(1,1,0.4,0.6)
@export var snap_duration := 0.15
@export var bounce_scale := 1.2
@export var bounce_time := 0.12
@export var sound_snap: AudioStreamPlayer2D
@export var sound_swap: AudioStreamPlayer2D
@export var sound_return: AudioStreamPlayer2D
@export var particles_snap: CPUParticles2D

var dragging = false
var offset = Vector2.ZERO
var original_parent
var original_index
var original_position
static var piece_being_dragged = null
@onready var area = $Area2D
@onready var sprite = $Sprite2D
var overlapped_slots = []
var ruleta = null
var blocked = false

func _ready():
	scale = base_scale
	area.input_pickable = true
	area.connect("input_event", _on_input_event)
	area.connect("area_entered", _on_area_entered)
	area.connect("area_exited", _on_area_exited)
   
	# Conectar con la ruleta si existe
	ruleta = get_tree().get_current_scene().get_node_or_null("Roulette")
	if ruleta:
		ruleta.connect("start_spin", Callable(self,"_on_ruleta_spin_start"))
		ruleta.connect("end_spin", Callable(self,"_on_ruleta_spin_end"))
		
func _on_ruleta_spin_start():
	blocked = true

func _on_ruleta_spin_end():
	blocked = false
	
func _on_input_event(_viewport, event, _shape_idx):
	if blocked: return  # ❌ Bloqueo mientras ruleta gira
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not dragging and piece_being_dragged == null:
			if ruleta and ruleta.is_moving(): return
			_start_drag()
		elif not event.pressed and dragging:
			_stop_drag()

func _input(event):
	if blocked: return
	if dragging and event is InputEventMouseMotion:
		global_position = event.global_position - offset

func _start_drag():
	if not drag_layer: return
	dragging = true
	piece_being_dragged = self
	original_position = global_position
	offset = get_global_mouse_position()-global_position
	original_parent = get_parent()
	original_index = get_index()
	var gpos = global_position
	original_parent.remove_child(self)
	drag_layer.add_child(self)
	global_position = gpos
	create_tween().tween_property(self,"scale",grab_scale,0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _stop_drag():
	if not dragging: return
	dragging = false
	piece_being_dragged = null
	var slot = _get_best_slot()
	if slot != null:
		_place_in_slot(slot)
	else:
		_return_to_inventory()
	_clear_slot_highlights()
	overlapped_slots.clear()

func _place_in_slot(slot):
	if not slot: return
	if slot.occupied:
		var other_piece = slot.get_child(0)
		if other_piece and other_piece != self:
			_swap_with(other_piece)
	if get_parent() == drag_layer:
		drag_layer.remove_child(self)
	slot.add_child(self)
	slot.occupied = true
	var t = create_tween()
	t.tween_property(self,"global_position",slot.global_position,snap_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self,"scale",base_scale*bounce_scale,bounce_time)
	t.tween_property(self,"scale",base_scale,bounce_time)
	t.play()
	if sound_snap: sound_snap.play()
	if particles_snap:
		particles_snap.global_position = global_position
		particles_snap.emitting = true

func _swap_with(other_piece):
	if not other_piece: return
	var t = create_tween()
	t.tween_property(other_piece,"global_position",original_position,snap_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.play()
	if inventory_node:
		drag_layer.add_child(other_piece)
		inventory_node.add_child(other_piece)
		other_piece.global_position = inventory_node.to_global(Vector2.ZERO)
	else:
		drag_layer.add_child(other_piece)
		original_parent.add_child(other_piece)
		original_parent.move_child(other_piece,other_piece.original_index)
		other_piece.global_position = other_piece.original_position
	if sound_swap: sound_swap.play()

func _return_to_inventory():
	var t = create_tween()
	if get_parent() == drag_layer: drag_layer.remove_child(self)
	if inventory_node:
		inventory_node.add_child(self)
		t.tween_property(self,"global_position",inventory_node.to_global(Vector2.ZERO),snap_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif original_parent:
		original_parent.add_child(self)
		original_parent.move_child(self,original_index)
		t.tween_property(self,"global_position",original_position,snap_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self,"scale",base_scale,snap_duration)
	t.play()
	if sound_return: sound_return.play()

func _on_area_entered(area):
	if blocked: return
	if area.is_in_group("slot") and not overlapped_slots.has(area):
		overlapped_slots.append(area)
		_highlight_slot(area,true)

func _on_area_exited(area):
	if blocked: return
	if area.is_in_group("slot"):
		overlapped_slots.erase(area)
		_highlight_slot(area,false)

func _get_best_slot():
	if not overlapped_slots: return null
	var closest = null
	var min_dist = INF
	for s in overlapped_slots:
		if not s: continue
		var dist = global_position.distance_to(s.global_position)
		if dist<min_dist:
			min_dist=dist
			closest=s
	return closest

func _highlight_slot(slot,enable):
	if not slot.has_node("Highlight"):
		var h = ColorRect.new()
		h.name="Highlight"
		h.color=highlight_color
		h.size=Vector2(80,80)
		slot.add_child(h)
	slot.get_node("Highlight").visible = enable

func _clear_slot_highlights():
	for s in overlapped_slots:
		_highlight_slot(s,false)
		
