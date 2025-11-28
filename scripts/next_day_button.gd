extends TextureButton

# Cargamos el shader que ya tienes en el proyecto
const SHADER_OUTLINE = preload("res://shaders/outline_highlight.gdshader")

# Variable para guardar nuestro material personalizado
var highlight_material: ShaderMaterial

func _ready() -> void:
	# 1. Crear una nueva instancia de ShaderMaterial
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = SHADER_OUTLINE
	
	# 2. Configurar los parámetros del shader (Color, Ancho, etc.)
	# Puedes cambiar Color.WHITE por el color que prefieras (ej. Color(1, 0.8, 0))
	highlight_material.set_shader_parameter("color", Color.WHITE) 
	highlight_material.set_shader_parameter("width", 4.0) # Ajusta el grosor del borde aquí
	highlight_material.set_shader_parameter("pattern", 0) # 0 = Sólido
	highlight_material.set_shader_parameter("inside", false)
	highlight_material.set_shader_parameter("add_margins", true)
	
	# 3. Conectar las señales de ratón (Mouse Enter y Mouse Exit)
	# Esto detecta cuando el cursor entra o sale del botón
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# 4. Asegurarnos de que el material empiece desactivado
	material = null

# Cuando el ratón entra, asignamos el material de resaltado
func _on_mouse_entered() -> void:
	material = highlight_material

# Cuando el ratón sale, quitamos el material
func _on_mouse_exited() -> void:
	material = null
