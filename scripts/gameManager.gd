extends Node2D

## ------------------------------------------------------------------
## Estado del Juego (FSM)
## ------------------------------------------------------------------
enum GameState {
	SHOP,      # Fase de Tienda
	ROULETTE,  # Fase de Ruleta
	SPINNING,  # Ruleta Girando
	COMBAT     # Combate en curso
}
var current_state: GameState
var current_round: int = 1
var current_day: int = 1
var gladiators_defeated: int = 0 

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

# --- CONFIGURACIÓN ---
@export var gold_round_base: int = 100
@export var gold_day_mult: float = 1
@export var rounds_per_day: int = 10
@export var gladiators_per_day: int = 1
@export var gladiators_mult: int = 1
@export var max_days: int = 2

# --- UI LABELS ---
@onready var round_label: Label = $RoundLabel
@onready var day_label: Label = $DayLabel
@onready var gladiator_label: Label = $GladiatorLabel

# --- VISTAS (UI) ---
@onready var day_finished_view: CanvasLayer = $DayFinished
@onready var next_day_image: TextureRect = $DayFinished/NextDayImage 
@onready var game_over_view: CanvasLayer = $GameOver
@onready var win_view: CanvasLayer = $Win

var pupil_offset: Vector2
var original_eye_texture: Texture2D
var eye_closed_texture: Texture2D
var blink_timer := 0.0
var blink_interval_min := 2.0
var blink_interval_max := 5.0
var blink_time := 0.1
var pause_scene = preload("res://scenes/pause.tscn")
var is_tended = true
var original_positions = {}
var blink_tween: Tween = null
var max_distance: float = 100

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

	# --- Conexiones ---
	if roulette.has_signal("roulette_spin_started"):
		roulette.roulette_spin_started.connect(_on_roulette_spin_started)
	
	GlobalSignals.combat_requested.connect(_on_combat_requested)
	
	if combat_scene and combat_scene.has_signal("combat_finished"):
		if combat_scene.combat_finished.is_connected(_on_combat_finished):
			combat_scene.combat_finished.disconnect(_on_combat_finished)
		combat_scene.combat_finished.connect(_on_combat_finished)

	anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
	buttonShop.connect("pressed", Callable(self, "_on_shop_button_pressed"))
	buttonShop.connect("mouse_entered", Callable(self, "_on_shop_hover"))
	buttonShop.connect("mouse_exited", Callable(self, "_on_shop_exit"))
	PlayerData.currency_changed.connect(_on_PlayerData_currency_changed)
	if inventory.has_signal("item_sold"):
		inventory.item_sold.connect(PlayerData.add_currency)
		
	if next_day_image:
		next_day_image.gui_input.connect(_on_next_day_image_input)

	blink_timer = randf_range(blink_interval_min, blink_interval_max)
	_on_PlayerData_currency_changed(PlayerData.get_current_currency())
	store.generate()
	
	_update_ui_labels()

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

func _update_ui_labels() -> void:
	if is_instance_valid(day_label):
		day_label.text = "Día " + str(current_day) + " / " + str(max_days)
	
	if is_instance_valid(gladiator_label):
		gladiator_label.text = "Gladiadores: %d/%d" % [gladiators_defeated, gladiators_per_day]
	
	if is_instance_valid(round_label):
		var state_text = ""
		match current_state:
			GameState.SHOP: state_text = " - Tienda"
			GameState.ROULETTE: state_text = " - ¡Gira la ruleta!"
			GameState.SPINNING: state_text = " - ¡Girando!"
			GameState.COMBAT: state_text = " - ¡Combate!"
		
		round_label.text = "Ronda %d/%d%s" % [current_round, rounds_per_day, state_text]

## ------------------------------------------------------------------
## Máquina de Estados
## ------------------------------------------------------------------

func set_state(new_state: GameState):
	if current_state == new_state: return
	if anim.is_playing(): return

	print("Cambiando de estado: %s -> %s" % [GameState.keys()[current_state], GameState.keys()[new_state]])
	current_state = new_state
	_update_ui_labels()

	match current_state:
		GameState.SHOP:
			_toggle_store(false)
			buttonShop.disabled = false
			inventory.set_interactive(true)
		GameState.ROULETTE:
			_toggle_store(true)
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
## Lógica Principal (MODIFICADA)
## ------------------------------------------------------------------

func _on_combat_requested(piece_resource: Resource):
	if piece_resource and piece_resource is PieceRes:
		set_state(GameState.COMBAT)
	else:
		print("Giro en vacío. Pasando a siguiente ronda.")
		_on_combat_finished(false)

func _on_combat_finished(player_won: bool = false):
	var round_income = int(gold_round_base * gold_day_mult)
	PlayerData.add_currency(round_income)
	
	if player_won:
		gladiators_defeated += 1
	
	# COMPROBAMOS SI SE ACABÓ EL DÍA
	if current_round >= rounds_per_day:
		print("¡Fin del Día %d! Verificando cuota..." % current_day)
		
		if gladiators_defeated >= gladiators_per_day:
			# 3. NUEVO: Comprobar si es el último día para GANAR
			if current_day >= max_days:
				print("¡Juego Completado! Victoria.")
				_show_win_view()
			else:
				print("Cuota cumplida. Pasando a Siguiente Día.")
				_show_day_finished_view()
		else:
			print("Cuota NO cumplida (%d/%d). GAME OVER." % [gladiators_defeated, gladiators_per_day])
			_show_game_over_view()
			
	else:
		current_round += 1
		print("--- Empezando Ronda %d ---" % current_round)
		_update_ui_labels()
		set_state(GameState.SHOP)
		store.generate()

