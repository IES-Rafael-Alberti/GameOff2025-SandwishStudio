# game.gd
extends Node2D

## ------------------------------------------------------------------
## Estado del Juego (FSM)
## ------------------------------------------------------------------
enum GameState {
	SHOP,      # Fase de Tienda: Comprando items (Ruleta oculta)
	ROULETTE,  # Fase de Ruleta: Preparando la ruleta (Tienda oculta)
	SPINNING,  # Ruleta Girando: Interacciones bloqueadas
	COMBAT     # Combate en curso: Interacciones bloqueadas
}
var current_state: GameState
var current_round: int = 1

## ------------------------------------------------------------------
## Nodos
## ------------------------------------------------------------------
@onready var buttonShop: Button = $ButtonShop
@onready var sprite_show: Sprite2D = $ButtonShop/EyeSprite
@onready var pupil: Sprite2D = $ButtonShop/EyeSprite/Pupil
@onready var mat = $Store/Sprite2D.material
@onready var anim = $Store/AnimationPlayer
@onready var gold_label: Label = $gold_label
@onready var store: Control = $Store
@onready var inventory: Control = $inventory
@onready var roulette: Node2D = $Roulette
@onready var combat_scene: Node2D = $combat_scene

var pupil_offset: Vector2
var original_eye_texture: Texture2D
var eye_closed_texture: Texture2D
var blink_timer := 0.0
var blink_interval_min := 2.0
var blink_interval_max := 5.0
var blink_time := 0.1
var pause_scene = preload("res://scenes/pause.tscn")
var is_tended = true # true = tienda cerrada/ruleta visible; false = tienda abierta/ruleta oculta
var original_positions = {}
var blink_tween: Tween = null
var max_distance: float = 100

# ¡ELIMINADA LA VARIABLE 'anim_playing'!
# Ya no la necesitamos, usaremos anim.is_playing() para todo.

## ------------------------------------------------------------------
## Funciones de Godot
## ------------------------------------------------------------------

func _ready():
	pupil_offset = pupil.position
	eye_closed_texture = preload("res://assets/Oculta.png")
	original_eye_texture = sprite_show.texture

	for child in store.get_children():
		if child is CanvasItem:
			original_positions[child] = child.position
			child.modulate.a = 1.0

	# --- Conexiones de la FSM ---
	if roulette.has_signal("roulette_spin_started"):
		roulette.roulette_spin_started.connect(_on_roulette_spin_started)
	else:
		push_warning("gameManager.gd: ¡RouletteScene.gd necesita la señal 'roulette_spin_started'!")
		
	GlobalSignals.combat_requested.connect(_on_combat_requested)
	
	if combat_scene and combat_scene.has_signal("combat_finished"):
		combat_scene.combat_finished.connect(_on_combat_finished)
	else:
		push_warning("gameManager.gd: ¡CombatScene.gd necesita la señal 'combat_finished'!")

	# --- Conexiones de UI (Originales) ---
	# ¡CAMBIO! Ya no necesitamos conectar "animation_finished" para la variable 'anim_playing'
	# anim.connect("animation_finished", Callable(self, "_on_animation_finished")) # <- Eliminada
	# La reconectamos solo para la lógica de ocultar la tienda
	anim.connect("animation_finished", Callable(self, "_on_animation_finished"))

	buttonShop.connect("pressed", Callable(self, "_on_shop_button_pressed"))
	buttonShop.connect("mouse_entered", Callable(self, "_on_shop_hover"))
	buttonShop.connect("mouse_exited", Callable(self, "_on_shop_exit"))
	PlayerData.currency_changed.connect(_on_PlayerData_currency_changed)
	if inventory.has_signal("item_sold"):
		inventory.item_sold.connect(PlayerData.add_currency)
	else:
		push_warning("game.gd: El nodo de inventario no tiene la señal 'item_sold'.")

	blink_timer = randf_range(blink_interval_min, blink_interval_max)
	_on_PlayerData_currency_changed(PlayerData.get_current_currency())
	store.generate()

	# --- Arranque del Juego ---
	if current_round == 1:
		_give_initial_piece()
		set_state(GameState.ROULETTE)
	else:
		set_state(GameState.SHOP)


func _process(delta: float) -> void:
	if not is_tended:
		pupil.visible = false
	else:
		pupil.visible = true
		blink_timer -= delta
		_update_pupil_position()
		if blink_timer <= 0.0 and sprite_show.visible:
			await _toggle_eye_parpadeo()
			blink_timer = randf_range(blink_interval_min, blink_interval_max)

	if Input.is_action_just_pressed("pause"):
		pausar()

## ------------------------------------------------------------------
## Máquina de Estados (FSM)
## ------------------------------------------------------------------

