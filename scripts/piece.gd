extends Control

@export_multiline var description: String
@export var piece_origin: PackedScene
@export var price: int
@onready var sprite_2d: Sprite2D = $Sprite2D


func _ready() -> void:
	if piece_origin:
		var piece_instanced = piece_origin.instantiate()
		var sprite_in_piece = piece_instanced.find_child("Sprite2D", true, false)

		if sprite_in_piece and sprite_in_piece.texture:
			sprite_2d.texture = sprite_in_piece.texture

		piece_instanced.queue_free()
