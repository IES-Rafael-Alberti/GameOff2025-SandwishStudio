extends Control

# 11 imágenes (o las que sean) que tendrán el contenido
@export var slides: Array[Texture2D] = []

var current_index: int = 0
var is_animating: bool = false

@onready var panel_bg: TextureRect = $PanelBg
@onready var slide_current: TextureRect = $PanelBg/SlideCurrent
@onready var slide_next: TextureRect = $PanelBg/SlideNext
@onready var btn_prev: Button = $PanelBg/BtnPrev
@onready var btn_next: Button = $PanelBg/BtnNext
@onready var dots: HBoxContainer = $PanelBg/Dots
@onready var help_button: Button = $HelpButton

func _ready() -> void:
	print("HelpOverlay READY")

	help_button.visible = true

	# Siempre estamos vivos
	visible = true
	panel_bg.visible = true

	if get_tree().current_scene != self:
		# Usada dentro de game → empezar cerrado
		panel_bg.visible = false

	if slides.is_empty():
		push_warning("HelpOverLay: 'slides' está vacío, asigna las imágenes en el inspector.")
	else:
		current_index = 0
		slide_current.texture = slides[current_index]
		slide_current.position = Vector2.ZERO

	slide_next.visible = false
	slide_next.position = Vector2.ZERO

	_build_dots()
	_update_buttons()
	_update_dots()

	btn_prev.pressed.connect(_on_btn_prev_pressed)
	btn_next.pressed.connect(_on_btn_next_pressed)
	help_button.pressed.connect(func(): toggle_overlay())

# API para la escena Game
func toggle_overlay() -> void:
	if is_animating:
		print("HelpOverlay: ignorado, está animando")
		return

	print("HelpOverlay: toggle_overlay, panel_bg.visible =", panel_bg.visible)

	if panel_bg.visible:
		_close_overlay()
	else:
		_open_overlay()

func _open_overlay() -> void:
	print("HelpOverlay: _open_overlay")
	panel_bg.visible = true
	panel_bg.modulate.a = 0.0
	panel_bg.position = Vector2(0, -40)

	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(panel_bg, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(panel_bg, "position", Vector2.ZERO, 0.2)

func _close_overlay() -> void:
	print("HelpOverlay: _close_overlay")
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(panel_bg, "modulate:a", 0.0, 0.15)
	t.parallel().tween_property(panel_bg, "position", Vector2(0, -40), 0.15)
	t.finished.connect(func():
		panel_bg.visible = false
		panel_bg.position = Vector2.ZERO
		panel_bg.modulate.a = 1.0
	)

# Puntos del carrusel
func _build_dots() -> void:
	if dots == null:
		print("HelpOverlay: dots es null, revisa el nodo PanelBg/Dots")
		return

	# Borrar puntos anteriores
	for c in dots.get_children():
		c.queue_free()

	# Crear los nuevos puntos
	for i in range(max(slides.size(), 1)):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)

		# StyleBox para permitir color + bordes redondeados
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.25)  # apagado
		sb.corner_radius_top_left = 5
		sb.corner_radius_top_right = 5
		sb.corner_radius_bottom_left = 5
		sb.corner_radius_bottom_right = 5

		dot.add_theme_stylebox_override("panel", sb)
		dots.add_child(dot)

func _update_dots() -> void:
	for i in range(dots.get_child_count()):
		var dot := dots.get_child(i) as Panel
		var sb := dot.get_theme_stylebox("panel") as StyleBoxFlat

		if i == current_index:
			# punto activo
			sb.bg_color = Color(1, 1, 1, 1.0)
			dot.custom_minimum_size = Vector2(12, 12)
		else:
			# punto apagado
			sb.bg_color = Color(1, 1, 1, 0.25)
			dot.custom_minimum_size = Vector2(10, 10)

# Botones izquierdo/derecho
func _update_buttons() -> void:
	if is_animating:
		btn_prev.disabled = true
		btn_next.disabled = true
		return

	btn_prev.disabled = (current_index == 0)
	btn_next.disabled = (current_index == slides.size() - 1)

func _on_btn_next_pressed() -> void:
	if is_animating: return
	if current_index >= slides.size() - 1: return
	_show_slide(current_index + 1, +1)

func _on_btn_prev_pressed() -> void:
	if is_animating: return
	if current_index <= 0: return
	_show_slide(current_index - 1, -1)

func _show_slide(new_index: int, direction: int) -> void:
	if new_index < 0 or new_index >= slides.size():
		return

	is_animating = true
	_update_buttons()

	var slide_width: float = get_viewport_rect().size.x * 1.1

	slide_next.texture = slides[new_index]
	slide_next.visible = true
	slide_next.position = Vector2(direction * slide_width, 0.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		slide_current, "position",
		Vector2(-direction * slide_width, 0.0),
		0.35
	)
	tween.parallel().tween_property(
		slide_next, "position",
		Vector2.ZERO,
		0.35
	)

	tween.finished.connect(func() -> void:
		slide_current.texture = slide_next.texture
		slide_current.position = Vector2.ZERO

		slide_next.visible = false
		slide_next.position = Vector2.ZERO

		current_index = new_index
		is_animating = false

		_update_buttons()
		_update_dots()
	)
