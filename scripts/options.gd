extends Control

signal opened
signal closed

@onready var papiro: TextureRect = $Papiro

var _visible_pos: Vector2
var _hidden_pos: Vector2
var _closing: bool = false

var is_pause_menu: bool = false

func _ready() -> void:
	# Que se dibuje por encima de todo y no herede transforms raros
	top_level = true
	z_index = 100

	process_mode = Node.PROCESS_MODE_ALWAYS

	_visible_pos = papiro.position 
	_hidden_pos = Vector2(-papiro.size.x - 350.0, _visible_pos.y)
	papiro.position = _hidden_pos

	var tween := create_tween()
	tween.tween_property(papiro, "position", _visible_pos, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		opened.emit()
	)

func _setup_and_open() -> void:
	var viewport_size := get_viewport_rect().size

	if is_pause_menu:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
		size = viewport_size
		mouse_filter = Control.MOUSE_FILTER_STOP

		_visible_pos = (viewport_size - papiro.size) * 0.5
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		_visible_pos = papiro.position

	_hidden_pos = _visible_pos + Vector2(0, -papiro.size.y * 1.4)
	papiro.position = _hidden_pos

	print("OPTIONS _setup_and_open  is_pause_menu =", is_pause_menu,
		"  visible_pos =", _visible_pos, "  hidden_pos =", _hidden_pos)

	var tween := create_tween()
	tween.tween_property(papiro, "position", _visible_pos, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		opened.emit()
	)

func set_as_pause_menu(value: bool = true) -> void:
	is_pause_menu = value
	var tree := get_tree()
	if is_pause_menu:
		if tree:
			print("OPTIONS: set_as_pause_menu(true) -> tree.paused = true")
			tree.paused = true
	else:
		if tree:
			print("OPTIONS: set_as_pause_menu(false) -> tree.paused = false")
			tree.paused = false

func close_with_anim() -> void:
	if _closing:
		return
	_closing = true

	var tween := create_tween()
	tween.tween_property(papiro, "position", _hidden_pos, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		var tree := get_tree()
		if is_pause_menu and tree:
			tree.paused = false
			print("OPTIONS: cerrando pausa -> tree.paused = false")
		closed.emit()
		queue_free()
	)

func _on_back_pressed() -> void:
	close_with_anim()

func _process(delta: float) -> void:
	if is_pause_menu and Input.is_action_just_pressed("pause"):
		close_with_anim()
