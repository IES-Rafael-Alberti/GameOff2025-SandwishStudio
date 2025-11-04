extends Sprite2D

class_name enemy

@export var enemy_res: enemyRes 

func _ready() -> void:
	texture = enemy_res.sprite
