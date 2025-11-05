extends Control

@export_multiline var description: String
@export var piece_origin: PackedScene
@onready var sprite_2d: Sprite2D = $Sprite2D

var draggable = false
var is_inside_dropable = false
var body_ref

func _ready() -> void:
	if piece_origin:
		var piece_instanced = piece_origin.instantiate()
		var sprite_in_piece = piece_instanced.find_child("Sprite2D", true, false)

		if sprite_in_piece and sprite_in_piece.texture:
			sprite_2d.texture = sprite_in_piece.texture

		piece_instanced.queue_free()
		
func _process(delta):
	if draggable:
		if Input.is_action_just_pressed("click"):
			initialPos = global_position
			offset = get_global_mouse_position() - global_position
			global.is_dragging = true
		if Input.is_action_just_pressed("click"):
			global_position = get_global_mouse_position() - offset
		elif Input.is_action_just_pressed("click"):
			global.is_dragging = false
			var tween = get_tree().create_tween()
			if is_inside_dropable:
				tween.tween_property(self, "position", body_ref.position,0.2).set_case(Tween.EASE_OUT)
			else:
				tween.tween_property(self, "position", body_ref.position,0.2).set_case(Tween.EASE_OUT)
		
func _on_area_2d_mouse_entered(area):
	if not global.is_dragging:
		draggable = true
		scale= Vector2(1.05, 1.05)

func _on_area_2d_area_exited(area):
	if not global.is_dragging:
		draggable = false
		scale= Vector2(1, 1)
		
func _on_area_2d_body_entered(body):
	if body.is_in_group('dropable'):
		is_inside_dropable = true
		body.modulate = Color(Color.REBECCA_PURPLE, 1)
		body_ref = body
	

func _on_area_2d_body_exited(body):
	if body.is_in_group('dropable'):
		is_inside_dropable = false
		body.modulate = Color(Color.MEDIUM_PURPLE, 0.7)
	
