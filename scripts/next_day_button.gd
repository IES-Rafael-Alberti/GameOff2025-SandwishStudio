extends TextureButton

const SHADER_OUTLINE = preload("res://shaders/outline_highlight.gdshader")

var highlight_material: ShaderMaterial

func _ready() -> void:
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = SHADER_OUTLINE

	highlight_material.set_shader_parameter("color", Color.WHITE) 
	highlight_material.set_shader_parameter("width", 4.0) 
	highlight_material.set_shader_parameter("pattern", 0) 
	highlight_material.set_shader_parameter("inside", false)
	highlight_material.set_shader_parameter("add_margins", true)
	

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	material = null

func _on_mouse_entered() -> void:
	material = highlight_material

func _on_mouse_exited() -> void:
	material = null
