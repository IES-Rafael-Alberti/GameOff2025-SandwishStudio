extends Sprite2D

# Cargamos el mismo shader que usa la palanca de la ruleta
const OUTLINE_SHADER = preload("res://shaders/outline_highlight.gdshader")
var highlight_material: ShaderMaterial

# Referencia al botón hijo que gestiona la interacción
@onready var button_shop = $ButtonShop

func _ready():
	# Configuración del material idéntica a RuletaScene.gd
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = OUTLINE_SHADER
	highlight_material.set_shader_parameter("width", 30.0) 
	highlight_material.set_shader_parameter("color", Color.GOLDENROD)
	
	# Conectamos las señales del botón para detectar el cursor
	if button_shop:
		button_shop.mouse_entered.connect(_on_mouse_entered)
		button_shop.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	material = highlight_material

func _on_mouse_exited():
	material = null