# --- Funciones de Vistas (DayFinished, GameOver & Win) ---

func _show_day_finished_view() -> void:
	if day_finished_view:
		day_finished_view.visible = true
		buttonShop.disabled = true
	else:
		_advance_to_next_day()

func _show_game_over_view() -> void:
	if game_over_view:
		game_over_view.visible = true
		buttonShop.disabled = true
	else:
		push_error("GameManager: No se encontró el nodo 'GameOver'.")

# 4. NUEVO: Función para mostrar Victoria
func _show_win_view() -> void:
	if win_view:
		win_view.visible = true
		buttonShop.disabled = true
		# Aquí podrías detener timers o poner música de victoria
	else:
		push_error("GameManager: No se encontró el nodo 'Win'.")

func _on_next_day_image_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Click en imagen de Siguiente Día recibido.")
		_advance_to_next_day()

func _advance_to_next_day() -> void:
	print("Iniciando Día %d..." % (current_day + 1))
	
	current_day += 1
	current_round = 1
	gladiators_defeated = 0 
	
	if day_finished_view:
		day_finished_view.visible = false
	
	buttonShop.disabled = false
	
	_update_ui_labels()
	set_state(GameState.SHOP)
	store.generate()

## ------------------------------------------------------------------
## Resto de Funciones
## ------------------------------------------------------------------
# ... (El resto de funciones auxiliares siguen igual) ...

func _on_shop_button_pressed():
	if anim.is_playing(): return
	if current_state == GameState.SHOP:
		set_state(GameState.ROULETTE)
	elif current_state == GameState.ROULETTE:
		set_state(GameState.SHOP)

func _on_roulette_spin_started():
	set_state(GameState.SPINNING)

func _give_initial_piece():
	if not inventory.has_method("get_random_initial_piece"): return
	var initial_piece: Resource = inventory.get_random_initial_piece()
	if initial_piece and inventory.can_add_item(initial_piece):
		inventory.add_item(initial_piece)

func _toggle_store(close_store: bool):
	if anim.is_playing(): return
	is_tended = close_store
	_update_eye_state()
	if not is_tended: roulette.visible = false
	if is_tended:
		anim.play("roll")
		animate_store(true, Callable(self, "_on_store_hidden"))
	else:
		store.visible = true
		anim.play("unroll")
		animate_store(false)
	var target = 1.0 if is_tended else 0.0
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/roll_amount", target, 0.6)

func _on_animation_finished(anim_name: String):
	roulette.visible = is_tended
	if anim_name == "roll": store.visible = false

func _on_PlayerData_currency_changed(new_amount: int) -> void:
	if gold_label: gold_label.text = str(new_amount) + "€"

func _toggle_eye_parpadeo() -> void:
	if not is_tended: return
	sprite_show.texture = eye_closed_texture
	await get_tree().create_timer(0.07).timeout
	sprite_show.texture = original_eye_texture

func _update_pupil_position():
	if not pupil.visible or not sprite_show.visible: return
	var mouse_global = get_global_mouse_position()
	var dir = mouse_global - sprite_show.global_position
	if dir.length() > max_distance: dir = dir.normalized() * max_distance
	pupil.position = pupil_offset + dir

func _on_shop_hover():
	if blink_tween and blink_tween.is_valid(): blink_tween.kill()
	blink_tween = create_tween()
	blink_tween.tween_property(sprite_show, "modulate:a", 0.5, 0.12)
	blink_tween.tween_property(sprite_show, "modulate:a", 1.0, 0.12)

func _on_shop_exit():
	if blink_tween and blink_tween.is_valid(): blink_tween.kill()
	sprite_show.modulate.a = 1.0

func _update_eye_state():
	if is_tended:
		sprite_show.texture = original_eye_texture
		pupil.visible = true
	else:
		sprite_show.texture = eye_closed_texture
		pupil.visible = false

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
		if not (child is CanvasItem): continue
		var orig_pos = original_positions.get(child, child.position)
		var offset = Vector2(200, 0)
		var target_pos = orig_pos + offset if hide else orig_pos
		var target_alpha = 0.0 if hide else 1.0
		tween.parallel().tween_property(child, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		tween.parallel().tween_property(child, "modulate:a", target_alpha, 0.5).set_delay(delay)
		delay += 0.05
	if callback.is_valid(): tween.tween_callback(callback)

func _on_store_hidden(): store.visible = false

func pausar():
	var pause_instance = pause_scene.instantiate()
	add_child(pause_instance)
	get_tree().paused = true
	
func get_inventory_piece_count(resource_to_check: Resource) -> int:
	var item_to_search = resource_to_check
	if resource_to_check is PieceData: item_to_search = resource_to_check.piece_origin
	if inventory and inventory.has_method("get_item_count"):
		return inventory.get_item_count(item_to_search)
	return 0
