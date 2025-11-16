# game.gd
extends Node2D

@onready var buttonShop: Button = $ButtonShop
@onready var sprite_show: Sprite2D = $ButtonShop/EyeSprite
@onready var pupil: Sprite2D = $ButtonShop/EyeSprite/Pupil
@onready var mat = $Store/Sprite2D.material
@onready var anim = $Store/AnimationPlayer
@onready var gold_label: Label = $gold_label
@onready var store: Control = $Store
@onready var inventory: Control = $inventory
@onready var roulette: Node2D = $Roulette

var pupil_offset: Vector2
var original_eye_texture: Texture2D
var eye_closed_texture: Texture2D
var blink_timer := 0.0
var blink_interval_min := 2.0
var blink_interval_max := 5.0
var blink_time := 0.1
var pause_scene = preload("res://scenes/pause.tscn")
var is_tended = true
var anim_playing = false
var original_positions = {}
var blink_tween: Tween = null
var max_distance: float = 5.0

func _ready():
	pupil_offset = pupil.position
	eye_closed_texture = preload("res://assets/Mostrada.png")
	original_eye_texture = sprite_show.texture

	# Guardar posiciones originales
	for child in store.get_children():
		if child is CanvasItem:
			original_positions[child] = child.position
			child.modulate.a = 1.0

	anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
	buttonShop.connect("pressed", Callable(self, "_on_shop_button_pressed"))
	buttonShop.connect("mouse_entered", Callable(self, "_on_shop_hover"))
	buttonShop.connect("mouse_exited", Callable(self, "_on_shop_exit"))

	PlayerData.currency_changed.connect(_on_PlayerData_currency_changed)
	if inventory.has_signal("item_sold"):
		inventory.item_sold.connect(PlayerData.add_currency)
	else:
		push_warning("game.gd: El nodo de inventario no tiene la señal 'item_sold'.")

	# Sincronizar estado inicial
	_update_eye_state()
	roulette.visible = is_tended
	_on_PlayerData_currency_changed(PlayerData.get_current_currency())
	store.generate()

func _process(delta: float) -> void:
	if not is_tended:
		blink_timer -= delta
		if blink_timer <= 0.0 and sprite_show.visible:
			await _toggle_eye_parpadeo()
			blink_timer = randf_range(blink_interval_min, blink_interval_max)
	if Input.is_action_just_pressed("pause"):
		pausar()
	_update_pupil_position()

# --- Señales ---
func _on_PlayerData_currency_changed(new_amount: int) -> void:
	if gold_label:
		gold_label.text = str(new_amount) + "€"

# --- Parpadeo ---
func _toggle_eye_parpadeo() -> void:
	if is_tended:
		return

	sprite_show.texture = eye_closed_texture
	await get_tree().create_timer(0.07).timeout
	sprite_show.texture = original_eye_texture

# --- Pupila ---
func _update_pupil_position():
	if not pupil.visible or not sprite_show.visible:
		return

	var mouse_global = get_viewport().get_mouse_position()
	var mouse_local = sprite_show.to_local(mouse_global)
	var dir = pupil_offset - mouse_local 
	if dir.length() > max_distance:
		dir = dir.normalized() * max_distance
	pupil.position = pupil_offset + dir

# --- Hover del botón de tienda ---
func _on_shop_hover():
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	blink_tween = create_tween()
	blink_tween.tween_property(sprite_show, "modulate:a", 0.5, 0.12)
	blink_tween.tween_property(sprite_show, "modulate:a", 1.0, 0.12)

func _on_shop_exit():
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	sprite_show.modulate.a = 1.0

# --- Presionar botón de tienda ---
func _on_shop_button_pressed():
	if anim_playing:
		return
	_toggle_store()

# --- Toggle tienda y ruleta ---
func _toggle_store():
	if anim_playing:
		return

	anim_playing = true
	is_tended = !is_tended

	# Actualizar estado del ojo
	_update_eye_state()

	# La ruleta desaparece **antes** de la animación
	roulette.visible = false

	# Animación de tienda
	if is_tended:
		anim.play("roll")
		animate_store(true, Callable(self, "_on_store_hidden"))
	else:
		store.visible = true
		anim.play("unroll")
		animate_store(false)

	# Tween del shader de roll_amount
	var target = 1.0 if is_tended else 0.0
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/roll_amount", target, 0.6)
	tween.connect("finished", Callable(self, "_update_collision"))

# --- Cuando termina la animación ---
func _on_animation_finished(anim_name: String):
	anim_playing = false
	# Mostrar ruleta solo si la tienda está desplegada
	roulette.visible = is_tended

# --- Ojo según estado ---
func _update_eye_state():
	if is_tended:
		sprite_show.texture = eye_closed_texture
		pupil.visible = true
	else:
		sprite_show.texture = original_eye_texture
		pupil.visible = false

# --- Animaciones ---
func start_unroll():
	anim.play("unroll")
	store.visible = true
	roulette.visible = false
	animate_store(false)

	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/roll_amount", 0.0, 0.6)
	tween.connect("finished", Callable(self, "_update_collision"))

func animate_store(hide: bool, callback: Callable = Callable()):
	var tween = get_tree().create_tween()
	var delay = 0.0
	for child in store.get_children():
		if not (child is CanvasItem):
			continue
		var orig_pos = original_positions.get(child, child.position)
		var offset = Vector2(200, 0)
		var target_pos = orig_pos + offset if hide else orig_pos
		var target_alpha = 0.0 if hide else 1.0
		tween.parallel().tween_property(child, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		tween.parallel().tween_property(child, "modulate:a", target_alpha, 0.5).set_delay(delay)
		delay += 0.05
	if callback.is_valid():
		tween.tween_callback(callback)

func pausar():
	var pause_instance = pause_scene.instantiate()
	add_child(pause_instance)
	get_tree().paused = true
