extends TextureRect

var bitmap: BitMap

func _ready():
	# Crear el mapa de bits manualmente desde la textura
	var img = texture.get_image()
	bitmap = BitMap.new()
	bitmap.create_from_image_alpha(img)

func _has_point(point: Vector2) -> bool:
	# Verificamos primero si el punto está dentro de los límites de la imagen
	var texture_size = texture.get_size()
	if point.x < 0 or point.y < 0 or point.x >= texture_size.x or point.y >= texture_size.y:
		return false

	# CORRECCIÓN: Pasamos X e Y por separado convertidos a enteros
	return bitmap.get_bit(int(point.x), int(point.y))
