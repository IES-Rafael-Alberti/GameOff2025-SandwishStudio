extends Control

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
@onready var progress_label: Label = $PanelBg/progress_label

var slide_base_pos: Vector2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("HelpOverlay READY")

	var empty_style := StyleBoxEmpty.new()
	for b in [btn_prev, btn_next]:
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", empty_style)
		b.add_theme_stylebox_override("hover", empty_style)
		b.add_theme_stylebox_override("pressed", empty_style)
		b.add_theme_stylebox_override("focus", empty_style)
		b.add_theme_stylebox_override("hover_pressed", empty_style)

	# Que el papiro no robe el ratón si pasa por encima del botón
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Botón de help siempre visible por encima
	help_button.visible = true
	help_button.z_index = 30
	help_button.mouse_filter = Control.MOUSE_FILTER_STOP
	help_button.pressed.connect(toggle_overlay)

	# El overlay existe siempre, pero el papiro empieza cerrado
	visible = true
	panel_bg.visible = false

	# Guardamos la posición base de las slides (la que tienes puesta en el editor)
	slide_base_pos = slide_current.position

	if not slides.is_empty():
		current_index = 0
		slide_current.texture = slides[current_index]
		slide_current.position = slide_base_pos
	else:
		current_index = 0

	slide_next.visible = false
	slide_next.position = slide_base_pos

	_build_dots()
	_update_buttons()
	_update_dots()
	_update_progress_bar()

	btn_prev.pressed.connect(_on_btn_prev_pressed)
	btn_next.pressed.connect(_on_btn_next_pressed)


# API: abrir / cerrar
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

	# Mientras el help está abierto, bloqueamos clicks al juego
	mouse_filter = Control.MOUSE_FILTER_STOP

	panel_bg.visible = true
	panel_bg.modulate.a = 0.0
	panel_bg.position = Vector2(0, 0)

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
		# Cuando cerramos, dejamos de bloquear el juego
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


# Dots, botones
func _build_dots() -> void:
	if dots == null:
		print("HelpOverlay: dots es null, revisa el nodo PanelBg/Dots")
		return

	for c in dots.get_children():
		c.queue_free()

	for i in range(max(slides.size(), 1)):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.25)
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
			sb.bg_color = Color(1, 1, 1, 1.0)
			dot.custom_minimum_size = Vector2(12, 12)
		else:
			sb.bg_color = Color(1, 1, 1, 0.25)
			dot.custom_minimum_size = Vector2(10, 10)

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

	# Ancho que usaremos para sacar/entrar las slides
	var slide_width: float = slide_current.size.x * 1.1
	# Si prefieres fijo: var slide_width: float = 904.0 * 1.1

	# Preparar la siguiente slide
	slide_next.texture = slides[new_index]
	slide_next.visible = true

	# Colocarla fuera, pero RELATIVA a la base
	slide_current.position = slide_base_pos
	slide_next.position = slide_base_pos + Vector2(direction * slide_width, 0.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Slide actual sale hacia el lado contrario
	tween.tween_property(
		slide_current, "position",
		slide_base_pos + Vector2(-direction * slide_width, 0.0),
		0.35
	)

	# Slide nueva entra hasta la posición base
	tween.parallel().tween_property(
		slide_next, "position",
		slide_base_pos,
		0.35
	)

	tween.finished.connect(func() -> void:
		slide_current.texture = slide_next.texture
		slide_current.position = slide_base_pos

		slide_next.visible = false
		slide_next.position = slide_base_pos

		current_index = new_index
		is_animating = false

		_update_buttons()
		_update_dots()
		_update_progress_bar()
	)


func _update_progress_bar() -> void:
	if progress_label:
		if slides.is_empty():
			progress_label.text = "0 / 0"
		else:
			progress_label.text = "%d / %d" % [current_index + 1, slides.size()]