func set_state(new_state: GameState):
	if current_state == new_state:
		return
		
	# No permitir cambiar de estado si la tienda se está animando
	if anim.is_playing():
		return

	print("Cambiando de estado: %s -> %s" % [GameState.keys()[current_state], GameState.keys()[new_state]])
	current_state = new_state

	match current_state:
		GameState.SHOP:
			_toggle_store(false) # Abrir tienda
			buttonShop.disabled = false
			inventory.set_interactive(true)
			
		GameState.ROULETTE:
			_toggle_store(true) # Cerrar tienda
			buttonShop.disabled = false
			inventory.set_interactive(true)
			roulette.set_interactive(true)

		GameState.SPINNING:
			buttonShop.disabled = true
			inventory.set_interactive(false)
			roulette.set_interactive(false)

		GameState.COMBAT:
			buttonShop.disabled = true
			inventory.set_interactive(false)
			roulette.set_interactive(false)


## ------------------------------------------------------------------
## Transiciones de Estado (Señales)
## ------------------------------------------------------------------

# El jugador pulsa el botón de la tienda/ruleta
func _on_shop_button_pressed():
	# Comprobamos directamente la animación
	if anim.is_playing():
		return
		
	# El botón ahora cambia entre fases
	if current_state == GameState.SHOP:
		set_state(GameState.ROULETTE)
	elif current_state == GameState.ROULETTE:
		set_state(GameState.SHOP)

# La ruleta EMPIEZA a girar
func _on_roulette_spin_started():
	set_state(GameState.SPINNING)

# La ruleta TERMINA y pide combate
func _on_combat_requested(_piece_resource: Resource):
	set_state(GameState.COMBAT)

# El combate TERMINA
func _on_combat_finished():
	current_round += 1
	print("--- Fin de la Ronda. Empezando Ronda %d ---" % current_round)
	set_state(GameState.SHOP)
	store.generate()


## ------------------------------------------------------------------
## Lógica de Arranque (Ronda 1)
## ------------------------------------------------------------------

func _give_initial_piece():
	if not inventory.has_method("get_random_initial_piece"):
		push_error("gameManager.gd: inventory.gd no tiene el método 'get_random_initial_piece()'")
		return

	var initial_piece: Resource = inventory.get_random_initial_piece()
	if initial_piece:
		if inventory.can_add_item(initial_piece):
			inventory.add_item(initial_piece)
			print("Ronda 1: Pieza inicial '%s' añadida al inventario." % initial_piece.resource_name)
		else:
			push_warning("Ronda 1: Inventario lleno, no se pudo añadir la pieza inicial.")
	else:
		push_warning("Ronda 1: No se pudo obtener una pieza inicial (¿Array 'initial_pieces' vacío en inventory.gd?)")


## ------------------------------------------------------------------
## Funciones de UI (Originales Modificadas)
## ------------------------------------------------------------------

# 'close_store' = true (cerrar tienda, mostrar ruleta)
# 'close_store' = false (abrir tienda, ocultar ruleta)
func _toggle_store(close_store: bool):
	
	# Solo comprobamos si la animación está en curso
	if anim.is_playing():
		return
		
	# ¡ERROR CORREGIDO!
	# Eliminamos la comprobación 'if close_store == is_tended: return'
	# Siempre ejecutaremos la animación para forzar la sincronización visual.

	is_tended = close_store
	_update_eye_state()
	
	# Ocultamos la ruleta INMEDIATAMENTE si vamos a abrir la tienda
	if not is_tended:
		roulette.visible = false

	if is_tended:
		anim.play("roll") # Animación de cerrar tienda
		animate_store(true, Callable(self, "_on_store_hidden"))
	else:
		store.visible = true # Animación de abrir tienda
		anim.play("unroll")
		animate_store(false)

	var target = 1.0 if is_tended else 0.0
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/roll_amount", target, 0.6)


# ¡CAMBIO!
# Esta función ahora solo se usa para ocultar el nodo 'store'
# después de que la animación "roll" (cerrar) termine.
func _on_animation_finished(anim_name: String):
	# Mostrar ruleta SOLO si la tienda está cerrada (is_tended = true)
	roulette.visible = is_tended
	
	if anim_name == "roll":
		store.visible = false

# --- Señales ---
func _on_PlayerData_currency_changed(new_amount: int) -> void:
	if gold_label:
		gold_label.text = str(new_amount) + "€"

# --- Parpadeo ---
func _toggle_eye_parpadeo() -> void:
	if not is_tended:
		return
	sprite_show.texture = eye_closed_texture
	await get_tree().create_timer(0.07).timeout
	sprite_show.texture = original_eye_texture

# --- Pupila ---
func _update_pupil_position():
	if not pupil.visible or not sprite_show.visible:
		return
	var mouse_global = get_global_mouse_position()
	var eye_global_pos = sprite_show.global_position
	var dir = mouse_global - eye_global_pos
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

# --- Ojo según estado ---
func _update_eye_state():
	if is_tended:
		sprite_show.texture = original_eye_texture
		pupil.visible = true
	else:
		sprite_show.texture = eye_closed_texture
		pupil.visible = false

# --- Animaciones ---
func start_unroll():
	anim.play("unroll")
	store.visible = true
	roulette.visible = false
	animate_store(false)

	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/roll_amount", 0.0, 0.6)

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

func _on_store_hidden():
	store.visible = false

func pausar():
	var pause_instance = pause_scene.instantiate()
	add_child(pause_instance)
	get_tree().paused = true
