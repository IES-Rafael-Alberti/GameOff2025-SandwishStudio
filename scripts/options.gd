extends Control

signal opened
signal closed

@onready var papiro: TextureRect = $Papiro

var _visible_pos: Vector2
var _hidden_pos: Vector2
var _closing: bool = false

func _ready() -> void:
	_visible_pos = papiro.position
	_hidden_pos = Vector2(-papiro.size.x - 350.0, _visible_pos.y)
	papiro.position = _hidden_pos

	var tween := create_tween()
	tween.tween_property(papiro, "position", _visible_pos, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# cuando termina de entrar, avisamos al menú
	tween.tween_callback(func():
		opened.emit()
	)

func close_with_anim() -> void:
	if _closing:
		return
	_closing = true

	var tween := create_tween()
	tween.tween_property(papiro, "position", _hidden_pos, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		closed.emit()
		queue_free()
	)

func _on_back_pressed() -> void:
	close_with_anim()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		close_with_anim()
