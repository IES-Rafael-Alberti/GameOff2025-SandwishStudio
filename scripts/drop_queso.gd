extends Marker2D


func _draw():
	draw_circle(Vector2.ZERO, 10, Color.RED)
	
func select():
	for c in get_tree().get_nodes_in_group("zone"):
		c.deselect()
	modulate = Color.BLACK
	
func deselect():
	modulate = Color.RED
